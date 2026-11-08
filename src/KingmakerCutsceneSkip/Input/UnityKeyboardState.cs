using UnityEngine;

namespace KingmakerCutsceneSkip.Input
{
    public sealed class UnityKeyboardState : IKeyboardState
    {
        public int FrameIndex => Time.frameCount;

        public bool IsHeld(KeyCode key) => UnityEngine.Input.GetKey(key);

        public bool WentDown(KeyCode key) => UnityEngine.Input.GetKeyDown(key);

        public bool WentUp(KeyCode key) => UnityEngine.Input.GetKeyUp(key);
    }
}
