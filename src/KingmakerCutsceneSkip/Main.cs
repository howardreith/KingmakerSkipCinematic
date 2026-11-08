using System;
using KingmakerCutsceneSkip.Logging;
using KingmakerCutsceneSkip.UI;
using UnityModManagerNet;

namespace KingmakerCutsceneSkip
{
    /// <summary>Unity Mod Manager entry point. Kept thin: every callback forwards to <see cref="SkipRuntime"/>.</summary>
    public static class Main
    {
        private static Settings settings;
        private static SkipRuntime runtime;

        internal static SkipRuntime Runtime => runtime;

        public static bool Load(UnityModManager.ModEntry modEntry)
        {
            if (modEntry == null) return false;
            try
            {
                settings = UnityModManager.ModSettings.Load<Settings>(modEntry) ?? new Settings();
                UmmLogger logger = new UmmLogger(modEntry.Logger, () => settings != null && settings.VerboseDiagnostics);
                runtime = new SkipRuntime(settings, logger);
                modEntry.OnToggle = OnToggle;
                modEntry.OnUpdate = OnUpdate;
                modEntry.OnGUI = OnGui;
                modEntry.OnSaveGUI = OnSaveGui;
                modEntry.OnUnload = OnUnload;
                logger.Info(ProductMetadata.Name + " " + ProductMetadata.Version + " loaded.");
                return true;
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Load Cutscene Skip", exception);
                runtime = null;
                return false;
            }
        }

        private static bool OnToggle(UnityModManager.ModEntry modEntry, bool value)
        {
            try
            {
                return runtime != null && runtime.SetEnabled(value);
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Toggle Cutscene Skip", exception);
                return false;
            }
        }

        private static void OnUpdate(UnityModManager.ModEntry modEntry, float deltaTime)
        {
            try
            {
                runtime?.Update();
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Update Cutscene Skip", exception);
            }
        }

        private static void OnGui(UnityModManager.ModEntry modEntry)
        {
            try
            {
                if (settings != null) SettingsView.Draw(settings, runtime?.Status);
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Draw Cutscene Skip settings", exception);
            }
        }

        private static void OnSaveGui(UnityModManager.ModEntry modEntry)
        {
            try
            {
                settings?.Save(modEntry);
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Save Cutscene Skip settings", exception);
            }
        }

        private static bool OnUnload(UnityModManager.ModEntry modEntry)
        {
            try
            {
                bool unloaded = runtime == null || runtime.TryUnload();
                if (unloaded) runtime = null;
                return unloaded;
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Unload Cutscene Skip", exception);
                return false;
            }
        }
    }
}
