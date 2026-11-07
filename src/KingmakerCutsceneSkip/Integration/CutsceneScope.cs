using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Text;
using Kingmaker;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.PubSubSystem;
using KingmakerCutsceneSkip.Core;
using KingmakerCutsceneSkip.Logging;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// The cutscenes one skip operation owns. At start: every live cutscene that locks player control (Exclusive).
    /// During the operation: control-locking cutscenes the engine starts, plus any cutscene started while an owned
    /// command was executing (a child scene). Unrelated ambient cutscenes are never added.
    /// </summary>
    internal sealed class CutsceneScope : ISkipScope, ICutsceneHandler
    {
        private readonly PresentationHandlers handlers;
        private readonly IModLogger logger;
        private readonly List<CutscenePlayerData> owned = new List<CutscenePlayerData>();
        private readonly StringBuilder builder = new StringBuilder(256);
        private int ownedCommandDepth;

        public CutsceneScope(PresentationHandlers handlers, IModLogger logger)
        {
            this.handlers = handlers ?? throw new ArgumentNullException(nameof(handlers));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public bool IsActive { get; private set; }

        public string BoundaryCommand { get; private set; }

        public bool HasLiveCutscene
        {
            get
            {
                for (int index = 0; index < owned.Count; index++)
                {
                    if (IsLive(owned[index])) return true;
                }

                return false;
            }
        }

        public string ProgressFingerprint
        {
            get
            {
                builder.Length = 0;
                for (int index = 0; index < owned.Count; index++)
                {
                    CutscenePlayerData player = owned[index];
                    builder.Append(RuntimeHelpers.GetHashCode(player)).Append(IsLive(player) ? '{' : '!');
                    foreach (CutscenePlayerData.TrackData track in CutsceneInternals.ActiveTracks(player))
                    {
                        builder.Append(RuntimeHelpers.GetHashCode(track.StartGate)).Append(':')
                            .Append(track.TrackIndex).Append('/').Append(track.CommandIndex)
                            .Append(track.IsPlaying ? 'p' : '-').Append(';');
                    }

                    builder.Append('}');
                }

                return builder.ToString();
            }
        }

        public void Begin()
        {
            End();
            IsActive = true;
            BoundaryCommand = null;
            foreach (CutscenePlayerData player in LiveCutscenes())
            {
                if (player.Exclusive) owned.Add(player);
            }

            EventBus.Subscribe(this);
        }

        public void End()
        {
            if (IsActive) EventBus.Unsubscribe(this);
            IsActive = false;
            ownedCommandDepth = 0;
            owned.Clear();
        }

        public string DescribePlayingCommands()
        {
            builder.Length = 0;
            for (int index = 0; index < owned.Count; index++)
            {
                CutscenePlayerData player = owned[index];
                if (!IsLive(player)) continue;
                if (builder.Length > 0) builder.Append(" | ");
                builder.Append(player.Cutscene != null ? player.Cutscene.name : "?").Append('[');
                bool first = true;
                foreach (CutscenePlayerData.TrackData track in CutsceneInternals.ActiveTracks(player))
                {
                    if (!track.IsPlaying) continue;
                    CommandBase command = SafeCommand(track);
                    if (!first) builder.Append(", ");
                    first = false;
                    builder.Append('t').Append(track.TrackIndex).Append(':').Append(command != null ? command.GetType().Name : "?");
                }

                builder.Append(']');
            }

            return builder.Length == 0 ? "(none)" : builder.ToString();
        }

        public void PrepareActiveCommandsForAcceleration()
        {
            for (int index = 0; index < owned.Count; index++)
            {
                CutscenePlayerData player = owned[index];
                if (!IsLive(player)) continue;
                foreach (CutscenePlayerData.TrackData track in CutsceneInternals.ActiveTracks(player))
                {
                    if (!track.IsPlaying) continue;
                    CommandBase command = SafeCommand(track);
                    if (command != null) handlers.PrepareForAcceleration(command, player);
                }
            }
        }

        /// <summary>CommandBase.Run prefix. Returns true when the command belongs to an owned cutscene.</summary>
        public bool EnterCommand(CutscenePlayerData player)
        {
            if (!IsActive || !owned.Contains(player)) return false;
            ownedCommandDepth++;
            return true;
        }

        /// <summary>CommandBase.Run postfix for a command that <see cref="EnterCommand"/> accepted.</summary>
        public void ExitCommand(CommandBase command, CutscenePlayerData player, bool accelerating)
        {
            if (ownedCommandDepth > 0) ownedCommandDepth--;
            if (!IsActive) return;

            string boundary = handlers.GetBoundaryName(command);
            if (boundary != null && BoundaryCommand == null) BoundaryCommand = boundary;
            if (accelerating) handlers.PrepareForAcceleration(command, player);
        }

        public void HandleCutsceneStarted(CutscenePlayerData cutscene, bool queued)
        {
            if (!IsActive || cutscene == null || owned.Contains(cutscene)) return;
            if (!cutscene.Exclusive && ownedCommandDepth == 0) return;
            owned.Add(cutscene);
            logger.Verbose("Skip scope adopted cutscene " + (cutscene.Cutscene != null ? cutscene.Cutscene.name : "?") +
                (cutscene.Exclusive ? " (locks control)" : " (started by an owned command)"));
        }

        public void HandleCutsceneRestarted(CutscenePlayerData cutscene)
        {
        }

        public void HandleCutscenePaused(CutscenePlayerData cutscene)
        {
        }

        public void HandleCutsceneResumed(CutscenePlayerData cutscene)
        {
        }

        public void HandleCutsceneStopped(CutscenePlayerData cutscene)
        {
        }

        /// <summary>Live, control-locking, unpaused cutscenes: the ones a skip request can act on.</summary>
        public static bool AnyControllingCutscene()
        {
            foreach (CutscenePlayerData player in LiveCutscenes())
            {
                if (player.Exclusive && !player.Paused) return true;
            }

            return false;
        }

        private static List<CutscenePlayerData> LiveCutscenes()
        {
            List<CutscenePlayerData> result = new List<CutscenePlayerData>();
            Game game = Game.Instance;
            if (game?.State?.Cutscenes == null) return result;
            foreach (CutscenePlayerData player in game.State.Cutscenes)
            {
                if (IsLive(player)) result.Add(player);
            }

            return result;
        }

        private static bool IsLive(CutscenePlayerData player)
        {
            return player != null && !player.IsFinished && !player.Destroyed;
        }

        private static CommandBase SafeCommand(CutscenePlayerData.TrackData track)
        {
            try
            {
                return track.Command;
            }
            catch (ArgumentOutOfRangeException)
            {
                return null;
            }
            catch (NullReferenceException)
            {
                return null;
            }
        }
    }
}
