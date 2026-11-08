namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Why a skip request was declined. <see cref="None"/> means the request is eligible.</summary>
    public enum SkipStartBlocker
    {
        None,
        NoGame,
        Loading,
        NotInCutsceneMode,
        TurnBasedCombat,
        NoControllingCutscene,

        /// <summary>A controlling cutscene is showing a real-time loading card (CommandCustomLoadingScreen).</summary>
        BoundaryCommandPlaying,
        FadeUnavailable
    }
}
