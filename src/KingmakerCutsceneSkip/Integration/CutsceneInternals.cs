using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using Kingmaker.AreaLogic.Cutscenes;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// Read-only access to CutscenePlayerData state that Kingmaker 2.1.7b keeps private.
    /// Resolved once; when a member is missing every query degrades to "nothing known" instead of throwing.
    /// </summary>
    internal static class CutsceneInternals
    {
        private const BindingFlags InstanceMembers = BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public;

        private static readonly FieldInfo ActivatedGatesField = typeof(CutscenePlayerData).GetField("m_ActivatedGates", InstanceMembers);
        private static readonly FieldInfo CommandDataField = typeof(CutscenePlayerData).GetField("m_CommandData", InstanceMembers);

        public static bool IsResolved => ActivatedGatesField != null && CommandDataField != null;

        public static string DescribeResolution()
        {
            return "m_ActivatedGates=" + (ActivatedGatesField != null) + ", m_CommandData=" + (CommandDataField != null);
        }

        /// <summary>Tracks of every gate currently activated in the cutscene, in engine tick order.</summary>
        public static IEnumerable<CutscenePlayerData.TrackData> ActiveTracks(CutscenePlayerData player)
        {
            if (player == null || ActivatedGatesField == null) yield break;
            if (!(ActivatedGatesField.GetValue(player) is IList gates)) yield break;

            for (int gateIndex = 0; gateIndex < gates.Count; gateIndex++)
            {
                if (!(gates[gateIndex] is CutscenePlayerData.GateData gate) || gate.StartedTracks == null) continue;
                for (int trackIndex = 0; trackIndex < gate.StartedTracks.Count; trackIndex++)
                {
                    CutscenePlayerData.TrackData track = gate.StartedTracks[trackIndex];
                    if (track != null) yield return track;
                }
            }
        }

        /// <summary>The per-command runtime data object the engine stores for <paramref name="command"/>, if any.</summary>
        public static object GetCommandData(CutscenePlayerData player, CommandBase command)
        {
            if (player == null || command == null || CommandDataField == null) return null;
            if (!(CommandDataField.GetValue(player) is IDictionary data)) return null;
            return data.Contains(command) ? data[command] : null;
        }

        /// <summary>Reads a field from a command's private runtime data object (for example CommandBark's BarkHandle).</summary>
        public static T ReadDataField<T>(object commandData, string fieldName) where T : class
        {
            if (commandData == null) return null;
            FieldInfo field = commandData.GetType().GetField(fieldName, InstanceMembers);
            return field?.GetValue(commandData) as T;
        }
    }
}
