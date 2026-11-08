using KingmakerCutsceneSkip.Core;
using KingmakerCutsceneSkip.Input;
using UnityEngine;

namespace KingmakerCutsceneSkip.Tests
{
    public static class SkipInputGateTests
    {
        private sealed class GateFixture
        {
            public readonly ControllerFixture Skip = new ControllerFixture();
            public readonly FakeKeyboard Keyboard = new FakeKeyboard();
            public readonly SkipInputGate Gate;
            public bool Enabled = true;

            public GateFixture()
            {
                Gate = new SkipInputGate(Keyboard, Skip.Controller, new[] { KeyCode.Return, KeyCode.KeypadEnter }, KeyCode.Escape, () => Enabled);
            }

            public void Frame()
            {
                Keyboard.NextFrame();
                Gate.Poll();
            }
        }

        public static void EnterInCinematicStartsOneSkipAndIsHidden()
        {
            GateFixture f = new GateFixture();
            f.Keyboard.Press(KeyCode.Return);
            AssertEx.True(f.Gate.IsClaimed(KeyCode.Return), "initiating press hidden from bindings");
            AssertEx.True(f.Skip.Controller.IsSkipping, "skip started");
            AssertEx.Equal(1, f.Skip.Scope.BeginCount, "exactly one operation");
        }

        public static void KeypadEnterAlsoStartsASkip()
        {
            GateFixture f = new GateFixture();
            f.Keyboard.Press(KeyCode.KeypadEnter);
            AssertEx.True(f.Gate.IsClaimed(KeyCode.KeypadEnter), "claimed");
            AssertEx.True(f.Skip.Controller.IsSkipping, "skip started");
        }

        public static void EnterOutsideCinematicReachesTheGame()
        {
            GateFixture f = new GateFixture();
            f.Skip.Probe.Blocker = SkipStartBlocker.NotInCutsceneMode;
            f.Keyboard.Press(KeyCode.Return);
            AssertEx.False(f.Gate.IsClaimed(KeyCode.Return), "unclaimed: normal Enter behaviour");
            AssertEx.False(f.Skip.Controller.IsSkipping, "no skip");
        }

        public static void HeldEnterDoesNotStartAnotherOperation()
        {
            GateFixture f = new GateFixture();
            f.Keyboard.Press(KeyCode.Return);
            f.Gate.Poll();
            f.Skip.Probe.Boundary = SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog");
            f.Skip.Controller.Tick();
            for (int frame = 0; frame < 10; frame++) f.Frame();
            AssertEx.Equal(1, f.Skip.Scope.BeginCount, "held key never restarts");
            AssertEx.True(f.Gate.IsClaimed(KeyCode.Return), "still hidden while held");
        }

        public static void ClaimCoversTheReleaseFrameThenEnds()
        {
            GateFixture f = new GateFixture();
            f.Keyboard.Press(KeyCode.Return);
            f.Gate.Poll();
            f.Keyboard.Release(KeyCode.Return);
            AssertEx.True(f.Gate.IsClaimed(KeyCode.Return), "key-up of the initiating press is hidden (release-triggered bindings)");
            f.Frame();
            AssertEx.False(f.Gate.IsClaimed(KeyCode.Return), "claim ends after release");
        }

        public static void RepeatedPressesDuringSkipAreSwallowed()
        {
            GateFixture f = new GateFixture();
            f.Keyboard.Press(KeyCode.Return);
            f.Gate.Poll();
            f.Keyboard.Release(KeyCode.Return);
            f.Frame();
            f.Keyboard.Press(KeyCode.Return);
            AssertEx.True(f.Gate.IsClaimed(KeyCode.Return), "second press hidden");
            AssertEx.Equal(1, f.Skip.Scope.BeginCount, "no overlapping operation");
        }

        public static void PressRightAfterRevealIsSwallowedThenNormal()
        {
            GateFixture f = new GateFixture();
            f.Skip.StartAndAdvance();
            f.Skip.Controller.NotifyBoundary(SkipBoundary.Of(SkipEndReason.InteractionBoundary, "Dialog"));
            f.Skip.FadeHost.State = FadeVisualState.Hidden;
            f.Skip.Controller.Tick();
            f.Keyboard.Press(KeyCode.Return);
            AssertEx.True(f.Gate.IsClaimed(KeyCode.Return), "mash-through guard");
            f.Keyboard.Release(KeyCode.Return);
            f.Frame();
            f.Skip.Clock.Advance(f.Skip.Tuning.PostRevealInputGuardSeconds + 0.01);
            f.Skip.Probe.Blocker = SkipStartBlocker.NotInCutsceneMode;
            f.Keyboard.Press(KeyCode.Return);
            AssertEx.False(f.Gate.IsClaimed(KeyCode.Return), "dialogue receives Enter normally after the guard");
        }

        public static void EscapeCancelsOnlyDuringASkip()
        {
            GateFixture f = new GateFixture();
            f.Keyboard.Press(KeyCode.Escape);
            AssertEx.False(f.Gate.IsClaimed(KeyCode.Escape), "Escape is normal outside a skip");

            f.Keyboard.Release(KeyCode.Escape);
            f.Frame();
            f.Keyboard.Press(KeyCode.Return);
            f.Gate.Poll();
            f.Keyboard.Press(KeyCode.Escape);
            AssertEx.True(f.Gate.IsClaimed(KeyCode.Escape), "Escape hidden so the menu does not open");
            AssertEx.Equal(SkipEndReason.Cancelled, f.Skip.Controller.LastReport.Reason, "cancelled");
        }

        public static void DisabledGateClaimsNothing()
        {
            GateFixture f = new GateFixture();
            f.Enabled = false;
            f.Keyboard.Press(KeyCode.Return);
            AssertEx.False(f.Gate.IsClaimed(KeyCode.Return), "unclaimed");
            AssertEx.False(f.Skip.Controller.IsSkipping, "no skip");
        }

        public static void PollingTwiceInOneFrameActsOnce()
        {
            GateFixture f = new GateFixture();
            f.Keyboard.Press(KeyCode.Return);
            f.Gate.Poll();
            f.Skip.Controller.TryCancel();
            f.Gate.Poll();
            AssertEx.Equal(1, f.Skip.Scope.BeginCount, "the same key-down is not processed twice");
        }
    }
}
