using Kingmaker.EntitySystem.Persistence;
using Kingmaker.UI;
using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// The native black fade: FadeCanvas shown through LoadingProcess's reference-counted manual loading screen,
    /// the same mechanism CommandFadeout uses, so the skip's claim composes with a cutscene's own fades.
    /// </summary>
    public sealed class KingmakerFadeHost : IManualFadeHost
    {
        private static int resetGeneration;

        /// <summary>Called by the LoadingProcess reset patches whenever the game zeroes the manual-screen count.</summary>
        public static void NotifyManualScreenReset() => resetGeneration++;

        public bool IsAvailable => FadeCanvas.Instance != null;

        public int ResetGeneration => resetGeneration;

        public FadeVisualState State
        {
            get
            {
                FadeCanvas canvas = FadeCanvas.Instance;
                if (canvas == null) return FadeVisualState.Unavailable;
                switch (canvas.GetLoadingScreenState())
                {
                    case LoadingScreenState.Hidden: return FadeVisualState.Hidden;
                    case LoadingScreenState.ShowAnimation: return FadeVisualState.Showing;
                    case LoadingScreenState.Shown: return FadeVisualState.Shown;
                    case LoadingScreenState.HideAnimation: return FadeVisualState.Hiding;
                    default: return FadeVisualState.Unavailable;
                }
            }
        }

        public void Show() => LoadingProcess.Instance.ShowManualLoadingScreen(FadeCanvas.Instance);

        public void Hide() => LoadingProcess.Instance.HideManualLoadingScreen();
    }
}
