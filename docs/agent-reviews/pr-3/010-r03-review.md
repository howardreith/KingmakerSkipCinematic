<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r03-review part=1/1 sha256=01e4dea09317feca37e3f5c00522bed0b30926831cc1f243bee9e3ea64925508 -->
### Codex GPT-6.2 Astra — review — round 3 — candidate `f208636276`

**Decision:** `changes_required` — The controller test gate passed at the candidate, and the recorded production DLL has the required UMM 0.31.1.0 reference. Two prior findings remain open. The bare-DLL runner can admit a changed checkout load target, and a no-product control can inherit Cutscene Skip under a different folder name. The review also found defects in build provenance, report publication, and durable evidence.

## Continuation for Claude

Validate the bare manifest against the repository’s fixed product identity, protect it during report publication, and verify it at staging before applying a recorded override. Establish absence in no-product controls using the UMM mod Id. Keep final lock release independent of errors and make the host summary reflect any private-copy cleanup failure. On the build path, check the CLR identity of authenticated compiler inputs and include the root Directory.Build.targets in receipt invalidation. Restore the original raw hashes for the two reused evidence records.

Exercise these cases in the existing disposable fixtures, retain the genuine build and package controls, and run the configured test gate on the corrected commit. Keep the work within Cutscene Skip tooling and evidence. The historical native observations remain attached to their frozen DLL, and the 0.33.4 row remains static-only.

#### Findings

**R2-F4** · P2 · defect · blocks readiness — The default bare manifest supplies its own expected load target
- Location: `scripts/Validate-Package.ps1:104`; acceptance: mission §5, mission §6, mission §7, AGENTS.md fixed product identity
- Trigger: Build the genuine DLL, change EntryMethod in the checkout’s Info.json, then use the ordinary bare-DLL runner path.
- Expected: Bare preparation admits the fixed shipping Id, assembly filename, and entry method together with the validated DLL.
- Actual: New-ValidatedNativeProduct defaults to the checkout’s Info.json. Validate-Package.ps1 compares the private copy with Get-ProductInfo, which reads that same checkout manifest. A changed Id, AssemblyName, or EntryMethod therefore agrees with its own copy. The Id regression passes a separate bad manifest while leaving the checkout manifest valid. Staging checks only the copied DLL digest.
- Why it blocks / does not: The normal runner can stage a manifest that directs UMM to a different load target from the product the validator inspected.
- Requested correction: Check the frozen manifest against the repository’s fixed product identity independently of its source file. Compare the staged manifest with the recorded info_sha256 before applying any explicit ManagerVersion override.
- Requested evidence: In a disposable checkout, change the actual root Info.json after building and call preparation with its default manifest path. Show refusal for a changed Id, AssemblyName, and EntryMethod before locking. Retain the passing frozen-pair case and verify the staged digest.

**R2-F5** · P2 · defect · blocks readiness — No-product controls check the folder name instead of the UMM Id
- Location: `scripts/runtime/NativeProduct.ps1:66`; acceptance: mission §6, mission §7
- Trigger: Select an owner profile containing a working Cutscene Skip installation in a folder such as CutsceneSkip-0.1.2.
- Expected: The effective Mods set excludes the shipping UMM Id, or the runner refuses the control.
- Actual: Set-GameCopyMods filters directory names, and Assert-NoProductControlMods checks only Mods\KingmakerCutsceneSkip. A renamed folder carrying the shipping Id passes both checks. The host then accepts the scenario status without checking the harness’s productLoaded observation.
- Why it blocks / does not: A persistence or comparison result can be recorded as a no-product control while the product is loaded.
- Requested correction: Identify Cutscene Skip from the effective mod manifests. Exclude it from a disposable copy or refuse the control while preserving the owner profile. The existing in-process product identity can corroborate absence.
- Requested evidence: Use a temporary owner profile with the genuine shipping Id under a different directory name. Exercise controls with and without a comparison ZIP and verify exclusion or refusal, preservation of the unrelated mod, and unchanged source files.

