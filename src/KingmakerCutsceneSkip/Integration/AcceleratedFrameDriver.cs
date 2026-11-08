using System;
using System.Collections.Generic;
using System.Reflection;
using Kingmaker;
using Kingmaker.Controllers;
using Kingmaker.Controllers.Rest;
using Kingmaker.Dungeon.Leaderboard;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.GameModes;
using Kingmaker.UI;
using KingmakerCutsceneSkip.Core;
using TurnBased.Controllers;
using UnityEngine;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// While a skip is accelerating, runs each rendered frame of the Cutscene game mode as complete game ticks of at most
    /// <see cref="MaximumStepSeconds"/> (one 30 fps frame of engine time) — the mode's whole controller list, in native
    /// order, per substep. This is what the engine would do over consecutive normal frames, so cutscene tracks, unit
    /// movement, unit actions, script zones, projectiles and every other simulation controller stay interleaved exactly
    /// as in normal playback.
    /// <para>
    /// Between substeps the frame stops early whenever normal playback would have ended the frame first: the skip
    /// reached a boundary, the game scheduled work for the start of the next frame (deferred game-mode changes, a
    /// dialogue start, a control lock change), or a load began. Unsimulated time is simply not consumed.
    /// </para>
    /// </summary>
    internal sealed class AcceleratedFrameDriver
    {
        /// <summary>Largest engine delta one substep may consume (a 30 fps frame).</summary>
        public const float MaximumStepSeconds = 1f / 30f;

        /// <summary>
        /// Upper bound on complete ticks per rendered frame. TimeController caps a frame at
        /// PlayerTimeScale × DebugTimeScale / 12 game seconds (0.83 s at ×10), i.e. 25 substeps.
        /// </summary>
        public const int MaximumSubsteps = 25;

        private const BindingFlags AnyInstance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;

        /// <summary>
        /// Controllers in the Cutscene mode that read per-rendered-frame state directly instead of engine time:
        /// keyboard bindings (key-down edges), the cutscene camera, weather (Time.deltaTime), realtime lights and the
        /// dungeon leaderboard (Time.unscaledDeltaTime), and the cutscene UI hider.
        /// </summary>
        private static readonly Type[] OncePerFrameTypes =
        {
            typeof(KeyboardAccess),
            typeof(CameraController),
            typeof(WeatherController),
            typeof(RealtimeLightsController),
            typeof(DungeonLeaderboardController),
            typeof(CutsceneUIHideController)
        };

        public static readonly FieldInfo ModeControllersField = typeof(GameMode).GetField("m_Controllers", AnyInstance);
        public static readonly FieldInfo BeforeTickActionsField = typeof(Game).GetField("m_BeforeTickActions", AnyInstance);

        private readonly FrameSubstepScheduler scheduler = new FrameSubstepScheduler(MaximumStepSeconds, MaximumSubsteps);
        private readonly Func<bool> continueSkip;
        private readonly Func<IController, SubstepRole> roleOf = RoleOf;
        private readonly Action<IController> tickController = TickController;
        private readonly Func<bool> mayContinue;
        private readonly Action<float> advanceTime;
        private TimeController time;
        private Game game;
        private List<Action> beforeTickActions;

        /// <param name="continueSkip">Re-evaluates the skip's boundaries; false when acceleration has ended.</param>
        public AcceleratedFrameDriver(Func<bool> continueSkip)
        {
            this.continueSkip = continueSkip ?? throw new ArgumentNullException(nameof(continueSkip));
            mayContinue = MayContinue;
            advanceTime = AdvanceTime;
        }

        /// <summary>True from the first substep of a frame until it finished (for exception recovery).</summary>
        public bool FrameInProgress { get; private set; }

        public static bool IsResolved => ModeControllersField != null && BeforeTickActionsField != null;

        /// <summary>
        /// Runs the mode's frame substepped. Returns false (nothing executed; the native tick must run) when the frame
        /// does not need substepping or this is not the plain Cutscene mode.
        /// </summary>
        public bool TryRunFrame(GameMode mode)
        {
            FrameInProgress = false;
            if (mode == null || mode.Type != GameModeType.Cutscene) return false;
            game = Game.Instance;
            time = game?.TimeController;
            if (time == null || game.Player == null || time.m_JustActivated || CombatController.IsInTurnBasedCombat()) return false;

            IController[] controllers = ModeControllersField.GetValue(mode) as IController[];
            if (controllers == null || CountTimeControllers(controllers) != 1) return false;

            // TimeController.Tick's own formula for this frame's engine delta (outside turn-based combat).
            float frameDelta = Math.Min(time.PlayerTimeScale * time.DebugTimeScale / 12f, Time.deltaTime);
            if (scheduler.SubstepCount(frameDelta) <= 1) return false;

            beforeTickActions = BeforeTickActionsField.GetValue(game) as List<Action>;
            FrameInProgress = true;
            float simulated = scheduler.Run(controllers, roleOf, frameDelta, advanceTime, tickController, mayContinue);

            // Code outside the mode tick (unit views, barks, camera rig) reads the frame's delta later in this frame:
            // report the engine time actually simulated, as an unsubstepped frame would.
            time.SetDeltaTime(simulated);
            time.SetGameDeltaTime(simulated);
            FrameInProgress = false;
            return true;
        }

        private bool MayContinue()
        {
            if (beforeTickActions != null)
            {
                lock (beforeTickActions)
                {
                    if (beforeTickActions.Count > 0) return false;
                }
            }

            if (LoadingProcess.Instance.IsLoadingInProcess || game.CurrentMode != GameModeType.Cutscene) return false;
            return continueSkip();
        }

        /// <summary>TimeController.Tick for one substep in Cutscene mode outside turn-based combat.</summary>
        private void AdvanceTime(float step)
        {
            time.SetDeltaTime(step);
            time.SetGameDeltaTime(step);
            game.Player.GameTime += TimeSpan.FromSeconds(step);
            Time.timeScale = time.PlayerTimeScale * time.DebugTimeScale * time.UiTimeScale;
        }

        /// <summary>GameMode.Tick's per-controller isolation: one failing controller does not stop the others.</summary>
        private static void TickController(IController controller)
        {
            try
            {
                controller.Tick();
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }

        private static SubstepRole RoleOf(IController controller)
        {
            if (controller is TimeController) return SubstepRole.Time;
            Type type = controller.GetType();
            for (int index = 0; index < OncePerFrameTypes.Length; index++)
            {
                if (OncePerFrameTypes[index] == type) return SubstepRole.OncePerFrame;
            }

            return SubstepRole.Simulation;
        }

        private static int CountTimeControllers(IController[] controllers)
        {
            int count = 0;
            for (int index = 0; index < controllers.Length; index++)
            {
                if (controllers[index] is TimeController) count++;
            }

            return count;
        }
    }
}
