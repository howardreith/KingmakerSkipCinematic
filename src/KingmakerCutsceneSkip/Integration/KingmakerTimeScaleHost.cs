using Kingmaker;
using Kingmaker.Controllers;
using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// TimeController.DebugTimeScale: the multiplier Owlcat applies to TimeController.DeltaTime, Unity's Time.timeScale,
    /// camera follow speed and turn-based waits. It is not serialized into saves.
    /// </summary>
    public sealed class KingmakerTimeScaleHost : ITimeScaleHost
    {
        public object Identity => CurrentController;

        public float Scale
        {
            get
            {
                TimeController controller = CurrentController;
                return controller == null ? 1f : controller.DebugTimeScale;
            }
            set
            {
                TimeController controller = CurrentController;
                if (controller != null) controller.DebugTimeScale = value;
            }
        }

        private static TimeController CurrentController => Game.Instance?.TimeController;
    }
}
