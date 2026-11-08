using System.Reflection;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.UI;
using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// The native black fade: FadeCanvas shown through LoadingProcess's reference-counted manual loading screen,
    /// the same mechanism CommandFadeout uses, so the skip's claim composes with a cutscene's own fades.
    /// The reported state is that of the screen LoadingProcess is actually displaying for the claim: when an area
    /// loading screen is still up (a cutscene that starts while it hides), that screen already covers the scene.
    /// </summary>
    public sealed class KingmakerFadeHost : IManualFadeHost
    {
        private static readonly FieldInfo CurrentScreenField =
            typeof(LoadingProcess).GetField("m_LoadingScreen", BindingFlags.Instance | BindingFlags.NonPublic);

        private static int resetGeneration;

        /// <summary>Called by the LoadingProcess reset patches whenever the game zeroes the manual-screen count.</summary>
        public static void NotifyManualScreenReset() => resetGeneration++;

        public bool IsAvailable => FadeCanvas.Instance != null;

        public int ResetGeneration => resetGeneration;

        public FadeVisualState State
        {
            get
            {
                ILoadingScreen screen = DisplayedScreen();
                if (screen == null) return FadeCanvas.Instance != null ? FadeVisualState.Hidden : FadeVisualState.Unavailable;
                switch (screen.GetLoadingScreenState())
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

        private static ILoadingScreen DisplayedScreen()
        {
            ILoadingScreen current = CurrentScreenField?.GetValue(LoadingProcess.Instance) as ILoadingScreen;
            if (current is UnityEngine.Object unityObject && unityObject == null) current = null;
            return current ?? FadeCanvas.Instance;
        }
    }
}
