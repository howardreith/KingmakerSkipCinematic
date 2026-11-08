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
