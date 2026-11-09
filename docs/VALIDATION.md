# Validation record — Mr. Bard's Kingmaker Cutscene Skip

## Candidate 0.1.2 (UMM compatibility and cinematic safety)

Status: **the listed checks are complete; not yet accepted by the owner.** A `MATCH` below means the compared fields
matched for the named sequences. It is not a claim about other scenes; see "Not covered".

| Item | Value |
|---|---|
| `KingmakerCutsceneSkip.dll` SHA-256 | `a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba` (deterministic) |
| Final `KingmakerCutsceneSkip-0.1.2.zip` SHA-256 | `c1be6ae26f0cb02d4e9cdebbbeba4977472ad8a5349ab441eb8496cc250005fb`, built and packaged at `8fb95da` |
| Earlier ZIPs | `ec60d96a…` (built at `69fefdb`, used for the story-state rows and the original loader matrix) and `13321f92…`. Same DLL and `Info.json`; only `README.md` differs |
| Change from 0.1.1 | version strings, `ManagerVersion` 0.31.1, pinned build references. No behaviour change: `git diff a7ecb13 -- src` touches only the project references and version strings |
| Unit tests / provenance tests / comparator | 55/55; 11/11; 12/12 |
| Environment | machine DATA, Kingmaker 2.1.7b build 6757524, disposable full game copy (`-GameCopy`), runs 2026-11-08 (ids below are `20261108T…`) |

Every real-key, negative-control, smoke and persistence row below ran on the final ZIP, with a clean tree at the harness
commit in its `host-summary.json`, except the Escape-menu run 174739Z, which used `ec60d96a…` (same DLL). Run 202141Z
repeated Escape cancel while advancing on the final ZIP. Later commits change only the harness, scenarios and documentation.

Loader and coexistence matrix: `COMPATIBILITY.md`.

### Story state: matched runs from identical copies of a save

`compare_runs.py`, tolerances unchanged. UMM 0.33.0 unless noted.

| Comparison | Runs | Result |
|---|---|---|
| Normal, mod absent vs present | 160733Z / 160846Z (StartGame); 161227Z / 161429Z (chain) | MATCH; game time -0.04 s, +0.01 s |
| Normal vs completed skip, direct | 160846Z / 161118Z (StartGame); 161429Z / 161632Z (3-segment chain) | MATCH; +0.56 s, +0.88 s |
| Same on UMM 0.31.1 | 165511Z / 165714Z (chain) | MATCH; +1.29 s |
| Normal vs real-Enter skip | 160846Z / 180653Z; final ZIP 195903Z | MATCH; +0.58 s both; `MageArmorBuff` -0.55 s, the game-time difference |
| Normal vs real-Enter chain (3 skips) | 161429Z / 201437Z; pressed one frame after each episode is seen 210512Z | MATCH at free control; +1.01 s, +1.20 s |
| Normal vs real-Enter night attack | 170838Z and 171011Z / 202541Z (owner mods) | MATCH; -0.05 s, -0.08 s; second skip ended `ControlReturned` |
| Normal vs real-Enter skip with Craft Magic Items and Bugfixes, same mods and loader on both sides | 0.31.1 210702Z / 203241Z; 0.32.4 210815Z / 203550Z; 0.33.0 210927Z / 203858Z | MATCH; +0.37 s, +0.48 s, +0.45 s |
| Normal vs skip cancelled while advancing, direct | 161429Z / 161813Z | MATCH at free control; -0.18 s |
| Normal vs skip cancelled during fade-out, direct | 161429Z / 171301Z | MATCH at free control; -0.19 s; 0 s advanced |
| Normal vs normal control, night attack | 170838Z / 171011Z (owner mods) | MATCH; +0.03 s |
| Normal vs skip, night attack, direct | 170838Z and 171011Z / 171137Z | MATCH; -0.00 s, -0.03 s; second skip ended `ControlReturned` |
| Menu pause and resume, mod absent vs present (API-driven native handler) | 164839Z / 165357Z | MATCH; +0.03 s |
| Save after direct skips, reload with the mod removed | 165855Z, 171503Z (mod-only); 170038Z, 171607Z (owner mods, others kept) | loaded; all state equal except two NPC positions, below |