**R3-F1** · P1 · defect · blocks readiness — A material Directory.Build.targets change can reuse an old DLL
- Location: `scripts/Common.ps1:140`; acceptance: mission §5, mission §6
- Trigger: After a clean build, commit a root Directory.Build.targets that changes production compilation, then package with the existing receipt.
- Expected: Adding or changing a repository target that affects production compilation invalidates the earlier build receipt.
- Actual: ProductInputPaths includes LoaderReferences.Final.targets but omits Directory.Build.targets. The new direct-build regression demonstrates that the root hook affects compiler inputs. Package.ps1 checks the narrower path list when deciding whether a receipt remains valid.
- Why it blocks / does not: Packaging can set provenance_verified to true for a frozen DLL even when rebuilding the packaging commit would use different inputs or fail its reference check.
- Requested correction: Include the root Directory.Build.targets in the product inputs used for both working-tree and between-commit checks.
- Requested evidence: Build in a temporary checkout, commit a material root Directory.Build.targets change, and show that packaging the old DLL fails without an override. Retain successful fresh-build and documentation-only reuse controls.

**R3-F2** · P2 · defect · blocks readiness — The compiler gate accepts a pin whose digest and declared version disagree
- Location: `scripts/Assert-PinnedReferences.ps1:30`; acceptance: mission §5, mission §6
- Trigger: Use a pin that declares UMM 0.31.1 while its digest authenticates an API-compatible newer UnityModManager.dll.
- Expected: An authenticated compiler input must also carry the identity declared by the pin.
- Actual: Both phases of Assert-PinnedReferences.ps1 compare paths and SHA-256 values. Neither compares the assembly’s CLR name and version with the declaration. The standalone validator performs this check later, so the direct build can succeed on a pin configuration the validator rejects.
- Why it blocks / does not: A supported production build can compile against a different loader version from the declared baseline and report that its reference check passed.
- Requested correction: Cross-check the declared CLR identity against the authenticated reference bytes in the production MSBuild gate. Reuse the standalone validator’s identity rule where practical.
- Requested evidence: Apply the existing declared-version disagreement fixture to a direct project rebuild. Show refusal before compilation and a successful rebuild after restoring the coherent pin.

**R3-F3** · P2 · defect · blocks readiness — A validation report can overwrite its supplied Info.json
- Location: `scripts/Validate-Package.ps1:138`; acceptance: mission §5, mission §6
- Trigger: Validate a bare DLL with -InfoPath and use that same manifest, or a hard link to it, as -ReportPath.
- Expected: Report publication preserves both members of the supplied DLL and manifest pair.
- Actual: The validator reads and hashes InfoPath, then passes only the DLL’s snapshot identity and current path to WriteChecked. If ReportPath identifies the supplied manifest, the writer truncates it and replaces it with the validation report.
- Why it blocks / does not: A successful standalone validation can destroy one of the inputs it just certified.
- Requested correction: Capture the supplied manifest’s identity with its bytes and include both inputs in the report destination checks through publication.
- Requested evidence: Use disposable files to show refusal when ReportPath equals InfoPath or is a hard link to it. Verify both input hashes survive and that a distinct report path succeeds.

**R3-F4** · P2 · defect · blocks readiness — Two reused records lost their original raw hashes in the evidence index
- Location: `docs/evidence/umm-0311/INDEX.md:26`; acceptance: mission §7, mission §8
- Trigger: Use the round-three index to verify the original static-audit or onboarding output.
- Expected: Reusing an exported record preserves the digest of its original output and identifies the sanitized blob separately.
- Actual: The unchanged api-audit.json and onboarding-check-project.json exports now repeat their exported hashes in the raw column. Both f7e5387 and ccd7a2b record the original raw hashes beginning bc2aeeb4 and d1efccf5 respectively. The current values begin 1185ca9b and c67b8d2b, which match the committed exports.
- Why it blocks / does not: The current index gives incorrect original-file identities for historical evidence that the mission requires preserving.
- Requested correction: Restore the original raw digests for both reused rows. If documenting the input to this round’s re-export, label that digest separately.
- Requested evidence: Show that the original-digest column agrees with the earlier evidence index and the exported-digest column agrees with the current Git blobs.

