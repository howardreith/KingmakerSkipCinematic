# Validation record — Mr. Bard's Kingmaker Cutscene Skip

## Blackout while playback remains at normal speed (2026-11-27, PR #4, unreleased)

Report: Varnhold DLC cinematics and later multi-stage scenes such as "the Kingdom of the Cleansed one with Remus'
speech" go black when skipped but keep playing at ordinary speed until Escape.

**Outcome: not reproduced; root cause in the reporter's game not established.** Both report targets were reached through
their normal triggers on DATA and skip correctly with the released 0.1.2 build, PR #4 and the candidate below. One
mechanism that produces exactly the reported symptom was reproduced natively, by test injection: another owner
replacing the skip's time multiplier. 0.1.2 then stays black at about ordinary speed until the 60 s watchdog; the
candidate reveals at once. Nothing in the tested environment performs that override during real play, so this is not
shown to be what happens in the reporter's game. The report stays open.

### Candidate

| Item | Value |
|---|---|
| Product commits | `2cd8579` (time-override ownership check), `0ff67e3` (game time in the skip report); candidate built and packaged at `f57cd00` from a clean tree |
| `KingmakerCutsceneSkip.dll` | `38e97ae6be46992b3d598dcf1f4e386cd664379d299524a674f22614a9def7f9`, MVID `648f71bb-4a4e-43e6-aa71-72ae387d12e1` |
| `KingmakerCutsceneSkip-0.1.2.zip` | `2967eafc70691ac6680c9c940931b09fe2aabdcbc9e6696fff02e89f8dc42e96` (version string unchanged; identify by hash). `Validate-Package.ps1` passed (references UnityModManager 0.31.1.0, 0Harmony12 1.2.0.1) |
| Compared builds | released 0.1.2 ZIP `c1be6ae2…05fb` (DLL `a2a8706b…a1ba`); PR #4 head `2cd8579` DLL `9f853960…ac58` |
| Tests | `scripts/Test.ps1` at `0ff67e3`: unit 64/64, provenance 70/70, package provenance 35/35 (.NET Framework 4.7.2, C# 7.3, warnings as errors) |
| Environment | DATA, Kingmaker 2.1.7b (build 6757524), disposable game copy, owner's 16 mods on UMM 0.33.0 unless noted, English |

### Report targets and triggers

* **Remus / Kingdom of the Cleansed** is Tristian's quest. Remus is the "Doomsayer" whose sermon opens
  `C22-TristianQ1_Gathering` ("It looks like Remus has returned from his exile..."). Amalia and the First Faithful
  follow, and the gathering ends in the `FirstFaithful_BeforeFight` dialogue. Answering it starts
  `C22-GatheringAmaliaRun`, another dialogue, then combat. Sixteen sermon lines are `CommandBark`s with
  `BarkDurationByText` and `AwaitFinish` (about 113 s of text-timed waits), none voiced. Trigger: the party walks into
  the `C22-TristianQ1_Gathering` script zone (enter action `PlayCutscene`; requires Tristian in the party and
  `Visit_the_Gathering` started). Fixture: the owner's `Quick_432.zks` (`15ca7a07…8cb2`), saved in the
  KingdomOfTheCleansed area before the trigger.
  It does not load under the current mod set. It names 28 blueprints that no installed mod provides (2 features,
  6 feature selections and 10 spells on party members, a kingdom event, and 9 vendor items), so Kingmaker drops
  `Player.MainCharacter` and `Player.PostLoad` throws. The scenarios register inert, component-free stand-ins for
  exactly those GUIDs before loading; the save file is not modified (`placeholderNote` in the scenarios).
* **Varnhold's Lot**: no Varnhold campaign save exists on DATA. A new DLC campaign is started from the main menu with
  the first pregen (`VarnholdPregenBardUnit`) through the engine's `FastStartNewGame` calls and the DLC's
  `StartGamePreset`. The pregen is not levelled to the preset experience. The run plays `StartDLC2_enterchapter` and the
  interchapter dialogue, then the opening `BaronationCeremonyDLC2` (about 125 s, voiced barks). Only this Varnhold
  cinematic was tested; the reporter's Varnhold scene is unknown and remains unverified.

### Measurements

`tools/native/summarize_diag.py` over the harness's per-frame `diag.jsonl` (time controller identity, multipliers,
planned/executed substeps, bark handles). Skips requested through the product API 2 s into each episode (`*-direct`).

