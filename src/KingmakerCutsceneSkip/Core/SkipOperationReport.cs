using System.Globalization;

namespace KingmakerCutsceneSkip.Core
{
    /// <summary>Diagnostic summary of one finished skip operation (logged; never persisted in saves).</summary>
    public sealed class SkipOperationReport
    {
        public int OperationId { get; set; }
        public SkipEndReason Reason { get; set; }
        public string Detail { get; set; }
        public double FadeOutSeconds { get; set; }
        public double AdvanceSeconds { get; set; }
        public double TotalHeldSeconds { get; set; }
        public bool ReachedFullBlack { get; set; }
        public int ProgressEvents { get; set; }

        /// <summary>
        /// Engine game time that passed while advancing (NaN when unknown: no game, or the skip ended because loading
        /// began). Compared with <see cref="AdvanceSeconds"/> it shows whether the scene actually ran faster than normal
        /// playback. It includes any game time the scene itself jumps forward (for example a scripted time skip).
        /// </summary>
        public double GameSecondsAdvanced { get; set; }
        public string PlayingCommandsAtEnd { get; set; }

        public override string ToString()
        {
            return string.Format(
                CultureInfo.InvariantCulture,
                "skip #{0} ended: {1}{2} | fade-out {3:0.00}s (full black: {4}), advance {5:0.00}s{9}, held {6:0.00}s, progress events {7}{8}",
                OperationId,
                Reason,
                string.IsNullOrEmpty(Detail) ? string.Empty : " (" + Detail + ")",
                FadeOutSeconds,
                ReachedFullBlack ? "yes" : "no",
                AdvanceSeconds,
                TotalHeldSeconds,
                ProgressEvents,
                string.IsNullOrEmpty(PlayingCommandsAtEnd) ? string.Empty : " | playing: " + PlayingCommandsAtEnd,
                DescribeGameTime());
        }

        private string DescribeGameTime()
        {
            if (!(AdvanceSeconds > 0) || double.IsNaN(GameSecondsAdvanced) || GameSecondsAdvanced < 0) return string.Empty;
            return string.Format(CultureInfo.InvariantCulture, " ({0:0.00} game s, x{1:0.0})", GameSecondsAdvanced, GameSecondsAdvanced / AdvanceSeconds);
        }
    }
}
