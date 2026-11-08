using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Tests
{
    public static class OverrideOwnershipTests
    {
        public static void TimeScaleRestoresCapturedPriorValue()
        {
            FakeTimeScaleHost host = new FakeTimeScaleHost { Scale = 1.5f };
            TimeScaleOverride scale = new TimeScaleOverride(host, new RecordingLogger());
            scale.Apply(10f);
            AssertEx.Equal(10f, host.Scale, "applied");
            scale.Restore();
            AssertEx.Equal(1.5f, host.Scale, "prior restored, not blindly 1");
        }

        public static void TimeScaleLeavesAnotherOwnersChange()
        {
            FakeTimeScaleHost host = new FakeTimeScaleHost();
            TimeScaleOverride scale = new TimeScaleOverride(host, new RecordingLogger());
            scale.Apply(10f);
            host.Scale = 2f;
            scale.Restore();
            AssertEx.Equal(2f, host.Scale, "later owner wins");
        }

        public static void TimeScaleNeverSlowsAFasterPriorScale()
        {
            FakeTimeScaleHost host = new FakeTimeScaleHost { Scale = 20f };
            TimeScaleOverride scale = new TimeScaleOverride(host, new RecordingLogger());
            scale.Apply(10f);
            AssertEx.Equal(20f, host.Scale, "unchanged");
            scale.Restore();
            AssertEx.Equal(20f, host.Scale, "unchanged after restore");
        }

        public static void TimeScaleIgnoresAReplacedController()
        {
            FakeTimeScaleHost host = new FakeTimeScaleHost();
            TimeScaleOverride scale = new TimeScaleOverride(host, new RecordingLogger());
            scale.Apply(10f);
            host.Identity = new object();
            host.Scale = 1f;
            scale.Restore();
            AssertEx.Equal(1f, host.Scale, "new controller untouched");
            AssertEx.False(scale.IsApplied, "no longer applied");
        }

        public static void FadeReleaseIsIdempotent()
        {
            FakeFadeHost host = new FakeFadeHost();
            ScreenFadeOverride fade = new ScreenFadeOverride(host);
            fade.TryAcquire();
            fade.TryAcquire();
            fade.Release();
            fade.Release();
            AssertEx.Equal(1, host.ShowCalls, "one claim");
            AssertEx.Equal(1, host.HideCalls, "one release");
        }

        public static void FadeClaimIsVoidedByGameReset()
        {
            FakeFadeHost host = new FakeFadeHost();
            ScreenFadeOverride fade = new ScreenFadeOverride(host);
            fade.TryAcquire();
            host.ForceReset();
            host.State = FadeVisualState.Shown;
            AssertEx.False(fade.IsFullyFaded, "a voided claim does not count as our black screen");
            fade.Release();
            AssertEx.Equal(0, host.HideCalls, "no decrement after reset");
        }

        public static void AudioRestoreReappliesLivePlayerSetting()
        {
            FakeVolumeHost host = new FakeVolumeHost();
            AudioMuteOverride audio = new AudioMuteOverride(host, () => true, 250);
            audio.Mute();
            host.PlayerSetting = 35f; // the player changed the setting meanwhile
            audio.Restore();
            AssertEx.Equal(35f, host.Level, "live setting, not a stale capture");
            audio.Restore();
            AssertEx.Equal(1, host.RestoreCalls, "restore is idempotent");
        }

        public static void ProgressWatchdogDistinguishesStallFromProgress()
        {
            ProgressWatchdog watchdog = new ProgressWatchdog(2, 10);
            watchdog.Reset(0, "a");
            AssertEx.Equal<SkipEndReason?>(null, watchdog.Observe(1.5, "a"), "within stall budget");
            AssertEx.Equal<SkipEndReason?>(null, watchdog.Observe(3, "b"), "progress");
            AssertEx.Equal(SkipEndReason.Stalled, watchdog.Observe(5.1, "b").Value, "stalled");
            AssertEx.Equal(1, watchdog.ProgressEvents, "one progress event");
        }
    }
}