Reload positions: `StartAdventurer_3` and `_8` differ by about 4.5 m between the pre-save snapshot and the snapshot 2 s
after load. A control from a normal playthrough with the mod absent (174432Z save, 174636Z reload) shows the same movement,
and the normal-origin and skip-origin reloads MATCH each other (one NPC 0.61 m, within tolerance). These NPCs walk during the
wait; it is not skip-related. No tolerance was changed.

Two earlier results are test errors, not findings: `Auto_1120` in a profile without the owner's mods never finishes loading
(162116Z, 163023Z, 163932Z; the save depends on those mods), and 1.5 s into StartGame the screen is still black, so the
mod's fade finishes in a frame and the fade-cancel step missed it (162010Z, 175020Z).

### Real keys

| Case | Run | Result |
|---|---|---|
| Enter starts exactly one skip, stops at dialogue, no answer chosen | 195903Z | pass, operation 1 `InteractionBoundary`, state MATCH |
| Escape while advancing cancels; no menu; a fresh Escape opens the native menu and the next closes it; no further skip | 174739Z | pass, operation 1 `Cancelled`, state MATCH vs 164839Z |
| Escape during fade-out | 200211Z | pass, operation 1 `Cancelled` after 0.13 s, before full black |
| Escape during the reveal | 200517Z | pass, operation 1 `InteractionBoundary`; the key is not claimed and `EscMenuWindow` refuses while a loading screen is active, so no menu opens; a fresh Escape then opens the native menu and the next closes it; no new skip |
| Keypad Enter, held and repeated Enter | 200824Z | pass, one operation only, `InteractionBoundary` |
| Enter and Escape outside cinematics | 201133Z | pass, no operation |
| Enter in exploration with the mod absent | 204206Z | pass, no operation |
| Key-started chain | 201437Z | pass, three operations, each `InteractionBoundary`, state MATCH |
| Key-started chain, pressed as soon as each episode can receive a key | 210512Z | pass, three presses, three operations, state MATCH |
| Held Enter across a boundary, Escape cancel, injected fault mid-skip, then autoplay, Enter in exploration, save | 202141Z | pass, operations `InteractionBoundary`, `Cancelled`, `Error`; no skip from the exploration Enter |
| Night attack | 202541Z | pass, `InteractionBoundary` then `ControlReturned` at the combat auto-pause, state MATCH |
| Disable mid-skip, re-enable, load a save mid-skip | 202909Z | pass, `Disabled` then `Loading`; Enter while disabled and after the load started nothing |
| Enter skip with Craft Magic Items and Bugfixes on 0.31.1, 0.32.4, 0.33.0 | 203241Z, 203550Z, 203858Z | pass, one operation `InteractionBoundary`, state MATCH (above) |

Failed and corrected: 201803Z pressed Enter at the first sight of every episode and reported four presses but three
operations. `Tutorial_1_cutscene` holds Cutscene mode for a single frame in every chain run, including normal ones. A real
key arrives at least a frame after it is sent, so that press landed after the mode had ended and correctly started nothing.
A direct request can land in that frame (034236Z), which is why this was not seen before. The scenario now presses on the
next frame, so a one-frame episode gets no press. The rule that each press starts exactly one operation is unchanged.

Runs 175640Z, 181200Z, 181403Z, 181604Z, 181711Z, 181844Z, 182012Z, 182236Z, 182343Z failed with the harness refusing to
send keys to a window that was not foreground. They are not evidence in either direction.

### Verifier controls

`verifier-negative-controls` (204440Z) passes only if each injected fault makes its check fail:

* A render fault injected into the settings view is caught through the product's own exception logging ("settings GUI
  failed"). `Main.OnGui` keeps its exception handling.
* A suppressed load request reports "load did not begin within 15s" with `began` false, not a successful reload.
* The real load in the same run ends `Complete` with the player state replaced.

The panel check now needs repaints that logged no failure (45-47 repaints on 0.31.1, 0.32.4 and 0.33.0) and a settings
round trip: `MuteAudioWhileSkipping` flipped, saved, read back, flipped again, read back and restored.

### Correction: earlier same-process reloads did not prove persistence

`loadLastSave` originally passed the object returned by `CreateNewSave`, which is not marked as saved. `SaveManager.LoadRoutine`
silently ignores such an object while the rest of the area reload still runs, so the area reloaded and the running player
state stayed in place. The check could not tell the difference. Those runs did not prove that anything survived a save.
The review's negative test exposed this ("loading ran but the player state was not replaced", 194206Z to 195516Z).

