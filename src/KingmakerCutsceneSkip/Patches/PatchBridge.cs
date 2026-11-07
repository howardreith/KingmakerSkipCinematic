using System;
using Kingmaker.AreaLogic.Cutscenes;
using KingmakerCutsceneSkip.Logging;
using UnityEngine;

namespace KingmakerCutsceneSkip.Patches
{
    /// <summary>What the Harmony entry points call. Implemented by the composition root's runtime.</summary>
    internal interface IPatchTarget
    {
        bool IsEnabled { get; }

        bool ShouldSuppressVoice { get; }

        void PollInput();

        bool IsKeyClaimed(KeyCode key);

        bool EnterCommand(CutscenePlayerData player);

        void ExitCommand(CommandBase command, CutscenePlayerData player);
    }

    /// <summary>
    /// Static bridge between Harmony's static patch methods and the mod's object graph. Every entry point is
    /// exception-safe and inert while the mod is disabled or unloaded, so a patch can never break the game method.
    /// </summary>
    internal static class PatchBridge
    {
        private static IPatchTarget target;
        private static IModLogger logger;
        private static bool exceptionReported;

        public static void Initialize(IPatchTarget value, IModLogger modLogger)
        {
            target = value;
            logger = modLogger;
            exceptionReported = false;
        }

        public static void Clear()
        {
            target = null;
        }

        public static void PollInput()
        {
            IPatchTarget current = target;
            if (current == null || !current.IsEnabled) return;
            Guard("poll skip input", current.PollInput);
        }

        public static bool IsKeyClaimed(KeyCode key)
        {
            IPatchTarget current = target;
            if (current == null) return false;
            try
            {
                return current.IsKeyClaimed(key);
            }
            catch (Exception exception)
            {
                Report("check claimed key", exception);
                return false;
            }
        }

        public static bool EnterCommand(CutscenePlayerData player)
        {
            IPatchTarget current = target;
            if (current == null || !current.IsEnabled) return false;
            try
            {
                return current.EnterCommand(player);
            }
            catch (Exception exception)
            {
                Report("enter cutscene command", exception);
                return false;
            }
        }

        public static void ExitCommand(CommandBase command, CutscenePlayerData player)
        {
            IPatchTarget current = target;
            if (current == null) return;
            Guard("exit cutscene command", () => current.ExitCommand(command, player));
        }

        public static bool ShouldSuppressVoice
        {
            get
            {
                IPatchTarget current = target;
                return current != null && current.ShouldSuppressVoice;
            }
        }

        private static void Guard(string operation, Action action)
        {
            try
            {
                action();
            }
            catch (Exception exception)
            {
                Report(operation, exception);
            }
        }

        private static void Report(string operation, Exception exception)
        {
            if (exceptionReported || logger == null) return;
            exceptionReported = true;
            logger.Exception(operation + " (further patch exceptions suppressed)", exception);
        }
    }
}
