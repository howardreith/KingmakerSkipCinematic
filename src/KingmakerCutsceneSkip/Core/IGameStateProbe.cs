namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Read-only questions about the game that decide eligibility and boundaries.</summary>
    public interface IGameStateProbe
    {
        SkipStartBlocker GetStartBlocker();

        SkipBoundary GetBoundary(ISkipScope scope);

        /// <summary>Engine game time in seconds (NaN when there is no game). Diagnostics only: never a boundary or timer.</summary>
        double GameTimeSeconds { get; }
    }
}
