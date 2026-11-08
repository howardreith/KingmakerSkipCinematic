# Validation record — Cutscene Skip 0.1.0

Status: **candidate validated natively for the documented scope** (V1–V7 below; one partial noted).
Machine DATA (Windows 10 19045), Pathfinder: Kingmaker 2.1.7b Steam build 6757524, UMM 0.33.0, run 2026-11-07/08.

## Candidate identity

| Item | Value |
|---|---|
| Product source | unchanged since commit `8620407`; native matrix run on commit `91f3e4f` |
| Package built from | commit `39371c3` (branch `feature/cutscene-skip`; later commits are documentation only) |
| `KingmakerCutsceneSkip.dll` SHA-256 | `9ad4a19617a2e537ba8547d36a8f42205c4b94011f3388096936e76118864708` (identical in every validated run and in the ZIP) |
| `KingmakerCutsceneSkip-0.1.0.zip` SHA-256 | `a1ec9ff7202e5470fb4af1cb7cf419e461c252df3be594dc41800007b73ed927` |
| Unit tests | 39/39 (`scripts/Test.ps1`) |

Every native run listed below loaded exactly this DLL (hash recorded per run in `host-summary.json`), except the two
runs marked *product absent*.

## Method

* `scripts/runtime/Invoke-NativeRun.ps1` launches through Steam with a scenario; the test-only harness
  (`tools/RuntimeHarness`) redirects all persistent data to a disposable per-run profile, loads a **copy** of a fixture
  save from the main menu and executes scripted steps. Skips are requested with **real OS key events**
  (`keybd_event`, sent only while the game window is foreground), never by calling the mod.
* Dialogues are advanced with one deterministic rule (first not-yet-chosen answer) in both normal and skipped runs.
* Evidence per run: frame-correlated `timeline.json` (mode, skip phase, fade, time scale, audio RTPC, cutscenes,
  dialogue cue, every cutscene command start with game time, story-state changes tagged with the skip phase), semantic
  `snapshot-*.json`, UI-inclusive screenshots every 3–4 frames around each skip, UMM and player logs.
* `tools/native/compare_runs.py` compares normal vs skipped state at the same boundary: quests and objectives, unlocked
  flags, inventory, money, party, every area unit (presence, death, HP, combat flag, position within 1.5 m — spawned
  units are paired by blueprint), dialogue position and presentation state. Game time and real time are reported, not
  normalised.
* Two mod profiles: **owner** (the owner's 16 installed mods + Cutscene Skip + harness) and **isolated** (only Cutscene
  Skip + harness). Evidence directories are under the lab's `runtime-evidence/` (outside Git: game imagery and logs).

## Scenes

| Scene | Fixture | Content |
|---|---|---|
| `StartGame_cutscene` (prologue opening) | `Auto_1069` (time-zero prologue autosave) | 3 control-locking segments (staging, camera, 16 animation tracks; ~19 parallel `CommandMoveUnit`/`CommandUnitLookAt` tracks; delays), each ending in a dialogue (Amiri, Jamandi, Kaessi), then `Tutorial_1_cutscene` and free control; NPC spawns and a quest start inside the chain |
| `FirstRoom_cutscene` (night attack) | `Auto_1120` + native area transition | area load into Jamandi's Mansion; cutscene starts **during the loading screen**; segment → Linzi dialogue → segment ending in **playable combat** (assassin attack, auto-pause); an NPC spawn inside the second segment |

## Results

