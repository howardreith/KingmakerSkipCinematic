<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r01-review part=1/1 sha256=00d6835f65dd108e0080c64ae1d5c90743aac2c1d6f6edfbb83966b31edbb1e7 -->
### Codex GPT-6.2 Astra — review — round 1 — candidate `f7e5387224`

**Decision:** `changes_required` — The production DLL has the declared baseline, and the controller test gate passed. The candidate can still qualify the wrong bytes, reuse a build after a material helper change, and fail its own tests on an installation using the supported minimum. The newest loader also lacks a native result or a documented blocker.

## Continuation for Claude

Keep the corrections in Cutscene Skip’s existing build, package, test, and guarded runtime paths. Bind qualification to the effective build inputs, the packaged load target, and the bytes actually staged. Preserve the no-product control and cleanup on failure. Exercise the reported failures with real files in disposable locations, then rerun the controller test gate on the corrected commit. Update the compatibility guide with reproducible checks and a disposition for UMM 0.33.4. Reuse historical native observations for their exact DLL, profile, and scenario. Keep any new native work to the approved disposable runner, skip boundary, and persistence check, with the existing locks and restoration protections.

#### Findings

**R1-F1** · P1 · defect · blocks readiness — Build-helper changes can leave a stale DLL eligible for packaging
- Location: `scripts/Common.ps1:134`; acceptance: mission §5, mission §6
- Trigger: Build the product, commit a material helper change, then package the previously built DLL.
- Expected: Packaging requires a fresh build receipt after a material change to the build wrapper or reference helper.
- Actual: Get-ProductInputPaths omits scripts/Build.ps1 and scripts/Common.ps1. Both the dirty-input check and the between-commit check use that list. A change to compiler arguments or reference selection in those scripts can leave the old DLL eligible for provenance_verified=true.
- Why it blocks / does not: The mission explicitly requires material build and reference-helper changes to invalidate frozen-binary reuse.
- Requested correction: Include the effective build and reference helpers in the product-input comparison used by both build and package receipts. Retain reuse for documentation-only changes.
- Requested evidence: In a temporary Git checkout, show that changing a material helper invalidates the prior receipt, a fresh build passes, and a documentation-only change can reuse the frozen DLL.

**R1-F2** · P1 · defect · blocks readiness — The standalone check can validate a different load target from the manifest
- Location: `scripts/Validate-Package.ps1:63`; acceptance: mission §5, mission §6, AGENTS.md product identity
- Trigger: Supply a four-entry ZIP with valid baseline references and change only its manifest load target or the product DLL version.
- Expected: The inspected DLL is the load target named by the packaged manifest, the repository’s fixed entry method is preserved, and the product version agrees with the DLL under the packaging rule.
- Actual: The validator inspects a hard-coded DLL entry and checks three manifest fields. It ignores the packaged AssemblyName and EntryMethod and does not compare the DLL’s product version with the manifest. The passing ZIP fixture contains a Probe assembly with no product version attributes.
- Why it blocks / does not: A supplied archive can pass pre-install validation even when UMM is directed to a missing assembly or entry point, or the packaged product version is wrong.
- Requested correction: Check the packaged AssemblyName and EntryMethod against the shipping identity and apply the product-version check to the DLL read from the ZIP.
- Requested evidence: Show standalone rejection for a wrong assembly target, a wrong entry method, and a conflicting DLL version. Keep the genuine frozen 0.1.2 ZIP as a passing control.

**R1-F3** · P2 · defect · blocks readiness — The loader reference check discards binding identity
- Location: `scripts/Validate-Package.ps1:75`; acceptance: mission §5, mission §6
- Trigger: A supplied DLL references a differently signed or cultured loader with the pinned simple name and version.
- Expected: The DLL’s loader AssemblyRefs match the binding identities of the genuine pins, and the documented additional-loader rule is enforced.
- Actual: The validator projects each AssemblyRef to simple name and version, discarding culture and public-key token. A distinct CLR binding identity with the same name and version passes. The filter also ignores additional UnityModManager-prefixed names while the documented contract excludes other UMM assemblies.
- Why it blocks / does not: A successful result can describe a reference that the genuine baseline assembly cannot satisfy.
- Requested correction: Compare the relevant CLR identity fields with the verified pin identities and apply the additional-assembly check consistently to the declared loader families.
- Requested evidence: Show standalone rejection of a same-name, same-version reference with a different binding identity and of an additional UMM-family reference, alongside the genuine package pass.

