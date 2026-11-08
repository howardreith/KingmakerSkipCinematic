using System.Reflection;
using Kingmaker.View;
using Pathfinding;

namespace KingmakerCutsceneSkip.Patches
{
    /// <summary>
    /// UnitMovementAgent.PathTo postfix. A* computes paths on worker threads and hands them back a few rendered frames
    /// later; under acceleration each frame of that latency costs ten times the game time, so every move command of a
    /// skipped scene would start measurably later than in normal play. While accelerating, the just-queued path is
    /// completed with the library's own blocking call (AstarPath.WaitForPath): the same path, delivered immediately.
    /// </summary>
    internal static class SynchronousPathPatch
    {
        internal static readonly FieldInfo RequestedPathField =
            typeof(UnitMovementAgent).GetField("m_RequestedPath", BindingFlags.Instance | BindingFlags.NonPublic);

        private static bool waiting;

        public static void Postfix(UnitMovementAgent __instance)
        {
            if (waiting || !PatchBridge.IsAccelerating || AstarPath.active == null) return;
            if (!(RequestedPathField.GetValue(__instance) is Path path) || path.IsDone() || path.GetState() == PathState.Created) return;

            waiting = true;
            try
            {
                AstarPath.WaitForPath(path);
            }
            finally
            {
                waiting = false;
            }
        }
    }
}
