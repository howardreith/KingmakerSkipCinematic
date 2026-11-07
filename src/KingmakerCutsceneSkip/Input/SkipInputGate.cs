using System;
using System.Collections.Generic;
using UnityEngine;

namespace KingmakerCutsceneSkip.Input
{
    /// <summary>
    /// Decides, once per frame, which key presses belong to the skip feature and hides them from the game's key bindings.
    /// A claimed key stays hidden until it is physically released, so neither a held key nor its key-up event can
    /// activate the interaction that appears when the skip ends. Unclaimed presses reach the game untouched.
    /// </summary>
    public sealed class SkipInputGate
    {
        private readonly IKeyboardState keyboard;
        private readonly ISkipCommandSink sink;
        private readonly KeyCode[] skipKeys;
        private readonly KeyCode cancelKey;
        private readonly Func<bool> enabled;
        private readonly HashSet<KeyCode> claimed = new HashSet<KeyCode>();
        private int lastPolledFrame = int.MinValue;

        public SkipInputGate(IKeyboardState keyboard, ISkipCommandSink sink, KeyCode[] skipKeys, KeyCode cancelKey, Func<bool> enabled)
        {
            this.keyboard = keyboard ?? throw new ArgumentNullException(nameof(keyboard));
            this.sink = sink ?? throw new ArgumentNullException(nameof(sink));
            this.skipKeys = skipKeys ?? throw new ArgumentNullException(nameof(skipKeys));
            this.cancelKey = cancelKey;
            this.enabled = enabled ?? throw new ArgumentNullException(nameof(enabled));
        }

        public int ClaimedKeyCount => claimed.Count;

        /// <summary>Idempotent within a frame; safe to call from several hooks.</summary>
        public void Poll()
        {
            int frame = keyboard.FrameIndex;
            if (frame == lastPolledFrame) return;
            lastPolledFrame = frame;

            ReleaseClaimsOfReleasedKeys();
            if (!enabled()) return;

            for (int index = 0; index < skipKeys.Length; index++)
            {
                KeyCode key = skipKeys[index];
                if (!keyboard.WentDown(key)) continue;
                if (sink.ShouldSwallowSkipKey || sink.TryStart()) claimed.Add(key);
            }

            if (keyboard.WentDown(cancelKey) && sink.IsSkipping && sink.TryCancel())
            {
                claimed.Add(cancelKey);
            }
        }

        /// <summary>True when the game must not see this key's down/up events in the current frame.</summary>
        public bool IsClaimed(KeyCode key)
        {
            Poll();
            return claimed.Contains(key);
        }

        public void ReleaseAll() => claimed.Clear();

        private void ReleaseClaimsOfReleasedKeys()
        {
            if (claimed.Count == 0) return;
            List<KeyCode> released = null;
            foreach (KeyCode key in claimed)
            {
                if (keyboard.IsHeld(key) || keyboard.WentUp(key)) continue;
                (released ?? (released = new List<KeyCode>())).Add(key);
            }

            if (released == null) return;
            for (int index = 0; index < released.Count; index++) claimed.Remove(released[index]);
        }
    }
}