| Scene, build | Run | Real s advancing | Game s | Ratio | Substeps executed/planned | End |
|---|---|---|---|---|---|---|
| Gathering, normal playback | 152145Z | trigger to dialogue 160.6 | 159.0 | 1.0 | – | dialogue |
| Gathering, 0.1.2 | 152837Z | 16.58 | 163.39 | 9.86 | 5134/5143 | `ControlReturned` (the engine's one Default frame before the dialogue) |
| Gathering, PR #4 | 152620Z | 16.57 | 163.16 | 9.85 | 5129/5134 | same |
| Gathering + AmaliaRun, PR #4 | 153526Z | 16.44 + 1.46 | 162.19 + 13.90 | 9.87, 9.50 | 5099/5101, 439/448 | `ControlReturned`, `InteractionBoundary` |
| Varnhold opening, 0.1.2 / PR #4 | 154751Z / 154550Z | 12.50 / 12.53 | 121.11 / 121.36 | 9.69 / 9.68 | 3811/3819, 3818/3825 | `ControlReturned` (free control) |
| Gathering, candidate | 160931Z | 16.85 | 163.97 | 9.7 | – | `ControlReturned` |
| Varnhold opening, candidate | 161724Z | 12.27 | 121.41 | 9.9 | – | `ControlReturned` |

In every run the time controller kept one identity and `DebugTimeScale` stayed 10. Each accelerated frame was cut short
at most once, by the `StopMode` deferred action that starts the next mode. Every awaited Gathering bark used
`BarkController` (engine time) with the speaker outside fog of war. The Varnhold voiced barks were interrupted when
acceleration began or the command started. No `BarkVm` (real-time) handle was seen.

### Story state, candidate ZIP (`compare_runs.py`, tolerances unchanged)

| Comparison | Runs | Result |
|---|---|---|
| Gathering normal vs skip, at the dialogue | 160543Z / 160931Z | MATCH (26 units, 65 quests, 404 flags, 346 stacks); game time +7.36 s; real 159.7 s → 18.8 s |
| Gathering normal vs skip cancelled 3 s into advancing, at the dialogue | 160543Z / 161057Z | MATCH; +0.20 s; the cutscene continued natively |
| Gathering + AmaliaRun normal vs skips, at the combat auto-pause | 155947Z / 160406Z | **DIFFERENT (1)**: `C22-Amalia` 1.7 m behind (tolerance 1.5 m); everything else equal; +6.72 s; real 177.8 s → 26.2 s |
| Same, PR #4 head (earlier build) | 153048Z / 153526Z | same difference: Amalia 1.9 m behind, +8.00 s |
| Gathering + AmaliaRun normal vs normal (control) | 153048Z / 155947Z | MATCH; +0.42 s |
| Varnhold opening normal vs skip, at free control | 161416Z / 161724Z | MATCH (32 units); −0.53 s; real 126.7 s → 16.1 s |
| Varnhold opening normal vs cancelled skip | 161416Z / 161842Z | MATCH; +0.30 s |
| Prologue chain normal vs 3 skips (regression), at free control | 162123Z / 162320Z | MATCH; +0.97 s |

The Amalia difference is skip-related and repeatable. Amalia runs off during `C22-GatheringAmaliaRun` and is still
moving when combat pauses. Her command starts at the same game time in both runs (±0.1 s) and the next dialogue starts
0.6 s later in the skipped run, yet she has covered less ground. 1.7 m is about one rendered frame of ×10 game time at
this frame rate. That fits the documented limitation for Unity-driven systems (Animator, per-rendered-frame updates),
but her movement start was not instrumented, so this is not proven. Quests, flags, inventory and every other unit
match. The extra game time of the long Gathering (+7.4 s over 157 s) is larger than the 0.2–1.3 s measured on prologue
segments. It comes from the same per-rendered-frame animation completion; the scene contains many sequential
`CommandUnitPlayCutsceneAnimation`s.

### Mechanism: another owner replaces the skip's multiplier (test injection, not a gameplay trigger)

`cleansed-gathering-override-direct`: skip 2 s into the gathering, and 3 s into advancing the harness sets
`DebugTimeScale = 1`.

| Build | Run | Result |
|---|---|---|
| released 0.1.2 | 162758Z | screen black for the 60 s watchdog (`Watchdog`), scene advancing at ×1.44 (86 game s in 60 s), commands still progressing |
| candidate | 163116Z | `TimeScaleUnavailable` 3.07 s into advancing; overrides released; the other value (1) left in place |

Bag of Tricks, the one installed mod that writes `DebugTimeScale`, does so in a `TimeController.Tick` prefix that
substepped frames never call (`ENGINE-NOTES.md`). At its configured ×1 it writes nothing.

### Loader checks

`startgame-skip-direct` with the candidate ZIP, isolated profile: UMM 0.31.1 (162457Z; loaded `UnityModManager
0.31.1.0`, `0Harmony12 1.2.0.1`) and UMM 0.32.4 (162603Z): one operation each, `InteractionBoundary` at Amiri's
dialogue. UMM 0.33.0 (owner loader): every run above. 0.27.12 and the synthetic profile were not rerun.

### Not executed or not resolved

* **Real keys.** Enter and Escape were not sent: the RDP session was unattended and Windows refused the foreground
  change (154946Z; the harness sends no input then). Cancellation was exercised through the product API. That shows
  release of overrides and native continuation (MATCH above), but not that a real Escape press opens no menu and selects
  no dialogue answer in these scenes. Scenarios ready: `cleansed-gathering-chain-skip-enter`,
  `cleansed-gathering-cancel-escape`.
* The reporter's mods, settings, frame rate, language and exact Varnhold scene are unknown. A `BarkVm` real-time wait
  (unvoiced bark by a fogged speaker) and native-tick frames under Bag of Tricks ≠ 1 remain possible slow paths. Neither
  occurred in these scenes.
* To resume: the reporter's UMM log after a failing skip now contains `advance Xs (Y game s, xR)`, and the warning
  names the end reason and the playing commands. Also needed: their mod list, or a save from just before the Varnhold
  scene they skipped.
* Runs that are not evidence: 140338Z, 142005Z, 143940Z, 144916Z, 151242Z, 151539Z, 151737Z, 151944Z (fixture would not
  load before the stand-ins were complete), 153927Z (runner error before launch), 153949Z (new-game path incomplete).
  All were restored with owner saves and installation unchanged.

Every run listed reports the installation restored and the owner's 95 saves and installation unchanged. The candidate
and harness were never installed in the owner's game.

## Package contract: the packaged DLL's actual loader references (2026-11-24)

**Compiler inputs.** Every MSBuild compile of the product, through `scripts/Build.ps1` or directly
(`dotnet msbuild src/KingmakerCutsceneSkip/KingmakerCutsceneSkip.csproj`), runs `scripts/Assert-PinnedReferences.ps1`
twice: before references resolve, the cache files must match the hashes parsed from `scripts/reference-pins.json`; and in
`LoaderReferences.Final.targets`, imported after `Microsoft.CSharp.targets` (so after `Directory.Build.targets` and any
other repository-level hook) as the last step before `CoreCompile`, the UnityModManager and 0Harmony12 entries Csc
receives must be exactly the two pinned files, re-hashed against the parsed pins. In both checks the CLR identity read
from the same bytes as the digest must be the identity the pin declares (name, version, neutral culture, no token), so a
pin whose digest matches but whose declared version does not is refused. Each compile logs both compiler-input paths and
hashes. These two files, the targets, everything under `src/` (including any `src/Directory.Build.props` or
`src/Directory.Build.targets`) and the root `Directory.Build.props` / `Directory.Build.targets` are product inputs for
the receipt comparison. Digests, CLR identities, entry names and manifest fields are compared with exact ordinal
equality (PowerShell's `-ceq` follows culture rules, under which an ignorable character such as a soft hyphen makes
different strings equal).

**Package validation.** `scripts/Validate-Package.ps1` is the standalone check of what will be installed. It reads the
input once, through one handle, into memory, and takes the digest and every inspection from that snapshot. For a ZIP it
requires exactly the four package entries (`Info.json`, `KingmakerCutsceneSkip.dll`, `README.md`, `LICENSE` under
`KingmakerCutsceneSkip/`). The packaged `Info.json` must name the product's fixed load target (`Id`
`KingmakerCutsceneSkip`, `AssemblyName` `KingmakerCutsceneSkip.dll`, `EntryMethod` `KingmakerCutsceneSkip.Main.Load`,
defined in `scripts/Common.ps1` independently of any manifest file), this checkout's `Version`, and a `ManagerVersion`
equal to the pinned floor (0.31.1). Each of these five members must be present under exactly its declared name
(compared ordinally; PowerShell's member lookup ignores case, so `managerversion` alone is refused), be a string, and be
declared only once in the JSON as written (the raw text is scanned before conversion, which would keep only the last of
repeated names). A bare DLL (`-DllPath`) may be given its `Info.json` (`-InfoPath`). It is read once
through one handle, checked the same way, and protected like the input. The DLL must define `KingmakerCutsceneSkip` with a file version
belonging to the shipping version. Within the UnityModManager and Harmony families (any case, any suffix), the full
identities in its AssemblyRef table, compared ordinally, must be exactly the declared pins:
`UnityModManager, Version=0.31.1.0, Culture=neutral, PublicKeyToken=null` and
`0Harmony12, Version=1.2.0.1, Culture=neutral, PublicKeyToken=null`. A case variant such as `unitymodmanager` is a
different, refused reference. The declared pin is authoritative. A cached pinned file whose digest authenticates it must
also carry the declared identity (digest and identity come from one read), or validation stops. The report is written
through one handle that is refused if it is the snapshot identity or current file of the input or of the supplied
`Info.json`. This also covers a report path that becomes a hard link to the input at publication, and an input replaced
by rename.

- `scripts/Package.ps1` validates the ZIP it builds (a refused ZIP is removed) and records the validated ZIP digest and
  references in its manifest. Documentation-only commits still reuse the frozen DLL. Build-receipt fields are typed
  before any comparison: `status` and `configuration` are strings (the configuration compared without case, since
  `release` and `Release` select the same output), `commit` is a 40-character hexadecimal string, and `dll_sha256` and
  every recorded pinned-reference digest are strings of 64 lowercase hexadecimal characters. The dirty flag
  (`product_inputs_dirty`, or `dirty` in an older receipt) must be a JSON boolean, and a clean claim that lists product
  changes is refused. Each recorded pinned reference's `assembly_version` must equal the pin's declared version
  (normalized to four parts). A boolean, an array or a padded digest is refused, never compared.
- The reference cache refuses an existing entry that does not match its pin (remove it explicitly to re-fetch); only an
  absent entry is downloaded.
- Native runner: `scripts/runtime/RuntimeLab.Common.ps1` is unchanged from `main`, and `scripts/runtime/Invoke-NativeRun.ps1`
  differs from `main` only by a narrow preflight (rounds 9-10, `scripts/runtime/ProductZip.ps1`): a product ZIP that will
  be installed (`-ProductZip` without `-NoProduct`) is copied into a private folder and held open read-only (no writer,
  rename or delete while held), validated by the standalone validator before any lock, backup or staging, and extracted
  through the same handle, so the installed bytes are the validated bytes; one cleanup scope covers the copy from its
  creation, and the runner's `finally` releases it. A ZIP given with `-NoProduct` stays a comparison archive. The
  preflight's tests call it directly in a private fixture folder (refusal with the validator's reference diagnostic, a
  genuine ZIP extracted from the held copy, write/rename/delete refused while held, no copy left after a setup failure
  or after close) and check statically that the runner opens it before the lock and extracts only the held copy; they
  never start the runner. Round 11: a relative `-ProductZip` is resolved with PowerShell's literal file-system
  semantics (`Resolve-Path -LiteralPath`, against the PowerShell location) before .NET copies it. The package-provenance
  suite passes the clean production package it builds through the real preflight with a relative path while the process
  working directory holds a different ZIP of the same name (the admitted ZIP and extracted DLL match the production
  manifest), and runs the real runner in its disposable checkout with fixture overrides (fixture lab and game folders, a
  failing runtime preflight, an unreachable run lock): after validation and handoff the later setup failure leaves no
  private copy in the runner's own temporary folder and nothing in the fixture Mods folder. Round 8 removed
  this change's other runner additions (`scripts/runtime/NativeProduct.ps1`, run-lock ownership, journal handoff and
  recovery) with their tests: native runs are outside this mission's scope and none was made, so no claim about the
  runner's staging or recovery is made here.
