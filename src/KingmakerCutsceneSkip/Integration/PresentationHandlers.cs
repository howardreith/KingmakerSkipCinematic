using System.Reflection;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.AreaLogic.Cutscenes.Commands;
using Kingmaker.Assets.AreaLogic.Cutscenes.Commands;
using Kingmaker.Localization;
using Kingmaker.UI.Bark;
using Kingmaker.UI.Overtip;
using KingmakerCutsceneSkip.Logging;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// Command-specific handling for the few presentation commands whose duration does not follow engine time.
    /// Everything else (delays, movement, animation, camera, timelines, actions) already advances with
    /// TimeController.DebugTimeScale and is left entirely to the engine.
    /// </summary>
    internal sealed class PresentationHandlers
    {
        private static readonly FieldInfo BarkBaseVoiceField =
            typeof(BarkBase).GetField("m_VoiceOverStatus", BindingFlags.Instance | BindingFlags.NonPublic);

        private readonly IModLogger logger;

        public PresentationHandlers(IModLogger logger)
        {
            this.logger = logger;
        }

        /// <summary>
        /// Returns the command type name when the command is a boundary the skip must not cross.
        /// CommandCustomLoadingScreen shows a loading card for a real-time duration and runs its actions behind it.
        /// </summary>
        public string GetBoundaryName(CommandBase command)
        {
            return command is CommandCustomLoadingScreen ? nameof(CommandCustomLoadingScreen) : null;
        }

        /// <summary>
        /// A voiced bark that waits for its voice line holds its track for the real duration of the audio,
        /// regardless of engine time. Interrupting it is exactly what the engine does when a bark is cut short;
        /// the bark's text, speaker and the track's next command are unaffected.
        /// </summary>
        public void PrepareForAcceleration(CommandBase command, CutscenePlayerData player)
        {
            if (!(command is CommandBark)) return;

            object data = CutsceneInternals.GetCommandData(player, command);
            IBarkHandle handle = CutsceneInternals.ReadDataField<IBarkHandle>(data, "BarkHandle");
            if (handle == null || !IsVoiced(handle) || !handle.IsPlayingBark()) return;

            handle.InterruptBark();
            logger.Verbose("Interrupted voiced bark in " + player.Cutscene.name);
        }

        private static bool IsVoiced(IBarkHandle handle)
        {
            if (handle is BarkVm viewModel) return viewModel.VoiceOverStatus != null;
            if (handle is BarkBase bark && BarkBaseVoiceField != null) return BarkBaseVoiceField.GetValue(bark) is VoiceOverStatus;
            return false;
        }
    }
}
