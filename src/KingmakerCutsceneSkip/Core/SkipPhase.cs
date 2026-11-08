namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Lifecycle of one skip operation. Only <see cref="FadingOut"/> and <see cref="Advancing"/> hold temporary overrides.</summary>
    public enum SkipPhase
    {
        /// <summary>No operation; Enter is evaluated normally.</summary>
        Idle,

        /// <summary>The screen and audio are fading out while the scene still plays at normal speed.</summary>
        FadingOut,

        /// <summary>The screen is black and the scene runs under accelerated engine time.</summary>
        Advancing,

        /// <summary>Overrides are released; the native fade is revealing the scene and input is still guarded.</summary>
        Revealing
    }
}
