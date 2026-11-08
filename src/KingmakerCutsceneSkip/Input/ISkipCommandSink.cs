namespace KingmakerCutsceneSkip.Input
{
    /// <summary>What the input gate needs from the skip lifecycle.</summary>
    public interface ISkipCommandSink
    {
        bool IsSkipping { get; }

        bool ShouldSwallowSkipKey { get; }

        bool TryStart();

        bool TryCancel();
    }
}
