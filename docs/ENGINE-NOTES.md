# Engine and implementation note

Target: Pathfinder: Kingmaker 2.1.7b (Steam build 6757524). `Assembly-CSharp.dll` SHA-256
`3b6450ffec440e296e586f71c711b195aed144b28d53e1cbb29406d18fef5afb`, MVID `07fa1e4d-8618-41b3-9b8d-faa17d3b26f7`.
Every game signature below was read from that assembly (decompiled locally with ilspycmd 9.1; decompiled sources are
never committed). The mod is built against Unity Mod Manager 0.31.1 and its Harmony 1.2 shim (`0Harmony12.dll`), pinned
by version and SHA-256 in `scripts/Common.ps1` and recorded in the build receipt. Supported loaders and the member
audit behind them: `COMPATIBILITY.md`.

## How Kingmaker plays a cutscene

* Each frame `Game.Tick` runs the deferred start-of-frame actions (`m_BeforeTickActions`: game-mode starts/stops,
  dialogue starts, control-lock changes requested during the previous tick) and then `GameMode.Tick` of the top mode,
  which ticks that mode's controller list in a fixed order (`GameModesFactory`). The Cutscene mode's list starts
  `UnitGroupsController, TimeController, KeyboardAccess, CutsceneController, …, UnitMoveController, …,
  UnitActionController, …, ScriptZoneController, …, UnitAnimationController, …` (40 controllers).
* A cutscene is a `CutscenePlayerData` entity. `CutsceneController.Tick` (one per frame in Cutscene, Dialog, Rest and
  global-map modes) calls `TickScene`, which ticks the tracks of every activated `GateData`.
* `TrackData.Tick`: `PlayTime += TimeController.DeltaTime`, then `command.SetTime(PlayTime)`; a non-continuous command
  whose `IsFinished` is true is stopped and the next command started **in the same tick with `PlayTime = 0`**.
  Entry conditions (`EntryCondition`/`OnFail`), gates (`And`/`Or`, first/random track), signals and continuous tracks
  are all evaluated by this code. Story effects run through `CommandAction` → `ActionList.Run()`.
* Kingmaker 2.1.7b has **no skip API**: no skipping flag, `Interrupt`, `CanBeSkipped` or `NonSkippable` (those exist
  only in Wrath). `stop_cutscene`, `CheatResetCutsceneLock`, `CutscenePlayerData.Stop` or `TrackData.ForceStop`
  discard remaining commands; none is used.
* `CommandLockControls` makes a cutscene `Exclusive` and calls `Game.SetCutsceneLock`, which pushes
  `GameModeType.Cutscene` on the game-mode **stack**. Dialogue (`CommandStartDialog` → `DialogController`), rest,
  book events and full-screen UI push their own mode on top; releasing the lock pops back to `Default`
  (exploration or playable real-time combat). `IGameModeHandler.OnGameModeStart` fires synchronously in that call.
* Time: `TimeController.Tick` computes `DeltaTime = min(PlayerTimeScale*DebugTimeScale/12, Time.deltaTime)`, advances
  `Player.GameTime` by it in Default/Cutscene modes and sets `Time.timeScale = PlayerTimeScale*DebugTimeScale*UiTimeScale`.
  `DebugTimeScale` is Owlcat's own speed knob (console `time_scale`; `CameraRig` follow and turn-based waits read it),
  is not serialized, and is the property Wrath's skip sets (`TimeScaleOnSkip`).
* Fade: `UIAccess.Fadeout` shows `FadeCanvas` through `LoadingProcess.ShowManualLoadingScreen` — a reference-counted
  `CountingGuard` shared with `CommandFadeout`. `LoadingProcess.StopAll` / `ResetManualLoadingScreen` zero the count
  (loads, main menu). While a manual screen is up the game cannot be paused.
* Input: `KeyboardAccess.Tick` (a controller ticked inside the mode tick) evaluates mode-scoped bindings; each binding
  reads Unity input only in `KeyboardAccess.Binding.InputMatched()` (`GetKeyDown`, or `GetKeyUp` for release bindings).
  `EscPressed` (Escape) is registered for every mode. Player key bindings (`NextEnd`, `DialogChoiceN`, …) are
  data-driven settings; whatever they are, a claimed key is hidden from all of them.

## Decision: accelerate the engine, never complete commands

