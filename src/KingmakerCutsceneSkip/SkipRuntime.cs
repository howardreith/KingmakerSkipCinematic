using System;
using Kingmaker.AreaLogic.Cutscenes;
using KingmakerCutsceneSkip.Core;
using KingmakerCutsceneSkip.Input;
using KingmakerCutsceneSkip.Integration;
using KingmakerCutsceneSkip.Logging;
using KingmakerCutsceneSkip.Patches;
using UnityEngine;

namespace KingmakerCutsceneSkip
{
    /// <summary>Composition root: builds the object graph, owns patch installation and the enable/disable lifecycle.</summary>
    internal sealed class SkipRuntime : IPatchTarget
    {
        private static readonly KeyCode[] SkipKeys = { KeyCode.Return, KeyCode.KeypadEnter };
        private const KeyCode CancelKey = KeyCode.Escape;
        private const int AudioRampMilliseconds = 250;

        private readonly IModLogger logger;
        private readonly PatchInstaller installer;
        private readonly CutsceneScope scope;
        private readonly GameEventListener listener;
        private readonly SkipInputGate inputGate;
        private bool enabled;

        public SkipRuntime(Settings settings, IModLogger logger)
        {
            if (settings == null) throw new ArgumentNullException(nameof(settings));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));

            installer = new PatchInstaller(logger);
            scope = new CutsceneScope(new PresentationHandlers(logger), logger);
            Controller = new CutsceneSkipController(
                new KingmakerGameStateProbe(),
                scope,
                new ScreenFadeOverride(new KingmakerFadeHost()),
                new TimeScaleOverride(new KingmakerTimeScaleHost(), logger),
                new AudioMuteOverride(new KingmakerMasterVolumeHost(), () => settings.MuteAudioWhileSkipping, AudioRampMilliseconds),
                new UnityClock(),
                new SkipTuning(),
                logger);
            listener = new GameEventListener(Controller.NotifyBoundary);
            inputGate = new SkipInputGate(new UnityKeyboardState(), Controller, SkipKeys, CancelKey, () => enabled);
        }

        public CutsceneSkipController Controller { get; }

        public bool IsEnabled => enabled;

        public bool ShouldSuppressVoice => enabled && Controller.IsSkipping;

        public bool IsAccelerating => enabled && Controller.Phase == SkipPhase.Advancing;

        public string Status
        {
            get
            {
                if (!installer.IsInstalled) return "Inactive: this game version does not match the methods Cutscene Skip needs (see log).";
                SkipOperationReport report = Controller.LastReport;
                return report == null ? null : "Last skip: " + report.Reason + " after " + report.TotalHeldSeconds.ToString("0.0") + "s.";
            }
        }

        public bool SetEnabled(bool value)
        {
            if (!value)
            {
                Controller.Shutdown(SkipEndReason.Disabled, "mod disabled");
                inputGate.ReleaseAll();
                listener.Unsubscribe();
                enabled = false;
                return true;
            }

            if (!installer.TryInstall()) return false;
            if (!CutsceneInternals.IsResolved)
            {
                logger.Warning("Cutscene progress tracking is unavailable (" + CutsceneInternals.DescribeResolution() +
                    "); stall detection falls back to scene completion only.");
            }

            PatchBridge.Initialize(this, logger);
            listener.Subscribe();
            enabled = true;
            return true;
        }

        public void Update()
        {
            if (enabled) inputGate.Poll();
            Controller.Tick();
        }

        public bool TryUnload()
        {
            SetEnabled(false);
            PatchBridge.Clear();
            return installer.TryUninstall();
        }

        public void PollInput() => inputGate.Poll();

        public bool IsKeyClaimed(KeyCode key) => inputGate.IsClaimed(key);

        public bool EnterCommand(CutscenePlayerData player) => scope.EnterCommand(player);

        public void ExitCommand(CommandBase command, CutscenePlayerData player)
        {
            scope.ExitCommand(command, player, Controller.Phase == SkipPhase.Advancing);
        }
    }
}
