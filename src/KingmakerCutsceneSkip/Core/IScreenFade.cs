namespace KingmakerCutsceneSkip.Core
{
    /// <summary>The operation's single claim on the game's native black fade.</summary>
    public interface IScreenFade
    {
        bool TryAcquire();

        bool IsHeld { get; }

        bool IsFullyFaded { get; }

        /// <summary>True when the native fade has finished hiding or another owner now controls it.</summary>
        bool IsRevealed { get; }

        void Release();
    }
}
