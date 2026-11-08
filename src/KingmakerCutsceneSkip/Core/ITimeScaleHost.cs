namespace KingmakerCutsceneSkip.Core
{
    /// <summary>The engine's time multiplier. <see cref="Identity"/> changes when the game replaces its time controller.</summary>
    public interface ITimeScaleHost
    {
        object Identity { get; }

        float Scale { get; set; }
    }
}
