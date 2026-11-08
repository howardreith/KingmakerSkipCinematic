namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Read-only questions about the game that decide eligibility and boundaries.</summary>
    public interface IGameStateProbe
    {
        SkipStartBlocker GetStartBlocker();

        SkipBoundary GetBoundary(ISkipScope scope);
    }
}
