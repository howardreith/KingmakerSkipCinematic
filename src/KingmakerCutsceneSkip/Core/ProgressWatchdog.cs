namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Detects an operation that stopped making cutscene progress, or ran too long, using real time only.</summary>
    public sealed class ProgressWatchdog
    {
        private readonly double stallTimeout;
        private readonly double maximumDuration;
        private double startedAt;
        private double lastProgressAt;
        private string lastFingerprint;

        public ProgressWatchdog(double stallTimeoutSeconds, double maximumDurationSeconds)
        {
            stallTimeout = stallTimeoutSeconds;
            maximumDuration = maximumDurationSeconds;
        }

        public int ProgressEvents { get; private set; }

        public void Reset(double now, string fingerprint)
        {
            startedAt = now;
            lastProgressAt = now;
            lastFingerprint = fingerprint;
            ProgressEvents = 0;
        }

        /// <summary>Returns <see cref="SkipEndReason.Stalled"/> or <see cref="SkipEndReason.Watchdog"/> when a limit is exceeded.</summary>
        public SkipEndReason? Observe(double now, string fingerprint)
        {
            if (!string.Equals(fingerprint, lastFingerprint, System.StringComparison.Ordinal))
            {
                lastFingerprint = fingerprint;
                lastProgressAt = now;
                ProgressEvents++;
            }

            if (now - startedAt > maximumDuration) return SkipEndReason.Watchdog;
            if (now - lastProgressAt > stallTimeout) return SkipEndReason.Stalled;
            return null;
        }
    }
}
