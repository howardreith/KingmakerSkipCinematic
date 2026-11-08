namespace KingmakerCutsceneSkip.Core
{
    /// <summary>The game's master audio level. Restoring always re-applies the player's current volume setting.</summary>
    public interface IMasterVolumeHost
    {
        bool IsAvailable { get; }

        void FadeToSilence(int durationMilliseconds);

        void RestorePlayerSetting(int durationMilliseconds);
    }
}
