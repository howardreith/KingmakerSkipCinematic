namespace KingmakerCutsceneSkip.Core
{
    /// <summary>
    /// Which frames the mod runs itself while a skip is advancing, instead of the native GameMode.Tick.
    /// <para>
    /// Every plain Cutscene-mode frame is run by the mod, including one that needs only a single step. The first
    /// accelerated frame is such a frame: Unity computed its Time.deltaTime before the skip raised Time.timeScale.
    /// Letting that frame (or any later one) take the native tick would run TimeController.Tick, where another mod
    /// (Bag of Tricks' game-speed multiplier) re-applies its own DebugTimeScale and ends the acceleration. The frames
    /// that still use the native tick are the ones the scheduler cannot represent: the time controller's
    /// just-activated frame, turn-based combat, and a mode whose controller list does not hold exactly one time
    /// controller.
    /// </para>
    /// </summary>
    public static class AcceleratedFramePolicy
    {
        public static bool RunsFrame(bool isCutsceneMode, bool timeJustActivated, bool turnBasedCombat, int timeControllerCount)
        {
            return isCutsceneMode && !timeJustActivated && !turnBasedCombat && timeControllerCount == 1;
        }
    }
}
