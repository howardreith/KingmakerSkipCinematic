namespace KingmakerCutsceneSkip.Core
{
    /// <summary>
    /// The cutscenes a skip operation owns: those controlling the game when it began plus any the engine starts during it.
    /// Command-specific handling never touches cutscenes outside this scope.
    /// </summary>
    public interface ISkipScope
    {
        void Begin();

        void End();

        bool IsActive { get; }

        bool HasLiveCutscene { get; }

        /// <summary>Name of an owned command that represents a boundary the skip must not cross (null when none started).</summary>
        string BoundaryCommand { get; }

        /// <summary>Changes whenever any owned track starts, finishes or advances to another command.</summary>
        string ProgressFingerprint { get; }

        /// <summary>A human-readable list of the commands currently playing, for diagnostics.</summary>
        string DescribePlayingCommands();

        /// <summary>Applies presentation handlers to commands that were already running when acceleration began.</summary>
        void PrepareActiveCommandsForAcceleration();
    }
}
