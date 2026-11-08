using Kingmaker.GameModes;

namespace KingmakerCutsceneSkip.Patches
{
    /// <summary>
    /// GameMode.Tick prefix. While a skip is accelerating, the Cutscene mode's frame is run as complete, normal-sized
    /// game ticks (see Integration.AcceleratedFrameDriver); otherwise the native tick runs untouched.
    /// </summary>
    internal static class AcceleratedFramePatch
    {
        public static bool Prefix(GameMode __instance)
        {
            return !PatchBridge.TryRunAcceleratedFrame(__instance);
        }
    }
}
