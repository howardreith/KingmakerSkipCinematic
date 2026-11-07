namespace KingmakerCutsceneSkip.Core
{
    public enum FadeVisualState
    {
        Unavailable,
        Hidden,
        Showing,
        Shown,
        Hiding
    }

    /// <summary>
    /// The game's shared, reference-counted "manual loading screen" slot that drives the native black fade.
    /// <see cref="ResetGeneration"/> increments whenever the game force-resets the count (for example when loading),
    /// which voids every outstanding claim.
    /// </summary>
    public interface IManualFadeHost
    {
        bool IsAvailable { get; }

        int ResetGeneration { get; }

        FadeVisualState State { get; }

        void Show();

        void Hide();
    }
}
