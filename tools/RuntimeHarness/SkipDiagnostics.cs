using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using Harmony12;
using Kingmaker;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.AreaLogic.Cutscenes.Commands;
using Kingmaker.EntitySystem.Entities;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.Localization;
using Kingmaker.UI.Bark;
using Kingmaker.UI.Overtip;
using UnityEngine;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// Test-only, bounded per-frame diagnostics written to diag.jsonl while a cutscene plays or a skip is active:
    /// skip phase, game time, real time, multipliers and time-controller identity, the accelerated frame's planned
    /// versus executed substeps (and why it stopped early), and the state of every playing CommandBark handle.
    /// Observes only; never changes game or product state. Works as a pure observer when the product is absent.
    /// </summary>
    internal static class SkipDiagnostics
    {
        private const BindingFlags AnyInstance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
        private const float MaximumStepSeconds = 1f / 30f;
        private const int MaximumSubsteps = 25;

        private static readonly FieldInfo CommandDataField = typeof(CutscenePlayerData).GetField("m_CommandData", AnyInstance);
        private static readonly FieldInfo ActivatedGatesField = typeof(CutscenePlayerData).GetField("m_ActivatedGates", AnyInstance);
        private static readonly FieldInfo BarkRemainingField = typeof(BarkBase).GetField("m_RemainingTime", AnyInstance);
        private static readonly FieldInfo BarkVoiceField = typeof(BarkBase).GetField("m_VoiceOverStatus", AnyInstance);
        private static readonly FieldInfo BeforeTickActionsField = typeof(Game).GetField("m_BeforeTickActions", AnyInstance);

        private static readonly StringBuilder Lines = new StringBuilder(1 << 20);
        private static string path;

        // Accelerated-frame record of the current rendered frame (filled by the product driver patches).
        private static int driverFrame = -1;
        private static double driverGameBefore;
        private static float driverPlannedDelta;
        private static int driverPlanned;
        private static string driverResult;
        private static double driverSimulated;
        private static string driverStop;
        private static int driverChecks;
        private static int emittedDriverFrame = -1;

        public static void Install(HarmonyInstance harmony, string evidenceDirectory)
        {
            path = Path.Combine(evidenceDirectory, "diag.jsonl");
            if (!ProductAccess.IsLoaded) return;
            InstallCore(harmony);
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static void InstallCore(HarmonyInstance harmony)
        {
            Type driver = typeof(ProductMetadata).Assembly.GetType("KingmakerCutsceneSkip.Integration.AcceleratedFrameDriver", false);
            if (driver == null) return;
            const BindingFlags Private = BindingFlags.Static | BindingFlags.NonPublic;
            MethodInfo tryRun = driver.GetMethod("TryRunFrame", AnyInstance);
            MethodInfo mayContinue = driver.GetMethod("MayContinue", AnyInstance);
            if (tryRun != null)
            {
                harmony.Patch(tryRun, new HarmonyMethod(typeof(SkipDiagnostics).GetMethod(nameof(TryRunPrefix), Private)),
                    new HarmonyMethod(typeof(SkipDiagnostics).GetMethod(nameof(TryRunPostfix), Private)));
            }

            if (mayContinue != null)
            {
                harmony.Patch(mayContinue, null, new HarmonyMethod(typeof(SkipDiagnostics).GetMethod(nameof(MayContinuePostfix), Private)));
            }
        }

        private static void TryRunPrefix()
        {
            try
            {
                Game game = Game.Instance;
                driverFrame = Time.frameCount;
                driverGameBefore = game.Player?.GameTime.TotalSeconds ?? -1;
                var time = game.TimeController;
                driverPlannedDelta = time == null ? 0 : Math.Min(time.PlayerTimeScale * time.DebugTimeScale / 12f, Time.deltaTime);
                driverPlanned = driverPlannedDelta > MaximumStepSeconds ? Math.Min(MaximumSubsteps, (int)Math.Ceiling(driverPlannedDelta / MaximumStepSeconds - 1e-4)) : 1;
                driverResult = null;
                driverSimulated = 0;
                driverStop = null;
                driverChecks = 0;
            }
            catch (Exception)
            {
            }
        }

        private static void TryRunPostfix(bool __result)
        {
            try
            {
                driverResult = __result ? "substepped" : "native";
                driverSimulated = (Game.Instance.Player?.GameTime.TotalSeconds ?? -1) - driverGameBefore;
            }
            catch (Exception)
            {
            }
        }

        private static void MayContinuePostfix(bool __result)
        {
            try
            {
                driverChecks++;
                if (__result || driverStop != null) return;
                Game game = Game.Instance;
                string reason;
                var actions = BeforeTickActionsField?.GetValue(game) as List<Action>;
                int pending = 0;
                string first = null;
                if (actions != null)
                {
                    lock (actions)
                    {
                        pending = actions.Count;
                        if (pending > 0 && actions[0] != null) first = actions[0].Method.DeclaringType?.Name + "." + actions[0].Method.Name;
                    }
                }

                if (pending > 0) reason = "beforeTickActions=" + pending + (first != null ? " (" + first + ")" : string.Empty);
                else if (LoadingProcess.Instance.IsLoadingInProcess) reason = "loading";
                else if (game.CurrentMode != Kingmaker.GameModes.GameModeType.Cutscene) reason = "mode=" + game.CurrentMode;
                else reason = "skip ended: " + ProductAccess.Phase;
                driverStop = "after substep " + driverChecks + ": " + reason;
            }
            catch (Exception)
            {
            }
        }

        /// <summary>Called once per rendered frame by the recorder.</summary>
        public static void Sample()
        {
            if (path == null) return;
            try
            {
                Game game = Game.Instance;
                if (game?.Player == null || game.State?.Cutscenes == null) return;
                string phase = ProductAccess.Phase;
                bool cutsceneMode = game.CurrentMode == Kingmaker.GameModes.GameModeType.Cutscene;
                if (!cutsceneMode && (phase == "Idle" || phase == "absent")) return;

                var time = game.TimeController;
                StringBuilder line = new StringBuilder(512);
                line.Append("{\"f\":").Append(Time.frameCount)
                    .Append(",\"t\":").Append(Num(Time.realtimeSinceStartup))
                    .Append(",\"udt\":").Append(Num(Time.unscaledDeltaTime))
                    .Append(",\"mode\":\"").Append(game.CurrentMode).Append('"')
                    .Append(",\"phase\":\"").Append(phase).Append('"')
                    .Append(",\"game\":").Append(Num(game.Player.GameTime.TotalSeconds))
                    .Append(",\"dts\":").Append(Num(time?.DebugTimeScale ?? -1))
                    .Append(",\"uts\":").Append(Num(Time.timeScale))
                    .Append(",\"tc\":").Append(time == null ? 0 : RuntimeHelpers.GetHashCode(time));
                // The driver runs inside Game.Tick, which may come after this sample in a frame: emit each record once.
                if (driverResult != null && driverFrame != emittedDriverFrame)
                {
                    emittedDriverFrame = driverFrame;
                    int executed = driverResult == "substepped" && driverPlanned > 0 ? (int)Math.Round(driverSimulated / (driverPlannedDelta / driverPlanned)) : 1;
                    line.Append(",\"drv\":{\"df\":").Append(driverFrame).Append(",\"r\":\"").Append(driverResult).Append("\",\"plannedDelta\":").Append(Num(driverPlannedDelta))
                        .Append(",\"planned\":").Append(driverPlanned).Append(",\"executed\":").Append(executed)
                        .Append(",\"simulated\":").Append(Num(driverSimulated));
                    if (driverStop != null) line.Append(",\"stop\":\"").Append(Escape(driverStop)).Append('"');
                    line.Append('}');
                }

                line.Append(",\"cmds\":[");
                bool firstCommand = true;
                foreach (CutscenePlayerData player in game.State.Cutscenes)
                {
                    if (player == null || player.IsFinished || player.Destroyed) continue;
                    foreach (CutscenePlayerData.TrackData track in Tracks(player))
                    {
                        if (!track.IsPlaying) continue;
                        CommandBase command;
                        try { command = track.Command; } catch (Exception) { continue; }
                        if (command == null) continue;
                        if (!firstCommand) line.Append(',');
                        firstCommand = false;
                        line.Append("{\"cs\":\"").Append(Escape(player.Cutscene != null ? player.Cutscene.name : "?")).Append(player.Exclusive ? "[lock]" : string.Empty)
                            .Append(player.Paused ? "[paused]" : string.Empty).Append("\",\"c\":\"").Append(Escape(command.name)).Append("\",\"type\":\"")
                            .Append(command.GetType().Name).Append("\",\"pt\":").Append(Num(track.PlayTime));
                        if (command is CommandBark bark) AppendBark(line, bark, player);
                        line.Append('}');
                    }
                }

                line.Append("]}\n");
                Lines.Append(line);
            }
            catch (Exception exception)
            {
                Lines.Append("{\"sampleError\":\"").Append(Escape(exception.GetType().Name + ": " + exception.Message)).Append("\"}\n");
            }
        }

        private static void AppendBark(StringBuilder line, CommandBark bark, CutscenePlayerData player)
        {
            object data = null;
            if (CommandDataField?.GetValue(player) is IDictionary dictionary && dictionary.Contains(bark)) data = dictionary[bark];
            if (data == null)
            {
                line.Append(",\"bark\":\"no data\"");
                return;
            }

            Type dataType = data.GetType();
            IBarkHandle handle = dataType.GetField("BarkHandle", AnyInstance)?.GetValue(data) as IBarkHandle;
            object finished = dataType.GetField("Finished", AnyInstance)?.GetValue(data);
            line.Append(",\"await\":").Append(bark.AwaitFinish ? "true" : "false")
                .Append(",\"byText\":").Append(bark.BarkDurationByText ? "true" : "false")
                .Append(",\"finished\":").Append(finished is bool b && b ? "true" : "false");
            try
            {
                UnitEntityData speaker = bark.Unit != null ? bark.Unit.GetValue() : null;
                if (speaker != null)
                {
                    line.Append(",\"speakerFog\":").Append(speaker.IsInFogOfWar ? "true" : "false")
                        .Append(",\"speakerVisible\":").Append(speaker.IsVisibleForPlayer ? "true" : "false");
                }
            }
            catch (Exception)
            {
            }

            if (handle == null)
            {
                line.Append(",\"handle\":null");
                return;
            }

            line.Append(",\"handle\":\"").Append(handle.GetType().Name).Append("\",\"playing\":").Append(handle.IsPlayingBark() ? "true" : "false");
            VoiceOverStatus voice = null;
            if (handle is BarkBase barkBase)
            {
                line.Append(",\"active\":").Append(barkBase.gameObject.activeInHierarchy ? "true" : "false");
                if (BarkRemainingField != null) line.Append(",\"remaining\":").Append(Num((float)BarkRemainingField.GetValue(barkBase)));
                voice = BarkVoiceField?.GetValue(barkBase) as VoiceOverStatus;
            }
            else if (handle is BarkVm viewModel)
            {
                line.Append(",\"remainingReal\":").Append(Num(viewModel.EndTime - Game.Instance.TimeController.RealTime.TotalSeconds));
                voice = viewModel.VoiceOverStatus;
            }

            if (voice != null) line.Append(",\"vo\":{\"id\":").Append(voice.PlayingSoundId).Append(",\"ended\":").Append(voice.IsEnded ? "true" : "false").Append('}');
        }

        private static IEnumerable<CutscenePlayerData.TrackData> Tracks(CutscenePlayerData player)
        {
            if (!(ActivatedGatesField?.GetValue(player) is IList gates)) yield break;
            for (int gateIndex = 0; gateIndex < gates.Count; gateIndex++)
            {
                if (!(gates[gateIndex] is CutscenePlayerData.GateData gate) || gate.StartedTracks == null) continue;
                foreach (CutscenePlayerData.TrackData track in gate.StartedTracks)
                {
                    if (track != null) yield return track;
                }
            }
        }

        public static void Flush()
        {
            if (path == null) return;
            File.WriteAllText(path, Lines.ToString());
        }

        private static string Num(double value) => value.ToString("0.####", CultureInfo.InvariantCulture);

        private static string Escape(string text) => (text ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
