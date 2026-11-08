# Mr. Bard's Kingmaker Cutscene Skip

A cutscene skip mod for Pathfinder: Kingmaker.

Press **Enter** during a cinematic. The screen fades to black, the cinematic plays out at high speed with every story
action still happening, and the screen fades back at the next dialogue, choice or the moment you regain control —
the way Wrath of the Righteous skips cinematics.

## Requirements

* Pathfinder: Kingmaker 2.1.7b (Steam). If a different game build lacks any method the mod relies on, the mod stays
  inactive and says so in its settings panel and log.
* [Unity Mod Manager](https://www.nexusmods.com/site/mods/21) 0.31.1 or later, installed for Pathfinder: Kingmaker.
  Tested on 0.31.1, 0.32.4 and 0.33.0 (details and limits in `docs/COMPATIBILITY.md`). If your newer Unity Mod Manager
  already works with your other mods, there is no need to downgrade. Other versions of 0.31.x, and 0.32.0-0.32.3, were
  not tested.

## Installation

1. Open Unity Mod Manager, select Pathfinder: Kingmaker, open the **Mods** tab.
2. Drag `KingmakerCutsceneSkip-<version>.zip` onto the window (or click **Install Mod** and choose the ZIP).
3. Start the game. **Mr. Bard's Kingmaker Cutscene Skip** appears in the mod list (Ctrl+F10) with a green status.

Manual alternative: extract the ZIP so that `Mods\KingmakerCutsceneSkip\Info.json` sits inside the game folder.

## Controls

| Key | When | Effect |
|---|---|---|
| Enter / keypad Enter | a cinematic has taken control of the game | fade out and skip ahead |
| Escape | while the screen is fading to black or black during a skip | stop skipping; the cinematic continues normally from where it is, and the menu does not open |

Holding Enter or pressing it repeatedly starts only one skip, and the press that started it never reaches the dialogue
or choice that appears next. Outside a skip Escape is the game's own Escape: it opens the menu, and the cinematic
pauses and resumes as usual. During the half second while the screen fades back in, the game ignores Escape as it does
during any loading screen; press it again once the picture is back. Outside cinematics Enter behaves as without the
mod.

## What a skip does — and does not do

* The game's own cutscene engine keeps running, only faster and out of sight: quest updates, items, party changes,
  NPCs appearing or leaving, fights staged inside the cinematic all happen. Game logic runs in the same normal-sized
  steps and order as when watching; only animation timing is coarser (see limitations).
* It **stops** at every dialogue (even one with a single *Continue*), book/story event, rest screen or other window
  that needs you, at playable combat, when you regain control, and at loading screens or area transitions.
  It never picks an answer or makes a choice for you. Press Enter again to skip the next part.
* Audio is muted while the screen is black (can be turned off in the settings panel). Voice lines of skipped barks
  are cut.
* The mod adds no data of its own to save files, so a save does not need the mod to load. A skip still runs the
  game's own scripts, and whatever they change is saved as usual, exactly as if you had watched the scene.

## Settings (Ctrl+F10 → Mr. Bard's Kingmaker Cutscene Skip)

* **Mute game audio while skipping** (on by default).
* **Write detailed skip diagnostics to the log** (off by default). Every skip is summarised in the Unity Mod Manager
  log either way.

## Known limitations

* Cinematics on the global map are not skipped (Enter does nothing there).
* No skipping while turn-based combat mode is active.
* Animations finish on whole frames at high speed, so a skipped cinematic uses a little more in-game time than
  watching it (about 0.2–1 s per segment in testing). Timed effects count that extra time, so a buff with less than
  about a second to spare can run out during a skipped cinematic but not during a watched one.
* If Bag of Tricks' game-speed multiplier is set to anything other than 1, skips run at that speed instead.
* Tested in the prologue and the opening of the night attack (see `docs/VALIDATION.md`). Other cinematics use the same
  engine paths but were not individually tested, so a problem in a particular later scene cannot be ruled out. Keep a
  save from before an important scene, as you would with any mod. If you see a problem, please report the quest and
  location, your Unity Mod Manager and mod versions, and a save from before the scene.
* If a cinematic cannot be skipped safely, the mod reveals normal playback within about 10 seconds and logs which
  command it waited on. If the screen does not go black, the skip is abandoned and the scene simply continues.

## Removal

Uninstall in Unity Mod Manager (or delete `Mods\KingmakerCutsceneSkip`). The mod adds nothing to saves that would need
cleaning up.

## Building from source

Requirements: Windows, .NET SDK 8 (for `dotnet msbuild`), the .NET Framework 4.7.2 reference assemblies, and a local
Kingmaker 2.1.7b installation.

```powershell
Copy-Item GamePath.props.example GamePath.props   # then set KingmakerInstallDir
powershell -ExecutionPolicy Bypass -File scripts\Build.ps1      # artifacts\bin\Release\KingmakerCutsceneSkip\
powershell -ExecutionPolicy Bypass -File scripts\Test.ps1       # deterministic unit tests
powershell -ExecutionPolicy Bypass -File scripts\Package.ps1    # artifacts\package\KingmakerCutsceneSkip-<version>.zip
```

Game assemblies are referenced from your installation and never copied into the build output or the package. The
Unity Mod Manager and Harmony shim references are downloaded by `scripts\Build.ps1` at pinned versions and SHA-256
hashes and recorded in the build receipt, so a local loader update cannot change what the mod is built against.
Native test tooling lives in `tools/` and `scripts/runtime/`; see `docs/VALIDATION.md`.

## License

MIT. See `LICENSE`.
