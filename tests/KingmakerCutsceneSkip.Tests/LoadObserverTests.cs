using System;
using KingmakerCutsceneSkip.RuntimeHarness;

namespace KingmakerCutsceneSkip.Tests
{
    public static class LoadObserverTests
    {
        private const long Saved = 100;
        private const long Marked = 1100;
        private static readonly object OldPlayer = new object();
        private static readonly object NewPlayer = new object();

        private static void Expect(LoadProgress expected, LoadProgress actual)
        {
            if (expected != actual) throw new Exception("expected " + expected + ", got " + actual);
        }

        private static LoadObserver Observer() => new LoadObserver(0, OldPlayer, Saved);

        public static void RealLoadCompletesAfterStateIsReplacedAndMarkerUndone()
        {
            LoadObserver o = Observer();
            Expect(LoadProgress.Waiting, o.Observe(0.1, true, OldPlayer, true, true, Marked));
            Expect(LoadProgress.Waiting, o.Observe(5.0, true, NewPlayer, false, false, Saved));
            Expect(LoadProgress.Waiting, o.Observe(5.5, false, NewPlayer, true, true, Saved));
            Expect(LoadProgress.Complete, o.Observe(6.1, false, NewPlayer, true, true, Saved));
        }

        public static void RejectedRequestIsNeverComplete()
        {
            LoadObserver o = Observer();
            Expect(LoadProgress.Waiting, o.Observe(1.0, false, OldPlayer, true, true, Marked));
            Expect(LoadProgress.Waiting, o.Observe(LoadObserver.BeginTimeoutSeconds, false, OldPlayer, true, true, Marked));
            Expect(LoadProgress.NeverBegan, o.Observe(LoadObserver.BeginTimeoutSeconds + 0.1, false, OldPlayer, true, true, Marked));
        }

        public static void LoadingThatLeavesTheOldStateFails()
        {
            LoadObserver o = Observer();
            o.Observe(0.1, true, OldPlayer, true, true, Marked);
            Expect(LoadProgress.StateNotReplaced, o.Observe(1.2, false, OldPlayer, true, true, Marked));
        }

        public static void MarkerSurvivingTheLoadFails()
        {
            LoadObserver o = Observer();
            o.Observe(0.1, true, NewPlayer, true, true, Marked);
            Expect(LoadProgress.SentinelNotRestored, o.Observe(1.2, false, NewPlayer, true, true, Marked));
        }

        public static void GapBetweenLoadingProcessesGivesNoVerdict()
        {
            LoadObserver o = Observer();
            o.Observe(0.1, true, OldPlayer, true, true, Marked);
            Expect(LoadProgress.Waiting, o.Observe(0.5, false, OldPlayer, true, true, Marked));
            Expect(LoadProgress.Waiting, o.Observe(0.6, true, NewPlayer, false, false, Saved));
            Expect(LoadProgress.Complete, o.Observe(1.7, false, NewPlayer, true, true, Saved));
        }

        public static void LoadThatNeverBecomesPlayableFails()
        {
            LoadObserver o = Observer();
            o.Observe(0.1, true, NewPlayer, false, false, Saved);
            Expect(LoadProgress.Waiting, o.Observe(30.0, false, NewPlayer, false, false, Saved));
            Expect(LoadProgress.NotPlayable, o.Observe(LoadObserver.PlayableTimeoutSeconds + 0.2, false, NewPlayer, false, false, Saved));
        }

        public static void WithoutAnExpectedValueTheReplacedStateIsEnough()
        {
            LoadObserver o = new LoadObserver(0, OldPlayer, null);
            o.Observe(0.1, true, NewPlayer, false, false, 7);
            Expect(LoadProgress.Complete, o.Observe(1.2, false, NewPlayer, true, true, 7));
        }
    }
}
