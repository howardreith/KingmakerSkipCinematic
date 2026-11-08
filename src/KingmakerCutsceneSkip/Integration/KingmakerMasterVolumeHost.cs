using Kingmaker;
using Kingmaker.UI.SettingsUI;
using KingmakerCutsceneSkip.Core;

namespace KingmakerCutsceneSkip.Integration
{
    /// <summary>
    /// The Wwise "AudioLevel" RTPC that SoundSettingsController drives from the master volume setting.
    /// Muting writes only the RTPC; the player's saved setting is never modified.
    /// </summary>
    public sealed class KingmakerMasterVolumeHost : IMasterVolumeHost
    {
        private const string MasterLevelRtpc = "AudioLevel";

        public bool IsAvailable => SoundSettings?.MasterVolume != null;

        public void FadeToSilence(int durationMilliseconds)
        {
            AkSoundEngine.SetRTPCValue(MasterLevelRtpc, 0f, null, durationMilliseconds);
        }

        public void RestorePlayerSetting(int durationMilliseconds)
        {
            float level = SoundSettings.MasterVolume.NormalizedValue * 100f;
            AkSoundEngine.SetRTPCValue(MasterLevelRtpc, level, null, durationMilliseconds);
        }

        private static SoundSettingsController SoundSettings => Game.Instance?.SettingsManager?.SoundSettingsController;
    }
}
