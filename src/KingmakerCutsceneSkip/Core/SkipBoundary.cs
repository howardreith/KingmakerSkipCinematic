namespace KingmakerCutsceneSkip.Core
{
    /// <summary>A reason, observed in the game, for an active skip to stop.</summary>
    public struct SkipBoundary
    {
        public static readonly SkipBoundary None = new SkipBoundary(null, null);

        public SkipBoundary(SkipEndReason? reason, string detail)
        {
            Reason = reason;
            Detail = detail;
        }

        public SkipEndReason? Reason { get; }

        public string Detail { get; }

        public bool IsReached => Reason.HasValue;

        public static SkipBoundary Of(SkipEndReason reason, string detail) => new SkipBoundary(reason, detail);
    }
}