`loadLastSave` now loads the file the game wrote, adds a 1234-money marker first, and requires the player state object to
be replaced and the money to return to its saved value. This affects the "save, reload" part of the smokes and the CMI
"kept through save and reload" rows from before commit `b2bbded`. They are superseded by 204707Z, 205234Z, 205800Z (smokes)
and 204917Z, 205443Z, 210008Z (CMI), each `Complete` with the player state replaced. Reloads with the mod removed start a
new process and load from disk, so they were never affected.

### Not covered

* Voiced barks, `CommandCustomLoadingScreen`, global-map scenes, turn-based mode and movement-dependent scripted triggers
  were not reached. The chain covers unit movement, parallel tracks and waits, animations and dialogue starts; the night
  attack covers a scene that starts during an area transition.
* Combat handoff with auto-pause turned off was not separately run.
* The Craft Magic Items and Bugfixes skip covers the first StartGame cinematic. The crafting check and the skip check are
  separate runs; no skip was performed in the crafting scenario.
* Later content: `Auto_1076/1077/1079/1080` (DLC dungeon) and `Auto_1082` load into exploration with no cinematic, so they
  add no coverage (171715Z-172144Z). `Auto_1116` fails with `LoadGameException` under the owner's current mod set
  (172250Z); the cause was not investigated and it is not attributed to this mod. The save is preserved unchanged.
* No synthetic cinematic fixture was built: starting scenes outside their scripted context would not represent real triggers.

### Owner environment

Every run above reports the owner's installation and 95 saves unchanged and its copy restored (99 runs since 15:00Z, no
integrity problems). Runs execute only in the disposable copy; the candidate and harness were never installed in the
owner's game. After the last run there are 95 saves, 16 mods with no candidate or harness, and no recovery journal. Settings and
log files in the owner's installation were written at 18:33-18:35Z and 19:39-19:41Z. No run of this work was active then: both
fall inside windows this work held open for another Kingmaker session on this machine.

## Release 0.1.1

| Item | Value |
|---|---|
| Released DLL SHA-256 | `61ca1afb481fafd23bc6f9cefa0269ed74af7e6c23ccecc0f865c6fe0a5a7328` (built and packaged at commit `7ede77f`, provenance verified) |
| `KingmakerCutsceneSkip-0.1.1.zip` SHA-256 | `ac3db162f48caf9707fa179f4afa5706655714be4f7ba7481b99cef91321cc17` |
| Relation to the validated candidate | product source identical to the candidate `39852adf…` below except the display name and version strings (`Info.json`, `ProductMetadata.cs`, `AssemblyInfo.cs`) |
| Native smoke test of the released DLL | `startgame-skip-direct-owner` (045228Z): loaded as "Mr. Bard's Kingmaker Cutscene Skip 0.1.1", ended `InteractionBoundary` at Amiri's dialogue, state MATCH vs normal (+0.35 s game time), installation restored, owner saves unchanged |
| Accepted by the owner with | the real-key rows below still not re-run on the new scheduling code |

## Review revision (candidate 0.1.0)

Status: **partial.** The review revision (whole-tick substepping, fade-timeout reveal, loading-card classification)
is validated natively for story fidelity, boundaries and restoration with the skip **requested through the product's
API** (`skipDirect`). The rows that depend on **real key input** (V2 "Enter does not choose", held/repeated Enter,
Escape cancel, Enter outside cinematics, disable/load mid-skip via key-started skips, isolated profile) have **not yet
been re-run on this DLL**: during this session the remote desktop session was locked and then refused foreground
changes, and the harness only sends key events to a foreground game window. The input code (`Input/`,
`Patches/InputPatches.cs`) is unchanged since the previous candidate, whose real-key results are listed under
"Previous candidate" for reference only.

Machine DATA (Windows 10 19045), Pathfinder: Kingmaker 2.1.7b Steam build 6757524, UMM 0.33.0, runs 2026-11-08.

## Candidate identity

