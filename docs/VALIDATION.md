# Validation record — Cutscene Skip 0.1.0 (review revision)

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
| Comparator self-test | 11/11 (`python -I tools/native/test_compare_runs.py`) |

## Method

* `scripts/runtime/Invoke-NativeRun.ps1` launches through Steam; the test-only harness redirects persistent data to a
  disposable profile, loads a **copy** of a fixture save and executes scripted steps. A run passes only when the
  scenario passed, the installation was restored and the owner's saves are unchanged.
* Skip requests: `pressKey`/autoplay send **real OS key events** (only while the game window is foreground);
  `skipDirect`/autoplay `"key": "direct"` call the product's `TryStart` and are labelled `*-direct` below. A direct
  request exercises the same skip lifecycle, scope, fade, acceleration and boundaries, but not the input gate.
* Assertions are bound to operations: every skip-key press or direct request records the product's started-operation
  counter; `waitSkipIdle` requires exactly one new operation that finished with the expected end reason; `expectNoSkip`
  requires that no operation started since the mark; autoplay requires one started operation per press and fails if a
  press could not be sent.
* Snapshots: quests, objectives, flags, inventory, money, party, every area unit (presence, death, HP, combat flag,
  faction, position, buffs with remaining duration, ability resources, active toggles, action cooldowns), dialogue
  position, presentation (debug and Unity time scale, fade, manual loading screen, audio, pause).
* `tools/native/compare_runs.py` compares those fields (rules in its header). Initiative order is dice-dependent
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

Run the real-key scenarios listed above on `39852adf…` and record them here; then the owner's manual test list in the
PR.
