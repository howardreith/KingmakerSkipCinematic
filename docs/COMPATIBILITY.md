# Loader and mod compatibility

Applies to `KingmakerCutsceneSkip.dll` SHA-256 `a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba`
(version 0.1.2), Pathfinder: Kingmaker 2.1.7b Steam build 6757524. Evidence run ids are under the lab's
`runtime-evidence/`, prefix `20261108T`.

## Supported loaders

`Info.json` declares `ManagerVersion` 0.31.1, the lowest version verified across loading, settings, a skip and
coexistence. A user whose newer Unity Mod Manager already works does not need to change it.

| Unity Mod Manager | Status |
|---|---|
| 0.33.0 | tested |
| 0.32.4 | tested |
| 0.31.1 | tested (declared minimum) |
| 0.33.1 and later | not run; the audited member surface is present in 0.33.2 |
| other 0.31.x, 0.32.0-0.32.3 as published | **not tested** |
| 0.27.12 | loaded and passed a smoke test only with a staged `ManagerVersion` override; no coexistence run, not supported |
| 0.27.10 | **unavailable** to this work; no claim |

## Build contract

`scripts/Build.ps1` downloads `UnityModManager.dll` 0.31.1 (author's NuGet package) and `0Harmony12.dll` (UMM repository
at the 0.31.1 commit `10cfb1cc`) into `artifacts/references`, verifies them against the SHA-256 values in
`scripts/Common.ps1`, and records them in `artifacts/qualification/build.json`. A local loader update cannot change the
build. Neither file enters the package or source control, and the mod does not replace the shared loader or Harmony.

Member audit (metadata, `private/contract-tool` in the lab): the mod binds only `ModEntry` (`Logger`, `OnGUI`,
`OnSaveGUI`, `OnToggle`, `OnUnload`, `OnUpdate`), `ModLogger` (`Log`, `Warning`, `Error`, `LogException`), `ModSettings`
(constructor, `Load<T>`, `Save`, `Save<T>`), and Harmony 1.2's `HarmonyInstance.Create`/`Patch`/`UnpatchAll` and
`HarmonyMethod`. All exist in UMM 0.27.12, 0.31.1, 0.32.3, 0.32.4, 0.33.0 and 0.33.2. `0Harmony12.dll` is byte-identical
across those versions, and the members it binds exist in Harmony 2.3.1.1, 2.3.3, 2.3.5 and 2.3.6.

## The early-0.32 failure reports

Harmony 2.3.5 removed `AccessTools.MethodDelegate<T>(MethodInfo, object, bool)`; Harmony 2.3.6 restored it. Combining UMM
0.32.3 with Harmony 2.3.5 reproduced a Craft Magic Items failure **without this mod installed**: its `Load` threw
`MissingMethodException` for that member (153823Z, which then hung and was stopped at the run timeout). This is a
synthetic combination. UMM's own project file pins Harmony 2.3.1.1 for the 0.32.0-0.32.3 source, so which published
builds shipped 2.3.5 is unverified. Craft Magic Items worked on 0.32.4 (Harmony 2.3.6).

So the failure is real for a Harmony 2.3.5 loader and does not apply to every 0.32+ version. Skip Cutscenes itself does
not bind the removed member and loaded with Harmony 2.3.5 (160318Z).

## How the loaders were installed

Nexus pages refuse automated access here, so these are **component-assembled** profiles and not the Nexus ZIPs. Each uses
the author's NuGet `UnityModManager` package, `Lib.Harmony`, `dnlib` and the UMM repository at the matching commit, all
SHA-256 verified, installed into a disposable full copy of the game (`scripts/runtime/loader-profiles.json`). The 0.33.0
profile is a byte copy of the owner's installation. In-process versions come from each run's `runtime-assemblies.json`.

## Results

Mods: Craft Magic Items 2.1.0, Kingmaker Bugfixes 1.3.3. Tested ZIP `ec60d96a…` (same DLL as the final ZIP). CMI behaviour:
upgrade a Standard Flail with Enhancement 1 through CMI's own code, save, reload, confirm the custom item persists.
Bugfixes behaviour: its Dart `IsLight` blueprint change is present.

| Loader / Harmony | Profile | Behaviour | Outcome | Run |
|---|---|---|---|---|
| 0.31.1 / 2.3.1.1 | mod alone | panel draws, settings save, disable/enable, direct skip to dialogue, save, reload | pass | 155655Z |
| 0.32.4 / 2.3.6 | mod alone | same | pass | 155903Z |
| 0.33.0 / 2.3.6 | mod alone | same | pass | 160110Z |
| 0.27.12 / 2.3.1.1 | mod alone, `ManagerVersion` override | same | pass, not a supported target | 160525Z |
| synthetic 0.32.3 / 2.3.5 | mod alone | same | pass | 160318Z |
| 0.31.1 / 2.3.1.1 | CMI + Bugfixes, mod absent | CMI and Bugfixes behaviour | pass | 151727Z |
| 0.31.1 / 2.3.1.1 | CMI + Bugfixes + mod | same, no skip run | pass | 151939Z |
| 0.32.4 / 2.3.6 | CMI + Bugfixes, mod absent | same | pass | 152949Z |
| 0.32.4 / 2.3.6 | CMI + Bugfixes + mod | same, no skip run | pass | 153157Z |
| 0.33.0 / 2.3.6 | CMI + Bugfixes, mod absent | same | pass | 153406Z |
| 0.33.0 / 2.3.6 | CMI + Bugfixes + mod | same, no skip run | pass | 153614Z |
| 0.33.0 / 2.3.6 | owner's 16 mods + mod | direct skips, prologue chain, save | pass | 170038Z |
| 0.33.0 / 2.3.6 | owner's 16 mods + mod | direct skips, night attack | pass, state MATCH | 171137Z |
| synthetic 0.32.3 / 2.3.5 | CMI + Bugfixes, mod absent | CMI load | **reproduced failure** | 153823Z |
| 0.31.1, 0.32.4, 0.33.0 | CMI + Bugfixes + mod | real-Enter skip | **blocked, not run** | see `VALIDATION.md` |
| 0.27.10, published 0.32.0-0.32.3 | any | any | **untested** | - |

A log line from Kingmaker Bugfixes about deserializing `SaveInfo` appears in every run, including those without this mod.

Third-party reports not reproduced here: the March 2025 recommendation of 0.31.1 after early 0.32 failures, and the July
2025 report of Craft Magic Items working on 0.32.4. The second agrees with the 152949Z result.
