using System;
using System.Globalization;
using System.Linq;
using Kingmaker;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.AreaLogic.QuestSystem;
using Kingmaker.EntitySystem.Entities;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.Items;
using Kingmaker.UI;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// Semantic game state for comparing a normal run with a skipped run from the same save: story progress (quests,
    /// objectives, flags), party, inventory, units present in the area (life, HP, combat, faction, position) and their
    /// timing-sensitive state (buffs with remaining duration, ability resources, active toggles, action cooldowns),
    /// dialogue position and control state. Presentation values (time scales, fade, audio) are recorded separately to
    /// verify restoration.
    /// </summary>
    internal static class StateSnapshot
    {
        public static JObject Capture(string label)
        {
            Game game = Game.Instance;
            JObject snapshot = new JObject
            {
                ["label"] = label,
                ["realtime"] = Time.realtimeSinceStartup,
                ["frame"] = Time.frameCount,
                ["mode"] = game.CurrentMode.ToString(),
                ["cutsceneLock"] = game.CutsceneLock,
                ["gameTimeSeconds"] = game.Player?.GameTime.TotalSeconds ?? -1,
                ["area"] = game.CurrentlyLoadedArea != null ? game.CurrentlyLoadedArea.name : null,
                ["presentation"] = Presentation(),
                ["dialog"] = Dialog(game),
                ["cutscenes"] = Cutscenes(game)
            };

            if (game.Player == null) return snapshot;
            snapshot["inCombat"] = game.Player.IsInCombat;
            snapshot["money"] = game.Player.Money;
            snapshot["quests"] = new JArray(game.Player.QuestBook.Quests
                .OrderBy(q => q.Blueprint.name, StringComparer.Ordinal)
                .Select(q => new JObject
                {
                    ["quest"] = q.Blueprint.name,
                    ["state"] = q.State.ToString(),
                    ["objectives"] = new JArray(q.Objectives
                        .OrderBy(o => o.Blueprint.name, StringComparer.Ordinal)
                        .Select(o => o.Blueprint.name + "=" + o.State))
                }));
            snapshot["flags"] = new JArray(game.Player.UnlockableFlags.UnlockedFlags
                .Select(pair => pair.Key.name + "=" + pair.Value.ToString(CultureInfo.InvariantCulture))
                .OrderBy(text => text, StringComparer.Ordinal));
            snapshot["party"] = new JArray(game.Player.Party.Select(Unit));
            snapshot["inventory"] = new JArray(game.Player.Inventory
                .GroupBy(item => item.Blueprint.name)
                .OrderBy(group => group.Key, StringComparer.Ordinal)
                .Select(group => group.Key + "x" + group.Sum(item => item.Count)));
            System.Collections.Generic.HashSet<UnitEntityData> party = new System.Collections.Generic.HashSet<UnitEntityData>(game.Player.Party);
            snapshot["areaUnits"] = new JArray(game.State.Units
                .Where(unit => unit != null && unit.IsInGame && !party.Contains(unit))
                .OrderBy(unit => unit.Blueprint.name, StringComparer.Ordinal)
                .ThenBy(unit => unit.UniqueId, StringComparer.Ordinal)
                .Select(Unit));
            return snapshot;
        }

        public static JObject Presentation()
        {
            Game game = Game.Instance;
            FadeCanvas fade = FadeCanvas.Instance;
            return new JObject
            {
                ["debugTimeScale"] = game.TimeController?.DebugTimeScale ?? -1,
                ["unityTimeScale"] = Time.timeScale,
                ["fadeCanvas"] = fade != null ? fade.GetLoadingScreenState().ToString() : "none",
                ["manualLoadingScreen"] = LoadingProcess.Instance.IsManualLoadingScreenActive,
                ["loading"] = LoadingProcess.Instance.IsLoadingInProcess,
                ["paused"] = game.IsPaused,
                ["audioLevel"] = ReadAudioLevel()
            };
        }

        public static JObject Dialog(Game game)
        {
            var controller = game.DialogController;
            if (controller?.Dialog == null) return null;
            return new JObject
            {
                ["dialog"] = controller.Dialog.name,
                ["cue"] = controller.CurrentCue != null ? controller.CurrentCue.name : null,
                ["answers"] = new JArray(controller.Answers.Select(answer => answer.name))
            };
        }

        public static JArray Cutscenes(Game game)
        {
            JArray result = new JArray();
            if (game.State?.Cutscenes == null) return result;
            foreach (CutscenePlayerData player in game.State.Cutscenes.ToList())
            {
                if (player == null || player.IsFinished || player.Destroyed) continue;
                result.Add((player.Cutscene != null ? player.Cutscene.name : "?") + (player.Exclusive ? "[lock]" : string.Empty) + (player.Paused ? "[paused]" : string.Empty));
            }

            return result;
        }

        private static JObject Unit(UnitEntityData unit)
        {
            Vector3 position = unit.Position;
            return new JObject
            {
                ["unit"] = unit.Blueprint.name,
                ["id"] = unit.UniqueId,
                ["dead"] = unit.Descriptor.State.IsDead,
                ["hp"] = unit.HPLeft,
                ["position"] = string.Format(CultureInfo.InvariantCulture, "{0:0.0},{1:0.0},{2:0.0}", position.x, position.y, position.z),
                ["inCombat"] = unit.IsInCombat,
                ["faction"] = unit.Descriptor.Faction != null ? unit.Descriptor.Faction.name : null,
                ["buffs"] = Buffs(unit),
                ["resources"] = Resources(unit),
                ["activeToggles"] = new JArray(unit.Descriptor.ActivatableAbilities.Enumerable
                    .Where(ability => ability.IsOn)
                    .Select(ability => ability.Blueprint.name)
                    .OrderBy(text => text, StringComparer.Ordinal)),
                ["cooldowns"] = Cooldowns(unit)
            };
        }

        /// <summary>Every buff with its remaining game-time duration in seconds (-1 = permanent).</summary>
        private static JArray Buffs(UnitEntityData unit)
        {
            return new JArray(unit.Descriptor.Buffs.Enumerable
                .OrderBy(buff => buff.Blueprint.name, StringComparer.Ordinal)
                .ThenBy(buff => buff.EndTime)
                .Select(buff => new JObject
                {
                    ["buff"] = buff.Blueprint.name,
                    ["timeLeft"] = buff.IsPermanent ? -1.0 : Math.Round(buff.TimeLeft.TotalSeconds, 3),
                    ["suppressed"] = buff.IsSuppressed
                }));
        }

        private static JArray Resources(UnitEntityData unit)
        {
            System.Collections.Generic.List<string> amounts = new System.Collections.Generic.List<string>();
            foreach (var resource in unit.Descriptor.Resources)
            {
                amounts.Add(resource.name + "=" + unit.Descriptor.Resources.GetResourceAmount(resource));
            }

            amounts.Sort(StringComparer.Ordinal);
            return new JArray(amounts);
        }

        private static JObject Cooldowns(UnitEntityData unit)
        {
            var cooldown = unit.CombatState?.Cooldown;
            if (cooldown == null) return null;
            return new JObject
            {
                ["initiative"] = Math.Round(cooldown.Initiative, 3),
                ["standard"] = Math.Round(cooldown.StandardAction, 3),
                ["move"] = Math.Round(cooldown.MoveAction, 3),
                ["swift"] = Math.Round(cooldown.SwiftAction, 3),
                ["attackOfOpportunity"] = Math.Round(cooldown.AttackOfOpportunity, 3)
            };
        }

        private static float ReadAudioLevel()
        {
            int valueType = 1;
            AkSoundEngine.GetRTPCValue("AudioLevel", null, 0u, out float value, ref valueType);
            return value;
        }
    }
}
