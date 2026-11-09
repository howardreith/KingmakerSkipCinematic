using System;
using System.IO;
using System.Reflection;
using Harmony12;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityModManagerNet;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// Test-only UMM entry point. Inert unless the game was launched with -kmcsRequest=&lt;path&gt;. Never packaged with the product.
    /// </summary>
    public static class HarnessMain
    {
        private const string RequestArgument = "-kmcsRequest=";
        private static ScenarioRunner runner;
        private static UnityModManager.ModEntry entry;

        public static bool Load(UnityModManager.ModEntry modEntry)
        {
            entry = modEntry;
            string requestPath = FindRequestPath();
            if (requestPath == null)
            {
                modEntry.Logger.Log("No " + RequestArgument + " argument; harness inactive.");
                return true;
            }

            JObject result = new JObject { ["requestPath"] = requestPath };
            HarnessRequest request = JsonConvert.DeserializeObject<HarnessRequest>(File.ReadAllText(requestPath));
            Directory.CreateDirectory(request.EvidenceDir);
            result["runId"] = request.RunId;
            result["product"] = ProductAccess.Identity();
            EvidenceRecorder recorder = new EvidenceRecorder(request.EvidenceDir, request.CaptureEveryFrames);
            try
            {
                HarmonyInstance harmony = HarmonyInstance.Create("howardreith.kingmaker.cutsceneskip.runtimeharness");
                result["isolation"] = ProfileIsolation.Apply(harmony, request.ProfileDir);
                ProductAccess.InstallFaultInjection(harmony);
                ProductAccess.InstallPanelFaultWatch(harmony);
                CommandTrace.Install(harmony, recorder);
            }
            catch (Exception exception)
            {
                result["status"] = "failed";
                result["failure"] = "isolation: " + exception;
                recorder.WriteJson("runtime-result.json", result);
                modEntry.Logger.LogException("Harness isolation", exception);
                UnityEngine.Application.Quit();
                return false;
            }

            recorder.WriteJson("runtime-stage-loaded.json", result);
            runner = new ScenarioRunner(request, recorder, result);
            modEntry.OnUpdate = OnUpdate;
            modEntry.Logger.Log("Harness run " + request.RunId + " armed: " + result["isolation"]);
            return true;
        }

        private static void OnUpdate(UnityModManager.ModEntry modEntry, float deltaTime)
        {
            try
            {
                runner?.Tick();
            }
            catch (Exception exception)
            {
                entry.Logger.LogException("Harness tick", exception);
                runner?.Finish(false, "harness exception: " + exception);
            }
        }

        private static string FindRequestPath()
        {
            foreach (string argument in Environment.GetCommandLineArgs())
            {
                if (argument.StartsWith(RequestArgument, StringComparison.OrdinalIgnoreCase)) return argument.Substring(RequestArgument.Length).Trim('"');
            }

            return null;
        }
    }

    /// <summary>Timeline entry for every cutscene command start: cutscene, command asset, type and game time.</summary>
    internal static class CommandTrace
    {
        private static EvidenceRecorder traceRecorder;

        public static void Install(HarmonyInstance harmony, EvidenceRecorder recorder)
        {
            traceRecorder = recorder;
            MethodInfo run = typeof(Kingmaker.AreaLogic.Cutscenes.CommandBase).GetMethod("Run", BindingFlags.Instance | BindingFlags.Public);
            harmony.Patch(run, null, new HarmonyMethod(typeof(CommandTrace).GetMethod(nameof(Postfix), BindingFlags.Static | BindingFlags.NonPublic)));
        }

        private static void Postfix(Kingmaker.AreaLogic.Cutscenes.CommandBase __instance, Kingmaker.AreaLogic.Cutscenes.CutscenePlayerData player)
        {
            try
            {
                traceRecorder?.Event("cmd", new JObject
                {
                    ["cutscene"] = player?.Cutscene != null ? player.Cutscene.name : "?",
                    ["command"] = __instance.name,
                    ["type"] = __instance.GetType().Name,
                    ["game"] = Kingmaker.Game.Instance.Player?.GameTime.TotalSeconds ?? -1
                });
            }
            catch (Exception)
            {
            }
        }
    }

    /// <summary>A narrowly targeted, one-shot exception inside the product's boundary probe, for exception-recovery evidence.</summary>
    internal static class FaultInjection
    {
        private static bool armed;

        public static void Arm() => armed = true;

        private static void Prefix()
        {
            if (!armed) return;
            armed = false;
            throw new InvalidOperationException("harness controlled fault");
        }
    }
}