**R1-F4** · P1 · defect · blocks readiness — A bare-DLL run can stage bytes that never passed validation
- Location: `scripts/runtime/Invoke-NativeRun.ps1:86`; acceptance: mission §6, mission §7
- Trigger: The build output is replaced between the pre-lock validation and product deployment.
- Expected: The DLL admitted before locking, the DLL staged, and the digest in the run summary all identify the same bytes.
- Actual: The bare-DLL route validates the live build output at line 86, hashes that path again at line 115, and copies it at line 163. Only the ZIP branch compares the staged DLL with validatedProduct.dll_sha256.
- Why it blocks / does not: A concurrent rebuild can change which binary a native run qualifies and make its recorded hash disagree with the installed bytes.
- Requested correction: Freeze the bare DLL before validation or compare the staged file with the validator’s digest before launch. Record the verified staged digest.
- Requested evidence: Exercise the staging code with real temporary files and replace the original build output after validation. Show that the runner stages the validated bytes or stops before launch.

**R1-F5** · P1 · defect · blocks readiness — The test gate assumes the installed loader is newer than 0.31.1
- Location: `scripts/Test-Provenance.ps1:103`; acceptance: mission §5, mission §6
- Trigger: Run scripts/Test.ps1 with a valid Kingmaker installation using UMM 0.31.1.
- Expected: The version-mismatch regression remains deterministic with either the baseline or a newer loader installed.
- Actual: The negative fixture compiles against the live installation, and two assertions require that fixture to fail the 0.31.1 check. On an installation running 0.31.1, it has the correct references and the validator correctly accepts it.
- Why it blocks / does not: The required gate fails on the very loader version this project declares as its supported minimum.
- Requested correction: Compile the negative fixture against a known, independently identified nonbaseline reference. Remove its dependence on whichever UMM version happens to be installed.
- Requested evidence: Show the same positive and negative cases passing with baseline and newer reference configurations using disposable inputs, with the owner installation preserved.

**R1-F6** · P2 · defect · blocks readiness — A no-product control fails when a comparison ZIP is supplied
- Location: `scripts/runtime/Invoke-NativeRun.ps1:114`; acceptance: mission §6, mission §7
- Trigger: Invoke the runner with both -NoProduct and -ProductZip.
- Expected: A no-product control can reuse the comparison run’s arguments and proceed with the product absent.
- Actual: With -NoProduct, validatedProduct stays null. A supplied -ProductZip still enters the summary branch and reads validatedProduct.input_sha256. Under the runner’s strict mode this raises PropertyNotFoundStrict after the lock is acquired.
- Why it blocks / does not: This breaks a previously usable argument combination for product-absent controls and persistence comparisons.
- Requested correction: Make product requirements, summary fields, and staging honor the same no-product decision. Record any comparison archive separately from an installed product.
- Requested evidence: Exercise the no-product path with and without -ProductZip. Show that both produce a no-product summary and stage no product DLL.

**R1-F7** · P2 · defect · blocks readiness — A validation report can combine the hash and metadata of different files
- Location: `scripts/Validate-Package.ps1:46`; acceptance: mission §5, mission §6
- Trigger: Another packaging process replaces the supplied path between reads, or the report path aliases the input.
- Expected: Every digest and metadata field in a report comes from one input snapshot, and writing the report preserves that input.
- Actual: The validator hashes the path, closes it, then reopens it for inspection. On the bare-DLL route even input_sha256 and dll_sha256 can come from different reads. The report guard compares path strings, so a second filesystem name for the same file can also direct report output onto the validated input.
- Why it blocks / does not: A validation report can attest to bytes that were never inspected or overwrite the artifact it identifies.
- Requested correction: Hash and inspect one immutable snapshot or held read handle. Protect the input through report publication, including filesystem aliases, and use the validated ZIP digest in the package manifest.
- Requested evidence: Use disposable files to verify digest consistency during input replacement and that a report path alias leaves the input intact.

