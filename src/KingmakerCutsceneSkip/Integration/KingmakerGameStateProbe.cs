using Kingmaker;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.GameModes;
using KingmakerCutsceneSkip.Core;
using TurnBased.Controllers;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// Eligibility and boundary rules expressed against Kingmaker's game-mode stack:
    /// CommandLockControls pushes GameModeType.Cutscene; dialogue, rest, book events and full-screen UI push their own
    /// mode on top; releasing the lock returns to Default (exploration or playable combat). A skip is only valid while
    /// Cutscene is the top mode.
    /// </summary>
    internal sealed class KingmakerGameStateProbe : IGameStateProbe
    {
        public SkipStartBlocker GetStartBlocker()
        {
            Game game = Game.Instance;
            if (game?.Player == null || game.State == null) return SkipStartBlocker.NoGame;
            if (LoadingProcess.Instance.IsLoadingInProcess) return SkipStartBlocker.Loading;
            if (game.CurrentMode != GameModeType.Cutscene) return SkipStartBlocker.NotInCutsceneMode;
            if (CombatController.IsInTurnBasedCombat()) return SkipStartBlocker.TurnBasedCombat;
            if (!CutsceneScope.AnyControllingCutscene()) return SkipStartBlocker.NoControllingCutscene;
            if (CutsceneScope.ControllingCutsceneBoundaryCommand() != null) return SkipStartBlocker.BoundaryCommandPlaying;
            return SkipStartBlocker.None;
        }

        public SkipBoundary GetBoundary(ISkipScope scope)
        {
            Game game = Game.Instance;
            if (game?.Player == null) return SkipBoundary.Of(SkipEndReason.Loading, "no active game");
            if (LoadingProcess.Instance.IsLoadingInProcess) return SkipBoundary.Of(SkipEndReason.Loading, "loading process");

            SkipBoundary modeBoundary = ForMode(game.CurrentMode);
            if (modeBoundary.IsReached) return modeBoundary;

            if (CombatController.IsInTurnBasedCombat()) return SkipBoundary.Of(SkipEndReason.TurnBasedCombat, "turn-based combat");
            if (scope.BoundaryCommand != null) return SkipBoundary.Of(SkipEndReason.Loading, scope.BoundaryCommand);
            if (!scope.HasLiveCutscene) return SkipBoundary.Of(SkipEndReason.SceneComplete, "owned cutscenes finished");
            return SkipBoundary.None;
        }

        /// <summary>Maps a new top game mode to a boundary. Cutscene itself is not a boundary.</summary>
        public static SkipBoundary ForMode(GameModeType mode)
        {
            switch (mode)
            {
                case GameModeType.Cutscene:
                    return SkipBoundary.None;
                case GameModeType.Default:
                    return SkipBoundary.Of(SkipEndReason.ControlReturned, "Default");
                case GameModeType.None:
                    return SkipBoundary.Of(SkipEndReason.Loading, "no game mode");
                default:
                    return SkipBoundary.Of(SkipEndReason.InteractionBoundary, mode.ToString());
            }
        }
    }
}
