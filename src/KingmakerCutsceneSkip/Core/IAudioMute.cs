namespace KingmakerCutsceneSkip.Core
{
    public interface IAudioMute
    {
        bool IsMuted { get; }

        void Mute();

        void Restore();
    }
}
