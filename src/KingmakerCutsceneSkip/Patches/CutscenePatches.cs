using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.Localization;
using KingmakerCutsceneSkip.Integration;

namespace KingmakerCutsceneSkip.Patches
{
    /// <summary>CommandBase.Run (non-virtual; every command start and restore goes through it).</summary>
    internal static class CommandRunPatch
    {
        public static void Prefix(CutscenePlayerData player, out bool __state)
        {
            __state = PatchBridge.EnterCommand(player);
        }

        public static void Postfix(CommandBase __instance, CutscenePlayerData player, bool __state)
        {
            if (__state) PatchBridge.ExitCommand(__instance, player);
        }
    }

    /// <summary>
    /// LocalizedString.PlayVoiceOver postfix: a voice line started while the screen is black would otherwise hold
    /// voiced barks for its real duration and remain audible after the reveal.
    /// </summary>
    internal static class VoiceOverPatch
    {
        public static void Postfix(VoiceOverStatus __result)
        {
            if (__result != null && PatchBridge.ShouldSuppressVoice) __result.Stop();
        }
    }

    /// <summary>LoadingProcess.StopAll / ResetManualLoadingScreen / CheatRestManualLoadingScreen postfix.</summary>
    internal static class ManualScreenResetPatch
    {
        public static void Postfix()
        {
            KingmakerFadeHost.NotifyManualScreenReset();
        }
    }
}