- Manifest syntax: a top-level member name that is not a double-quoted JSON string (single-quoted or unquoted, both
  accepted by Windows PowerShell's decoder) and a single-quoted string anywhere (which could hide a brace from the
  scanner's depth) are refused, so the duplicate check counts every declaration the decoder accepts. Whichever dirty flag a receipt uses (`product_inputs_dirty`, or `dirty` in an older receipt), a clean claim
  that lists product changes is refused.
- The published v0.1.2 ZIP (`c1be6ae26f0cb02d4e9cdebbbeba4977472ad8a5349ab441eb8496cc250005fb`) passes: DLL `a2a8706b…a1ba`,
  MVID `a494d31e-dfb6-469f-b2a7-787e3094639d`, file version 0.1.2.0, the two pinned references above.
- Round 8, `scripts/Test.ps1` at `a7a33bc` (the round-8 code): 55/55 unit, provenance 62/62, package provenance 33/33.
  Added: a ZIP manifest whose conflicting earlier `ManagerVersion` is single-quoted and a bare manifest whose conflicting
  earlier `EntryMethod` is unquoted (last declarations genuine) are refused; the alternate build's dirty receipt and DLL
  in the older format (`dirty` false, no `product_inputs_dirty`, the changed file still listed) are refused, and a
  genuine clean receipt in the older format packages; bare manifests with a mismatched `Version`, `ManagerVersion` or
  `Id` are refused by the validator directly. The provenance count is lower than round 7's because the native-runner
  cases were removed with that machinery.
- Round-7 record, `scripts/Test.ps1` at `fd1ac03`: 55/55 unit, provenance 110/110, package provenance 31/31. Cases added
  in rounds 6 and 7 are listed first; the rest are unchanged from earlier rounds. Its native-runner, ZIP-staging and
  recovery cases were removed in round 8 with that machinery and are not listed here.
  - Round 7, receipts: the alternate build's own dirty receipt (digest matching its DLL) after the source is restored is
    refused as recorded and when `product_inputs_dirty` is `null`, `[]` or `"false"`, or `false` while listing the
    changed file; `-Configuration release` packages the genuine Release build and a Debug receipt for a Release package
    is refused; a receipt whose UnityModManager `assembly_version` alone is changed is refused; genuine controls package.
  - Round 7, manifests: `ManagerVersion` declared twice in a ZIP manifest and `EntryMethod` declared twice in a bare
    manifest (last declaration genuine) are refused.
  - Receipt digests: in the temporary checkout, a real build of an uncommitted source change (reverted before packaging)
    gives a different baseline-compatible DLL. Beside it, an otherwise coherent receipt with `dll_sha256` `true` or `[]`
    is refused without any override; the genuine receipt and DLL then package again. Recorded pin digests that are a
    boolean, an empty array or followed by a line feed are problems.
  - Manifest members: `ManagerVersion` spelled `managerversion` in a ZIP manifest and `EntryMethod` spelled `entrymethod`
    in a bare manifest are refused; a manifest with the declared names passes.
  - Fixtures are compiled with the .NET Framework compiler against the pinned files or disposable stub loaders of known
    identity, so no case depends on the installed loader.
  - Reference cases: newer UMM 0.33.0.0; a 0.31.1.0 with another culture; Harmony 2; an extra UMM-family assembly; an
    added case-variant `unitymodmanager` reference at 0.31.1.0 and 0.33.0.0 (fixture AssemblyRef name rewritten in
    place); in a disposable validator root, the genuine package with and without a cache, and a declared version that
    disagrees with the cached assembly.
  - Package cases: wrong assembly name, `AssemblyName`, `EntryMethod`, file version, extra loader payload, raised minimum;
    a soft hyphen in an otherwise correct `EntryMethod` or `ManagerVersion` (ZIP and bare manifest).
  - Report cases: aliases by spelling and hard link; a report below a fresh subdirectory; the input replaced in place and
    by rename right after its snapshot (every report field still comes from the snapshot); a report path aliased to the
    input, or to the replaced current input, at publication (refused, bytes intact). These use a PowerShell line
    breakpoint in a separate process, so the validator has no test hook.
  - Package provenance runs the real build and packaging commands in a temporary checkout: genuine package; build-helper
    change refused, then rebuilt; documentation-only reuse; corrupt cache refused before compilation; a DLL differing
    from its receipt refused; a committed root or `src/Directory.Build.targets` change refused, then rebuilt, with
    documentation-only reuse after it. It also runs
    direct MSBuild builds: a genuine rebuild recording both compiler inputs, a
    substituted cache file refused, a declared version disagreeing with the pinned bytes refused, and a `Directory.Build.targets` hook at the `CoreCompile` boundary that points
    UnityModManager elsewhere refused by the final check. It finds the manifest by the checkout's version.

## Candidate 0.1.2 (UMM compatibility and cinematic safety)

Status: **released as v0.1.2** (GitHub release 2026-11-09, ZIP `c1be6ae2…05fb`, the final ZIP below). A `MATCH` below
means the compared fields matched for the named sequences. It is not a claim about other scenes; see "Not covered".

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

PR #4 (blackout report): see the top section. The report is not reproduced and stays open; the real-key
Enter/Escape rows for the gathering need the owner present. 0.1.2 is released. The package-contract check above is a tooling change on a draft PR; merging it and any later release
or Nexus upload are the owner's decision. `Auto_1120` scenarios need `-ModProfile owner`.
