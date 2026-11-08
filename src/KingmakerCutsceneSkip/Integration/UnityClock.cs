using KingmakerCutsceneSkip.Core;
using UnityEngine;

namespace KingmakerCutsceneSkip.Integration
{
    public sealed class UnityClock : IClock
    {
        public double RealTimeSeconds => Time.realtimeSinceStartup;
    }
}
