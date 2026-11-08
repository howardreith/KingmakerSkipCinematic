using System;
using KingmakerCutsceneSkip.Input;
using KingmakerCutsceneSkip.Logging;

namespace KingmakerCutsceneSkip.Core
{
    /// <summary>
    /// Owns the lifecycle of skip operations: Idle → FadingOut → Advancing → Revealing → Idle.
    /// It is the single owner of every temporary override (fade claim, audio mute, time scale, scope)
    /// and releases all of them on every exit path. It never completes, removes or reorders story commands;
    /// the engine keeps executing the cutscene, only faster and behind a black screen.
    /// </summary>
    public sealed class CutsceneSkipController : ISkipCommandSink
    {
        private readonly IGameStateProbe probe;
        private readonly ISkipScope scope;
        private readonly IScreenFade fade;
        private readonly ITimeScaleOverride timeScale;
        private readonly IAudioMute audio;
        private readonly IClock clock;
        private readonly SkipTuning tuning;
        private readonly IModLogger logger;
        private readonly ProgressWatchdog watchdog;

        private int operationId;
        private double operationStartedAt;
        private double phaseStartedAt;
        private double fadeOutSeconds;
        private bool reachedFullBlack;
        private double inputGuardUntil = double.NegativeInfinity;

        public CutsceneSkipController(
            IGameStateProbe probe,
            ISkipScope scope,
            IScreenFade fade,
            ITimeScaleOverride timeScale,
            IAudioMute audio,
            IClock clock,
            SkipTuning tuning,
            IModLogger logger)
        {
            this.probe = probe ?? throw new ArgumentNullException(nameof(probe));
            this.scope = scope ?? throw new ArgumentNullException(nameof(scope));
            this.fade = fade ?? throw new ArgumentNullException(nameof(fade));
            this.timeScale = timeScale ?? throw new ArgumentNullException(nameof(timeScale));
            this.audio = audio ?? throw new ArgumentNullException(nameof(audio));
            this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
            this.tuning = tuning ?? throw new ArgumentNullException(nameof(tuning));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
            watchdog = new ProgressWatchdog(tuning.StallTimeoutSeconds, tuning.MaximumAdvanceSeconds);
        }

        public event Action<SkipOperationReport> OperationEnded;

        public SkipPhase Phase { get; private set; } = SkipPhase.Idle;

        /// <summary>True while the operation holds overrides (fading out or advancing).</summary>
        public bool IsSkipping => Phase == SkipPhase.FadingOut || Phase == SkipPhase.Advancing;

        /// <summary>True while presses of the skip key must not reach the game.</summary>
        public bool ShouldSwallowSkipKey => Phase != SkipPhase.Idle || clock.RealTimeSeconds < inputGuardUntil;

        public SkipOperationReport LastReport { get; private set; }

        public SkipStartBlocker LastDeclineReason { get; private set; }

        /// <summary>Number of operations started since the mod loaded (diagnostics and native test assertions).</summary>
        public int StartedOperations => operationId;

        /// <summary>Starts one operation if the game is in an eligible cinematic. Never overlaps operations.</summary>
        public bool TryStart()
        {
            if (Phase != SkipPhase.Idle) return false;

            SkipStartBlocker blocker = probe.GetStartBlocker();
            if (blocker == SkipStartBlocker.None && !fade.TryAcquire()) blocker = SkipStartBlocker.FadeUnavailable;
            LastDeclineReason = blocker;
            if (blocker != SkipStartBlocker.None)
            {
                logger.Verbose("Skip request declined: " + blocker);
                return false;
            }

            operationId++;
            operationStartedAt = clock.RealTimeSeconds;
            fadeOutSeconds = 0;
            reachedFullBlack = false;
            try
            {
                scope.Begin();
                audio.Mute();
            }
            catch (Exception exception)
            {
                logger.Exception("Begin cutscene skip", exception);
                EnterPhase(SkipPhase.FadingOut);
                End(SkipEndReason.Error, exception.GetType().Name);
                return true;
            }

            EnterPhase(SkipPhase.FadingOut);
            logger.Info("Skip #" + operationId + " started: " + scope.DescribePlayingCommands());
            return true;
        }

        /// <summary>Cancels the active operation, revealing the scene at its current progress.</summary>
        public bool TryCancel()
        {
            if (!IsSkipping) return false;
            End(SkipEndReason.Cancelled, "Escape");
            return true;
        }

        /// <summary>Ends the active operation from an external lifecycle event (disable, unload, teardown).</summary>
        public void Abort(SkipEndReason reason, string detail)
        {
            if (IsSkipping)
            {
                End(reason, detail);
            }
        }

        /// <summary>
        /// Ends the active operation and returns straight to Idle, for when the mod will stop receiving frame updates
        /// (disable/unload) and so could never observe the reveal finishing.
        /// </summary>
        public void Shutdown(SkipEndReason reason, string detail)
        {
            Abort(reason, detail);
            EnterPhase(SkipPhase.Idle);
            inputGuardUntil = double.NegativeInfinity;
        }

