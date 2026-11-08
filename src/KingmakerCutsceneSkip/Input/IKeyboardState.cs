using UnityEngine;

namespace KingmakerCutsceneSkip.Input
{
    /// <summary>Per-frame keyboard state. <see cref="FrameIndex"/> identifies the rendered frame the state belongs to.</summary>
    public interface IKeyboardState
    {
        int FrameIndex { get; }

        bool IsHeld(KeyCode key);

        bool WentDown(KeyCode key);

        bool WentUp(KeyCode key);
    }
}