**R1-F8** · P2 · defect · blocks readiness — Setup failures can leave a private copy or an unrecoverable run lock
- Location: `scripts/runtime/Invoke-NativeRun.ps1:94`; acceptance: mission §7, AGENTS.md native transaction
- Trigger: Copying the product fails, or the evidence directory cannot be created after acquiring the lock.
- Expected: Every resource acquired by this invocation is covered by cleanup from acquisition onward. A lock retained for restoration has a recoverable transaction.
- Actual: A copy or report-read error before line 92 leaves the private product directory behind. After Enter-RuntimeLock succeeds, evidence-directory creation at line 102 is outside the run’s finally block. A failure there leaves a lock with no recovery journal, and -RecoverOnly returns when the journal is absent.
- Why it blocks / does not: An ordinary setup failure can strand the shared runtime lock and prevent later guarded runs.
- Requested correction: Cover private preparation and post-lock initialization with cleanup. Release this invocation’s lock on pre-transaction failure while retaining the existing recovery behavior for incomplete restoration.
- Requested evidence: In a disposable lab, force a preparation failure and a post-lock evidence-directory failure. Verify the private directory and owned lock are cleaned up and foreign locks are preserved.

**R1-F9** · P2 · evidence_gap · blocks readiness — Cache corruption and stale DLL receipts lack real negative controls
- Location: `scripts/Test-Provenance.ps1:31`; acceptance: mission §5, mission §6
- Trigger: Evaluate the mission’s required rejection cases against the 21 passing provenance checks.
- Expected: A populated reference cache with incorrect bytes produces a clear refusal, and a stale build receipt fails against a different product DLL.
- Actual: ChangedHashIsRejected changes a field in an in-memory reference receipt. It never corrupts a cached file or presents Package.ps1 with different DLL bytes. Initialize-PinnedReferences routes an existing wrong digest through the cache-miss download path and can succeed without reporting the corruption.
- Why it blocks / does not: Two explicitly required failure boundaries lack an observed result through the real helpers.
- Requested correction: Distinguish a corrupt existing entry from normal first-time acquisition. Exercise the actual reference helper and packaging command with a temporary cache, checkout, DLL, and receipt.
- Requested evidence: Provide the observed corrupt-cache refusal before compilation, the package refusal for a mismatched DLL digest, and a genuine passing control without a provenance override.

**R1-F10** · P2 · evidence_gap · blocks readiness — UMM 0.33.4 has no native result or documented blocker
- Location: `docs/evidence/umm-0311/api-audit.json:51`; acceptance: mission §7, mission §8
- Trigger: Assess the newest stable loader selected for this mission.
- Expected: UMM 0.33.4 receives a focused guarded check where the disposable route is available, or an explicit NOT RUN/BLOCKED row with the concrete reason.
- Actual: The 0.33.4 record contains static metadata resolution only. Historical runs cover 0.31.1, 0.32.4, and 0.33.0 on the released DLL. The report gives the tooling-only change as the reason for skipping native work, and identifies no current fixture, profile-admission, or guard failure for 0.33.4.
- Why it blocks / does not: The newest selected loader has neither the requested focused observation nor the specific unavailable prerequisite that permits a blocked row.
- Requested correction: Establish whether the existing disposable copy, fixture, and guarded harness can admit the measured 0.33.4 stack. Run the existing skip and persistence check if available, or record the exact unmet prerequisite.
- Requested evidence: Provide the frozen DLL hash, actual in-process loader and Harmony identities, interaction-boundary and reload observations, and restoration result, or the concrete blocked preflight or admission result.