**R3-F5** · P2 · defect · blocks readiness — A private-copy cleanup failure can leave a passing host summary
- Location: `scripts/runtime/NativeProduct.ps1:76`; acceptance: mission §6, mission §7, mission §8
- Trigger: The scenario and restoration succeed, and a held temporary file prevents private-copy removal.
- Expected: The host summary records the cleanup failure while preserving the successful scenario and restoration observations.
- Actual: Complete-NativeRun writes host-summary.json before attempting private-copy removal. If the summary is writable and cleanup fails, the command releases the lock and throws, but the durable host summary still reports passed. The combined-failure fixture makes the summary unwritable, so it cannot detect this discrepancy.
- Why it blocks / does not: The retained overall run status can certify a host invocation that returned a terminal cleanup error.
- Requested correction: Include the private-copy cleanup outcome in the final host summary and retain independent lock release if reporting fails.
- Requested evidence: With a writable summary and a held private file, show a failed host outcome in the saved summary, successful restoration, release of the owned lock, and a surfaced cleanup error.

#### Prior finding assessments

- **R1-F3** — `fix_verified` — Every observed loader-family full identity is checked, and the sorted collections must match in full. The gate covers genuine references plus an additional case-variant reference at both tested versions for ZIP and bare-DLL validation.
- **R1-F7** — `fix_verified` — The fixtures replace the primary input in place and by rename after its snapshot, compare every report field apart from the path, and check publication-time aliases against both original and replacement inputs. R3-F3 concerns the newly added manifest input.
- **R2-F1** — `fix_verified` — The production project now verifies the selected cache and the resolved compiler paths and hashes. Direct-build controls cover a substituted cache file and a reference rewritten immediately before CoreCompile. R3-F2 concerns an internally inconsistent pin declaration.
- **R2-F2** — `fix_verified` — The standalone validator derives the expected identity from the declaration and checks an authenticated cache file’s identity from the same byte array. The declared-version disagreement is refused, and the genuine package passes with and without a cache.
- **R2-F3** — `fix_verified` — Summary and cleanup errors are caught independently before owned-lock release. The forced-failure fixture verifies release after restoration, preservation of the foreign lock, and retention of the lock and journal on incomplete restoration. R3-F5 concerns the persisted status.
- **R2-F4** — `fix_rejected` — Freezing the manifest fixes the later source-file replacement case, and the pin independently enforces ManagerVersion. On the default runner path, a changed checkout Id, assembly filename, or entry method still passes because it supplies the expected value.
- **R2-F5** — `fix_rejected` — The canonical-folder fixtures pass. Both exclusion and refusal still use directory names, leaving the original obligation to establish absence of the shipping mod Id unmet.
- **R2-F6** — `fix_verified` — The temporary-checkout test derives the package-manifest filename from that checkout’s Info.json version. The documentation-only reuse case passes.
- **R2-F7** — `fix_verified` — The validator creates the report parent before opening the checked destination. The fresh nested-directory and primary-input alias cases pass.
- **R2-F8** — `fix_verified` — The index now attributes build and package outputs to 4e4a8e5, test outputs to 879c19d, and the reused static audit to the frozen DLL. These producer labels resolve the prior issue. R3-F4 concerns the raw-hash column.
- **R2-F9** — `fix_verified` — Preparation and both cleanup counts use the invocation’s unique temporary root. Another invocation’s directory in the shared temporary folder falls outside both counts.

#### Evidence assessment

