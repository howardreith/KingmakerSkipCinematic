using System;
using Kingmaker.GameModes;
using Kingmaker.PubSubSystem;
using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// Forwards game-mode and area events synchronously, so a boundary ends acceleration inside the same engine tick
    /// that pushed the dialogue, released control or began unloading, instead of one accelerated frame later.
    /// </summary>
    internal sealed class GameEventListener : IGameModeHandler, ISceneHandler
    {
        private readonly Action<SkipBoundary> notify;
        private bool subscribed;

        public GameEventListener(Action<SkipBoundary> notify)
        {
            this.notify = notify ?? throw new ArgumentNullException(nameof(notify));
        }

        public void Subscribe()
        {
            if (subscribed) return;
            EventBus.Subscribe(this);
            subscribed = true;
        }

        public void Unsubscribe()
        {
            if (!subscribed) return;
            EventBus.Unsubscribe(this);
            subscribed = false;
        }

        public void OnGameModeStart(GameModeType gameMode)
        {
            notify(KingmakerGameStateProbe.ForMode(gameMode));
        }

        public void OnGameModeStop(GameModeType gameMode)
        {
        }

        public void OnAreaBeginUnloading()
        {
            notify(SkipBoundary.Of(SkipEndReason.Loading, "area unloading"));
        }

        public void OnAreaDidLoad()
        {
        }
    }
}