A skip runs the cinematic **through the engine's own code at `DebugTimeScale = 10` behind the native black fade**,
until a real interaction boundary. Nothing is marked finished, teleported or removed. This is the same mechanism Wrath
uses (`DebugTimeScale` + fade + audio), minus Wrath's `Interrupt` that teleports movers (teleporting changes cross-track
ordering and skips script zones a mover would cross).

Keeping the commands is not by itself enough to keep their order: at ×10 a rendered frame carries ten frames of engine
time, and how that time is divided between controllers decides which of two parallel tracks observes the other's
effect first. The mod therefore runs each accelerated rendered frame as **complete Cutscene-mode ticks of at most
1/30 game-s** — the whole controller list, in native order, per substep (below). Game logic thus follows the same
tick schedule as normal playback at 30 fps. What it does **not** make equivalent: Unity-driven systems
(Animator/`AnimationManager`, physics, coroutines, A* worker threads, MonoBehaviour updates) still advance once per
rendered frame by ×10 time, so logic waiting on them observes coarser steps (measured below as extra game time).

Lifecycle (`CutsceneSkipController`, single owner of every override):
`Idle → FadingOut (fade + audio ramp, normal speed) → Advancing (time scale applied once the screen reports covered)
→ Revealing (all overrides released; native fade-in; input guard) → Idle`.

Boundaries that end a skip, evaluated every frame **and** synchronously from `OnGameModeStart`/`OnAreaBeginUnloading`
so acceleration stops in the same tick:

| Observation | End reason |
|---|---|
| top mode becomes Dialog, Rest, Pause, FullScreenUi, … | `InteractionBoundary` |
| top mode becomes Default (lock released: exploration or playable combat) | `ControlReturned` |
| `LoadingProcess.IsLoadingInProcess`, area unloading, or an owned `CommandCustomLoadingScreen` | `Loading` |
| turn-based combat active | `TurnBasedCombat` |
| every owned cutscene finished | `SceneComplete` |
| Escape during the skip | `Cancelled` |
| no owned track changed command for 10 s real time | `Stalled` |
| 60 s real time spent advancing | `Watchdog` |
| the native fade did not report full black within 1 s (nothing was accelerated) | `FadeTimeout` |
| exception inside the mod | `Error` |
| mod disabled/unloaded | `Disabled` |

Boundaries are also re-evaluated between the substeps of an accelerated frame, so acceleration stops at the game tick
at which normal playback would hand over. A request is declined (`BoundaryCommandPlaying`) while a controlling
cutscene is already showing a loading card; a card already running when a skip begins is classified like one that
starts during it.

A staged fight inside a cinematic keeps the Cutscene mode and is skipped; playable combat only begins when the lock is
released, which is a boundary. Scope: the operation owns every live `Exclusive` cutscene at start, plus cutscenes that
start while an owned command executes (child scenes) or that themselves lock control. Ambient cutscenes are never added.

## Command categories

| Category (commands) | Behaviour while accelerating |
|---|---|
| Timed: `CommandDelay`, `CommandLockControls` (timed), `CommandFadeout`, `CommandCameraShake`, `CommandSkipTime`, unvoiced `CommandBark` | engine time ×10 |
| Movement: `CommandMoveUnit`, `CommandMoveParty`, `CommandMoveByPath`, `CommandMoveUnitInCamp` | units walk their real paths in normal-sized substeps; paths computed synchronously (below) |
| Animation/staging: `CommandUnitPlayCutsceneAnimation`, `CommandPlayAnimationSequence`, `CommandUnitLookAt`, `CommandSetCombatMode`, `CommandCrossfadeToIdle`, `CommandPlayTimeline` | Unity/Animator time ×10 |
| Camera: `CommandMoveCamera` (timed scroll uses scaled `Time.time`; rubber band ×min(scale,4); 20 s game-time timeout), `CommandCameraFollow` | engine |
| Story/gameplay: `CommandAction`, `CommandActivateGate`, `CommandAddFact`, `CommandMarkUnitControlled`, `CommandUnitAttack`, `CommandUnitCastSpell`, `CommandEndCombat`, `CommandIgnoreCombat`, `CommandResolveRankUp`, `CommandTeleportParty`, `CommandInstantiatePrefab` | executed by the engine, unchanged |
| Voiced bark (`CommandBark` whose handle carries a `VoiceOverStatus`) | waits on **real** audio length → interrupted with the engine's own `IBarkHandle.InterruptBark()`; new voice-overs started during a skip are stopped (`VoiceOverStatus.Stop`) so none plays on after the reveal |
| Interaction: `CommandStartDialog`, `CommandForceCampUI`, `CommandStartSpecialEncounter` | the mode change is the boundary; the dialogue starts normally and nothing is answered |
| `CommandCustomLoadingScreen` (real-time card) | boundary (`Loading`) |
| Unknown/new command types | ordinary execution under acceleration; the stall watchdog reveals normal playback if one waits on something that does not accelerate |