| Item | Value |
|---|---|
| Product source | commit `b2f4bd6` (review fixes); later commits change only tests, tooling and documentation |
| `KingmakerCutsceneSkip.dll` SHA-256 | `39852adfb02bfe3c83aa573ad3fb0dfa73e59f2cef50d3285fca1fb3eea6cebe` (deterministic; identical in every run below and in the build receipt) |
| Package | see the PR description (built with `scripts/Package.ps1`, which verifies the build receipt) |
| Unit tests | 48/48 (`scripts/Test.ps1`), including `FrameSubstepSchedulerTests` (review counterexample) |
| Comparator self-test | 12/12 (`python -I tools/native/test_compare_runs.py`) |

## Method

* `scripts/runtime/Invoke-NativeRun.ps1` launches through Steam; the test-only harness redirects persistent data to a
  disposable profile, loads a **copy** of a fixture save and executes scripted steps. A run passes only when the
  scenario passed, the installation was restored and the owner's saves are unchanged.
* Skip requests: `pressKey`/autoplay send **real OS key events** (only while the game window is foreground);
  `skipDirect`/autoplay `"key": "direct"` call the product's `TryStart` and are labelled `*-direct` below. A direct
  request exercises the same skip lifecycle, scope, fade, acceleration and boundaries, but not the input gate.
* Assertions are bound to operations: every skip-key press or direct request records the product's started-operation
  counter; `waitSkipIdle` requires exactly one new operation that finished with the expected end reason; `expectNoSkip`
  requires that no operation started since the mark; an autoplay step that requests skips fails unless the product is
  loaded, at least one request was made, every press reached the game and each request started exactly one operation.
* Snapshots: quests, objectives, flags, inventory, money, party, every area unit (presence, death, HP, combat flag,
  faction, position, buffs with remaining duration, ability resources, active toggles, action cooldowns), dialogue
  position, presentation (debug and Unity time scale, fade, manual loading screen, audio, pause).
* `tools/native/compare_runs.py` compares those fields (rules in its header). Timed buff durations are paired only
  within the same blueprint and suppression state. Initiative order is dice-dependent
  (`UnityEngine.Random`, unseeded per launch): it differed between two **normal** runs too (below), so the initiative
  schedule must match and the per-unit order is reported as a note.
* Timer fixture: StartGame and night-attack scenarios apply, identically in normal and skipped runs, `BlessBuff` (3 s /
  4 s, expires inside the cinematic) and `MageArmorBuff` (600 s, measures remaining-duration drift) to the main
  character right after the `pre` snapshot.

## Results on candidate `39852adf…`

| Row | Evidence (run id) | Result |
|---|---|---|
| **V1** staging, waits, camera, movement | `startgame-normal-owner` (032958Z) vs `startgame-skip-direct-owner` (033447Z) | MATCH (22 area units, 11 flags, inventory, party, dialogue cue, buffs). Ended `InteractionBoundary` at Amiri's dialogue; black 0.94 s (fade 0.34 + advance 0.59). Game time pre→boundary 5.54 → 5.94 s (+0.40 s); real time 6.64 → 2.84 s |
| V1 timer | same | `BlessBuff` expired in both runs; `MageArmorBuff` time left 594.50 vs 594.13 s (−0.37 s, equal to the game-time difference) |
| **V3** story/NPC change during acceleration | `firstroom-skip-direct-owner` (033722Z, 034726Z) | NPC spawn (units 30→31) recorded during `Advancing` in both runs at game time ≤ 43249.62 (frame-sampled; normal runs 43249.41–43249.46); final state MATCH |
| **V4** handoff to playable combat | `firstroom-normal-owner` (033553Z, 034601Z, 034844Z) vs `firstroom-skip-direct-owner` (033722Z, 034726Z) | MATCH in both pairs at the combat auto-pause (30 area units incl. HP/positions/faction/buffs, 18 flags, quest, party). Second skip ended `ControlReturned` (lock released). Game time +0.01 s / +0.06 s; real time 7.81 → 1.80 s / 7.80 → 2.24 s. Initiative order differed in both pairs **and between normal runs 033553Z and 034601Z** (d20) |
| **V5** coordinated tracks across a chain | `prologue-chain-normal-owner` (033846Z) vs `prologue-chain-skip-direct-owner` (034052Z) | 3 skips, each `InteractionBoundary`; state at free control MATCH. Game time 28.90 → 29.73 s (+0.82 s); real time 58.86 → 39.30 s |
| V5/V6 request at the first frame of every episode | `prologue-chain-skip-immediate-direct-owner` (034236Z) | MATCH at free control (+1.29 s game time). The fourth request landed in the frame control was released and ended `ControlReturned` immediately (no acceleration) |
| **V7** mod absent | `startgame-normal-owner-noproduct` (034417Z) vs `startgame-normal-owner` (032958Z) | normal playback identical with and without the mod (game time ±0.00 s; buff time −0.04 s) |
| Restoration | all 19 runs of this session, including failed ones | installation restored and owner saves (95 files) unchanged after every run |

