using Kingmaker.UI;

namespace KingmakerCutsceneSkip.Patches
{
    /// <summary>KeyboardAccess.Tick prefix: decide skip/cancel presses before any binding of this frame is evaluated.</summary>
    internal static class KeyboardTickPatch
    {
        public static void Prefix()
        {
            PatchBridge.PollInput();
        }
    }

    /// <summary>KeyboardAccess.Binding.InputMatched prefix: hide claimed keys from every game key binding.</summary>
    internal static class BindingInputMatchedPatch
    {
        public static bool Prefix(KeyboardAccess.Binding __instance, ref bool __result)
        {
            if (!PatchBridge.IsKeyClaimed(__instance.Key)) return true;
            __result = false;
            return false;
        }
    }
}
