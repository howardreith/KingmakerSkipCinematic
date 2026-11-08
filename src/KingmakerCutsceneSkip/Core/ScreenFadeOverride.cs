using System;

namespace KingmakerCutsceneSkip.Core
{
    /// <summary>
    /// Holds at most one reference on the native fade. Releasing decrements only when the claim is still valid,
    /// so a game-side reset (load, main menu) can never be followed by a decrement that steals another owner's claim.
    /// </summary>
    public sealed class ScreenFadeOverride : IScreenFade
    {
        private readonly IManualFadeHost host;
        private int heldGeneration;

        public ScreenFadeOverride(IManualFadeHost host)
        {
            this.host = host ?? throw new ArgumentNullException(nameof(host));
        }

        public bool IsHeld { get; private set; }

        private bool ClaimIsValid => IsHeld && host.ResetGeneration == heldGeneration;

        public bool IsFullyFaded => ClaimIsValid && host.State == FadeVisualState.Shown;

        public bool IsRevealed
        {
            get
            {
                FadeVisualState state = host.State;
                return state == FadeVisualState.Hidden || state == FadeVisualState.Unavailable;
            }
        }

        public bool TryAcquire()
        {
            if (IsHeld) return true;
            if (!host.IsAvailable) return false;
            heldGeneration = host.ResetGeneration;
            host.Show();
            IsHeld = true;
            return true;
        }

        public void Release()
        {
            if (!IsHeld) return;
            bool valid = ClaimIsValid;
            IsHeld = false;
            if (valid) host.Hide();
        }
    }
}