| Row | Evidence (run id suffix) | Result |
|---|---|---|
| **V1** passive staging, waits, camera, movement | `startgame-skip-enter-owner` (011749Z) vs mod-absent normal (011145Z) | MATCH (22 area units, 11 flags, inventory, party, dialogue cue). Black screen 0.94 s (fade 0.31 + advance 0.63); real time pre→boundary 6.69 s → 2.60 s |
| **V2** direct transition to interactive dialogue; Enter does not choose | same; contact sheet `contact-sheet.png` (000351Z) | stops at Amiri's single-*Continue* cue `Cue_0001`; cue unchanged 1 s later and with Enter held 1.8 s across the boundary (`chain-lifecycle`, snapshot `held-boundary`) |
| **V3** story/NPC/party state change | `firstroom-skip-owner` (012353Z) timeline `story` events; chain runs | NPC spawn (units 30→31) executed **during `Advancing`**; final state MATCH. In the chain, two NPC spawns and the start of `Quest_FirstSteps` happen at episode boundaries (outside acceleration) and match after three skipped segments (012044Z, 012558Z) |
| **V4** handoff to playable combat; return to exploration elsewhere | `firstroom-skip-owner` vs `firstroom-normal-owner` (012230Z); `contact-combat-handoff.png` | MATCH at the combat auto-pause (30 area units incl. HP/positions, 18 flags, quest, party). Game time +0.61 s; real time 8.07 s → 1.86 s. Combat did not progress under acceleration (skip ended the same frame the lock released). Return to exploration: prologue chain reaches free control with identical state |
| **V5** multiple coordinated tracks; loading boundary | chain (19+ concurrent tracks, 3 gates); `firstroom-lifecycle` (010728Z) | coordinated tracks: MATCH. Load requested mid-skip → `Loading`; afterwards scale 1.0, Unity time 1.0, fade hidden, no manual screen, audio 100, new Enter starts nothing in the loaded dialogue. A cutscene starting under a still-visible area loading screen is treated as already covered (no extra fade). Enter while a load is in progress is declined by contract (`Loading` blocker; not pressed natively) |
| **V6** mid-scene request | every skip run (Enter 0–2.5 s into a segment) | ✓ |
| V6 held / repeated Enter | `chain-lifecycle` (010533Z); unit tests | one operation per press; held key hidden until release incl. key-up |
| V6 cancel | `chain-lifecycle` | Escape → `Cancelled` after 0.42 s advancing; scene continued at normal speed and reached Jamandi's dialogue (`Cue_0008`); Escape menu did not open; final state at free control MATCH (+0.89 s) |
| V6 unsupported/exception recovery | `chain-lifecycle` (controlled one-shot fault in the boundary probe) | `Error` logged with exception; all overrides released; scene continued normally |
| V6 interruption after effects applied | `firstroom-lifecycle` | disable via UMM mid-skip → `Disabled`, overrides released, Enter while disabled does nothing; re-enable works; load mid-skip → `Loading` |
| **V7** mod absent / disabled | `startgame-normal-owner-noproduct` vs `startgame-normal-owner` | normal playback identical with and without the mod (game time −0.01 s) |
| V7 input outside cinematics | `chain-lifecycle` (`enter-in-exploration`), `firstroom-lifecycle` (`after-load-enter`) | Enter in exploration and in a dialogue: no skip, no state change |
| V7 save after skips, reload without the mod | save `KMCS_AFTER_SKIPS` from `chain-lifecycle`; `reload-without-mod-owner-noproduct` (011029Z) | loads with Cutscene Skip absent; quests, flags, inventory, party identical; three ambient roaming NPCs 1.9–3.0 m apart (moved during the seconds between snapshot, save and reload) |
| Isolated profile | `startgame-skip-enter-isolated` (011350Z) | MATCH vs normal; owner mods restored (16) |

Owner saves: the 95 real save files hashed before/after every run — unchanged in all runs. Mods folder, UMM
`Params.xml` and the game's registry settings were restored after every run, including development runs that failed in
the host script (one, before the game launched, was completed with `-RecoverOnly`).

## Timing compared with normal playback

| Sequence | Normal game time | Skipped game time | Real time normal → skipped |
|---|---|---|---|
| StartGame segment A (from 2.5 s in) | 5.58 s | 6.25 s | 6.69 → 2.60 s |
| Prologue chain (3 skipped segments + 4 dialogues) | 28.94 s | 32.05 s (+3.1 s) | 58.8 → 39.4 s* |
| Night attack (2 skipped segments) to combat | 7.99 s | 8.60 s (+0.6 s) | 8.07 → 1.86 s |

\* dominated by the harness answering 21 dialogue cues at one per second.

Skipped scenes consume ~0.2–1.1 s more game time per segment: animation completion is evaluated once per rendered
frame (~0.33 game-s at ×10). Three larger step-size effects found by aligning command start times were fixed
(see `ENGINE-NOTES.md`). No combat, buff or quest timing difference was observed in the compared states.
Black screen per skip: 0.3 s fade-out + 0.4–1.5 s advance; fade-in 0.3 s (native `FadeCanvas.FadeTimer`).

## Not covered / limitations

* Global-map cinematics (declined by design), turn-based mode, `CommandCustomLoadingScreen` and voiced barks were not
  reached in the available fixtures; their handling is implemented from the engine contract only.
* Fixtures are the prologue; later chapters and DLC cinematics were not individually exercised (the owner's later
  campaign saves need mods that are no longer installed).
* Coexistence verified with the owner's installed set only (BagOfTricks, BetterVendors, CallOfTheWild, CheatMenu,
  CraftMagicItems, EddicKingmakerRespec, KingmakerBuffPlanner, KingmakerBugfixes, KingmakerDiceRoller,
  KingmakerGunslinger, KingmakerLastAzlantiPreserver, ProperFlanking2, RacesUnleashed, SkipIntro, TweakOrTreat,
  ZFavoredClass). Bag of Tricks' game-speed cheat (default 1, as configured) would override the skip speed when changed.

## Re-running

```powershell
scripts\Build.ps1; dotnet msbuild tools\RuntimeHarness\KingmakerCutsceneSkip.RuntimeHarness.csproj /p:Configuration=Release
scripts\runtime\Invoke-NativeRun.ps1 -Scenario tests\native\scenarios\firstroom-skip.json -ModProfile owner
python -I tools\native\compare_runs.py <normal-evidence> <skipped-evidence> boundary
```

Interrupted run: `scripts\runtime\Invoke-NativeRun.ps1 -RecoverOnly`. Scenario definitions: `tests/native/scenarios/`.

## Resume point

Next useful steps: owner manual test on a live campaign (list in the PR), then additional fixtures for global-map and
later-chapter cinematics if they are wanted in scope.
