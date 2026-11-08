namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Why a skip operation ended. Every reason releases all temporary overrides.</summary>
    public enum SkipEndReason
    {
        /// <summary>A dialogue, rest screen, book event or other modal took the top game mode.</summary>
        InteractionBoundary,

        /// <summary>The cutscene lock was released and the game returned to ordinary play (exploration or combat).</summary>
        ControlReturned,

        /// <summary>A load, area transition or loading screen began.</summary>
        Loading,

        /// <summary>Every cutscene owned by the operation finished without reaching another boundary.</summary>
        SceneComplete,

        /// <summary>Turn-based combat became active.</summary>
        TurnBasedCombat,

        /// <summary>The player pressed Escape during the skip.</summary>
        Cancelled,

        /// <summary>No cutscene command advanced for too long; normal playback is revealed.</summary>
        Stalled,

        /// <summary>The operation exceeded its maximum real-time budget; normal playback is revealed.</summary>
        Watchdog,

        /// <summary>The screen never reported full black; the scene is revealed without having been accelerated.</summary>
        FadeTimeout,

        /// <summary>An exception occurred inside the mod; normal playback is revealed.</summary>
        Error,

        /// <summary>The mod was disabled or unloaded.</summary>
        Disabled
    }
}
