# Nexus text for owner review

Nothing here has been posted. Replace the mod page wording only when a release is published.

## Replacement page copy

**Mr. Bard's Kingmaker Cutscene Skip**

Press **Enter** during a cinematic. The screen fades to black, the cinematic plays out at high speed with its story
actions still running, and the screen fades back at the next dialogue, choice, or when you regain control. Press
**Escape** while it is skipping to stop and watch the rest of the scene normally.

**How it works.** The game's own cutscene scripts keep running, in order, only faster and out of sight. The mod does not
complete or remove scene commands and never picks a dialogue answer for you. It stops at every dialogue, book event, rest
screen, loading screen or area change, at playable combat, and whenever you regain control.

**Requirements.** Pathfinder: Kingmaker 2.1.7b and Unity Mod Manager 0.31.1 or later. Tested on 0.31.1, 0.32.4 and 0.33.0.
If your newer Unity Mod Manager already works with your other mods, there is no need to downgrade.

**What has been tested.** Identical saves were played normally and with skips through the prologue and the opening of the
night attack, and skip cancellation was compared in the prologue. Quests, flags, inventory, party and NPC state matched.
Craft Magic Items and Kingmaker Bugfixes were checked while installed alongside it; skipping with those two mods has not
been tested separately.

**Limitations.**
* Other cinematics use the same engine paths but were not individually tested, so a problem in a later scene cannot be
  ruled out. Keep a save from before an important scene, as with any mod.
* If acceleration stalls or exceeds its time limit, the mod stops accelerating and returns to visible playback. This does
  not guarantee that every cinematic is free of scene-specific problems.
* A skipped cinematic uses up to about a second more in-game time per segment. Timed effects count that time, so a buff
  about to expire can run out during a skipped scene when it would not have during a watched one.
* Skips are not available on the global map or in turn-based mode.
* If Bag of Tricks' game-speed multiplier is not 1, skips run at that speed.

**Saves.** The mod adds no data of its own to save files, so a save does not need the mod to load. A skip still runs the
game's scripts, and their results are saved as usual.

**Found a problem?** Please include the quest and location, your Unity Mod Manager and mod versions, a save from before the
scene, and what you did.

## Proposed replies

Drafted against the current test state. Update them if the blocked real-key rows in `VALIDATION.md` are completed first.

### Compatibility request

> Thanks for the request. The next version (0.1.2) lowers the minimum to Unity Mod Manager 0.31.1. I tested it on 0.31.1,
> 0.32.4 and 0.33.0, using loaders assembled from the upstream UMM and Harmony components rather than the original Nexus
> installers. On each it ran alongside Craft Magic Items and Kingmaker Bugfixes, with an item crafted and kept through a
> save and reload, though that check didn't include skipping a scene. I couldn't get hold of 0.27.10, so I'm not claiming
> anything older than 0.31.1.
>
> On the 0.32+ reports: Harmony 2.3.5 did break Craft Magic Items in a test setup, and Harmony 2.3.6, used by UMM 0.32.4,
> has the fix, so it doesn't apply to all of 0.32+. I couldn't test the original 0.32.0-0.32.3 downloads. If your UMM
> already works, there's no need to downgrade.

### Safety warning

> Thanks for the warning, it's a fair thing to check. A skip doesn't drop or finish scene commands: the game's own script
> keeps running, only faster behind the black screen. Pressing Escape during a skip just stops the speed-up, and the scene
> carries on normally. That's separate from the Escape menu, which pauses the game as usual.
>
> I compared identical saves played normally and skipped through the prologue and the start of the night attack, and
> skipped then cancelled in the prologue. Quests, flags, inventory, party and NPCs matched. One known difference is up to
> about a second of extra game time per segment, so a buff about to expire can end sooner. I haven't tested every scene,
> especially later chapters.
>
> If you've seen a quest break, could you share a save from before the scene, the quest and location, your UMM and mod
> versions, and the steps to reproduce it? I'd like to look into it.
