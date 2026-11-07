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
        FadeUnavailable
    }
}
