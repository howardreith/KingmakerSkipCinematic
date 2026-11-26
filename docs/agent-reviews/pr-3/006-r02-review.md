<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r02-review part=1/1 sha256=206d810572481b1b48f1c199cb29651d19992c874217a24d2ae0d9b152089f59 -->
### Codex GPT-6.2 Astra — review — round 2 — candidate `ccd7a2b2de`

**Decision:** `changes_required` — The controller gate passed all 93 tests, and the build and package records identify the released product DLL. Direct MSBuild still bypasses the reference check. The standalone validator can accept an extra loader reference, and the native runner has paths that can misidentify a control run or strand its lock after restoration.

Continuation for Claude

Apply the existing pins to the production project's selected and compiler-resolved references. Make the standalone validator check every loader-family AssemblyRef against the declared full identity. Preserve cache-free package inspection and include any new build helper in receipt invalidation.

For bare-DLL runs, validate and stage the manifest and DLL together. Verify product absence in the effective Mods set for no-product controls. Make lock release after successful restoration independent of summary writing and temporary-file cleanup. Preserve journal-based recovery when restoration fails.

Exercise these paths and the outstanding input-replacement case with disposable files and checkouts. Rerun the controller test gate on the corrected commit. Keep the work within Cutscene Skip's build, packaging and test tooling. The existing product behavior and historical native evidence apply to the identified DLL. The documented missing 0.33.4 profile adequately explains its static-only status.

#### Findings

**R2-F1** · P1 · defect · blocks readiness — Direct production builds bypass the changed reference gate
- Location: `src/KingmakerCutsceneSkip/KingmakerCutsceneSkip.csproj:21`; acceptance: mission §5, mission §6
- Trigger: Build the production project or solution directly with an API-compatible newer UMM DLL in the prepared reference directory.
- Expected: The production project enforces the pin on both the selected file and the reference supplied to the compiler, including through the shipped solution.
- Actual: RequireLocalGamePaths checks only that both DLLs exist. The project references them by simple name and HintPath. Only the PowerShell wrapper runs the changed cache verifier, and Get-BuildReferenceIdentities reads the cache paths after compilation. A direct rebuild can compile against a newer valid DLL at the expected path.
- Why it blocks / does not: The mission expressly extends a changed pinning implementation to supported direct build paths and requires verification of the compiler's resolved input.
- Requested correction: Apply the existing pin definitions during the production MSBuild path and check the resolved loader files before compilation. Include any new material helper or target in the product-input comparison.
- Requested evidence: In a disposable checkout, show a genuine direct build passing and a direct rebuild refusing a substituted cache file. Exercise a resolved-reference mismatch and record the successful compiler input paths and hashes.

**R1-F3** · P1 · defect · blocks readiness — An additional case-variant loader reference can escape inspection
- Location: `scripts/Validate-Package.ps1:96`; acceptance: mission §5, mission §6
- Trigger: A supplied DLL contains the required UnityModManager reference and another AssemblyRef whose simple name differs only in case and whose binding identity differs.
- Expected: Every loader-family reference participates in the full-identity comparison, and the accepted set contains exactly the two required references.
- Actual: The first loop uses a case-insensitive ordered-map lookup. The second loop counts only case-exact names. With the canonical references present, an additional differently cased reference of another version or token passes the first loop and escapes the full-identity comparison in the second.
- Why it blocks / does not: The standalone validator can certify a DLL with more loader identities than the shipping contract permits.
- Requested correction: Compare the full identity of each observed loader-family reference with its expected identity and enforce exact cardinality using consistent name semantics.
- Requested evidence: Show rejection of a DLL containing the genuine references plus a case-variant loader reference with a distinct binding identity. Retain the genuine package pass.

**R2-F2** · P2 · defect · blocks readiness — Cached assembly metadata can override the declared pin version
- Location: `scripts/Validate-Package.ps1:46`; acceptance: mission §5, mission §6
- Trigger: A pin declares UMM 0.31.1 but its configured digest identifies a cached assembly of another version.
- Expected: The measured reference identity agrees with the pin declaration. A supplied package receives a consistent identity verdict with or without a local build cache.
- Actual: When a cache file matches the configured digest, line 46 adopts its FullName as the expected identity. The manifest check separately uses the pin's Version. An inconsistent pin can therefore admit a DLL referencing 0.33.0 under a 0.31.1 manifest when the cache is populated. The cache-free branch would reject the same package.
- Why it blocks / does not: This reintroduces the manifest/compiler mismatch that the standalone gate is intended to reject.
- Requested correction: Keep the declared pin authoritative and cross-check any consulted cache file against it. Obtain its digest and CLR identity from the same file snapshot.
- Requested evidence: Use disposable pin data whose declared version disagrees with the authenticated assembly. Show a clear refusal with the cache populated and continued acceptance of the genuine baseline package with and without a cache.

