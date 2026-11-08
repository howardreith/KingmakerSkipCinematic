using System;
using System.Collections.Generic;
using System.Reflection;
using Harmony12;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.Controllers;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.GameModes;
using Kingmaker.Localization;
using Kingmaker.UI;
using Kingmaker.UnitLogic.Commands.Base;
using Kingmaker.View;
using KingmakerCutsceneSkip.Logging;
using UnityEngine;

namespace KingmakerCutsceneSkip.Patches
{
    /// <summary>
    /// Resolves every Kingmaker 2.1.7b method the mod patches by exact signature, then installs all patches or none.
    /// A missing contract leaves the game untouched and the feature disabled, rather than partially patched.
    /// </summary>
    internal sealed class PatchInstaller
    {
        private const BindingFlags AnyInstance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;

        private readonly IModLogger logger;
        private HarmonyInstance harmony;

        public PatchInstaller(IModLogger logger)
        {
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public bool IsInstalled => harmony != null;

        public bool TryInstall()
        {
            if (IsInstalled) return true;

            List<string> missing = new List<string>();
            MethodInfo keyboardTick = Require(typeof(KeyboardAccess), "Tick", Type.EmptyTypes, missing);
            MethodInfo inputMatched = Require(typeof(KeyboardAccess.Binding), "InputMatched", Type.EmptyTypes, missing);
            MethodInfo commandRun = Require(typeof(CommandBase), "Run", new[] { typeof(CutscenePlayerData) }, missing);
            MethodInfo playVoiceOver = Require(typeof(LocalizedString), "PlayVoiceOver", new[] { typeof(MonoBehaviour) }, missing);
            MethodInfo modeTick = Require(typeof(GameMode), "Tick", Type.EmptyTypes, missing);
            if (Integration.AcceleratedFrameDriver.ModeControllersField == null) missing.Add("GameMode.m_Controllers");
            if (Integration.AcceleratedFrameDriver.BeforeTickActionsField == null) missing.Add("Game.m_BeforeTickActions");
            Require(typeof(TimeController), "SetDeltaTime", new[] { typeof(float) }, missing);
            Require(typeof(TimeController), "SetGameDeltaTime", new[] { typeof(float) }, missing);
            MethodInfo pathTo = Require(typeof(UnitMovementAgent), "PathTo",
                new[] { typeof(UnitCommand), typeof(Vector3), typeof(float), typeof(float), typeof(UnitMovementAgentBase) }, missing);
            if (SynchronousPathPatch.RequestedPathField == null) missing.Add("UnitMovementAgent.m_RequestedPath");
            MethodInfo stopAll = Require(typeof(LoadingProcess), "StopAll", Type.EmptyTypes, missing);
            MethodInfo resetManual = Require(typeof(LoadingProcess), "ResetManualLoadingScreen", Type.EmptyTypes, missing);
            MethodInfo cheatResetManual = Require(typeof(LoadingProcess), "CheatRestManualLoadingScreen", Type.EmptyTypes, missing);

            if (missing.Count > 0)
            {
                logger.Error("Kingmaker contract mismatch; Cutscene Skip stays disabled. Missing: " + string.Join(", ", missing.ToArray()));
                return false;
            }

            HarmonyInstance instance = HarmonyInstance.Create(ProductMetadata.HarmonyId);
            try
            {
                instance.Patch(keyboardTick, Method(typeof(KeyboardTickPatch), "Prefix"), null);
                instance.Patch(inputMatched, Method(typeof(BindingInputMatchedPatch), "Prefix"), null);
                instance.Patch(commandRun, Method(typeof(CommandRunPatch), "Prefix"), Method(typeof(CommandRunPatch), "Postfix"));
                instance.Patch(playVoiceOver, null, Method(typeof(VoiceOverPatch), "Postfix"));
                instance.Patch(modeTick, Method(typeof(AcceleratedFramePatch), "Prefix"), null);
                instance.Patch(pathTo, null, Method(typeof(SynchronousPathPatch), "Postfix"));
                HarmonyMethod resetPostfix = Method(typeof(ManualScreenResetPatch), "Postfix");
                instance.Patch(stopAll, null, resetPostfix);
                instance.Patch(resetManual, null, resetPostfix);
                instance.Patch(cheatResetManual, null, resetPostfix);
            }
            catch (Exception exception)
            {
                logger.Exception("Install Cutscene Skip patches", exception);
                TryUnpatch(instance);
                return false;
            }

            harmony = instance;
            return true;
        }

        public bool TryUninstall()
        {
            if (!IsInstalled) return true;
            bool removed = TryUnpatch(harmony);
            if (removed) harmony = null;
            return removed;
        }

        private bool TryUnpatch(HarmonyInstance instance)
        {
            try
            {
                instance.UnpatchAll(ProductMetadata.HarmonyId);
                return true;
            }
            catch (Exception exception)
            {
                logger.Exception("Remove Cutscene Skip patches", exception);
                return false;
            }
        }

        private static MethodInfo Require(Type type, string name, Type[] parameters, List<string> missing)
        {
            MethodInfo method = type.GetMethod(name, AnyInstance | BindingFlags.Static, null, parameters, null);
            if (method == null) missing.Add(type.FullName + "." + name);
            return method;
        }

        private static HarmonyMethod Method(Type type, string name)
        {
            MethodInfo method = type.GetMethod(name, BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic);
            if (method == null) throw new MissingMethodException(type.FullName, name);
            return new HarmonyMethod(method);
        }
    }
}