## Accelerated frames: whole-tick substepping

`GameMode.Tick` prefix, active only while a skip is advancing and the top mode is Cutscene
(`Integration/AcceleratedFrameDriver`, scheduling in `Core/FrameSubstepScheduler`, unit-tested):

* The frame's engine delta is `TimeController.Tick`'s own formula, `min(PlayerTimeScale·DebugTimeScale/12,
  Time.deltaTime)`; it is divided into `n = ceil(delta / (1/30))` equal substeps, at most 25 (the formula's cap at ×10).
  Frames that need no division, the frame a mode was just activated, and turn-based combat use the native tick.
* Each substep ticks the mode's controller list in native order. `TimeController` is replaced by its own Cutscene-mode
  bookkeeping for one substep (`DeltaTime` and `GameDeltaTime` = step, `Player.GameTime += step`, `Time.timeScale`
  re-derived). Each controller is isolated with try/catch as in `GameMode.Tick`.
* Controllers that read per-rendered-frame state instead of engine time tick once, in the first substep, at their
  native position: `KeyboardAccess` (key-down edges would fire per substep), the cutscene `CameraController`,
  `WeatherController` (`Time.deltaTime`), `RealtimeLightsController` and `DungeonLeaderboardController`
  (`Time.unscaledDeltaTime`), `CutsceneUIHideController`.
* Between complete substeps the frame ends early when normal playback would have ended it first: the game scheduled
  start-of-frame work (`m_BeforeTickActions` non-empty — e.g. a dialogue start or mode change requested during the
  tick), a load began, or the skip's boundary probe reports a boundary (the skip then ends in that tick, restoring the
  time scale). Unsimulated time is not consumed and no controller receives a partial or stale step.
* After the substeps `DeltaTime`/`GameDeltaTime` are set to the engine time actually simulated this frame, which is
  what code outside the mode tick (unit views, barks, camera rig) reads later in the frame.