**R1-F11** · P2 · required_gap · blocks readiness — The current compatibility guide omits the newest audit and its reproduction steps
- Location: `docs/COMPATIBILITY.md:17`; acceptance: mission §7, mission §8
- Trigger: Follow README’s compatibility link to determine how the current four-profile assessment was performed.
- Expected: A reader can distinguish the declared floor, compiler identity, static results, historical native results, and current native disposition from the main compatibility guide.
- Actual: The guide linked by README describes the later static audit only through 0.33.2. The 0.33.4 result is discoverable in the evidence directory, whose index explains how to hash exports but gives no invocation for reproducing the API audit.
- Why it blocks / does not: The mission requires current compatibility documentation that identifies the method, candidate, limits, and reproduction steps for each assessed version.
- Requested correction: Update the current matrix for all four profiles. Link the frozen artifact and audit records, give the audit tool and invocation and the guarded disposable-run command, and identify which combined-stack results are historical.
- Requested evidence: The guide should let a maintainer reproduce the checks and determine exactly what was observed on 0.33.4 without inferring native compatibility from the API report.

#### Evidence assessment

- **Inspected:** The enrolled mission and its SHA-256, applicable AGENTS.md and CLAUDE.md, fixed request, developer report, transcript notice, and empty prior-findings ledger.; The full feature diff, shipping manifest, production project, reference pins, build and receipt helpers, package validator, provenance tests, native runner, restoration helpers, and relevant native scenarios.; The candidate-bound controller receipt, exported build and package records, published-asset validation, static API audit, loader identities, and historical compatibility and validation records.
- **Executed verification:** The controller receipt binds scripts/Test.ps1 to f7e53872245032cbac77099b5bd56fe6dd9ba11c. It exited 0 in 5.8 seconds with 55/55 unit tests and 21/21 provenance checks. The gate exercised real ZIPs and compiled DLL fixtures.; Read-only Git comparisons confirmed the reviewed HEAD, the v0.1.2 tag at the target commit, unchanged product and compiler inputs across the feature diff, and an evidence-only change from 5efdcb0 to HEAD.; All eight exported SHA-256 values in docs/evidence/umm-0311/INDEX.md matched files whose Git blob IDs also matched HEAD.; An isolated Windows PowerShell check confirmed that reading input_sha256 from the null validation result under strict mode raises PropertyNotFoundStrict.
- **Source inspection only:** The build receipt records product inputs clean at 6c1d65a. The clean package manifest at 5efdcb0 and the published v0.1.2 validation record identify different ZIPs, f4bc5727… and c1be6ae2…, containing the same DLL a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba with MVID a494d31e-dfb6-469f-b2a7-787e3094639d.; The exported API audit reports six type references and 18 member references resolved on 0.31.1, 0.32.4, measured owner 0.33.0, and 0.33.4. Historical runs document skip and persistence behavior for the released DLL on the first three profiles.; The native-runner provenance test checks source text for call ordering and the ZIP variable used by Expand-Archive. It does not execute product selection, staging, or cleanup.
- **Required gaps:** Close the build-reuse, package-identity, staging, control-run, and cleanup defects below.; Provide real corrupt-cache and mismatched-receipt observations, including coverage on a baseline installation.; Provide a guarded 0.33.4 native result or identify the concrete unavailable prerequisite. Document the current compatibility matrix and reproduction commands.
- **Limitations:** The foreground command transcript was withheld because it contains unrelated work. The controller receipt independently confirms the test gate at HEAD. Packaging and API-audit results are available as exported records.; The review was read-only. Native behavior is supported here by historical records for their named artifacts and scenarios. The developer reported no new native run.

#### Summary

- **Delivered behavior:** Cutscene Skip declares UMM 0.31.1 and its recorded production DLL references UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. Packaging now inspects the archive’s actual DLL, compares its digest with the receipted build, and checks the four allowed entries. The ZIP route in the native runner stages a private validated copy.
- **Scope reviewed:** Final checkpoint for KingmakerSkipCinematic draft PR #3, covering the complete feature diff from 6c1d65a to f7e5387 and this repository’s applicable mission requirements.
- **Pending later-phase work:** none
- **Unresolved questions:** Whether the approved disposable environment can currently run the 0.33.4 skip and persistence fixture. No current preflight disposition was supplied.
- **Remaining owner review:** Final PR acceptance and any eventual merge or release decision.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: none.

