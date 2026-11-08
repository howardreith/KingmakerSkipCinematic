using System;
using System.IO;
using System.Reflection;
using Harmony12;
using Kingmaker;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.Utility;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// Redirects every persistent-data path (saves and the area cache) to a disposable lab profile and blocks Steam
    /// cloud replication, so a harness run can neither read nor write the owner's campaign saves.
    /// </summary>
    internal static class ProfileIsolation
    {
        public static string Apply(HarmonyInstance harmony, string profileDir)
        {
            string root = Path.GetFullPath(profileDir);
            Directory.CreateDirectory(Path.Combine(root, SaveManager.SaveFolderName));

            PropertyInfo persistent = typeof(ApplicationPaths).GetProperty("persistentDataPath", BindingFlags.Static | BindingFlags.Public);
            persistent.GetSetMethod(true).Invoke(null, new object[] { root });

            Type stash = typeof(SaveManager).Assembly.GetType("Kingmaker.EntitySystem.Persistence.AreaDataStash", true);
            stash.GetField("s_Folder", BindingFlags.Static | BindingFlags.NonPublic).SetValue(null, null);

            HarmonyMethod block = new HarmonyMethod(typeof(ProfileIsolation).GetMethod(nameof(BlockPrefix), BindingFlags.Static | BindingFlags.NonPublic));
            foreach (string name in new[] { "Initialize", "PullUpdates", "RegisterSave", "DeleteSave" })
            {
                MethodInfo method = typeof(SteamSavesReplicator).GetMethod(name, BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic);
                if (method == null || method.ReturnType != typeof(void)) throw new MissingMethodException(nameof(SteamSavesReplicator), name);
                harmony.Patch(method, block, null);
            }

            Game.Instance.SaveManager.UpdateSaveListAsync();
            string savePath = Path.GetFullPath(Game.Instance.SaveManager.SavePath);
            string areaFolder = Path.GetFullPath((string)stash.GetProperty("Folder", BindingFlags.Static | BindingFlags.Public).GetValue(null, null));
            if (!savePath.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !areaFolder.StartsWith(root, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Profile isolation failed: saves=" + savePath + " areas=" + areaFolder);
            }

            return "saves=" + savePath + "; areas=" + areaFolder;
        }

        private static bool BlockPrefix() => false;
    }
}
