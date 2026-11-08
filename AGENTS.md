# Repository instructions

* This repository contains only the standalone **Cutscene Skip** mod (UMM Id `KingmakerCutsceneSkip`). Never rename the
  Id, assembly, `EntryMethod`, namespaces or Harmony owner (`howardreith.kingmaker.cutsceneskip`).
* The locally installed Kingmaker 2.1.7b assemblies are the contract source of truth. Read the engine note
  (`docs/ENGINE-NOTES.md`) before changing skip behaviour. Do not transplant Wrath APIs; Kingmaker has none of them.
* Never complete, remove, reorder or teleport cutscene commands to make a skip faster. The design runs the engine's own
  cutscene code under `DebugTimeScale` and stops at interaction boundaries; story semantics must stay identical.
* Keep Harmony entry points thin (`Patches/` → `PatchBridge` → runtime). Pure lifecycle/ownership logic lives in `Core/`
  and `Input/` and is unit-tested; Kingmaker specifics live in `Integration/`.
* Build with C# 7.3 for .NET Framework 4.7.2; game/UMM references use `Private=False`. Warnings are errors.
* Do not commit game assemblies, decompiled sources, saves, logs, runtime evidence or `GamePath.props`
  (`scripts/Common.ps1` enforces this in Build/Package).
* Native tests: `scripts/runtime/Invoke-NativeRun.ps1` only. It honours sibling-lab locks, redirects all persistent
  data to a disposable profile, hashes the owner's saves before/after and restores Mods, UMM `Params.xml` and the game's
  registry settings in a `finally` block (`-RecoverOnly` replays an interrupted run). Never launch Kingmaker any other
  way, never use the owner's live saves directly, never leave the harness installed.
* `tools/RuntimeHarness` is test-only and never packaged.
* Keep `docs/VALIDATION.md` current with candidate hashes and native evidence; do not claim unexecuted coverage.
