namespace KingmakerCutsceneSkip.Core
{
    public interface ITimeScaleOverride
    {
        bool IsApplied { get; }

        void Apply(float scale);

        void Restore();
    }
}