- **Inspected:** The enrolled mission, repository instructions, full feature diff, round-three correction diff, prior-findings ledger, developer report, transcript notice, and controller gate receipt.; The production project and MSBuild targets, pin definitions, build and receipt helpers, package validator, report writer, native preparation and cleanup paths, harness result fields, and their focused tests.; The evidence index and its earlier Git revisions, build and package records, static audit and profile identities, and the compatibility and validation guides.
- **Executed verification:** The controller receipt records scripts/Test.ps1 at f208636276367222fb33390905be19a2800c3b47 with exit code 0, 39.9 seconds elapsed, and an unchanged worktree. Its output tail explicitly reports 10 package-provenance cases with zero failures.; The detailed test export at 879c19d records 55/55 unit cases, 54/54 provenance cases, and 10/10 package-provenance cases. Git shows only documentation and evidence changes between that revision and the controller-tested candidate.; Read-only checks confirmed HEAD, the enrolled mission digest, all 11 exported evidence blob hashes, and a clean git diff --check. The build receipt, package manifest, package validation, published-package validation, and static audit agree on DLL SHA-256 a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba. The validation and audit records agree on MVID a494d31e-dfb6-469f-b2a7-787e3094639d.; The build and package records identify 4e4a8e5 as their source and agree on candidate ZIP SHA-256 86651c9a23f2e2997cf538ae8fc8e200824e41142f968b20561f3b6f0a99cff4. Git shows no intervening change to the production inputs or packaged files.
- **Source inspection only:** The remaining manifest, mod-discovery, report-alias, compiler-pin, receipt-reuse, and cleanup-status findings follow from the changed code and its callers. The passing fixtures do not exercise those specific conditions.
- **Required gaps:** Demonstrate refusal of an invalid default checkout manifest and of a no-product fixture that installs the shipping Id under another folder name.; Demonstrate direct-build refusal of a declared CLR identity mismatch and stale-receipt refusal after a material root Directory.Build.targets change.; Show that report publication preserves both supplied input files and that a writable host summary records a cleanup failure.; Reconcile the raw digests for the two reused evidence exports with their original records.
- **Limitations:** The controller withheld the mixed developer-session transcript. The candidate gate has an independent receipt. Separate build, published-ZIP validation, and static-audit invocations are represented by repository exports.; This review used read-only source, Git, and evidence checks. Native execution for this revision is recorded as NOT RUN. Historical runs cover the frozen DLL on 0.31.1, 0.32.4, and owner 0.33.0. Version 0.33.4 has a static audit and lacks a reviewed native harness profile.

#### Summary

- **Delivered behavior:** Cutscene Skip declares UMM 0.31.1. The recorded four-file package contains the frozen product DLL referencing UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. The candidate adds direct-build checks, standalone package inspection, and disposable native-run preparation. Nine of the eleven pending prior findings are verified fixed.
- **Scope reviewed:** Final correction review of the Cutscene Skip candidate against the enrolled mission, including the changed build, package, validation, evidence, and native-run tooling.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** The owner retains the decision to merge draft PR #3 or make a release after the technical findings are resolved.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: none.

