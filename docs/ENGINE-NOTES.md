# Engine and implementation note

Target: Pathfinder: Kingmaker 2.1.7b (Steam build 6757524). `Assembly-CSharp.dll` SHA-256
`3b6450ffec440e296e586f71c711b195aed144b28d53e1cbb29406d18fef5afb`, MVID `07fa1e4d-8618-41b3-9b8d-faa17d3b26f7`.
Unity Mod Manager 0.33.0 with the bundled Harmony 1.2 (`0Harmony12.dll`). Every signature below was read from that
assembly (decompiled locally with ilspycmd 9.1; decompiled sources are never committed).

## How Kingmaker plays a cutscene

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
until a real interaction boundary. Every condition, gate, signal, branch and `CommandAction` executes exactly as in
normal playback and in the same order; nothing is marked finished, teleported or removed. This is the same mechanism
Wrath uses (`DebugTimeScale` + fade + audio), minus Wrath's `Interrupt` that teleports movers: teleporting changes
cross-track ordering and skips script zones a mover would cross, and the native comparisons below show that faithful
acceleration already reaches identical state.

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
| exception inside the mod | `Error` |
| mod disabled/unloaded | `Disabled` |

A staged fight inside a cinematic keeps the Cutscene mode and is skipped; playable combat only begins when the lock is
released, which is a boundary. Scope: the operation owns every live `Exclusive` cutscene at start, plus cutscenes that
start while an owned command executes (child scenes) or that themselves lock control. Ambient cutscenes are never added.

## Command categories

| Category (commands) | Behaviour while accelerating |
|---|---|
| Timed: `CommandDelay`, `CommandLockControls` (timed), `CommandFadeout`, `CommandCameraShake`, `CommandSkipTime`, unvoiced `CommandBark` | engine time ×10 |
| Movement: `CommandMoveUnit`, `CommandMoveParty`, `CommandMoveByPath`, `CommandMoveUnitInCamp` | units walk their real paths ×10; movement ticks substepped; paths computed synchronously (below) |
| Animation/staging: `CommandUnitPlayCutsceneAnimation`, `CommandPlayAnimationSequence`, `CommandUnitLookAt`, `CommandSetCombatMode`, `CommandCrossfadeToIdle`, `CommandPlayTimeline` | Unity/Animator time ×10 |
| Camera: `CommandMoveCamera` (timed scroll uses scaled `Time.time`; rubber band ×min(scale,4); 20 s game-time timeout), `CommandCameraFollow` | engine |
| Story/gameplay: `CommandAction`, `CommandActivateGate`, `CommandAddFact`, `CommandMarkUnitControlled`, `CommandUnitAttack`, `CommandUnitCastSpell`, `CommandEndCombat`, `CommandIgnoreCombat`, `CommandResolveRankUp`, `CommandTeleportParty`, `CommandInstantiatePrefab` | executed by the engine, unchanged |
| Voiced bark (`CommandBark` whose handle carries a `VoiceOverStatus`) | waits on **real** audio length → interrupted with the engine's own `IBarkHandle.InterruptBark()`; new voice-overs started during a skip are stopped (`VoiceOverStatus.Stop`) so none plays on after the reveal |
| Interaction: `CommandStartDialog`, `CommandForceCampUI`, `CommandStartSpecialEncounter` | the mode change is the boundary; the dialogue starts normally and nothing is answered |
| `CommandCustomLoadingScreen` (real-time card) | boundary (`Loading`) |
| Unknown/new command types | ordinary execution under acceleration; the stall watchdog reveals normal playback if one waits on something that does not accelerate |

## Fidelity fixes found by native measurement

Comparing command start times (game time) between normal and skipped runs exposed three step-size effects, each
fixed without changing semantics:

1. **Discarded frame remainder.** `TrackData.Tick` restarts `PlayTime` at 0 for the next command, discarding the rest of
   the frame's delta. At ×10 and ~30 fps a frame is ~0.33 game-s, so each sequential command lost ~0.17 s.
   → While advancing, `CutsceneController.Tick` is substepped with `TimeController.SetDeltaTime` into steps ≤ 1/30 s.
2. **Movement step size.** `UnitMovementAgent.TickMovement` brakes on the final approach (`sqrt(2·a·d)`); large steps
   overshoot. → `UnitMoveController.Tick` is substepped the same way.
3. **Asynchronous pathfinding.** A* returns paths a few rendered frames after `UnitMovementAgent.PathTo`; at ×10 each
   frame of latency is ten times the game time. → While advancing, `AstarPath.WaitForPath` (the library's blocking call)
   completes the just-queued path immediately. Same path, no latency.

Remaining measured difference: animation completion is evaluated once per rendered frame (Unity drives
`AnimationManager` with `Time.deltaTime`), so a skipped segment consumes ~0.2–1.1 s more game time than normal playback
(prologue chain of three segments: 32.1 s vs 28.9 s; night attack: 8.6 s vs 8.0 s). Story state is identical.
Substepping Unity's animation graph was judged too invasive for this bounded effect.

## Overrides and ownership

| Override | Acquire | Release (all exit paths) |
|---|---|---|
| Fade | one `ShowManualLoadingScreen(FadeCanvas)` claim | `HideManualLoadingScreen` only if no `StopAll`/reset happened since (generation counter from postfixes) |
| Covered detection | state of the screen `LoadingProcess` actually displays (`m_LoadingScreen`), so an area loading screen still up counts as covered | — |
| Time | `DebugTimeScale` = max(prior, 10); `Time.timeScale` updated the same frame unless the game suspended time (0) | prior value restored only if the scale is still ours on the same `TimeController` |
| Audio | Wwise RTPC `AudioLevel` ramped to 0 (setting untouched) | re-apply the player's live master-volume setting |
| Input | skip key claimed from press until physical release (hides key-down and key-up from every binding); new skip-key presses swallowed during the skip and 0.35 s after the reveal; Escape claimed only when it cancels | claims expire on release; disable clears them |

Nothing is serialized: no settings in saves, no blueprint changes, no scene edits. Patches stay installed while the mod
is disabled but are inert; UMM unload removes them.

## Patched methods (Harmony 1.2, owner `howardreith.kingmaker.cutsceneskip`)

`KeyboardAccess.Tick` (prefix), `KeyboardAccess.Binding.InputMatched` (prefix), `CommandBase.Run(CutscenePlayerData)`
(prefix/postfix), `CutsceneController.Tick` and `UnitMoveController.Tick` (substep prefixes, active only while
advancing), `UnitMovementAgent.PathTo(...)` (postfix, active only while advancing), `LocalizedString.PlayVoiceOver`
(postfix, active only while skipping), `LoadingProcess.StopAll` / `ResetManualLoadingScreen` /
`CheatRestManualLoadingScreen` (postfix). All are resolved by exact signature before anything is patched; a missing
contract leaves the game untouched and the mod reports itself inactive.

## Unresolved limitations

* Global-map cinematics (`GameModeType.CutsceneGlobalMap`) are declined: not exercised natively.
* Turn-based mode: a skip is declined, and ends, while turn-based combat is active.
* Bag of Tricks' game-speed multiplier, when set ≠ 1, rewrites `DebugTimeScale` every tick; a skip then runs at that
  speed (ownership rules leave Bag of Tricks' value in place).
* A cutscene that waits on something else that does not follow engine time would stall; the 10 s stall watchdog then
  reveals normal playback with the playing commands logged.
