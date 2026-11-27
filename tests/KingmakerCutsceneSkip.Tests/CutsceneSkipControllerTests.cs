using System;
using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Tests
{
    public static class CutsceneSkipControllerTests
    {
        public static void StartAcquiresFadeAndAudioButNotTimeScale()
        {
            ControllerFixture f = new ControllerFixture();
            AssertEx.True(f.Controller.TryStart(), "start accepted");
            AssertEx.Equal(SkipPhase.FadingOut, f.Controller.Phase, "fading out");
            AssertEx.Equal(1, f.FadeHost.ReferenceCount, "fade claimed once");
            AssertEx.Equal(0f, f.VolumeHost.Level, "audio fading to silence");
            AssertEx.Equal(1f, f.TimeHost.Scale, "no acceleration before the screen is black");
            AssertEx.True(f.Scope.IsActive, "scope begun");
        }

        public static void AccelerationBeginsOnlyWhenScreenIsFullyBlack()
        {
            ControllerFixture f = new ControllerFixture();
            f.Controller.TryStart();
            f.Clock.Advance(0.1);
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.FadingOut, f.Controller.Phase, "still fading");
            f.FadeHost.State = FadeVisualState.Shown;
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Advancing, f.Controller.Phase, "advancing");
            AssertEx.Equal(f.Tuning.TimeScale, f.TimeHost.Scale, "accelerated");
            AssertEx.Equal(1, f.Scope.PrepareCount, "running commands prepared once");
        }

        public static void FadeTimeoutRevealsWithoutEverAccelerating()
        {
            ControllerFixture f = new ControllerFixture();
            f.Controller.TryStart();
            f.Clock.Advance(f.Tuning.FadeOutTimeoutSeconds - 0.01);
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.FadingOut, f.Controller.Phase, "still waiting for black before the timeout");
            f.Clock.Advance(0.02);
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "revealing after the timeout");
            AssertEx.Equal(SkipEndReason.FadeTimeout, f.Controller.LastReport.Reason, "reason");
            AssertEx.False(f.Controller.LastReport.ReachedFullBlack, "report says full black was not reached");
            AssertEx.Equal(0, f.TimeHost.SetCalls, "time scale never touched while the scene could be visible");
            AssertEx.Equal(0, f.Scope.PrepareCount, "no command prepared for acceleration");
            f.AssertAllOverridesReleased();
        }

        public static void ContinueAdvancingIsTrueUntilABoundaryThenEndsTheSkip()
        {
            ControllerFixture f = new ControllerFixture();
            AssertEx.False(f.Controller.ContinueAdvancing(), "idle: nothing to continue");
            f.Controller.TryStart();
            AssertEx.False(f.Controller.ContinueAdvancing(), "fading out: not accelerating yet");
            f.FadeHost.State = FadeVisualState.Shown;
            f.Clock.Advance(0.3);
            f.Controller.Tick();
            AssertEx.True(f.Controller.ContinueAdvancing(), "advancing without a boundary");
            f.Probe.Boundary = SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog");
            AssertEx.False(f.Controller.ContinueAdvancing(), "boundary stops the frame");
            AssertEx.Equal(SkipEndReason.InteractionBoundary, f.Controller.LastReport.Reason, "ended at the boundary");
            f.AssertAllOverridesReleased();
        }

        public static void ContinueAdvancingProbeExceptionEndsWithError()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Probe.ThrowOnBoundary = new InvalidOperationException("probe");
            AssertEx.False(f.Controller.ContinueAdvancing(), "stops");
            AssertEx.Equal(SkipEndReason.Error, f.Controller.LastReport.Reason, "error reason");
            f.AssertAllOverridesReleased();
        }

        public static void ReportShowsGameTimeAdvancedAgainstRealTime()
        {
            // The log line a player can send must tell an accelerated skip from one that ran at ordinary speed.
            ControllerFixture f = new ControllerFixture();
            f.Probe.GameTime = 1000;
            f.StartAndAdvance();
            f.Probe.GameTime = 1163.2;
            f.Clock.Advance(16.5);
            f.Probe.Boundary = SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog");
            f.Controller.Tick();
            SkipOperationReport report = f.Controller.LastReport;
            AssertEx.Equal(163.2, Math.Round(report.GameSecondsAdvanced, 3), "game time measured from the start of advancing");
            AssertEx.True(report.ToString().Contains("advance 16.50s (163.20 game s, x9.9)"), "report: " + report);

            ControllerFixture slow = new ControllerFixture();
            slow.Probe.GameTime = 50;
            slow.StartAndAdvance();
            slow.Probe.GameTime = 60;
            slow.Clock.Advance(10);
            slow.Probe.Boundary = SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog");
            slow.Controller.Tick();
            AssertEx.True(slow.Controller.LastReport.ToString().Contains("advance 10.00s (10.00 game s, x1.0)"),
                "ordinary-speed advancing is visible in the report: " + slow.Controller.LastReport);
        }

        public static void ReportOmitsGameTimeWhenItIsUnknownOrNothingAdvanced()
        {
            ControllerFixture unknown = new ControllerFixture();
            unknown.Probe.GameTime = double.NaN;
            unknown.StartAndAdvance();
            unknown.Clock.Advance(2);
            unknown.Probe.Boundary = SkipBoundary.Of(SkipEndReason.Loading, "loading process");
            unknown.Controller.Tick();
            AssertEx.False(unknown.Controller.LastReport.ToString().Contains("game s"), "no ratio without a game time");

            ControllerFixture fading = new ControllerFixture();
            fading.Probe.GameTime = 10;
            fading.Controller.TryStart();
            fading.Controller.TryCancel();
            AssertEx.Equal(0.0, fading.Controller.LastReport.GameSecondsAdvanced, "nothing advanced during fade-out");
            AssertEx.False(fading.Controller.LastReport.ToString().Contains("game s"), "no ratio for a cancelled fade-out");
        }

        public static void LostAccelerationRevealsEvenWhenCommandsProgress()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.TimeHost.Scale = 1f;
            f.Scope.Fingerprint = "next command";
            f.Clock.Advance(0.1);
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "reveal immediately despite command progress");
            AssertEx.Equal(SkipEndReason.TimeScaleUnavailable, f.Controller.LastReport.Reason, "report the lost multiplier");
            AssertEx.True(f.Logger.Lines.Exists(line => line.StartsWith("W ") && line.Contains("TimeScaleUnavailable")),
                "the failure is logged even without verbose diagnostics");
            f.AssertAllOverridesReleased();
        }

        public static void ContinueAdvancingStopsWhenAccelerationIsLost()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.TimeHost.Scale = 1f;
            AssertEx.False(f.Controller.ContinueAdvancing(), "stop before another substep");
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "reveal without waiting for a rendered-frame update");
            f.AssertAllOverridesReleased();
        }

        public static void MissingTimeControllerRevealsWithoutEnteringAdvancing()
        {
            ControllerFixture f = new ControllerFixture();
            f.TimeHost.Identity = null;
            AssertEx.True(f.Controller.TryStart(), "start accepted before the fade completes");
            f.FadeHost.State = FadeVisualState.Shown;
            f.Clock.Advance(0.3);
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "reveal when acceleration cannot be applied");
            AssertEx.Equal(SkipEndReason.TimeScaleUnavailable, f.Controller.LastReport.Reason, "report unavailable acceleration");
            AssertEx.Equal(0, f.TimeHost.SetCalls, "no time controller was written");
            AssertEx.Equal(0, f.Scope.PrepareCount, "do not interrupt presentation without acquiring acceleration");
            AssertEx.Equal(0.0, f.Controller.LastReport.AdvanceSeconds, "never entered advancement");
            f.AssertAllOverridesReleased();
        }

        public static void ReplacedTimeControllerRevealsEvenWithTheSameScale()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.TimeHost.Identity = new object();
            int writesBefore = f.TimeHost.SetCalls;
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "the original controller no longer owns acceleration");
            AssertEx.Equal(f.Tuning.TimeScale, f.TimeHost.Scale, "replacement controller remains untouched");
            AssertEx.Equal(writesBefore, f.TimeHost.SetCalls, "do not restore onto the replacement controller");
            AssertEx.Equal(f.VolumeHost.PlayerSetting, f.VolumeHost.Level, "audio restored");
            AssertEx.Equal(0, f.FadeHost.ReferenceCount, "fade claim released");
            AssertEx.False(f.Scope.IsActive, "scope ended");
        }

        public static void LostAccelerationPreservesAnotherOwnersScale()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.TimeHost.Scale = 2f;
            int writesBefore = f.TimeHost.SetCalls;
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "reveal when another owner changes the scale");
            AssertEx.Equal(2f, f.TimeHost.Scale, "the newer owner's speed survives");
            AssertEx.Equal(writesBefore, f.TimeHost.SetCalls, "neither reapply acceleration nor restore a stale speed");
            AssertEx.Equal(f.VolumeHost.PlayerSetting, f.VolumeHost.Level, "audio restored");
            AssertEx.Equal(0, f.FadeHost.ReferenceCount, "fade claim released");
            AssertEx.False(f.Scope.IsActive, "scope ended");
        }

        public static void UnchangedFasterPriorScaleKeepsAdvancing()
        {
            ControllerFixture f = new ControllerFixture();
            f.TimeHost.Scale = 20f;
            f.StartAndAdvance();
            f.Clock.Advance(0.1);
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Advancing, f.Controller.Phase, "a faster captured speed is still valid");
            AssertEx.True(f.Controller.ContinueAdvancing(), "substeps may continue at the captured faster speed");
            AssertEx.Equal(20f, f.TimeHost.Scale, "never slow the existing speed");
            AssertEx.Equal(1, f.FadeHost.ReferenceCount, "keep the accelerated scene covered");
            f.Controller.TryCancel();
            AssertEx.Equal(20f, f.TimeHost.Scale, "the prior speed survives cancellation");
        }

        public static void InteractionBoundaryTakesPrecedenceOverLostAcceleration()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.TimeHost.Scale = 2f;
            f.Probe.Boundary = SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog");
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "reveal at the interaction boundary");
            AssertEx.Equal(SkipEndReason.InteractionBoundary, f.Controller.LastReport.Reason, "report the actual boundary");
            AssertEx.Equal(2f, f.TimeHost.Scale, "the external speed survives the boundary");
            AssertEx.Equal(f.VolumeHost.PlayerSetting, f.VolumeHost.Level, "audio restored");
            AssertEx.Equal(0, f.FadeHost.ReferenceCount, "fade claim released");
            AssertEx.False(f.Scope.IsActive, "scope ended");
        }

        public static void StartedOperationsCountsOnlyAcceptedStarts()
        {
            ControllerFixture f = new ControllerFixture();
            f.Probe.Blocker = SkipStartBlocker.NotInCutsceneMode;
            f.Controller.TryStart();
            AssertEx.Equal(0, f.Controller.StartedOperations, "declined request not counted");
            f.Probe.Blocker = SkipStartBlocker.None;
            f.Controller.TryStart();
            f.Controller.TryStart();
            AssertEx.Equal(1, f.Controller.StartedOperations, "overlapping request not counted");
        }

        public static void SecondStartWhileActiveIsRejected()
        {
            ControllerFixture f = new ControllerFixture();
            f.Controller.TryStart();
            AssertEx.False(f.Controller.TryStart(), "overlapping start rejected");
            AssertEx.Equal(1, f.FadeHost.ShowCalls, "no second fade claim");
            AssertEx.Equal(1, f.Scope.BeginCount, "no second scope");
        }

        public static void IneligibleRequestIsDeclinedWithoutSideEffects()
        {
            ControllerFixture f = new ControllerFixture();
            f.Probe.Blocker = SkipStartBlocker.NotInCutsceneMode;
            AssertEx.False(f.Controller.TryStart(), "declined");
            AssertEx.Equal(SkipPhase.Idle, f.Controller.Phase, "idle");
            AssertEx.Equal(0, f.FadeHost.ShowCalls, "no fade");
            AssertEx.Equal(0, f.VolumeHost.FadeCalls, "no mute");
            AssertEx.Equal(SkipStartBlocker.NotInCutsceneMode, f.Controller.LastDeclineReason, "reason recorded");
        }

        public static void MissingFadeDeclinesInsteadOfSkippingVisibly()
        {
            ControllerFixture f = new ControllerFixture();
            f.FadeHost.IsAvailable = false;
            AssertEx.False(f.Controller.TryStart(), "declined");
            AssertEx.Equal(SkipStartBlocker.FadeUnavailable, f.Controller.LastDeclineReason, "reason");
            AssertEx.Equal(0, f.Scope.BeginCount, "scope untouched");
        }

        public static void InteractionBoundaryReleasesEverything()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Probe.Boundary = SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog");
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "revealing");
            AssertEx.Equal(SkipEndReason.InteractionBoundary, f.Controller.LastReport.Reason, "reason");
            f.AssertAllOverridesReleased();
        }

        public static void ImmediateNotificationEndsWithinTheSameTick()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Controller.NotifyBoundary(SkipBoundary.Of(SkipEndReason.ControlReturned, "Default"));
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "ended without waiting for Tick");
            f.AssertAllOverridesReleased();
        }

        public static void NonBoundaryNotificationIsIgnored()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Controller.NotifyBoundary(SkipBoundary.None);
            AssertEx.Equal(SkipPhase.Advancing, f.Controller.Phase, "still advancing");
        }

        public static void BoundaryDuringFadeOutReleasesEverything()
        {
            ControllerFixture f = new ControllerFixture();
            f.Controller.TryStart();
            f.Probe.Boundary = SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog");
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Revealing, f.Controller.Phase, "revealing");
            f.AssertAllOverridesReleased();
        }

        public static void CancelRevealsWithoutTouchingTheScene()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            AssertEx.True(f.Controller.TryCancel(), "cancel accepted");
            AssertEx.Equal(SkipEndReason.Cancelled, f.Controller.LastReport.Reason, "reason");
            f.AssertAllOverridesReleased();
            AssertEx.False(f.Controller.TryCancel(), "second cancel is not consumed");
        }

        public static void CancelOutsideSkipIsNotConsumed()
        {
            ControllerFixture f = new ControllerFixture();
            AssertEx.False(f.Controller.TryCancel(), "nothing to cancel");
        }

        public static void StalledProgressRevealsNormalPlayback()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Clock.Advance(f.Tuning.StallTimeoutSeconds / 2);
            f.Scope.Fingerprint = "b";
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Advancing, f.Controller.Phase, "progress resets the stall timer");
            f.Clock.Advance(f.Tuning.StallTimeoutSeconds + 0.1);
            f.Controller.Tick();
            AssertEx.Equal(SkipEndReason.Stalled, f.Controller.LastReport.Reason, "stalled");
            f.AssertAllOverridesReleased();
        }

        public static void TotalWatchdogRevealsEvenWithProgress()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            for (int step = 0; step < 200 && f.Controller.IsSkipping; step++)
            {
                f.Clock.Advance(1);
                f.Scope.Fingerprint = "step" + step;
                f.Controller.Tick();
            }

            AssertEx.Equal(SkipEndReason.Watchdog, f.Controller.LastReport.Reason, "watchdog");
            f.AssertAllOverridesReleased();
        }

        public static void ExceptionDuringTickRevealsAndLogs()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Probe.ThrowOnBoundary = new InvalidOperationException("controlled fault");
            f.Controller.Tick();
            AssertEx.Equal(SkipEndReason.Error, f.Controller.LastReport.Reason, "error reason");
            f.AssertAllOverridesReleased();
            AssertEx.True(f.Logger.Lines.Exists(line => line.StartsWith("X ") && line.Contains("controlled fault")), "exception logged");
        }

        public static void AbortForDisableReleasesEverything()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Controller.Abort(SkipEndReason.Disabled, "test");
            AssertEx.Equal(SkipEndReason.Disabled, f.Controller.LastReport.Reason, "disabled");
            f.AssertAllOverridesReleased();
        }

        public static void ShutdownReleasesEverythingAndReturnsToIdle()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Controller.Shutdown(SkipEndReason.Disabled, "test");
            AssertEx.Equal(SkipPhase.Idle, f.Controller.Phase, "idle without waiting for a reveal tick");
            AssertEx.False(f.Controller.ShouldSwallowSkipKey, "no input guard left behind");
            AssertEx.Equal(SkipEndReason.Disabled, f.Controller.LastReport.Reason, "reported");
            f.AssertAllOverridesReleased();
        }

        public static void RevealCompletesThenGuardsInputBriefly()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Controller.TryCancel();
            AssertEx.True(f.Controller.ShouldSwallowSkipKey, "swallowing during reveal");
            f.FadeHost.State = FadeVisualState.Hidden;
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Idle, f.Controller.Phase, "idle after reveal");
            AssertEx.True(f.Controller.ShouldSwallowSkipKey, "guard window active");
            f.Clock.Advance(f.Tuning.PostRevealInputGuardSeconds + 0.01);
            AssertEx.False(f.Controller.ShouldSwallowSkipKey, "guard window over");
            AssertEx.True(f.Controller.TryStart(), "a new skip can start");
        }

        public static void RevealTimeoutReturnsToIdle()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.Controller.TryCancel();
            f.FadeHost.State = FadeVisualState.Shown; // another owner keeps the screen black
            f.Clock.Advance(f.Tuning.RevealTimeoutSeconds);
            f.Controller.Tick();
            AssertEx.Equal(SkipPhase.Idle, f.Controller.Phase, "idle after timeout");
        }

        public static void MutingDisabledLeavesAudioAlone()
        {
            ControllerFixture f = new ControllerFixture();
            f.MuteEnabled = false;
            f.StartAndAdvance();
            AssertEx.Equal(0, f.VolumeHost.FadeCalls, "no mute");
            f.Controller.TryCancel();
            AssertEx.Equal(0, f.VolumeHost.RestoreCalls, "no restore");
        }

        public static void LoadResetDuringSkipIsNotDoubleReleased()
        {
            ControllerFixture f = new ControllerFixture();
            f.StartAndAdvance();
            f.FadeHost.ForceReset();
            f.FadeHost.Show(); // the loading screen's own claim after the reset
            f.Controller.NotifyBoundary(SkipBoundary.Of(SkipEndReason.Loading, "area unloading"));
            AssertEx.Equal(1, f.FadeHost.ReferenceCount, "the loader's claim survives");
            AssertEx.Equal(0, f.FadeHost.HideCalls, "no stale release");
        }
    }
}