**R2-F3** · P1 · defect · blocks readiness — Final cleanup can strand a restored run's lock
- Location: `scripts/runtime/Invoke-NativeRun.ps1:256`; acceptance: mission §6, mission §7, AGENTS.md native recovery
- Trigger: Restoration succeeds, then the host summary is unwritable or a temporary product file is still open.
- Expected: Successful restoration guarantees release of this invocation's lock even if final reporting or private-copy cleanup fails.
- Actual: Restore-RunJournal deletes the journal after successful restoration. Write-JsonFile and Remove-ValidatedNativeProduct then run before Exit-RuntimeLock. Either can throw, leaving a lock for which RecoverOnly finds no journal.
- Why it blocks / does not: A reporting or temporary-file error can indefinitely exclude subsequent guarded runs after the installation has already been restored.
- Requested correction: Put owned-lock release behind an independent finally conditioned on restoration success. Surface report and private-copy cleanup failures while retaining the journal and lock on incomplete restoration.
- Requested evidence: In a disposable lab, force a final summary-write failure and a private-copy deletion failure after restoration. Show the owned lock is released, a foreign lock survives and the incomplete-restoration path retains its recovery state.

**R2-F4** · P2 · defect · blocks readiness — Bare-DLL staging reopens an unvalidated manifest
- Location: `scripts/runtime/NativeProduct.ps1:52`; acceptance: mission §5, mission §6, mission §7
- Trigger: Run from a built DLL with a mismatched checkout manifest, or change Info.json between preparation and staging.
- Expected: Bare-build staging uses a validated DLL and manifest pair with the declared loader floor and shipping load target.
- Actual: The bare route freezes only the DLL. Its validator reads the checkout's product version, and the installer later copies the live Info.json. A raised ManagerVersion or changed load target can reach staging while the validated and staged DLL digests still agree.
- Why it blocks / does not: The runner can record an admitted product even though the manifest controlling the native load was never admitted with it.
- Requested correction: Freeze and validate Info.json with the bare DLL before locking, then install that pair. Preserve the separately recorded explicit ManagerVersion override for historical test scenarios.
- Requested evidence: Show that a mismatched bare manifest is refused and that changing the checkout's manifest after preparation cannot alter the staged manifest.

**R2-F5** · P2 · defect · blocks readiness — An inherited mod can invalidate a no-product control
- Location: `scripts/runtime/Invoke-NativeRun.ps1:125`; acceptance: mission §6, mission §7
- Trigger: Use -NoProduct with an owner profile whose pristine Mods set already includes the released mod.
- Expected: A no-product control establishes absence in the effective Mods set or refuses the run before it can produce that claim.
- Actual: Mode none skips the candidate installer, but Set-GameCopyMods can copy an already installed Cutscene Skip from the pristine owner set. The host derives noProduct from the requested plan and accepts the scenario status without checking product absence.
- Why it blocks / does not: A persistence or comparison run can be recorded as a product-absent control while Cutscene Skip is present.
- Requested correction: Check the effective profile for the shipping mod Id. Exclude it during disposable-copy preparation or refuse the control when it is present. Preserve the owner's installed files.
- Requested evidence: Exercise a temporary owner Mods fixture already containing Cutscene Skip, with and without a comparison ZIP. Show verified absence or explicit refusal and an intact source fixture.

**R1-F7** · P2 · evidence_gap · blocks readiness — The snapshot test never replaces its input
- Location: `scripts/Test-Provenance.ps1:158`; acceptance: mission §5, mission §6
- Trigger: Assess the replacement behavior claimed by the named report-consistency case.
- Expected: A disposable-file test demonstrates a consistent digest, MVID and reference set through input replacement, with the input protected during report publication.
- Actual: The validator now hashes and inspects one byte array, and the static hard-link refusal passed. ReportDigestAndMetadataComeFromOneSnapshot validates an unchanged ZIP. It would also pass with the former split reads. WriteChecked receives the identity captured before the input handle was closed.
- Why it blocks / does not: Input replacement through report publication was an explicit outstanding evidence requirement.
- Requested correction: Exercise actual replacement during validation and cover a report destination that aliases the input at publication. Protect the current input through the write if that case exposes an overwrite.
- Requested evidence: Record which known input snapshot supplied every report field, or the orderly refusal, and verify the package bytes survive the alias case.

