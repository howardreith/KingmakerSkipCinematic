using System;
using System.IO;
using Kingmaker;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.GameModes;
using Kingmaker.PubSubSystem;
using KingmakerCutsceneSkip.Core;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// Records a frame-correlated timeline (game mode, skip phase, fade, time scale, cutscenes, dialogue) and captures
    /// UI-inclusive screenshots around every skip, so the fade and the next interaction can be reviewed natively.
    /// </summary>
    internal sealed class EvidenceRecorder : ICutsceneHandler, IGameModeHandler
    {
        private const double CaptureTailSeconds = 2.0;

        private readonly string directory;
        private readonly int captureEveryFrames;
        private readonly JArray timeline = new JArray();
        private string lastSignature;
        private double captureUntil = double.NegativeInfinity;
        private int lastCaptureFrame = int.MinValue;
        private int framesCaptured;

        public EvidenceRecorder(string directory, int captureEveryFrames)
        {
            this.directory = directory;
            this.captureEveryFrames = captureEveryFrames;
            Directory.CreateDirectory(Path.Combine(directory, "frames"));
        }

        public int FramesCaptured => framesCaptured;

        public void Event(string kind, JToken detail = null)
        {
            JObject entry = new JObject
            {
                ["t"] = Math.Round(Time.realtimeSinceStartup, 3),
                ["frame"] = Time.frameCount,
                ["kind"] = kind
            };
            if (detail != null) entry["detail"] = detail;
            timeline.Add(entry);
        }

        /// <summary>Called every frame by the scenario runner.</summary>
        public void Tick(CutsceneSkipController controller)
        {
            Game game = Game.Instance;
            JObject presentation = StateSnapshot.Presentation();
            string phase = controller != null ? controller.Phase.ToString() : "unavailable";
            string signature = game.CurrentMode + "|" + phase + "|" + presentation["fadeCanvas"] + "|" + presentation["debugTimeScale"] +
                "|" + presentation["loading"] + "|" + StateSnapshot.Dialog(game)?["cue"] + "|" + string.Join(",", StateSnapshot.Cutscenes(game));
            if (signature != lastSignature)
            {
                lastSignature = signature;
                Event("state", new JObject
                {
                    ["mode"] = game.CurrentMode.ToString(),
                    ["skipPhase"] = phase,
                    ["presentation"] = presentation,
                    ["dialog"] = StateSnapshot.Dialog(game),
                    ["cutscenes"] = StateSnapshot.Cutscenes(game),
                    ["gameTimeSeconds"] = game.Player?.GameTime.TotalSeconds ?? -1
                });
            }

            if (controller != null && controller.Phase != SkipPhase.Idle) ExtendCapture(CaptureTailSeconds);
            if (captureEveryFrames > 0 && Time.realtimeSinceStartup <= captureUntil && Time.frameCount - lastCaptureFrame >= captureEveryFrames)
            {
                Screenshot("f" + Time.frameCount.ToString("D6") + "_" + phase);
            }
        }

        public void ExtendCapture(double seconds)
        {
            double until = Time.realtimeSinceStartup + seconds;
            if (until > captureUntil) captureUntil = until;
        }

        public string Screenshot(string name)
        {
            string relative = Path.Combine("frames", name + ".png");
            ScreenCapture.CaptureScreenshot(Path.Combine(directory, relative));
            lastCaptureFrame = Time.frameCount;
            framesCaptured++;
            Event("screenshot", relative);
            return relative;
        }

        public void WriteJson(string fileName, JToken value)
        {
            File.WriteAllText(Path.Combine(directory, fileName), value.ToString(Formatting.Indented));
        }

        public void Flush()
        {
            WriteJson("timeline.json", timeline);
        }

        public void HandleCutsceneStarted(CutscenePlayerData cutscene, bool queued) =>
            Event("cutsceneStarted", Describe(cutscene) + (queued ? " (queued)" : string.Empty));

        public void HandleCutsceneRestarted(CutscenePlayerData cutscene) => Event("cutsceneRestarted", Describe(cutscene));

        public void HandleCutscenePaused(CutscenePlayerData cutscene) => Event("cutscenePaused", Describe(cutscene));

        public void HandleCutsceneResumed(CutscenePlayerData cutscene) => Event("cutsceneResumed", Describe(cutscene));

        public void HandleCutsceneStopped(CutscenePlayerData cutscene) => Event("cutsceneStopped", Describe(cutscene));

        public void OnGameModeStart(GameModeType gameMode) => Event("modeStart", gameMode.ToString());

        public void OnGameModeStop(GameModeType gameMode) => Event("modeStop", gameMode.ToString());

        private static string Describe(CutscenePlayerData cutscene)
        {
            if (cutscene == null) return "?";
            return (cutscene.Cutscene != null ? cutscene.Cutscene.name : "?") + (cutscene.Exclusive ? " [locks control]" : string.Empty) +
                (LoadingProcess.Instance.IsLoadingInProcess ? " [during loading]" : string.Empty);
        }
    }
}
