using System;
using Kingmaker.Controllers;
using Kingmaker.Controllers.Units;

namespace KingmakerCutsceneSkip.Patches
{
    /// <summary>
    /// While accelerating, splits each frame's engine delta into substeps no larger than a normal frame for the two
    /// controllers whose results depend on step size, so accelerated playback matches normal playback's granularity:
    /// <list type="bullet">
    /// <item>CutsceneController: each command's PlayTime restarts at zero, discarding the rest of the frame's delta, so
    /// large frames would add game time at every sequential command.</item>
    /// <item>UnitMoveController: path following and final-approach braking overshoot with large steps, delaying arrival.</item>
    /// </list>
    /// Nothing is skipped or completed early; the engine simply runs these controllers at a normal frame rate.
    /// </summary>
    internal static class ControllerSubstepPatch
    {
        private static bool cutsceneSubstepping;
        private static bool movementSubstepping;

        public static bool CutscenePrefix(CutsceneController __instance)
        {
            return !RunSubstepped(__instance.Tick, ref cutsceneSubstepping);
        }

        public static bool MovementPrefix(UnitMoveController __instance)
        {
            return !RunSubstepped(__instance.Tick, ref movementSubstepping);
        }

        /// <summary>Returns true when it ran the substeps itself (the original call must then be skipped).</summary>
        private static bool RunSubstepped(Action tick, ref bool guard)
        {
            if (guard) return false;
            int substeps = PatchBridge.ControllerSubsteps();
            if (substeps <= 1) return false;

            TimeController time = Kingmaker.Game.Instance.TimeController;
            float frameDelta = time.DeltaTime;
            guard = true;
            try
            {
                time.SetDeltaTime(frameDelta / substeps);
                for (int step = 0; step < substeps; step++)
                {
                    tick();
                    if (!PatchBridge.IsAccelerating) break;
                }
            }
            finally
            {
                time.SetDeltaTime(frameDelta);
                guard = false;
            }

            return true;
        }
    }
}