**R2-F6** · P3 · optional_polish · non-blocking — The packaging test hard-codes the current release filename
- Location: `scripts/Test-PackageProvenance.ps1:54`; acceptance: mission §6
- Trigger: Run the standard test gate after a normal product version bump.
- Expected: The temporary-checkout test follows the version of the product it just packaged.
- Actual: The real packaging command derives the output filename from Info.json, while the new test opens KingmakerCutsceneSkip-0.1.2.manifest.json unconditionally.
- Why it blocks / does not: The fixed candidate is version 0.1.2 and its gate result is valid. This affects the next product version.
- Requested correction: Derive the manifest filename from the temporary checkout's shipping version.
- Requested evidence: Confirm the test locates the generated manifest for a coherently versioned temporary fixture.

**R2-F7** · P3 · optional_polish · non-blocking — Standalone report output lost parent-directory creation
- Location: `scripts/Validate-Package.ps1:110`; acceptance: mission §6
- Trigger: Supply -ReportPath below a directory that does not yet exist.
- Expected: A standalone report can be written under a newly named output directory.
- Actual: The previous report writer created missing parent directories. WriteChecked opens the destination directly and fails if its parent is absent.
- Why it blocks / does not: The packager and native runner already create their report directories. The convenience regression affects standalone callers.
- Requested correction: Create the report's parent directory before opening the identity-checked output handle.
- Requested evidence: Write a report below a fresh temporary subdirectory and retain the existing alias-refusal checks.

**R2-F8** · P3 · optional_polish · non-blocking — The evidence index gives different outputs one source commit
- Location: `docs/evidence/umm-0311/INDEX.md:3`; acceptance: mission §8
- Trigger: Use the index to identify the source revision that produced the reviewed ZIP.
- Expected: The evidence index distinguishes the implementation commit, producing commits and controller-tested candidate.
- Actual: The index attributes the bundle to 42b61a9. The build receipt and package manifest identify 65a182e as their producing commit.
- Why it blocks / does not: The individual records carry the correct SHAs, and Git confirms that only documentation and evidence changed after the implementation commit.
- Requested correction: Attribute each group of outputs to its recorded source commit and identify the reused frozen-DLL audit separately.
- Requested evidence: The index labels agree with the test results, build receipt and package manifest.

**R2-F9** · P3 · optional_polish · non-blocking — The cleanup assertion counts other runs' temporary folders
- Location: `scripts/Test-Provenance.ps1:176`; acceptance: mission §6
- Trigger: Another product preparation starts or finishes while the cleanup regression runs.
- Expected: The cleanup assertion observes only directories belonging to its fixture.
- Actual: The preparation-failure test compares counts of all kmcs-product-* directories in the user's temporary directory before and after validation. Another invocation can change either count.
- Why it blocks / does not: The recorded gate passed. This affects repeatability when tests or preparation overlap.
- Requested correction: Scope the temporary root or the observed directory to the test invocation.
- Requested evidence: Show that another invocation creating or removing its private folder cannot change this case's result.

#### Prior finding assessments

