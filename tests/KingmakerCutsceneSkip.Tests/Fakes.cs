using System;
using System.Collections.Generic;
using KingmakerCutsceneSkip.Core;
using KingmakerCutsceneSkip.Input;
using KingmakerCutsceneSkip.Logging;
using UnityEngine;

namespace KingmakerCutsceneSkip.Tests
{
    internal static class AssertEx
    {
        public static void True(bool value, string message)
        {
            if (!value) throw new InvalidOperationException(message);
        }

        public static void False(bool value, string message)
        {
            if (value) throw new InvalidOperationException(message);
        }

        public static void Equal<T>(T expected, T actual, string message)
        {
            if (!EqualityComparer<T>.Default.Equals(expected, actual))
            {
                throw new InvalidOperationException(message + " Expected <" + expected + ">, actual <" + actual + ">.");
            }
        }
    }

    internal sealed class FakeClock : IClock
    {
        public double RealTimeSeconds { get; set; } = 100;

        public void Advance(double seconds) => RealTimeSeconds += seconds;
    }

    internal sealed class RecordingLogger : IModLogger
    {
        public readonly List<string> Lines = new List<string>();

        public void Info(string message) => Lines.Add("I " + message);

        public void Warning(string message) => Lines.Add("W " + message);

        public void Error(string message) => Lines.Add("E " + message);

        public void Exception(string operation, Exception exception) => Lines.Add("X " + operation + ": " + exception.Message);

        public void Verbose(string message) => Lines.Add("V " + message);
    }

    internal sealed class FakeProbe : IGameStateProbe
    {
        public SkipStartBlocker Blocker = SkipStartBlocker.None;
        public SkipBoundary Boundary = SkipBoundary.None;
        public Exception ThrowOnBoundary;

        public SkipStartBlocker GetStartBlocker() => Blocker;

        public SkipBoundary GetBoundary(ISkipScope scope)
        {
            if (ThrowOnBoundary != null) throw ThrowOnBoundary;
            return Boundary;
        }
    }

    internal sealed class FakeScope : ISkipScope
    {
        public int BeginCount;
        public int EndCount;
        public int PrepareCount;
        public string Fingerprint = "a";

        public bool IsActive { get; private set; }

        public bool HasLiveCutscene => IsActive;

        public string BoundaryCommand => null;

        public string ProgressFingerprint => Fingerprint;

        public void Begin()
        {
            BeginCount++;
            IsActive = true;
        }

        public void End()
        {
            EndCount++;
            IsActive = false;
        }

        public string DescribePlayingCommands() => "FakeCutscene[t0:CommandDelay]";

        public void PrepareActiveCommandsForAcceleration() => PrepareCount++;
    }

    internal sealed class FakeFadeHost : IManualFadeHost
    {
        public bool IsAvailable { get; set; } = true;
        public int ResetGeneration { get; set; }
        public FadeVisualState State { get; set; } = FadeVisualState.Hidden;
        public int ReferenceCount;
        public int ShowCalls;
        public int HideCalls;

        public void Show()
        {
            ShowCalls++;
            ReferenceCount++;
            State = FadeVisualState.Showing;
        }

        public void Hide()
        {
            HideCalls++;
            ReferenceCount--;
            if (ReferenceCount <= 0) State = FadeVisualState.Hiding;
        }

        /// <summary>Simulates LoadingProcess.StopAll / ResetManualLoadingScreen.</summary>
        public void ForceReset()
        {
            ReferenceCount = 0;
            ResetGeneration++;
        }
    }

    internal sealed class FakeTimeScaleHost : ITimeScaleHost
    {
        public object Identity { get; set; } = new object();

        public float Scale { get; set; } = 1f;
    }

    internal sealed class FakeVolumeHost : IMasterVolumeHost
    {
        public bool IsAvailable { get; set; } = true;
        public float PlayerSetting = 80f;
        public float Level = 80f;
        public int FadeCalls;
        public int RestoreCalls;

        public void FadeToSilence(int durationMilliseconds)
        {
            FadeCalls++;
            Level = 0f;
        }

        public void RestorePlayerSetting(int durationMilliseconds)
        {
            RestoreCalls++;
            Level = PlayerSetting;
        }
    }

    internal sealed class FakeKeyboard : IKeyboardState
    {
        private readonly HashSet<KeyCode> held = new HashSet<KeyCode>();
        private readonly HashSet<KeyCode> down = new HashSet<KeyCode>();
        private readonly HashSet<KeyCode> up = new HashSet<KeyCode>();

        public int FrameIndex { get; private set; }

        public bool IsHeld(KeyCode key) => held.Contains(key);

        public bool WentDown(KeyCode key) => down.Contains(key);

        public bool WentUp(KeyCode key) => up.Contains(key);

        /// <summary>Advances to a new frame in which <paramref name="key"/> goes down and stays held.</summary>
        public void Press(KeyCode key)
        {
            NextFrame();
            held.Add(key);
            down.Add(key);
        }

        /// <summary>Advances to a new frame in which <paramref name="key"/> is released.</summary>
        public void Release(KeyCode key)
        {
            NextFrame();
            held.Remove(key);
            up.Add(key);
        }

        public void NextFrame()
        {
            FrameIndex++;
            down.Clear();
            up.Clear();
        }
    }

    /// <summary>A controller wired to real override classes over fake engine hosts.</summary>
    internal sealed class ControllerFixture
    {
        public readonly FakeClock Clock = new FakeClock();
        public readonly FakeProbe Probe = new FakeProbe();
        public readonly FakeScope Scope = new FakeScope();
        public readonly FakeFadeHost FadeHost = new FakeFadeHost();
        public readonly FakeTimeScaleHost TimeHost = new FakeTimeScaleHost();
        public readonly FakeVolumeHost VolumeHost = new FakeVolumeHost();
        public readonly RecordingLogger Logger = new RecordingLogger();
        public readonly SkipTuning Tuning = new SkipTuning();
        public readonly CutsceneSkipController Controller;
        public bool MuteEnabled = true;

        public ControllerFixture()
        {
            Controller = new CutsceneSkipController(
                Probe,
                Scope,
                new ScreenFadeOverride(FadeHost),
                new TimeScaleOverride(TimeHost, Logger),
                new AudioMuteOverride(VolumeHost, () => MuteEnabled, 250),
                Clock,
                Tuning,
                Logger);
        }

        /// <summary>Starts a skip and drives it to the Advancing phase.</summary>
        public void StartAndAdvance()
        {
            AssertEx.True(Controller.TryStart(), "skip should start");
            FadeHost.State = FadeVisualState.Shown;
            Clock.Advance(0.3);
            Controller.Tick();
            AssertEx.Equal(SkipPhase.Advancing, Controller.Phase, "should be advancing");
        }

        public void AssertAllOverridesReleased()
        {
            AssertEx.Equal(1f, TimeHost.Scale, "time scale restored");
            AssertEx.Equal(VolumeHost.PlayerSetting, VolumeHost.Level, "audio restored");
            AssertEx.Equal(0, FadeHost.ReferenceCount, "fade claim released");
            AssertEx.False(Scope.IsActive, "scope ended");
        }
    }
}
