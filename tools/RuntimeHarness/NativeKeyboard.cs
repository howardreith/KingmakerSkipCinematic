using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// Real operating-system key events, sent only while this game process owns the foreground window, so a test can
    /// never type into another application. Unity then observes them exactly like a physical keyboard.
    /// </summary>
    internal static class NativeKeyboard
    {
        private const uint KeyUp = 0x0002;
        private const uint ExtendedKey = 0x0001;

        [DllImport("user32.dll")] private static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
        [DllImport("user32.dll")] private static extern uint MapVirtualKey(uint code, uint mapType);

        public static bool IsGameForeground()
        {
            GetWindowThreadProcessId(GetForegroundWindow(), out uint processId);
            return processId == (uint)Process.GetCurrentProcess().Id;
        }

        public static bool EnsureForeground()
        {
            if (IsGameForeground()) return true;
            IntPtr window = Process.GetCurrentProcess().MainWindowHandle;
            if (window != IntPtr.Zero) SetForegroundWindow(window);
            return IsGameForeground();
        }

        public static bool Send(string key, bool down)
        {
            if (!IsGameForeground()) return false;
            Resolve(key, out byte virtualKey, out bool extended);
            byte scan = (byte)MapVirtualKey(virtualKey, 0);
            uint flags = (down ? 0u : KeyUp) | (extended ? ExtendedKey : 0u);
            keybd_event(virtualKey, scan, flags, UIntPtr.Zero);
            return true;
        }

        private static void Resolve(string key, out byte virtualKey, out bool extended)
        {
            extended = false;
            switch (key)
            {
                case "Return": virtualKey = 0x0D; break;
                case "KeypadEnter": virtualKey = 0x0D; extended = true; break;
                case "Escape": virtualKey = 0x1B; break;
                case "Space": virtualKey = 0x20; break;
                case "Alpha1": virtualKey = 0x31; break;
                default: throw new ArgumentException("Unsupported harness key: " + key);
            }
        }
    }
}