- **R1-F1** — `fix_verified` — Both Build.ps1 and Common.ps1 are product inputs for the dirty-tree and between-commit checks. The gate recorded rejection of the previous receipt, successful rebuilding and documentation-only reuse.
- **R1-F2** — `fix_verified` — The ZIP path checks the packaged AssemblyName and EntryMethod and applies the shipping file-version rule to the DLL bytes. All three negative cases passed, and the published 0.1.2 validation record identifies the genuine control.
- **R1-F3** — `fix_rejected` — The culture, Harmony 2 and additional UMM-suffix cases passed. The inconsistent name comparisons still allow an extra case-variant reference to escape full-identity checking.
- **R1-F4** — `fix_verified` — The exercised bare-DLL installer staged the validated private copy after the original build output was replaced and checked the staged digest. R2-F4 concerns the associated manifest.
- **R1-F5** — `fix_verified` — The negative fixture now uses a disposable UMM 0.33.0.0 assembly of known identity. The baseline and newer-reference cases passed through both validator entry points independently of the installed loader version.
- **R1-F6** — `fix_verified` — Both no-product plans passed. Caller inspection confirms the comparison ZIP has its own summary field and mode none skips access to a validated product. R2-F5 concerns a product inherited from the selected Mods profile.
- **R1-F7** — `fix_rejected` — The source uses one input snapshot, the static alias checks passed, and the package manifest records the validated digest. The requested observation during input replacement is still missing.
- **R1-F8** — `fix_verified` — Preparation now cleans up on failure, and the directory-setup helper releases its acquired lock on an evidence-directory error. Both disposable cases passed. R2-F3 is a distinct failure after successful restoration.
- **R1-F9** — `fix_verified` — The gate recorded refusal of a genuinely corrupted cache file before wrapper compilation and packaging refusal after DLL bytes changed. The clean build/package control passed without an override.
- **R1-F10** — `fix_verified` — The compatibility guide identifies the missing reviewed 0.33.4 component profile. The profile table and unknown-profile branch confirm that admission barrier. The row makes only a static claim.
- **R1-F11** — `fix_verified` — The guide identifies all four static profiles, their provenance, the frozen DLL, audit sources and invocation, and the guarded native command. Historical combined-stack runs have dates, scenarios and artifact identity.

#### Evidence assessment

- **Inspected:** The mission, repository instructions, developer report, prior ledger, complete feature diff, correction commits, controller receipt and gate log.; The shipping manifest, production project and solution, reference pins, build receipt generation, standalone validator, packager and temporary-checkout tests.; Native product preparation, profile selection, Mods staging, restoration and recovery, plus the compatibility guide, audit tool and exported evidence.
- **Executed verification:** Verified HEAD and the enrolled mission SHA-256 against the fixed inputs. The feature diff passed git diff --check.; Verified the controller gate log's SHA-256 against its receipt. At the exact candidate, scripts/Test.ps1 exited 0 in 20.1 seconds with 55/55 unit, 32/32 provenance and 6/6 package-provenance cases passing.; The gate log records a real build and package without an override, stale-helper refusal, successful rebuild, documentation-only reuse, corrupt-cache refusal before compilation and refusal of DLL bytes differing from the receipt.; Recomputed all ten exported Git-blob SHA-256 values listed in the evidence index. Cross-checked the DLL digest across the build, package, published-package and API-audit records, and the MVID across both validation reports and the audit.; Confirmed the PowerShell ordered-map lookup accepts an alternate-case key while the validator's case-sensitive name comparison counts only the canonical spelling.
- **Source inspection only:** The production project checks reference-file existence before resolution. The build receipt reads identities from the configured cache paths.; The runner's bare-manifest, inherited-Mods and final-cleanup failure paths were traced through their callers.; The native profile table omits umm-0.33.4, and Install-LoaderProfile rejects an unknown profile. This establishes the admission prerequisite without a game launch.
- **Required gaps:** Direct-build rejection of incorrect selected or resolved loader references, and standalone rejection of every extra or inconsistent loader identity.; A disposal-safe input-replacement test for validator reports.; File-backed runner checks for the bare manifest, actual product absence and lock release after post-restoration failures.
- **Limitations:** The reviewer used read-only inspection. The controller supplied the candidate-bound test execution. The mixed-project developer shell transcript was withheld.; The published-package check and four-profile API audit have committed output records. Their original binaries and independent command logs were unavailable in the snapshot.; Native coverage for this round was zero. The documented 0.31.1, 0.32.4 and owner 0.33.0 observations belong to the historical runs on the identical DLL. UMM 0.33.4 with Harmony 2.4.3 has static evidence only.

#### Summary

- **Delivered behavior:** The wrapper builds against UMM 0.31.1.0 and Harmony12 1.2.0.1. The package built at 65a182e has ZIP SHA-256 9b06a98317af8e8a3057ea5ea33cf6b002ba8c29879443ad33d872af8db90279 and the same DLL SHA-256 as released v0.1.2, a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba. The candidate adds standalone package inspection, build-helper receipt invalidation and private-copy DLL staging.
- **Scope reviewed:** Final checkpoint for Cutscene Skip PR #3, including all eleven prior findings, the changed tooling and its direct build, packaging and runtime consumers.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Disposition of draft PR #3 after correction and independent review, including any merge or release decision.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: none.

