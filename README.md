# Cutscene Skip for Pathfinder: Kingmaker

Press **Enter** during a cinematic. The screen fades to black, the cinematic plays out at high speed with every story
action still happening, and the screen fades back at the next dialogue, choice or the moment you regain control —
the way Wrath of the Righteous skips cinematics.

## Requirements

* Pathfinder: Kingmaker 2.1.7b (Steam). If a different game build lacks any method the mod relies on, the mod stays
  inactive and says so in its settings panel and log.
* [Unity Mod Manager](https://www.nexusmods.com/site/mods/21) 0.33.0 or later, installed for Pathfinder: Kingmaker.

## Installation

1. Open Unity Mod Manager, select Pathfinder: Kingmaker, open the **Mods** tab.
2. Drag `KingmakerCutsceneSkip-<version>.zip` onto the window (or click **Install Mod** and choose the ZIP).
3. Start the game. **Cutscene Skip** appears in the mod list (Ctrl+F10) with a green status.

Manual alternative: extract the ZIP so that `Mods\KingmakerCutsceneSkip\Info.json` sits inside the game folder.

## Controls

| Key | When | Effect |
|---|---|---|
| Enter / keypad Enter | a cinematic has taken control of the game | fade out and skip ahead |
| Escape | while the screen is black during a skip | stop skipping; the cinematic continues normally from where it is |

Holding Enter or pressing it repeatedly starts only one skip, and the press that started it never reaches the dialogue
or choice that appears next. Outside cinematics Enter and Escape behave exactly as without the mod.

## What a skip does — and does not do

* The game's own cutscene engine keeps running, only faster and out of sight: quest updates, items, party changes,
  NPCs appearing or leaving, fights staged inside the cinematic — everything happens, in the original order.
* It **stops** at every dialogue (even one with a single *Continue*), book/story event, rest screen or other window
  that needs you, at playable combat, when you regain control, and at loading screens or area transitions.
  It never picks an answer or makes a choice for you. Press Enter again to skip the next part.
* Audio is muted while the screen is black (can be turned off in the settings panel). Voice lines of skipped barks
  are cut.
* Nothing is written to your saves. Saves made after skipping load normally with the mod removed.

## Settings (Ctrl+F10 → Cutscene Skip)

* **Mute game audio while skipping** (on by default).
* **Write detailed skip diagnostics to the log** (off by default). Every skip is summarised in the Unity Mod Manager
  log either way.

## Known limitations

* Cinematics on the global map are not skipped (Enter does nothing there).
* No skipping while turn-based combat mode is active.
* Animations finish on whole frames at high speed, so a skipped cinematic uses up to about a second more in-game time
  than watching it. Story results are the same.
* If Bag of Tricks' game-speed multiplier is set to anything other than 1, skips run at that speed instead.
* Validated in the prologue and the opening of the night attack (see `docs/VALIDATION.md`). Other cinematics use the
  same engine paths but were not individually tested. If one cannot be skipped safely, the mod reveals normal playback
  within about 10 seconds and logs which command it waited on.

## Removal

Uninstall in Unity Mod Manager (or delete `Mods\KingmakerCutsceneSkip`). No save cleanup is needed.

## Building from source

Requirements: Windows, .NET SDK 8 (for `dotnet msbuild`), the .NET Framework 4.7.2 reference assemblies, and a local
Kingmaker 2.1.7b installation with UMM.

```powershell
Copy-Item GamePath.props.example GamePath.props   # then set KingmakerInstallDir
powershell -ExecutionPolicy Bypass -File scripts\Build.ps1      # artifacts\bin\Release\KingmakerCutsceneSkip\
powershell -ExecutionPolicy Bypass -File scripts\Test.ps1       # deterministic unit tests
powershell -ExecutionPolicy Bypass -File scripts\Package.ps1    # artifacts\package\KingmakerCutsceneSkip-<version>.zip
```

Game assemblies are referenced from your installation and never copied into the build output or the package.
Native test tooling lives in `tools/` and `scripts/runtime/`; see `docs/VALIDATION.md`.

## License

MIT. See `LICENSE`.
