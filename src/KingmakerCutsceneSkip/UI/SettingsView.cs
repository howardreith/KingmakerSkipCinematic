using UnityEngine;

namespace KingmakerCutsceneSkip.UI
{
    /// <summary>The UMM settings panel: two clearly labelled options and the controls reminder.</summary>
    internal static class SettingsView
    {
        public static void Draw(Settings settings, string status)
        {
            GUILayout.Label("Press Enter (or keypad Enter) during a cinematic to skip ahead to the next choice or to player control. " +
                "Press Escape while the screen is black to stop skipping.");
            settings.MuteAudioWhileSkipping = GUILayout.Toggle(settings.MuteAudioWhileSkipping, " Mute game audio while skipping");
            settings.VerboseDiagnostics = GUILayout.Toggle(settings.VerboseDiagnostics, " Write detailed skip diagnostics to the log");
            if (!string.IsNullOrEmpty(status)) GUILayout.Label(status);
        }
    }
}
