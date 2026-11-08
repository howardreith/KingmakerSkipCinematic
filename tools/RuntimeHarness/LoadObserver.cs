namespace KingmakerCutsceneSkip.RuntimeHarness
{
    internal enum LoadProgress
    {
        Waiting,
        Complete,
        NeverBegan,
        NotPlayable,
        StateNotReplaced,
        SentinelNotRestored
    }

    /// <summary>
    /// Decides from per-frame observations whether a requested in-game load really happened. A request that is rejected
    /// leaves the old game running, which looks exactly like a finished load if only "not loading, area present" is
    /// checked. Success therefore requires that loading was seen in progress, that the game's player state object was
    /// replaced, and (when a value is expected) that an in-memory change made after the save was undone by the load.
    /// Free of game types so the rules are covered by the deterministic tests.
    /// </summary>
    internal sealed class LoadObserver
    {
        public const double BeginTimeoutSeconds = 15.0;
        public const double SettleSeconds = 1.0;
        public const double PlayableTimeoutSeconds = 60.0;

        private readonly double requestedAt;
        private readonly object playerBefore;
        private readonly long? expectedMoney;
        private double lastLoadingAt;

        public LoadObserver(double requestedAt, object playerBefore, long? expectedMoney)
        {
            this.requestedAt = requestedAt;
            this.playerBefore = playerBefore;
            this.expectedMoney = expectedMoney;
        }

        public bool Began { get; private set; }

        public bool PlayerReplaced { get; private set; }

        public long LastMoney { get; private set; }

        public LoadProgress Observe(double now, bool loadingInProcess, object player, bool areaLoaded, bool playableMode, long money)
        {
            LastMoney = money;
            PlayerReplaced = player != null && !ReferenceEquals(player, playerBefore);
            if (loadingInProcess)
            {
                Began = true;
                lastLoadingAt = now;
                return LoadProgress.Waiting;
            }

            if (!Began) return now - requestedAt > BeginTimeoutSeconds ? LoadProgress.NeverBegan : LoadProgress.Waiting;

            // Queued loading processes can leave a gap between them, so no verdict until loading has stayed idle.
            if (now - lastLoadingAt < SettleSeconds) return LoadProgress.Waiting;
            if (!areaLoaded || player == null || !playableMode)
            {
                return now - lastLoadingAt > PlayableTimeoutSeconds ? LoadProgress.NotPlayable : LoadProgress.Waiting;
            }

            if (!PlayerReplaced) return LoadProgress.StateNotReplaced;
            if (expectedMoney.HasValue && money != expectedMoney.Value) return LoadProgress.SentinelNotRestored;
            return LoadProgress.Complete;
        }

        public string Describe(LoadProgress progress)
        {
            switch (progress)
            {
                case LoadProgress.NeverBegan:
                    return "load did not begin within " + BeginTimeoutSeconds + "s (request rejected or suppressed)";
                case LoadProgress.NotPlayable:
                    return "load finished but the game did not become playable";
                case LoadProgress.StateNotReplaced:
                    return "loading ran but the player state was not replaced";
                case LoadProgress.SentinelNotRestored:
                    return "the in-memory marker survived the load: money " + LastMoney + ", saved value " + expectedMoney;
                default:
                    return progress.ToString();
            }
        }
    }
}
