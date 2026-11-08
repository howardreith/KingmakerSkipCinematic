using System;
using System.Collections.Generic;

namespace KingmakerCutsceneSkip.Core
{
    /// <summary>How one controller of a game mode takes part in an accelerated frame.</summary>
    public enum SubstepRole
    {
        /// <summary>Simulation controller: ticked in every substep, at its native position in the list.</summary>
        Simulation,

        /// <summary>The time controller: replaced by advancing engine time by one substep.</summary>
        Time,

        /// <summary>
        /// A controller that reads per-rendered-frame state directly (input edges, Unity's frame delta, the camera):
        /// ticked once per rendered frame, in the first substep, at its native position.
        /// </summary>
        OncePerFrame
    }

    /// <summary>
    /// Runs one rendered frame of a game mode as several complete, normal-sized game ticks. Each substep ticks the mode's
    /// whole controller list in native order with the substep's delta, so every controller observes the same
    /// interleaving as consecutive frames of normal playback (cutscene tracks, movement, unit actions, script zones and
    /// so on advance together rather than one controller batching all of its steps ahead of the others).
    /// Work per rendered frame is bounded by <see cref="MaximumSubsteps"/> complete ticks.
    /// </summary>
    public sealed class FrameSubstepScheduler
    {
        public FrameSubstepScheduler(float maximumStepSeconds, int maximumSubsteps)
        {
            if (maximumStepSeconds <= 0) throw new ArgumentOutOfRangeException(nameof(maximumStepSeconds));
            if (maximumSubsteps < 1) throw new ArgumentOutOfRangeException(nameof(maximumSubsteps));
            MaximumStepSeconds = maximumStepSeconds;
            MaximumSubsteps = maximumSubsteps;
        }

        public float MaximumStepSeconds { get; }

        public int MaximumSubsteps { get; }

        /// <summary>Number of complete ticks the frame is divided into (1 means the frame needs no substepping).</summary>
        public int SubstepCount(float frameDelta)
        {
            if (!(frameDelta > MaximumStepSeconds)) return 1;
            int count = (int)Math.Ceiling(frameDelta / MaximumStepSeconds - 1e-4);
            return count < 1 ? 1 : (count > MaximumSubsteps ? MaximumSubsteps : count);
        }

        /// <summary>
        /// Ticks <paramref name="controllers"/> as <see cref="SubstepCount"/> complete ticks of equal size.
        /// <paramref name="mayContinue"/> is consulted only between complete ticks; when it returns false the rest of the
        /// frame's delta is not simulated (as when normal playback reaches the end of a frame), so no controller ever
        /// receives a partial or stale step. Returns the game time actually simulated.
        /// </summary>
        public float Run<TController>(
            IList<TController> controllers,
            Func<TController, SubstepRole> roleOf,
            float frameDelta,
            Action<float> advanceTime,
            Action<TController> tick,
            Func<bool> mayContinue)
        {
            if (controllers == null) throw new ArgumentNullException(nameof(controllers));
            if (roleOf == null) throw new ArgumentNullException(nameof(roleOf));
            if (advanceTime == null) throw new ArgumentNullException(nameof(advanceTime));
            if (tick == null) throw new ArgumentNullException(nameof(tick));
            if (mayContinue == null) throw new ArgumentNullException(nameof(mayContinue));

            SubstepRole[] roles = new SubstepRole[controllers.Count];
            for (int index = 0; index < roles.Length; index++) roles[index] = roleOf(controllers[index]);

            int count = SubstepCount(frameDelta);
            float step = frameDelta / count;
            float simulated = 0;
            for (int substep = 0; substep < count; substep++)
            {
                if (substep > 0 && !mayContinue()) break;
                for (int index = 0; index < roles.Length; index++)
                {
                    switch (roles[index])
                    {
                        case SubstepRole.Time:
                            advanceTime(step);
                            break;
                        case SubstepRole.OncePerFrame:
                            if (substep == 0) tick(controllers[index]);
                            break;
                        default:
                            tick(controllers[index]);
                            break;
                    }
                }

                simulated += step;
            }

            return simulated;
        }
    }
}
