using System.Collections.Generic;
using Newtonsoft.Json;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>One scripted native test run, read from the path given by the -kmcsRequest=&lt;path&gt; launch argument.</summary>
    public sealed class HarnessRequest
    {
        [JsonProperty("runId")] public string RunId;
        [JsonProperty("evidenceDir")] public string EvidenceDir;

        /// <summary>Replacement for Application.persistentDataPath: holds the disposable "Saved Games" and "Areas".</summary>
        [JsonProperty("profileDir")] public string ProfileDir;

        /// <summary>Save file (inside profileDir\Saved Games) to load from the main menu.</summary>
        [JsonProperty("save")] public string Save;

        [JsonProperty("timeoutSeconds")] public double TimeoutSeconds = 900;
        [JsonProperty("exitAfterCompletion")] public bool ExitAfterCompletion = true;

        /// <summary>While a skip is active (and briefly after), capture a screenshot every N frames. 0 disables.</summary>
        [JsonProperty("captureEveryFrames")] public int CaptureEveryFrames = 4;

        [JsonProperty("steps")] public List<HarnessStep> Steps = new List<HarnessStep>();
    }

    public sealed class HarnessStep
    {
        [JsonProperty("op")] public string Op;
        [JsonProperty("label")] public string Label;
        [JsonProperty("match")] public string Match;
        [JsonProperty("mode")] public string Mode;
        [JsonProperty("key")] public string Key;
        [JsonProperty("seconds")] public double Seconds;
        [JsonProperty("holdMs")] public int HoldMs = 60;
        [JsonProperty("count")] public int Count = 1;
        [JsonProperty("intervalMs")] public int IntervalMs = 150;
        [JsonProperty("index")] public int Index;
        [JsonProperty("timeoutSeconds")] public double TimeoutSeconds = 120;
        [JsonProperty("optional")] public bool Optional;
        [JsonProperty("enabled")] public bool Enabled;
        [JsonProperty("save")] public string Save;

        /// <summary>probeBlueprint: blueprint class short name.</summary>
        [JsonProperty("type")] public string Type;

        /// <summary>probeBlueprint: property or field to read.</summary>
        [JsonProperty("member")] public string Member;

        /// <summary>probeBlueprint: required value; omitted to record only (control runs).</summary>
        [JsonProperty("expect")] public string Expect;

        /// <summary>autoplayUntilControl: press the key this many seconds into each cinematic episode (-1 = never).</summary>
        [JsonProperty("skipAfterSeconds")] public double SkipAfterSeconds = -1;

        /// <summary>World position "x,y,z" for moveTo.</summary>
        [JsonProperty("position")] public string Position;

        public override string ToString()
        {
            return Op + (string.IsNullOrEmpty(Label) ? string.Empty : "(" + Label + ")");
        }
    }
}