Codex CLI `0.170.0`, thread `01a20b93-c4a3-7bd1-99a8-06a87bb6fbc1`, duration 741.2s, response sha256 `68fb2c15704150835bd29019e1b2940055931ee358b9ddf4d290f0d11cb27c31`, request `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r01-ec5374`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "f7e53872245032cbac77099b5bd56fe6dd9ba11c",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The production DLL has the declared baseline, and the controller test gate passed. The candidate can still qualify the wrong bytes, reuse a build after a material helper change, and fail its own tests on an installation using the supported minimum. The newest loader also lacks a native result or a documented blocker.\n\n## Continuation for Claude\n\nKeep the corrections in Cutscene Skip\u2019s existing build, package, test, and guarded runtime paths. Bind qualification to the effective build inputs, the packaged load target, and the bytes actually staged. Preserve the no-product control and cleanup on failure. Exercise the reported failures with real files in disposable locations, then rerun the controller test gate on the corrected commit. Update the compatibility guide with reproducible checks and a disposition for UMM 0.33.4. Reuse historical native observations for their exact DLL, profile, and scenario. Keep any new native work to the approved disposable runner, skip boundary, and persistence check, with the existing locks and restoration protections.",
  "evidence_assessment": {
    "executed_verification": [
      "The controller receipt binds scripts/Test.ps1 to f7e53872245032cbac77099b5bd56fe6dd9ba11c. It exited 0 in 5.8 seconds with 55/55 unit tests and 21/21 provenance checks. The gate exercised real ZIPs and compiled DLL fixtures.",
      "Read-only Git comparisons confirmed the reviewed HEAD, the v0.1.2 tag at the target commit, unchanged product and compiler inputs across the feature diff, and an evidence-only change from 5efdcb0 to HEAD.",
      "All eight exported SHA-256 values in docs/evidence/umm-0311/INDEX.md matched files whose Git blob IDs also matched HEAD.",
      "An isolated Windows PowerShell check confirmed that reading input_sha256 from the null validation result under strict mode raises PropertyNotFoundStrict."
    ],
    "inspected": [
      "The enrolled mission and its SHA-256, applicable AGENTS.md and CLAUDE.md, fixed request, developer report, transcript notice, and empty prior-findings ledger.",
      "The full feature diff, shipping manifest, production project, reference pins, build and receipt helpers, package validator, provenance tests, native runner, restoration helpers, and relevant native scenarios.",
      "The candidate-bound controller receipt, exported build and package records, published-asset validation, static API audit, loader identities, and historical compatibility and validation records."
    ],
    "limitations": [
      "The foreground command transcript was withheld because it contains unrelated work. The controller receipt independently confirms the test gate at HEAD. Packaging and API-audit results are available as exported records.",
      "The review was read-only. Native behavior is supported here by historical records for their named artifacts and scenarios. The developer reported no new native run."
    ],
    "required_gaps": [
      "Close the build-reuse, package-identity, staging, control-run, and cleanup defects below.",
      "Provide real corrupt-cache and mismatched-receipt observations, including coverage on a baseline installation.",
      "Provide a guarded 0.33.4 native result or identify the concrete unavailable prerequisite. Document the current compatibility matrix and reproduction commands."
    ],
    "source_inspection_only": [
      "The build receipt records product inputs clean at 6c1d65a. The clean package manifest at 5efdcb0 and the published v0.1.2 validation record identify different ZIPs, f4bc5727\u2026 and c1be6ae2\u2026, containing the same DLL a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba with MVID a494d31e-dfb6-469f-b2a7-787e3094639d.",
      "The exported API audit reports six type references and 18 member references resolved on 0.31.1, 0.32.4, measured owner 0.33.0, and 0.33.4. Historical runs document skip and persistence behavior for the released DLL on the first three profiles.",
      "The native-runner provenance test checks source text for call ordering and the ZIP variable used by Expand-Archive. It does not execute product selection, staging, or cleanup."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "Get-ProductInputPaths omits scripts/Build.ps1 and scripts/Common.ps1. Both the dirty-input check and the between-commit check use that list. A change to compiler arguments or reference selection in those scripts can leave the old DLL eligible for provenance_verified=true.",
      "blocking_rationale": "The mission explicitly requires material build and reference-helper changes to invalidate frozen-binary reuse.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Packaging requires a fresh build receipt after a material change to the build wrapper or reference helper.",
      "id": "R1-F1",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 134
      },
      "priority": "P1",
      "requested_correction": "Include the effective build and reference helpers in the product-input comparison used by both build and package receipts. Retain reuse for documentation-only changes.",
      "requested_evidence": "In a temporary Git checkout, show that changing a material helper invalidates the prior receipt, a fresh build passes, and a documentation-only change can reuse the frozen DLL.",
      "title": "Build-helper changes can leave a stale DLL eligible for packaging",
      "trigger": "Build the product, commit a material helper change, then package the previously built DLL."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76",
        "AGENTS.md product identity"
      ],
      "actual": "The validator inspects a hard-coded DLL entry and checks three manifest fields. It ignores the packaged AssemblyName and EntryMethod and does not compare the DLL\u2019s product version with the manifest. The passing ZIP fixture contains a Probe assembly with no product version attributes.",
      "blocking_rationale": "A supplied archive can pass pre-install validation even when UMM is directed to a missing assembly or entry point, or the packaged product version is wrong.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The inspected DLL is the load target named by the packaged manifest, the repository\u2019s fixed entry method is preserved, and the product version agrees with the DLL under the packaging rule.",
      "id": "R1-F2",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 63
      },
      "priority": "P1",
      "requested_correction": "Check the packaged AssemblyName and EntryMethod against the shipping identity and apply the product-version check to the DLL read from the ZIP.",
      "requested_evidence": "Show standalone rejection for a wrong assembly target, a wrong entry method, and a conflicting DLL version. Keep the genuine frozen 0.1.2 ZIP as a passing control.",
      "title": "The standalone check can validate a different load target from the manifest",
      "trigger": "Supply a four-entry ZIP with valid baseline references and change only its manifest load target or the product DLL version."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The validator projects each AssemblyRef to simple name and version, discarding culture and public-key token. A distinct CLR binding identity with the same name and version passes. The filter also ignores additional UnityModManager-prefixed names while the documented contract excludes other UMM assemblies.",
      "blocking_rationale": "A successful result can describe a reference that the genuine baseline assembly cannot satisfy.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The DLL\u2019s loader AssemblyRefs match the binding identities of the genuine pins, and the documented additional-loader rule is enforced.",
      "id": "R1-F3",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 75
      },
      "priority": "P2",
      "requested_correction": "Compare the relevant CLR identity fields with the verified pin identities and apply the additional-assembly check consistently to the declared loader families.",
      "requested_evidence": "Show standalone rejection of a same-name, same-version reference with a different binding identity and of an additional UMM-family reference, alongside the genuine package pass.",
      "title": "The loader reference check discards binding identity",
      "trigger": "A supplied DLL references a differently signed or cultured loader with the pinned simple name and version."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "mission \u00a77"
      ],
      "actual": "The bare-DLL route validates the live build output at line 86, hashes that path again at line 115, and copies it at line 163. Only the ZIP branch compares the staged DLL with validatedProduct.dll_sha256.",
      "blocking_rationale": "A concurrent rebuild can change which binary a native run qualifies and make its recorded hash disagree with the installed bytes.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The DLL admitted before locking, the DLL staged, and the digest in the run summary all identify the same bytes.",
      "id": "R1-F4",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 86
      },
      "priority": "P1",
      "requested_correction": "Freeze the bare DLL before validation or compare the staged file with the validator\u2019s digest before launch. Record the verified staged digest.",
      "requested_evidence": "Exercise the staging code with real temporary files and replace the original build output after validation. Show that the runner stages the validated bytes or stops before launch.",
      "title": "A bare-DLL run can stage bytes that never passed validation",
      "trigger": "The build output is replaced between the pre-lock validation and product deployment."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The negative fixture compiles against the live installation, and two assertions require that fixture to fail the 0.31.1 check. On an installation running 0.31.1, it has the correct references and the validator correctly accepts it.",
      "blocking_rationale": "The required gate fails on the very loader version this project declares as its supported minimum.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The version-mismatch regression remains deterministic with either the baseline or a newer loader installed.",
      "id": "R1-F5",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 103
      },
      "priority": "P1",
      "requested_correction": "Compile the negative fixture against a known, independently identified nonbaseline reference. Remove its dependence on whichever UMM version happens to be installed.",
      "requested_evidence": "Show the same positive and negative cases passing with baseline and newer reference configurations using disposable inputs, with the owner installation preserved.",
      "title": "The test gate assumes the installed loader is newer than 0.31.1",
      "trigger": "Run scripts/Test.ps1 with a valid Kingmaker installation using UMM 0.31.1."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "mission \u00a77"
      ],
      "actual": "With -NoProduct, validatedProduct stays null. A supplied -ProductZip still enters the summary branch and reads validatedProduct.input_sha256. Under the runner\u2019s strict mode this raises PropertyNotFoundStrict after the lock is acquired.",
      "blocking_rationale": "This breaks a previously usable argument combination for product-absent controls and persistence comparisons.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "A no-product control can reuse the comparison run\u2019s arguments and proceed with the product absent.",
      "id": "R1-F6",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 114
      },
      "priority": "P2",
      "requested_correction": "Make product requirements, summary fields, and staging honor the same no-product decision. Record any comparison archive separately from an installed product.",
      "requested_evidence": "Exercise the no-product path with and without -ProductZip. Show that both produce a no-product summary and stage no product DLL.",
      "title": "A no-product control fails when a comparison ZIP is supplied",
      "trigger": "Invoke the runner with both -NoProduct and -ProductZip."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The validator hashes the path, closes it, then reopens it for inspection. On the bare-DLL route even input_sha256 and dll_sha256 can come from different reads. The report guard compares path strings, so a second filesystem name for the same file can also direct report output onto the validated input.",
      "blocking_rationale": "A validation report can attest to bytes that were never inspected or overwrite the artifact it identifies.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Every digest and metadata field in a report comes from one input snapshot, and writing the report preserves that input.",
      "id": "R1-F7",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 46
      },
      "priority": "P2",
      "requested_correction": "Hash and inspect one immutable snapshot or held read handle. Protect the input through report publication, including filesystem aliases, and use the validated ZIP digest in the package manifest.",
      "requested_evidence": "Use disposable files to verify digest consistency during input replacement and that a report path alias leaves the input intact.",
      "title": "A validation report can combine the hash and metadata of different files",
      "trigger": "Another packaging process replaces the supplied path between reads, or the report path aliases the input."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "AGENTS.md native transaction"
      ],
      "actual": "A copy or report-read error before line 92 leaves the private product directory behind. After Enter-RuntimeLock succeeds, evidence-directory creation at line 102 is outside the run\u2019s finally block. A failure there leaves a lock with no recovery journal, and -RecoverOnly returns when the journal is absent.",
      "blocking_rationale": "An ordinary setup failure can strand the shared runtime lock and prevent later guarded runs.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Every resource acquired by this invocation is covered by cleanup from acquisition onward. A lock retained for restoration has a recoverable transaction.",
      "id": "R1-F8",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 94
      },
      "priority": "P2",
      "requested_correction": "Cover private preparation and post-lock initialization with cleanup. Release this invocation\u2019s lock on pre-transaction failure while retaining the existing recovery behavior for incomplete restoration.",
      "requested_evidence": "In a disposable lab, force a preparation failure and a post-lock evidence-directory failure. Verify the private directory and owned lock are cleaned up and foreign locks are preserved.",
      "title": "Setup failures can leave a private copy or an unrecoverable run lock",
      "trigger": "Copying the product fails, or the evidence directory cannot be created after acquiring the lock."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "ChangedHashIsRejected changes a field in an in-memory reference receipt. It never corrupts a cached file or presents Package.ps1 with different DLL bytes. Initialize-PinnedReferences routes an existing wrong digest through the cache-miss download path and can succeed without reporting the corruption.",
      "blocking_rationale": "Two explicitly required failure boundaries lack an observed result through the real helpers.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "A populated reference cache with incorrect bytes produces a clear refusal, and a stale build receipt fails against a different product DLL.",
      "id": "R1-F9",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 31
      },
      "priority": "P2",
      "requested_correction": "Distinguish a corrupt existing entry from normal first-time acquisition. Exercise the actual reference helper and packaging command with a temporary cache, checkout, DLL, and receipt.",
      "requested_evidence": "Provide the observed corrupt-cache refusal before compilation, the package refusal for a mismatched DLL digest, and a genuine passing control without a provenance override.",
      "title": "Cache corruption and stale DLL receipts lack real negative controls",
      "trigger": "Evaluate the mission\u2019s required rejection cases against the 21 passing provenance checks."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "mission \u00a78"
      ],
      "actual": "The 0.33.4 record contains static metadata resolution only. Historical runs cover 0.31.1, 0.32.4, and 0.33.0 on the released DLL. The report gives the tooling-only change as the reason for skipping native work, and identifies no current fixture, profile-admission, or guard failure for 0.33.4.",
      "blocking_rationale": "The newest selected loader has neither the requested focused observation nor the specific unavailable prerequisite that permits a blocked row.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "UMM 0.33.4 receives a focused guarded check where the disposable route is available, or an explicit NOT RUN/BLOCKED row with the concrete reason.",
      "id": "R1-F10",
      "location": {
        "file": "docs/evidence/umm-0311/api-audit.json",
        "line": 51
      },
      "priority": "P2",
      "requested_correction": "Establish whether the existing disposable copy, fixture, and guarded harness can admit the measured 0.33.4 stack. Run the existing skip and persistence check if available, or record the exact unmet prerequisite.",
      "requested_evidence": "Provide the frozen DLL hash, actual in-process loader and Harmony identities, interaction-boundary and reload observations, and restoration result, or the concrete blocked preflight or admission result.",
      "title": "UMM 0.33.4 has no native result or documented blocker",
      "trigger": "Assess the newest stable loader selected for this mission."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "mission \u00a78"
      ],
      "actual": "The guide linked by README describes the later static audit only through 0.33.2. The 0.33.4 result is discoverable in the evidence directory, whose index explains how to hash exports but gives no invocation for reproducing the API audit.",
      "blocking_rationale": "The mission requires current compatibility documentation that identifies the method, candidate, limits, and reproduction steps for each assessed version.",
      "blocks_readiness": true,
      "category": "required_gap",
      "expected": "A reader can distinguish the declared floor, compiler identity, static results, historical native results, and current native disposition from the main compatibility guide.",
      "id": "R1-F11",
      "location": {
        "file": "docs/COMPATIBILITY.md",
        "line": 17
      },
      "priority": "P2",
      "requested_correction": "Update the current matrix for all four profiles. Link the frozen artifact and audit records, give the audit tool and invocation and the guarded disposable-run command, and identify which combined-stack results are historical.",
      "requested_evidence": "The guide should let a maintainer reproduce the checks and determine exactly what was observed on 0.33.4 without inferring native compatibility from the API report.",
      "title": "The current compatibility guide omits the newest audit and its reproduction steps",
      "trigger": "Follow README\u2019s compatibility link to determine how the current four-profile assessment was performed."
    }
  ],
  "prior_finding_assessments": [],
  "request_id": "ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r01-ec5374",
  "round": 1,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "Cutscene Skip declares UMM 0.31.1 and its recorded production DLL references UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. Packaging now inspects the archive\u2019s actual DLL, compares its digest with the receipted build, and checks the four allowed entries. The ZIP route in the native runner stages a private validated copy.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Final PR acceptance and any eventual merge or release decision."
    ],
    "scope_reviewed": "Final checkpoint for KingmakerSkipCinematic draft PR #3, covering the complete feature diff from 6c1d65a to f7e5387 and this repository\u2019s applicable mission requirements.",
    "unresolved_questions": [
      "Whether the approved disposable environment can currently run the 0.33.4 skip and persistence fixture. No current preflight disposition was supplied."
    ]
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