Review counterexample, kept as a regression test (`FrameSubstepSchedulerTests`): track A sets a flag when a unit
arrives (0.05 s away), a parallel track B branches on that flag after a 0.15 s delay. Ten normal frames observe the
flag; the previous design (each controller's substeps batched separately) did not; whole-tick substepping matches
normal playback in both controller orders.

## Other fidelity fixes found by native measurement

* **Asynchronous pathfinding.** A* returns paths a few rendered frames after `UnitMovementAgent.PathTo`; at ×10 each
  frame of latency is ten times the game time. → While advancing, `AstarPath.WaitForPath` (the library's blocking call)
  completes the just-queued path immediately. Same path, no latency.
* **Covered-screen detection** uses the screen `LoadingProcess` actually displays (see Overrides).

Remaining measured difference: animation completion is evaluated once per rendered frame (Unity drives
`AnimationManager` with `Time.deltaTime`), so a skipped segment consumes more game time than normal playback (figures
in `VALIDATION.md`). Substepping Unity's animation graph was judged too invasive for this bounded effect.

Consequence for timers: `UnitBuffsController` does not run in the Cutscene mode, but `Player.GameTime` advances there,
so buffs whose end time passed are removed at the next Dialog/Default tick. A buff whose end time falls inside the
extra game time of a skip therefore expires at the boundary in the skipped run but not in the normal run; remaining
durations of all other timed buffs differ by exactly the extra game time (measured, `VALIDATION.md`).

## Overrides and ownership

| Override | Acquire | Release (all exit paths) |
|---|---|---|
| Fade | one `ShowManualLoadingScreen(FadeCanvas)` claim | `HideManualLoadingScreen` only if no `StopAll`/reset happened since (generation counter from postfixes) |
| Covered detection | state of the screen `LoadingProcess` actually displays (`m_LoadingScreen`), so an area loading screen still up counts as covered | — |
| Time | `DebugTimeScale` = max(prior, 10); `Time.timeScale` updated the same frame unless the game suspended time (0) | prior value restored only if the scale is still ours on the same `TimeController` |
| Audio | Wwise RTPC `AudioLevel` ramped to 0 (setting untouched) | re-apply the player's live master-volume setting |
| Input | skip key claimed from press until physical release (hides key-down and key-up from every binding); new skip-key presses swallowed during the skip and 0.35 s after the reveal; Escape claimed only when it cancels | claims expire on release; disable clears them |

The mod serializes nothing of its own: no settings in saves, no blueprint changes, no scene edits. That is narrower
than "cannot affect a save": the game's own scripts run during a skip and their results are saved like any others, and
the small extra game time of a skip (`VALIDATION.md`) counts on timed effects.

Patches stay installed while the mod is disabled but are inert; UMM unload removes them.

## Escape: cancelling a skip is not pausing the game

Two separate paths use the key:

* During `FadingOut` and `Advancing` the input gate claims Escape from press through release. The operation ends
  `Cancelled`: acceleration and the mod's fade, audio and input claims are released, and the same cutscene continues
  natively from its current commands. No command is finished, removed or reordered, and `EscPressed` never reaches the
  game, so the menu does not open.
* In every other state Escape is not claimed. It reaches `KeyboardAccess` -> `EscHotkeyManager` -> `EscMenuWindow`,
  and `Game.StartMode(EscMode)` pauses the scene as without the mod. `EscMode` is a boundary, so a skip never runs
  through the menu.
* During `Revealing` the key is also unclaimed, but the fade still counts as a loading screen and the game's
  `EscMenuWindow` refuses to open while `LoadingProcess.IsLoadingScreenActive`. The press does nothing, as it would
  during any loading screen; a fresh press after the reveal opens the menu.

## Patched methods (Harmony 1.2, owner `howardreith.kingmaker.cutsceneskip`)

`KeyboardAccess.Tick` (prefix), `KeyboardAccess.Binding.InputMatched` (prefix), `CommandBase.Run(CutscenePlayerData)`
(prefix/postfix), `GameMode.Tick` (prefix; runs the frame substepped only while advancing in the Cutscene mode), `UnitMovementAgent.PathTo(...)` (postfix, active only while advancing), `LocalizedString.PlayVoiceOver`
(postfix, active only while skipping), `LoadingProcess.StopAll` / `ResetManualLoadingScreen` /
`CheatRestManualLoadingScreen` (postfix). All are resolved by exact signature before anything is patched; a missing
contract leaves the game untouched and the mod reports itself inactive.

## Unresolved limitations

* Global-map cinematics (`GameModeType.CutsceneGlobalMap`) are declined: not exercised natively.
* No command in `Kingmaker.AreaLogic.Cutscenes*` reads a real-time clock (source audit), but scene-specific logic
  outside those commands, voiced barks and `CommandCustomLoadingScreen` were not reached in a native fixture.
* Turn-based mode: a skip is declined, and ends, while turn-based combat is active.
* Bag of Tricks' game-speed multiplier, when set ≠ 1, rewrites `DebugTimeScale` every tick; a skip then runs at that
  speed (ownership rules leave Bag of Tricks' value in place).
* A cutscene that waits on something else that does not follow engine time would stall; the 10 s stall watchdog then
  reveals normal playback with the playing commands logged.
* Logic coupled to Unity-driven systems (animation events, physics, coroutines) sees ×10 steps per rendered frame;
  only engine-time logic keeps normal granularity.
* Mods that patch `TimeController.Tick` do not see the substeps of an accelerated frame (the mod performs the
  Cutscene-mode time bookkeeping itself).

## Observed by the native harness

* `Game.CreateNewSave` returns a `SaveInfo` that is not marked as saved. `SaveManager.LoadRoutine` ignores such an object with
  a log warning while the rest of the area reload still runs, so the player state is not replaced. A verifier has to load
  the written file (`LoadZipSave`) and observe the state change.
* `Tutorial_1_cutscene` holds Cutscene mode for one frame. A real key press sent in that frame arrives after the mode has
  ended and starts nothing; a player cannot skip that episode, and nothing is left to skip.
