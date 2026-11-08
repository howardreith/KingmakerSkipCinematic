namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Real, unscaled time. Watchdogs must never use engine (scaled) time.</summary>
    public interface IClock
    {
        double RealTimeSeconds { get; }
    }
}
