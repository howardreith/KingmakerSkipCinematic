using System;

namespace KingmakerCutsceneSkip.Core
{
    /// <summary>
    /// Silences accelerated audio during a skip. Restoration re-applies the player's live volume setting rather than
    /// a captured value, so a setting changed during the skip is never overwritten with stale data.
    /// </summary>
    public sealed class AudioMuteOverride : IAudioMute
    {
        private readonly IMasterVolumeHost host;
        private readonly Func<bool> enabled;
        private readonly int rampMilliseconds;

        public AudioMuteOverride(IMasterVolumeHost host, Func<bool> enabled, int rampMilliseconds)
        {
            this.host = host ?? throw new ArgumentNullException(nameof(host));
            this.enabled = enabled ?? throw new ArgumentNullException(nameof(enabled));
            this.rampMilliseconds = rampMilliseconds;
        }

        public bool IsMuted { get; private set; }

        public void Mute()
        {
            if (IsMuted || !enabled() || !host.IsAvailable) return;
            host.FadeToSilence(rampMilliseconds);
            IsMuted = true;
        }

        public void Restore()
        {
            if (!IsMuted) return;
            IsMuted = false;
            if (host.IsAvailable) host.RestorePlayerSetting(rampMilliseconds);
        }
    }
}
