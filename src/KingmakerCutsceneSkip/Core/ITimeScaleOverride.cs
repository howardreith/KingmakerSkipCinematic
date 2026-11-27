namespace KingmakerCutsceneSkip.Core
{
    public interface ITimeScaleOverride
    {
        /// <summary>Whether an acquisition still needs to be released, even if another owner replaced its value.</summary>
        bool IsApplied { get; }

        /// <summary>Whether the captured controller still has the applied multiplier; not a measure of scene progress.</summary>
        bool IsCurrent { get; }

        void Apply(float scale);

        void Restore();
    }
}
