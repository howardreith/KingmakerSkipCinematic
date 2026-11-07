namespace KingmakerCutsceneSkip.Core
{
    /// <summary>
    /// Timing constants for one skip operation. All durations are real (unscaled) seconds.
    /// Values are chosen from native observation; see docs/ENGINE-NOTES.md.
    /// </summary>
    public sealed class SkipTuning
    {
        /// <summary>Engine time multiplier while the screen is black (applied through TimeController.DebugTimeScale).</summary>
        public float TimeScale { get; set; } = 10f;

        /// <summary>Upper bound on waiting for the native fade to reach full black before acceleration begins anyway.</summary>
        public double FadeOutTimeoutSeconds { get; set; } = 1.0;

        /// <summary>Abandon the skip when no owned track has changed command for this long.</summary>
        public double StallTimeoutSeconds { get; set; } = 10.0;

        /// <summary>Abandon the skip when it has been accelerating for this long in total.</summary>
        public double MaximumAdvanceSeconds { get; set; } = 60.0;

        /// <summary>Upper bound on the Revealing phase if the fade never reports hidden.</summary>
        public double RevealTimeoutSeconds { get; set; } = 1.5;

        /// <summary>New presses of the skip key are swallowed for this long after the reveal finishes.</summary>
        public double PostRevealInputGuardSeconds { get; set; } = 0.35;
    }
}
