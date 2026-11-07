using System;
using KingmakerCutsceneSkip.Logging;

namespace KingmakerCutsceneSkip.Core
{
    /// <summary>
    /// Temporarily sets the engine time multiplier and restores the captured prior value only if the multiplier
    /// is still the one this override applied, on the same time controller. Another owner's later change wins.
    /// </summary>
    public sealed class TimeScaleOverride : ITimeScaleOverride
    {
        private readonly ITimeScaleHost host;
        private readonly IModLogger logger;
        private object appliedTo;
        private float priorScale;
        private float appliedScale;

        public TimeScaleOverride(ITimeScaleHost host, IModLogger logger)
        {
            this.host = host ?? throw new ArgumentNullException(nameof(host));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public bool IsApplied => appliedTo != null;

        public void Apply(float scale)
        {
            if (IsApplied) return;
            object identity = host.Identity;
            if (identity == null) return;

            float prior = host.Scale;
            // Never slow down a faster multiplier another owner already set.
            float target = prior > scale ? prior : scale;
            priorScale = prior;
            appliedScale = target;
            appliedTo = identity;
            host.Scale = target;
        }

        public void Restore()
        {
            if (!IsApplied) return;
            object applied = appliedTo;
            appliedTo = null;

            if (!ReferenceEquals(host.Identity, applied))
            {
                logger.Verbose("Time controller was replaced during the skip; nothing to restore.");
                return;
            }

            float current = host.Scale;
            if (current != appliedScale)
            {
                logger.Warning("Time scale changed by another owner during the skip (now " + current + "); leaving it unchanged.");
                return;
            }

            host.Scale = priorScale;
        }
    }
}