Codex CLI `0.170.0`, thread `01a20c0a-caf6-7281-84dc-148b435a2821`, duration 677.6s, response sha256 `1b0f293de817f656e9b29b60797f5d80016c357e71e80f6a4596dd161a2ee55f`, request `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r03-0eccf2`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "f208636276367222fb33390905be19a2800c3b47",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The controller test gate passed at the candidate, and the recorded production DLL has the required UMM 0.31.1.0 reference. Two prior findings remain open. The bare-DLL runner can admit a changed checkout load target, and a no-product control can inherit Cutscene Skip under a different folder name. The review also found defects in build provenance, report publication, and durable evidence.\n\n## Continuation for Claude\n\nValidate the bare manifest against the repository\u2019s fixed product identity, protect it during report publication, and verify it at staging before applying a recorded override. Establish absence in no-product controls using the UMM mod Id. Keep final lock release independent of errors and make the host summary reflect any private-copy cleanup failure. On the build path, check the CLR identity of authenticated compiler inputs and include the root Directory.Build.targets in receipt invalidation. Restore the original raw hashes for the two reused evidence records.\n\nExercise these cases in the existing disposable fixtures, retain the genuine build and package controls, and run the configured test gate on the corrected commit. Keep the work within Cutscene Skip tooling and evidence. The historical native observations remain attached to their frozen DLL, and the 0.33.4 row remains static-only.",
  "evidence_assessment": {
    "executed_verification": [
      "The controller receipt records scripts/Test.ps1 at f208636276367222fb33390905be19a2800c3b47 with exit code 0, 39.9 seconds elapsed, and an unchanged worktree. Its output tail explicitly reports 10 package-provenance cases with zero failures.",
      "The detailed test export at 879c19d records 55/55 unit cases, 54/54 provenance cases, and 10/10 package-provenance cases. Git shows only documentation and evidence changes between that revision and the controller-tested candidate.",
      "Read-only checks confirmed HEAD, the enrolled mission digest, all 11 exported evidence blob hashes, and a clean git diff --check. The build receipt, package manifest, package validation, published-package validation, and static audit agree on DLL SHA-256 a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba. The validation and audit records agree on MVID a494d31e-dfb6-469f-b2a7-787e3094639d.",
      "The build and package records identify 4e4a8e5 as their source and agree on candidate ZIP SHA-256 86651c9a23f2e2997cf538ae8fc8e200824e41142f968b20561f3b6f0a99cff4. Git shows no intervening change to the production inputs or packaged files."
    ],
    "inspected": [
      "The enrolled mission, repository instructions, full feature diff, round-three correction diff, prior-findings ledger, developer report, transcript notice, and controller gate receipt.",
      "The production project and MSBuild targets, pin definitions, build and receipt helpers, package validator, report writer, native preparation and cleanup paths, harness result fields, and their focused tests.",
      "The evidence index and its earlier Git revisions, build and package records, static audit and profile identities, and the compatibility and validation guides."
    ],
    "limitations": [
      "The controller withheld the mixed developer-session transcript. The candidate gate has an independent receipt. Separate build, published-ZIP validation, and static-audit invocations are represented by repository exports.",
      "This review used read-only source, Git, and evidence checks. Native execution for this revision is recorded as NOT RUN. Historical runs cover the frozen DLL on 0.31.1, 0.32.4, and owner 0.33.0. Version 0.33.4 has a static audit and lacks a reviewed native harness profile."
    ],
    "required_gaps": [
      "Demonstrate refusal of an invalid default checkout manifest and of a no-product fixture that installs the shipping Id under another folder name.",
      "Demonstrate direct-build refusal of a declared CLR identity mismatch and stale-receipt refusal after a material root Directory.Build.targets change.",
      "Show that report publication preserves both supplied input files and that a writable host summary records a cleanup failure.",
      "Reconcile the raw digests for the two reused evidence exports with their original records."
    ],
    "source_inspection_only": [
      "The remaining manifest, mod-discovery, report-alias, compiler-pin, receipt-reuse, and cleanup-status findings follow from the changed code and its callers. The passing fixtures do not exercise those specific conditions."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76",
        "mission \u00a77",
        "AGENTS.md fixed product identity"
      ],
      "actual": "New-ValidatedNativeProduct defaults to the checkout\u2019s Info.json. Validate-Package.ps1 compares the private copy with Get-ProductInfo, which reads that same checkout manifest. A changed Id, AssemblyName, or EntryMethod therefore agrees with its own copy. The Id regression passes a separate bad manifest while leaving the checkout manifest valid. Staging checks only the copied DLL digest.",
      "blocking_rationale": "The normal runner can stage a manifest that directs UMM to a different load target from the product the validator inspected.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Bare preparation admits the fixed shipping Id, assembly filename, and entry method together with the validated DLL.",
      "id": "R2-F4",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 104
      },
      "priority": "P2",
      "requested_correction": "Check the frozen manifest against the repository\u2019s fixed product identity independently of its source file. Compare the staged manifest with the recorded info_sha256 before applying any explicit ManagerVersion override.",
      "requested_evidence": "In a disposable checkout, change the actual root Info.json after building and call preparation with its default manifest path. Show refusal for a changed Id, AssemblyName, and EntryMethod before locking. Retain the passing frozen-pair case and verify the staged digest.",
      "title": "The default bare manifest supplies its own expected load target",
      "trigger": "Build the genuine DLL, change EntryMethod in the checkout\u2019s Info.json, then use the ordinary bare-DLL runner path."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "mission \u00a77"
      ],
      "actual": "Set-GameCopyMods filters directory names, and Assert-NoProductControlMods checks only Mods\\KingmakerCutsceneSkip. A renamed folder carrying the shipping Id passes both checks. The host then accepts the scenario status without checking the harness\u2019s productLoaded observation.",
      "blocking_rationale": "A persistence or comparison result can be recorded as a no-product control while the product is loaded.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The effective Mods set excludes the shipping UMM Id, or the runner refuses the control.",
      "id": "R2-F5",
      "location": {
        "file": "scripts/runtime/NativeProduct.ps1",
        "line": 66
      },
      "priority": "P2",
      "requested_correction": "Identify Cutscene Skip from the effective mod manifests. Exclude it from a disposable copy or refuse the control while preserving the owner profile. The existing in-process product identity can corroborate absence.",
      "requested_evidence": "Use a temporary owner profile with the genuine shipping Id under a different directory name. Exercise controls with and without a comparison ZIP and verify exclusion or refusal, preservation of the unrelated mod, and unchanged source files.",
      "title": "No-product controls check the folder name instead of the UMM Id",
      "trigger": "Select an owner profile containing a working Cutscene Skip installation in a folder such as CutsceneSkip-0.1.2."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "ProductInputPaths includes LoaderReferences.Final.targets but omits Directory.Build.targets. The new direct-build regression demonstrates that the root hook affects compiler inputs. Package.ps1 checks the narrower path list when deciding whether a receipt remains valid.",
      "blocking_rationale": "Packaging can set provenance_verified to true for a frozen DLL even when rebuilding the packaging commit would use different inputs or fail its reference check.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Adding or changing a repository target that affects production compilation invalidates the earlier build receipt.",
      "id": "R3-F1",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 140
      },
      "priority": "P1",
      "requested_correction": "Include the root Directory.Build.targets in the product inputs used for both working-tree and between-commit checks.",
      "requested_evidence": "Build in a temporary checkout, commit a material root Directory.Build.targets change, and show that packaging the old DLL fails without an override. Retain successful fresh-build and documentation-only reuse controls.",
      "title": "A material Directory.Build.targets change can reuse an old DLL",
      "trigger": "After a clean build, commit a root Directory.Build.targets that changes production compilation, then package with the existing receipt."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "Both phases of Assert-PinnedReferences.ps1 compare paths and SHA-256 values. Neither compares the assembly\u2019s CLR name and version with the declaration. The standalone validator performs this check later, so the direct build can succeed on a pin configuration the validator rejects.",
      "blocking_rationale": "A supported production build can compile against a different loader version from the declared baseline and report that its reference check passed.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "An authenticated compiler input must also carry the identity declared by the pin.",
      "id": "R3-F2",
      "location": {
        "file": "scripts/Assert-PinnedReferences.ps1",
        "line": 30
      },
      "priority": "P2",
      "requested_correction": "Cross-check the declared CLR identity against the authenticated reference bytes in the production MSBuild gate. Reuse the standalone validator\u2019s identity rule where practical.",
      "requested_evidence": "Apply the existing declared-version disagreement fixture to a direct project rebuild. Show refusal before compilation and a successful rebuild after restoring the coherent pin.",
      "title": "The compiler gate accepts a pin whose digest and declared version disagree",
      "trigger": "Use a pin that declares UMM 0.31.1 while its digest authenticates an API-compatible newer UnityModManager.dll."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The validator reads and hashes InfoPath, then passes only the DLL\u2019s snapshot identity and current path to WriteChecked. If ReportPath identifies the supplied manifest, the writer truncates it and replaces it with the validation report.",
      "blocking_rationale": "A successful standalone validation can destroy one of the inputs it just certified.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Report publication preserves both members of the supplied DLL and manifest pair.",
      "id": "R3-F3",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 138
      },
      "priority": "P2",
      "requested_correction": "Capture the supplied manifest\u2019s identity with its bytes and include both inputs in the report destination checks through publication.",
      "requested_evidence": "Use disposable files to show refusal when ReportPath equals InfoPath or is a hard link to it. Verify both input hashes survive and that a distinct report path succeeds.",
      "title": "A validation report can overwrite its supplied Info.json",
      "trigger": "Validate a bare DLL with -InfoPath and use that same manifest, or a hard link to it, as -ReportPath."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "mission \u00a78"
      ],
      "actual": "The unchanged api-audit.json and onboarding-check-project.json exports now repeat their exported hashes in the raw column. Both f7e5387 and ccd7a2b record the original raw hashes beginning bc2aeeb4 and d1efccf5 respectively. The current values begin 1185ca9b and c67b8d2b, which match the committed exports.",
      "blocking_rationale": "The current index gives incorrect original-file identities for historical evidence that the mission requires preserving.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Reusing an exported record preserves the digest of its original output and identifies the sanitized blob separately.",
      "id": "R3-F4",
      "location": {
        "file": "docs/evidence/umm-0311/INDEX.md",
        "line": 26
      },
      "priority": "P2",
      "requested_correction": "Restore the original raw digests for both reused rows. If documenting the input to this round\u2019s re-export, label that digest separately.",
      "requested_evidence": "Show that the original-digest column agrees with the earlier evidence index and the exported-digest column agrees with the current Git blobs.",
      "title": "Two reused records lost their original raw hashes in the evidence index",
      "trigger": "Use the round-three index to verify the original static-audit or onboarding output."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "mission \u00a77",
        "mission \u00a78"
      ],
      "actual": "Complete-NativeRun writes host-summary.json before attempting private-copy removal. If the summary is writable and cleanup fails, the command releases the lock and throws, but the durable host summary still reports passed. The combined-failure fixture makes the summary unwritable, so it cannot detect this discrepancy.",
      "blocking_rationale": "The retained overall run status can certify a host invocation that returned a terminal cleanup error.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The host summary records the cleanup failure while preserving the successful scenario and restoration observations.",
      "id": "R3-F5",
      "location": {
        "file": "scripts/runtime/NativeProduct.ps1",
        "line": 76
      },
      "priority": "P2",
      "requested_correction": "Include the private-copy cleanup outcome in the final host summary and retain independent lock release if reporting fails.",
      "requested_evidence": "With a writable summary and a held private file, show a failed host outcome in the saved summary, successful restoration, release of the owned lock, and a surfaced cleanup error.",
      "title": "A private-copy cleanup failure can leave a passing host summary",
      "trigger": "The scenario and restoration succeed, and a held temporary file prevents private-copy removal."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F3",
      "rationale": "Every observed loader-family full identity is checked, and the sorted collections must match in full. The gate covers genuine references plus an additional case-variant reference at both tested versions for ZIP and bare-DLL validation."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F7",
      "rationale": "The fixtures replace the primary input in place and by rename after its snapshot, compare every report field apart from the path, and check publication-time aliases against both original and replacement inputs. R3-F3 concerns the newly added manifest input."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F1",
      "rationale": "The production project now verifies the selected cache and the resolved compiler paths and hashes. Direct-build controls cover a substituted cache file and a reference rewritten immediately before CoreCompile. R3-F2 concerns an internally inconsistent pin declaration."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F2",
      "rationale": "The standalone validator derives the expected identity from the declaration and checks an authenticated cache file\u2019s identity from the same byte array. The declared-version disagreement is refused, and the genuine package passes with and without a cache."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F3",
      "rationale": "Summary and cleanup errors are caught independently before owned-lock release. The forced-failure fixture verifies release after restoration, preservation of the foreign lock, and retention of the lock and journal on incomplete restoration. R3-F5 concerns the persisted status."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R2-F4",
      "rationale": "Freezing the manifest fixes the later source-file replacement case, and the pin independently enforces ManagerVersion. On the default runner path, a changed checkout Id, assembly filename, or entry method still passes because it supplies the expected value."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R2-F5",
      "rationale": "The canonical-folder fixtures pass. Both exclusion and refusal still use directory names, leaving the original obligation to establish absence of the shipping mod Id unmet."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F6",
      "rationale": "The temporary-checkout test derives the package-manifest filename from that checkout\u2019s Info.json version. The documentation-only reuse case passes."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F7",
      "rationale": "The validator creates the report parent before opening the checked destination. The fresh nested-directory and primary-input alias cases pass."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F8",
      "rationale": "The index now attributes build and package outputs to 4e4a8e5, test outputs to 879c19d, and the reused static audit to the frozen DLL. These producer labels resolve the prior issue. R3-F4 concerns the raw-hash column."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F9",
      "rationale": "Preparation and both cleanup counts use the invocation\u2019s unique temporary root. Another invocation\u2019s directory in the shared temporary folder falls outside both counts."
    }
  ],
  "request_id": "ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r03-0eccf2",
  "round": 3,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "Cutscene Skip declares UMM 0.31.1. The recorded four-file package contains the frozen product DLL referencing UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. The candidate adds direct-build checks, standalone package inspection, and disposable native-run preparation. Nine of the eleven pending prior findings are verified fixed.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "The owner retains the decision to merge draft PR #3 or make a release after the technical findings are resolved."
    ],
    "scope_reviewed": "Final correction review of the Cutscene Skip candidate against the enrolled mission, including the changed build, package, validation, evidence, and native-run tooling.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