Codex CLI `0.170.0`, thread `01a20bc7-24f7-7070-8f19-81208d7fc28b`, duration 763.7s, response sha256 `cd9cdfa4214e6272a98cacc7f023320857784595cc730240952ddce50dc05980`, request `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r02-2ad364`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "ccd7a2b2de6e7ccb5f2aeab5de08426b0eb20ad7",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The controller gate passed all 93 tests, and the build and package records identify the released product DLL. Direct MSBuild still bypasses the reference check. The standalone validator can accept an extra loader reference, and the native runner has paths that can misidentify a control run or strand its lock after restoration.\n\nContinuation for Claude\n\nApply the existing pins to the production project's selected and compiler-resolved references. Make the standalone validator check every loader-family AssemblyRef against the declared full identity. Preserve cache-free package inspection and include any new build helper in receipt invalidation.\n\nFor bare-DLL runs, validate and stage the manifest and DLL together. Verify product absence in the effective Mods set for no-product controls. Make lock release after successful restoration independent of summary writing and temporary-file cleanup. Preserve journal-based recovery when restoration fails.\n\nExercise these paths and the outstanding input-replacement case with disposable files and checkouts. Rerun the controller test gate on the corrected commit. Keep the work within Cutscene Skip's build, packaging and test tooling. The existing product behavior and historical native evidence apply to the identified DLL. The documented missing 0.33.4 profile adequately explains its static-only status.",
  "evidence_assessment": {
    "executed_verification": [
      "Verified HEAD and the enrolled mission SHA-256 against the fixed inputs. The feature diff passed git diff --check.",
      "Verified the controller gate log's SHA-256 against its receipt. At the exact candidate, scripts/Test.ps1 exited 0 in 20.1 seconds with 55/55 unit, 32/32 provenance and 6/6 package-provenance cases passing.",
      "The gate log records a real build and package without an override, stale-helper refusal, successful rebuild, documentation-only reuse, corrupt-cache refusal before compilation and refusal of DLL bytes differing from the receipt.",
      "Recomputed all ten exported Git-blob SHA-256 values listed in the evidence index. Cross-checked the DLL digest across the build, package, published-package and API-audit records, and the MVID across both validation reports and the audit.",
      "Confirmed the PowerShell ordered-map lookup accepts an alternate-case key while the validator's case-sensitive name comparison counts only the canonical spelling."
    ],
    "inspected": [
      "The mission, repository instructions, developer report, prior ledger, complete feature diff, correction commits, controller receipt and gate log.",
      "The shipping manifest, production project and solution, reference pins, build receipt generation, standalone validator, packager and temporary-checkout tests.",
      "Native product preparation, profile selection, Mods staging, restoration and recovery, plus the compatibility guide, audit tool and exported evidence."
    ],
    "limitations": [
      "The reviewer used read-only inspection. The controller supplied the candidate-bound test execution. The mixed-project developer shell transcript was withheld.",
      "The published-package check and four-profile API audit have committed output records. Their original binaries and independent command logs were unavailable in the snapshot.",
      "Native coverage for this round was zero. The documented 0.31.1, 0.32.4 and owner 0.33.0 observations belong to the historical runs on the identical DLL. UMM 0.33.4 with Harmony 2.4.3 has static evidence only."
    ],
    "required_gaps": [
      "Direct-build rejection of incorrect selected or resolved loader references, and standalone rejection of every extra or inconsistent loader identity.",
      "A disposal-safe input-replacement test for validator reports.",
      "File-backed runner checks for the bare manifest, actual product absence and lock release after post-restoration failures."
    ],
    "source_inspection_only": [
      "The production project checks reference-file existence before resolution. The build receipt reads identities from the configured cache paths.",
      "The runner's bare-manifest, inherited-Mods and final-cleanup failure paths were traced through their callers.",
      "The native profile table omits umm-0.33.4, and Install-LoaderProfile rejects an unknown profile. This establishes the admission prerequisite without a game launch."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "RequireLocalGamePaths checks only that both DLLs exist. The project references them by simple name and HintPath. Only the PowerShell wrapper runs the changed cache verifier, and Get-BuildReferenceIdentities reads the cache paths after compilation. A direct rebuild can compile against a newer valid DLL at the expected path.",
      "blocking_rationale": "The mission expressly extends a changed pinning implementation to supported direct build paths and requires verification of the compiler's resolved input.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The production project enforces the pin on both the selected file and the reference supplied to the compiler, including through the shipped solution.",
      "id": "R2-F1",
      "location": {
        "file": "src/KingmakerCutsceneSkip/KingmakerCutsceneSkip.csproj",
        "line": 21
      },
      "priority": "P1",
      "requested_correction": "Apply the existing pin definitions during the production MSBuild path and check the resolved loader files before compilation. Include any new material helper or target in the product-input comparison.",
      "requested_evidence": "In a disposable checkout, show a genuine direct build passing and a direct rebuild refusing a substituted cache file. Exercise a resolved-reference mismatch and record the successful compiler input paths and hashes.",
      "title": "Direct production builds bypass the changed reference gate",
      "trigger": "Build the production project or solution directly with an API-compatible newer UMM DLL in the prepared reference directory."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The first loop uses a case-insensitive ordered-map lookup. The second loop counts only case-exact names. With the canonical references present, an additional differently cased reference of another version or token passes the first loop and escapes the full-identity comparison in the second.",
      "blocking_rationale": "The standalone validator can certify a DLL with more loader identities than the shipping contract permits.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Every loader-family reference participates in the full-identity comparison, and the accepted set contains exactly the two required references.",
      "id": "R1-F3",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 96
      },
      "priority": "P1",
      "requested_correction": "Compare the full identity of each observed loader-family reference with its expected identity and enforce exact cardinality using consistent name semantics.",
      "requested_evidence": "Show rejection of a DLL containing the genuine references plus a case-variant loader reference with a distinct binding identity. Retain the genuine package pass.",
      "title": "An additional case-variant loader reference can escape inspection",
      "trigger": "A supplied DLL contains the required UnityModManager reference and another AssemblyRef whose simple name differs only in case and whose binding identity differs."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "When a cache file matches the configured digest, line 46 adopts its FullName as the expected identity. The manifest check separately uses the pin's Version. An inconsistent pin can therefore admit a DLL referencing 0.33.0 under a 0.31.1 manifest when the cache is populated. The cache-free branch would reject the same package.",
      "blocking_rationale": "This reintroduces the manifest/compiler mismatch that the standalone gate is intended to reject.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The measured reference identity agrees with the pin declaration. A supplied package receives a consistent identity verdict with or without a local build cache.",
      "id": "R2-F2",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 46
      },
      "priority": "P2",
      "requested_correction": "Keep the declared pin authoritative and cross-check any consulted cache file against it. Obtain its digest and CLR identity from the same file snapshot.",
      "requested_evidence": "Use disposable pin data whose declared version disagrees with the authenticated assembly. Show a clear refusal with the cache populated and continued acceptance of the genuine baseline package with and without a cache.",
      "title": "Cached assembly metadata can override the declared pin version",
      "trigger": "A pin declares UMM 0.31.1 but its configured digest identifies a cached assembly of another version."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "mission \u00a77",
        "AGENTS.md native recovery"
      ],
      "actual": "Restore-RunJournal deletes the journal after successful restoration. Write-JsonFile and Remove-ValidatedNativeProduct then run before Exit-RuntimeLock. Either can throw, leaving a lock for which RecoverOnly finds no journal.",
      "blocking_rationale": "A reporting or temporary-file error can indefinitely exclude subsequent guarded runs after the installation has already been restored.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Successful restoration guarantees release of this invocation's lock even if final reporting or private-copy cleanup fails.",
      "id": "R2-F3",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 256
      },
      "priority": "P1",
      "requested_correction": "Put owned-lock release behind an independent finally conditioned on restoration success. Surface report and private-copy cleanup failures while retaining the journal and lock on incomplete restoration.",
      "requested_evidence": "In a disposable lab, force a final summary-write failure and a private-copy deletion failure after restoration. Show the owned lock is released, a foreign lock survives and the incomplete-restoration path retains its recovery state.",
      "title": "Final cleanup can strand a restored run's lock",
      "trigger": "Restoration succeeds, then the host summary is unwritable or a temporary product file is still open."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76",
        "mission \u00a77"
      ],
      "actual": "The bare route freezes only the DLL. Its validator reads the checkout's product version, and the installer later copies the live Info.json. A raised ManagerVersion or changed load target can reach staging while the validated and staged DLL digests still agree.",
      "blocking_rationale": "The runner can record an admitted product even though the manifest controlling the native load was never admitted with it.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Bare-build staging uses a validated DLL and manifest pair with the declared loader floor and shipping load target.",
      "id": "R2-F4",
      "location": {
        "file": "scripts/runtime/NativeProduct.ps1",
        "line": 52
      },
      "priority": "P2",
      "requested_correction": "Freeze and validate Info.json with the bare DLL before locking, then install that pair. Preserve the separately recorded explicit ManagerVersion override for historical test scenarios.",
      "requested_evidence": "Show that a mismatched bare manifest is refused and that changing the checkout's manifest after preparation cannot alter the staged manifest.",
      "title": "Bare-DLL staging reopens an unvalidated manifest",
      "trigger": "Run from a built DLL with a mismatched checkout manifest, or change Info.json between preparation and staging."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "mission \u00a77"
      ],
      "actual": "Mode none skips the candidate installer, but Set-GameCopyMods can copy an already installed Cutscene Skip from the pristine owner set. The host derives noProduct from the requested plan and accepts the scenario status without checking product absence.",
      "blocking_rationale": "A persistence or comparison run can be recorded as a product-absent control while Cutscene Skip is present.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "A no-product control establishes absence in the effective Mods set or refuses the run before it can produce that claim.",
      "id": "R2-F5",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 125
      },
      "priority": "P2",
      "requested_correction": "Check the effective profile for the shipping mod Id. Exclude it during disposable-copy preparation or refuse the control when it is present. Preserve the owner's installed files.",
      "requested_evidence": "Exercise a temporary owner Mods fixture already containing Cutscene Skip, with and without a comparison ZIP. Show verified absence or explicit refusal and an intact source fixture.",
      "title": "An inherited mod can invalidate a no-product control",
      "trigger": "Use -NoProduct with an owner profile whose pristine Mods set already includes the released mod."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The validator now hashes and inspects one byte array, and the static hard-link refusal passed. ReportDigestAndMetadataComeFromOneSnapshot validates an unchanged ZIP. It would also pass with the former split reads. WriteChecked receives the identity captured before the input handle was closed.",
      "blocking_rationale": "Input replacement through report publication was an explicit outstanding evidence requirement.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "A disposable-file test demonstrates a consistent digest, MVID and reference set through input replacement, with the input protected during report publication.",
      "id": "R1-F7",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 158
      },
      "priority": "P2",
      "requested_correction": "Exercise actual replacement during validation and cover a report destination that aliases the input at publication. Protect the current input through the write if that case exposes an overwrite.",
      "requested_evidence": "Record which known input snapshot supplied every report field, or the orderly refusal, and verify the package bytes survive the alias case.",
      "title": "The snapshot test never replaces its input",
      "trigger": "Assess the replacement behavior claimed by the named report-consistency case."
    },
    {
      "acceptance_ids": [
        "mission \u00a76"
      ],
      "actual": "The real packaging command derives the output filename from Info.json, while the new test opens KingmakerCutsceneSkip-0.1.2.manifest.json unconditionally.",
      "blocking_rationale": "The fixed candidate is version 0.1.2 and its gate result is valid. This affects the next product version.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "The temporary-checkout test follows the version of the product it just packaged.",
      "id": "R2-F6",
      "location": {
        "file": "scripts/Test-PackageProvenance.ps1",
        "line": 54
      },
      "priority": "P3",
      "requested_correction": "Derive the manifest filename from the temporary checkout's shipping version.",
      "requested_evidence": "Confirm the test locates the generated manifest for a coherently versioned temporary fixture.",
      "title": "The packaging test hard-codes the current release filename",
      "trigger": "Run the standard test gate after a normal product version bump."
    },
    {
      "acceptance_ids": [
        "mission \u00a76"
      ],
      "actual": "The previous report writer created missing parent directories. WriteChecked opens the destination directly and fails if its parent is absent.",
      "blocking_rationale": "The packager and native runner already create their report directories. The convenience regression affects standalone callers.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "A standalone report can be written under a newly named output directory.",
      "id": "R2-F7",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 110
      },
      "priority": "P3",
      "requested_correction": "Create the report's parent directory before opening the identity-checked output handle.",
      "requested_evidence": "Write a report below a fresh temporary subdirectory and retain the existing alias-refusal checks.",
      "title": "Standalone report output lost parent-directory creation",
      "trigger": "Supply -ReportPath below a directory that does not yet exist."
    },
    {
      "acceptance_ids": [
        "mission \u00a78"
      ],
      "actual": "The index attributes the bundle to 42b61a9. The build receipt and package manifest identify 65a182e as their producing commit.",
      "blocking_rationale": "The individual records carry the correct SHAs, and Git confirms that only documentation and evidence changed after the implementation commit.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "The evidence index distinguishes the implementation commit, producing commits and controller-tested candidate.",
      "id": "R2-F8",
      "location": {
        "file": "docs/evidence/umm-0311/INDEX.md",
        "line": 3
      },
      "priority": "P3",
      "requested_correction": "Attribute each group of outputs to its recorded source commit and identify the reused frozen-DLL audit separately.",
      "requested_evidence": "The index labels agree with the test results, build receipt and package manifest.",
      "title": "The evidence index gives different outputs one source commit",
      "trigger": "Use the index to identify the source revision that produced the reviewed ZIP."
    },
    {
      "acceptance_ids": [
        "mission \u00a76"
      ],
      "actual": "The preparation-failure test compares counts of all kmcs-product-* directories in the user's temporary directory before and after validation. Another invocation can change either count.",
      "blocking_rationale": "The recorded gate passed. This affects repeatability when tests or preparation overlap.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "The cleanup assertion observes only directories belonging to its fixture.",
      "id": "R2-F9",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 176
      },
      "priority": "P3",
      "requested_correction": "Scope the temporary root or the observed directory to the test invocation.",
      "requested_evidence": "Show that another invocation creating or removing its private folder cannot change this case's result.",
      "title": "The cleanup assertion counts other runs' temporary folders",
      "trigger": "Another product preparation starts or finishes while the cleanup regression runs."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F1",
      "rationale": "Both Build.ps1 and Common.ps1 are product inputs for the dirty-tree and between-commit checks. The gate recorded rejection of the previous receipt, successful rebuilding and documentation-only reuse."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F2",
      "rationale": "The ZIP path checks the packaged AssemblyName and EntryMethod and applies the shipping file-version rule to the DLL bytes. All three negative cases passed, and the published 0.1.2 validation record identifies the genuine control."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R1-F3",
      "rationale": "The culture, Harmony 2 and additional UMM-suffix cases passed. The inconsistent name comparisons still allow an extra case-variant reference to escape full-identity checking."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F4",
      "rationale": "The exercised bare-DLL installer staged the validated private copy after the original build output was replaced and checked the staged digest. R2-F4 concerns the associated manifest."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F5",
      "rationale": "The negative fixture now uses a disposable UMM 0.33.0.0 assembly of known identity. The baseline and newer-reference cases passed through both validator entry points independently of the installed loader version."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F6",
      "rationale": "Both no-product plans passed. Caller inspection confirms the comparison ZIP has its own summary field and mode none skips access to a validated product. R2-F5 concerns a product inherited from the selected Mods profile."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R1-F7",
      "rationale": "The source uses one input snapshot, the static alias checks passed, and the package manifest records the validated digest. The requested observation during input replacement is still missing."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F8",
      "rationale": "Preparation now cleans up on failure, and the directory-setup helper releases its acquired lock on an evidence-directory error. Both disposable cases passed. R2-F3 is a distinct failure after successful restoration."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F9",
      "rationale": "The gate recorded refusal of a genuinely corrupted cache file before wrapper compilation and packaging refusal after DLL bytes changed. The clean build/package control passed without an override."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F10",
      "rationale": "The compatibility guide identifies the missing reviewed 0.33.4 component profile. The profile table and unknown-profile branch confirm that admission barrier. The row makes only a static claim."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F11",
      "rationale": "The guide identifies all four static profiles, their provenance, the frozen DLL, audit sources and invocation, and the guarded native command. Historical combined-stack runs have dates, scenarios and artifact identity."
    }
  ],
  "request_id": "ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r02-2ad364",
  "round": 2,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "The wrapper builds against UMM 0.31.1.0 and Harmony12 1.2.0.1. The package built at 65a182e has ZIP SHA-256 9b06a98317af8e8a3057ea5ea33cf6b002ba8c29879443ad33d872af8db90279 and the same DLL SHA-256 as released v0.1.2, a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba. The candidate adds standalone package inspection, build-helper receipt invalidation and private-copy DLL staging.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Disposition of draft PR #3 after correction and independent review, including any merge or release decision."
    ],
    "scope_reviewed": "Final checkpoint for Cutscene Skip PR #3, including all eleven prior findings, the changed tooling and its direct build, packaging and runtime consumers.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