        /// <summary>Immediate notification from the engine's game-mode events, so acceleration stops in the same tick.</summary>
        public void NotifyBoundary(SkipBoundary boundary)
        {
            if (IsSkipping && boundary.IsReached) End(boundary.Reason.Value, boundary.Detail);
        }

        /// <summary>
        /// Called between the game ticks of an accelerated frame: re-evaluates every boundary so acceleration stops at the
        /// same game tick at which normal playback would hand over. Returns false once the operation is no longer advancing.
        /// </summary>
        public bool ContinueAdvancing()
        {
            if (Phase != SkipPhase.Advancing) return false;
            try
            {
                return !EndIfBoundaryReached();
            }
            catch (Exception exception)
            {
                logger.Exception("Check cutscene skip boundary", exception);
                if (IsSkipping) End(SkipEndReason.Error, exception.GetType().Name);
                return false;
            }
        }

        /// <summary>Called once per rendered frame.</summary>
        public void Tick()
        {
            try
            {
                switch (Phase)
                {
                    case SkipPhase.FadingOut:
                        TickFadingOut();
                        break;
                    case SkipPhase.Advancing:
                        TickAdvancing();
                        break;
                    case SkipPhase.Revealing:
                        TickRevealing();
                        break;
                }
            }
            catch (Exception exception)
            {
                logger.Exception("Tick cutscene skip", exception);
                if (IsSkipping) End(SkipEndReason.Error, exception.GetType().Name);
                else if (Phase == SkipPhase.Revealing) Phase = SkipPhase.Idle;
            }
        }

        private void TickFadingOut()
        {
            if (EndIfBoundaryReached()) return;

            double elapsed = clock.RealTimeSeconds - phaseStartedAt;
            bool faded = fade.IsFullyFaded;
            if (!faded)
            {
                // Never accelerate a scene the player can still see: reveal it and let it continue normally.
                if (elapsed >= tuning.FadeOutTimeoutSeconds) End(SkipEndReason.FadeTimeout, "screen not black after " + tuning.FadeOutTimeoutSeconds + "s");
                return;
            }

            reachedFullBlack = true;
            fadeOutSeconds = elapsed;
            scope.PrepareActiveCommandsForAcceleration();
            timeScale.Apply(tuning.TimeScale);
            watchdog.Reset(clock.RealTimeSeconds, scope.ProgressFingerprint);
            EnterPhase(SkipPhase.Advancing);
        }

        private void TickAdvancing()
        {
            if (EndIfBoundaryReached()) return;

            SkipEndReason? limit = watchdog.Observe(clock.RealTimeSeconds, scope.ProgressFingerprint);
            if (limit.HasValue) End(limit.Value, "playing: " + scope.DescribePlayingCommands());
        }

        private void TickRevealing()
        {
            double elapsed = clock.RealTimeSeconds - phaseStartedAt;
            if (fade.IsRevealed || elapsed >= tuning.RevealTimeoutSeconds)
            {
                inputGuardUntil = clock.RealTimeSeconds + tuning.PostRevealInputGuardSeconds;
                EnterPhase(SkipPhase.Idle);
            }
        }

        private bool EndIfBoundaryReached()
        {
            SkipBoundary boundary = probe.GetBoundary(scope);
            if (!boundary.IsReached) return false;
            End(boundary.Reason.Value, boundary.Detail);
            return true;
        }

        private void End(SkipEndReason reason, string detail)
        {
            double now = clock.RealTimeSeconds;
            bool wasAdvancing = Phase == SkipPhase.Advancing;
            SkipOperationReport report = new SkipOperationReport
            {
                OperationId = operationId,
                Reason = reason,
                Detail = detail,
                FadeOutSeconds = wasAdvancing ? fadeOutSeconds : now - phaseStartedAt,
                AdvanceSeconds = wasAdvancing ? now - phaseStartedAt : 0,
                TotalHeldSeconds = now - operationStartedAt,
                ReachedFullBlack = reachedFullBlack,
                ProgressEvents = wasAdvancing ? watchdog.ProgressEvents : 0
            };

            // Release in reverse order of acquisition. Each release is independent so one failure cannot strand another override.
            Release("restore time scale", timeScale.Restore);
            Release("describe playing commands", () => report.PlayingCommandsAtEnd = scope.DescribePlayingCommands());
            Release("end skip scope", scope.End);
            Release("restore audio", audio.Restore);
            Release("release screen fade", fade.Release);

            EnterPhase(SkipPhase.Revealing);
            LastReport = report;
            if (reason == SkipEndReason.Error || reason == SkipEndReason.Stalled || reason == SkipEndReason.Watchdog ||
                reason == SkipEndReason.FadeTimeout)
            {
                logger.Warning(report.ToString());
            }
            else
            {
                logger.Info(report.ToString());
            }

            try
            {
                OperationEnded?.Invoke(report);
            }
            catch (Exception exception)
            {
                logger.Exception("Notify skip operation ended", exception);
            }
        }

        private void Release(string operation, Action release)
        {
            try
            {
                release();
            }
            catch (Exception exception)
            {
                logger.Exception(operation, exception);
            }
        }

        private void EnterPhase(SkipPhase phase)
        {
            Phase = phase;
            phaseStartedAt = clock.RealTimeSeconds;
        }
    }
}
