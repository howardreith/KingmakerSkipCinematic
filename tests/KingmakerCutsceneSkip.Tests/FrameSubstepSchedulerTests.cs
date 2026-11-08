using System;
using System.Collections.Generic;
using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Tests
{
    /// <summary>
    /// Ordering guarantees of accelerated frames. The mini engine reproduces the review counterexample: track A waits for
    /// a unit to arrive and then sets a flag; a parallel track B waits on a delay and then branches on that flag. Normal
    /// playback interleaves the cutscene and movement controllers frame by frame; an accelerated frame must observe the
    /// same interleaving.
    /// </summary>
    public static class FrameSubstepSchedulerTests
    {
        private const float NormalFrame = 1f / 30f;

        public static void AcceleratedFrameMatchesNormalFramesWhenCutsceneTicksBeforeMovement()
        {
            AssertSameAsNormalPlayback(MiniEngine.Order.CutsceneFirst);
        }

        public static void AcceleratedFrameMatchesNormalFramesWhenMovementTicksBeforeCutscene()
        {
            AssertSameAsNormalPlayback(MiniEngine.Order.MovementFirst);
        }

        public static void PerControllerBatchingWouldChangeTheBranchResult()
        {
            // Guards the regression scenario itself: batching each controller's substeps (the previous design) observes
            // the flag before the unit arrived, so the tests above are sensitive to the defect they cover.
            MiniEngine batched = MiniEngine.Create(MiniEngine.Order.CutsceneFirst);
            batched.RunBatchedPerController(10, NormalFrame);
            AssertEx.Equal(false, batched.FlagObservedByDelayTrack, "batched scheduling reads the flag too early");

            MiniEngine normal = MiniEngine.Create(MiniEngine.Order.CutsceneFirst);
            normal.RunNormalFrames(10, NormalFrame);
            AssertEx.Equal(true, normal.FlagObservedByDelayTrack, "normal playback reads the flag after arrival");
        }

        public static void TimeAdvancesInEqualStepsAndOncePerFrameControllersTickOnce()
        {
            FrameSubstepScheduler scheduler = new FrameSubstepScheduler(NormalFrame, 25);
            List<string> controllers = new List<string> { "time", "keyboard", "sim" };
            List<float> steps = new List<float>();
            Dictionary<string, int> ticks = new Dictionary<string, int> { { "keyboard", 0 }, { "sim", 0 } };

            float simulated = scheduler.Run(controllers, RoleOf, 10 * NormalFrame, steps.Add, name => ticks[name]++, () => true);

            AssertEx.Equal(10, steps.Count, "ten complete ticks");
            foreach (float step in steps) AssertEx.True(Math.Abs(step - NormalFrame) < 1e-6, "every step is one normal frame");
            AssertEx.Equal(10, ticks["sim"], "simulation controller ticked every substep");
            AssertEx.Equal(1, ticks["keyboard"], "per-frame controller ticked once");
            AssertEx.True(Math.Abs(simulated - 10 * NormalFrame) < 1e-5, "whole frame simulated");
        }

        public static void StopRequestEndsTheFrameAfterACompleteTick()
        {
            FrameSubstepScheduler scheduler = new FrameSubstepScheduler(NormalFrame, 25);
            List<string> controllers = new List<string> { "time", "a", "b" };
            List<string> log = new List<string>();
            int checks = 0;

            float simulated = scheduler.Run(controllers, RoleOf, 10 * NormalFrame, step => log.Add("time"), log.Add, () => ++checks < 2);

            AssertEx.Equal("time,a,b,time,a,b", string.Join(",", log.ToArray()), "two complete ticks, no partial tick");
            AssertEx.True(Math.Abs(simulated - 2 * NormalFrame) < 1e-6, "only the simulated time is reported");
        }

        public static void SubstepCountIsBoundedAndSmallFramesAreNotSplit()
        {
            FrameSubstepScheduler scheduler = new FrameSubstepScheduler(NormalFrame, 25);
            AssertEx.Equal(1, scheduler.SubstepCount(NormalFrame), "a normal frame is not split");
            AssertEx.Equal(1, scheduler.SubstepCount(0f), "a zero frame is not split");
            AssertEx.Equal(10, scheduler.SubstepCount(10 * NormalFrame), "x10 at 30 fps");
            AssertEx.Equal(25, scheduler.SubstepCount(10f / 12f), "TimeController's own cap at x10");
            AssertEx.Equal(25, scheduler.SubstepCount(100f), "never more than the bound");
        }

        private static SubstepRole RoleOf(string name)
        {
            return name == "time" ? SubstepRole.Time : (name == "keyboard" ? SubstepRole.OncePerFrame : SubstepRole.Simulation);
        }

        private static void AssertSameAsNormalPlayback(MiniEngine.Order order)
        {
            MiniEngine normal = MiniEngine.Create(order);
            normal.RunNormalFrames(10, NormalFrame);

            MiniEngine accelerated = MiniEngine.Create(order);
            accelerated.RunScheduledFrame(new FrameSubstepScheduler(NormalFrame, 25), 10 * NormalFrame);

            AssertEx.Equal(true, normal.FlagObservedByDelayTrack, "normal playback: delayed action sees the flag");
            AssertEx.Equal(normal.FlagObservedByDelayTrack, accelerated.FlagObservedByDelayTrack, "same branch result");
            AssertEx.Equal(string.Join(" ", normal.Events.ToArray()), string.Join(" ", accelerated.Events.ToArray()),
                "same events at the same engine ticks");
        }

        /// <summary>Two-track cutscene, a moving unit and an engine clock, ticked like a Kingmaker game mode.</summary>
        private sealed class MiniEngine
        {
            public enum Order
            {
                CutsceneFirst,
                MovementFirst
            }

            private const float Destination = 0.05f;
            private const float Speed = 1f;
            private const float Delay = 0.15f;

            private float deltaTime;
            private int tick;
            private float unitPosition;
            private bool flag;
            private float delayElapsed;

            public readonly List<string> Events = new List<string>();
            public readonly List<string> Controllers = new List<string>();

            public bool? FlagObservedByDelayTrack { get; private set; }

            public static MiniEngine Create(Order order)
            {
                MiniEngine engine = new MiniEngine();
                engine.Controllers.Add("time");
                if (order == Order.CutsceneFirst)
                {
                    engine.Controllers.Add("cutscene");
                    engine.Controllers.Add("movement");
                }
                else
                {
                    engine.Controllers.Add("movement");
                    engine.Controllers.Add("cutscene");
                }

                return engine;
            }

            public void RunNormalFrames(int frames, float frameDelta)
            {
                for (int frame = 0; frame < frames; frame++)
                {
                    foreach (string controller in Controllers)
                    {
                        if (controller == "time") AdvanceTime(frameDelta);
                        else Tick(controller);
                    }
                }
            }

            public void RunScheduledFrame(FrameSubstepScheduler scheduler, float frameDelta)
            {
                scheduler.Run(Controllers, name => name == "time" ? SubstepRole.Time : SubstepRole.Simulation, frameDelta,
                    AdvanceTime, Tick, () => true);
            }

            /// <summary>The previous design: each controller ran all of its substeps before the next controller.</summary>
            public void RunBatchedPerController(int substeps, float step)
            {
                foreach (string controller in Controllers)
                {
                    for (int index = 0; index < substeps; index++)
                    {
                        if (controller == "time") AdvanceTime(step);
                        else Tick(controller);
                    }
                }
            }

            private void AdvanceTime(float step)
            {
                deltaTime = step;
                tick++;
            }

            private void Tick(string controller)
            {
                if (controller == "movement")
                {
                    if (unitPosition < Destination) unitPosition = Math.Min(Destination, unitPosition + Speed * deltaTime);
                    return;
                }

                // Track A: wait for arrival, then set the story flag.
                if (!flag && unitPosition >= Destination)
                {
                    flag = true;
                    Events.Add("A:flag@" + tick);
                }

                // Track B: delay, then branch on the flag.
                if (FlagObservedByDelayTrack.HasValue) return;
                delayElapsed += deltaTime;
                if (delayElapsed >= Delay)
                {
                    FlagObservedByDelayTrack = flag;
                    Events.Add("B:branch(" + flag + ")@" + tick);
                }
            }
        }
    }
}
