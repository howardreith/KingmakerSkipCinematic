using UnityModManagerNet;

namespace KingmakerCutsceneSkip
{
    public sealed class Settings : UnityModManager.ModSettings
    {
        /// <summary>Silence game audio while the screen is black during a skip.</summary>
        public bool MuteAudioWhileSkipping = true;

        /// <summary>Write per-request and per-command diagnostics to the UMM log.</summary>
        public bool VerboseDiagnostics;

        public override void Save(UnityModManager.ModEntry modEntry)
        {
            Save(this, modEntry);
        }
    }
}