### Not yet re-run on this DLL (real key input required)

V2 (Enter reaches no dialogue answer; held Enter across the boundary), V6 held/repeated Enter, Escape cancel,
controlled fault, disable and load mid-skip, V7 Enter in exploration/dialogue, save after skips and reload without
the mod, isolated profile. Scenarios: `startgame-skip-enter`, `firstroom-skip`, `prologue-chain-skip`,
`chain-lifecycle`, `firstroom-lifecycle`, `startgame-skip-enter -ModProfile isolated`, then `reload-without-mod
-NoProduct` with the new `KMCS_AFTER_SKIPS` save copied to the lab's `fixtures/`.

### Runs that are not evidence

* 033120Z, 033242Z, 035110Z, 035209Z, 035510Z, 035612Z, 035719Z: failed before the first key event (game window not
  foreground); restored, saves unchanged.
* 035315Z `prologue-chain-skip-owner`: reported *passed* by the harness revision at that time although all three key
  presses were refused (no skip happened; it is effectively a normal run). The harness now fails autoplay when a press
  cannot be sent. Recorded here because it is exactly the false-pass class the review identified.

## Timing compared with normal playback

| Sequence | Normal game time | Skipped game time | Previous candidate (per-controller substeps) |
|---|---|---|---|
| StartGame segment A (from 2.5 s in) | 5.54 s | 5.94 s (+0.40) | +0.67 s |
| Prologue chain (3 skipped segments) | 28.90 s | 29.73 s (+0.82) | +3.1 s |
| Night attack (2 skipped segments) to combat | 7.73 s | 7.74 s (+0.01) / +0.06 | +0.61 s |

The remaining difference comes from Unity-driven animation completing on rendered frames (`ENGINE-NOTES.md`). Timed
buffs count it: remaining durations differ by the game-time difference, and a buff whose end time falls inside it
expires at the boundary in the skipped run only. No other timer-, resource- or cooldown-dependent difference was
observed in the compared states.

## Previous candidate (`9ad4a196…`, superseded; reference only)

Real-key results on the previous DLL (same input code): Enter 2.5 s into StartGame stopped at Amiri's single-Continue
cue with the cue unchanged 1 s later and with Enter held 1.8 s across the boundary; Escape cancelled after 0.42 s
advancing without opening the Escape menu; Enter in exploration and in a loaded dialogue started nothing; disable and
load mid-skip released every override; a save made after skips loaded with the mod absent. Those runs predate the
operation-bound assertions, so their pass status rests on the timelines rather than the harness verdict alone.

## Not covered / limitations

* Global-map cinematics (declined by design), turn-based mode, `CommandCustomLoadingScreen` and voiced barks were not
  reached in the available fixtures; their handling is implemented from the engine contract only.
* Fixtures are the prologue; later chapters and DLC cinematics were not individually exercised.
* Coexistence verified with the owner's installed set only (16 mods; see `README.md`). Bag of Tricks' game-speed cheat
  would override the skip speed when changed from 1.

## Re-running

```powershell
scripts\Build.ps1; dotnet msbuild tools\RuntimeHarness\KingmakerCutsceneSkip.RuntimeHarness.csproj /p:Configuration=Release
scripts\runtime\Invoke-NativeRun.ps1 -Scenario tests\native\scenarios\firstroom-skip.json -ModProfile owner
python -I tools\native\compare_runs.py <normal-evidence> <skipped-evidence> boundary
```

Key-input runs need an unlocked, interactive session in which the game window can take the foreground. Interrupted
run: `scripts\runtime\Invoke-NativeRun.ps1 -RecoverOnly`.

## Resume point

Candidate 0.1.2 awaits the owner's review and manual checks in the PR. Merge, release, Nexus upload and replies are the
owner's decision. `Auto_1120` scenarios need `-ModProfile owner`.
