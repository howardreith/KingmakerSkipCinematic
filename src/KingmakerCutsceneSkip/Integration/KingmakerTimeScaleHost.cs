using Kingmaker;
using Kingmaker.Controllers;
using KingmakerCutsceneSkip.Core;
using UnityEngine;

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
                if (controller == null) return;
                controller.DebugTimeScale = value;

                // TimeController re-derives Unity's time scale on its next tick; apply the same formula now so the
                // change takes effect this frame. A zero time scale means the game suspended time (pause, loading),
                // which must stay under the game's control.
                if (Time.timeScale > 0f) Time.timeScale = controller.PlayerTimeScale * value * controller.UiTimeScale;
            }
        }

        private static TimeController CurrentController => Game.Instance?.TimeController;
    }
}
