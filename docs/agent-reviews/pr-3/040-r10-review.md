<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r10-review part=1/1 sha256=584c11e1629e97c4618c49d0e9c9e65bd1d17bfcbd3013e6247abcb9f05ca26c -->
### Codex GPT-6.2 Astra — review — round 10 — candidate `4f3ef4aa68`

**Decision:** `changes_required` — A relative -ProductZip can select a different archive from the one the caller named. The controller gate passed, but two requested observations are still missing: the production package reaching handoff and cleanup after successful validation followed by a setup failure.

Continuation for Claude

Round 10 uses the last Skip review authorized by OWNER AMENDMENT 1. Record the stop against draft PR #3. If the owner authorizes further review, resolve the supplied ZIP using PowerShell literal-path semantics before copying it. Reuse the production ZIP already created by the package-provenance test for a relative-path handoff check, and compare its ZIP and extracted DLL digests with its package manifest. Exercise the setup-failure cleanup after validation has returned successfully. Keep these checks inside the disposable fixture, preserve the verified refusal and file-sharing controls, and use the configured candidate gate within the authorized allowance.

#### Findings

**R10-F1** · P1 · defect · blocks readiness — A relative product ZIP can resolve to another worktree's archive
- Location: `scripts/runtime/ProductZip.ps1:22`; acceptance: mission §6 supplied-ZIP validation, OWNER AMENDMENT 1 package accuracy and correction of regressions
- Trigger: Invoke the runner directly from a PowerShell session after changing directory and supply a relative -ProductZip.
- Expected: The existence check, copy, validation, and extraction all use the ZIP selected from the caller's PowerShell location.
- Actual: The runner checks the argument with Test-Path -LiteralPath. The new helper then passes the original string to System.IO.File.Copy, which resolves it against the process current directory. The previous Copy-Item -LiteralPath used the caller's PowerShell location. Both handoff fixtures supply absolute paths.
- Why it blocks / does not: A valid relative invocation can fail or silently validate and stage another worktree's same-named ZIP. The recorded digest then identifies the wrong candidate for that run.
- Requested correction: Resolve the supplied literal path to its absolute filesystem path before passing it to File.Copy.
- Requested evidence: Use a relative ZIP name in a disposable fixture whose PowerShell location differs from the process current directory. Verify that the held digest and extracted DLL match the selected package.

**R8-F1** · P2 · evidence_gap · blocks readiness — Only the probe DLL was observed at the ZIP handoff
- Location: `scripts/Test-Provenance.ps1:281`; acceptance: mission §6, R8-F1 requested passing handoff
- Trigger: Inspect the positive control reported as a genuine baseline package handoff.
- Expected: The genuine production ZIP reaches the same preflight and extraction boundary exercised by the refusal case.
- Actual: The positive case packages $genuine, compiled at line 140 from the small Probe class. It compares the extracted DLL with that probe. The separate package-provenance suite builds and validates the production ZIP but never passes it to the handoff helper.
- Why it blocks / does not: The gate establishes that a baseline-compiled fixture reaches extraction. The requested observation for the actual Cutscene Skip package remains outstanding.
- Requested correction: Pass the ZIP from the existing clean production packaging case through Open-ValidatedProductZip and Expand-ValidatedProductZip in the fixture.
- Requested evidence: Record a candidate-bound passing case that matches the held ZIP and extracted production DLL to the package manifest. Retain the specific 0.33.0.0 refusal.

**R9-F3** · P2 · evidence_gap · blocks readiness — The cleanup failure fixture stops before validation succeeds
- Location: `scripts/Test-Provenance.ps1:298`; acceptance: R9-F3 requested post-validation setup failure, OWNER AMENDMENT 1 focused validation
- Trigger: Evaluate cleanup when setup fails after a valid ZIP has been handed to the caller.
- Expected: A fixture admits a valid ZIP, forces a later setup error, and observes the caller's cleanup of the acquired resource.
- Actual: The failure fixture supplies missing-validator.ps1. Open-ValidatedProductZip throws before the validator runs and cleans up internally. The successful case closes its own handle in a test finally. Both cases would pass if the runner's setup catch omitted cleanup.
- Why it blocks / does not: Source inspection shows the original failure site is now covered. The gate still lacks the requested observation that cleanup runs after ownership of the validated archive transfers to the caller.
- Requested correction: Exercise the runner's package cleanup path in a disposable fixture with a setup failure after Open-ValidatedProductZip returns successfully.
- Requested evidence: Show successful validation, the intended later setup error, and an empty fixture work folder or released input handle. Keep the test independent of the native transaction.

#### Prior finding assessments

- **R8-F1** — `fix_rejected` — The negative case now checks the underlying 0.33.0.0 diagnostic. The passing extraction compares a generated Probe DLL with itself after handoff. The production ZIP was observed only at standalone validation.
- **R9-F1** — `fix_verified` — The package tests call the real ZIP helper in fixture-owned directories. Even unexpected admission ends inside the fixture. The runner is read as text, so the test cannot acquire the native lock or launch Kingmaker.
- **R9-F2** — `fix_verified` — The validator reads the copy while a FileShare.Read handle protects it. Hashing and extraction consume that handle. The gate confirmed refusal of writes, rename, and deletion through extraction. R10-F1 concerns selection of the source before that protection begins.
- **R9-F3** — `fix_rejected` — The runner now calls cleanup if evidence or backup directory creation throws. The submitted failure test exercises the helper before handoff, leaving the explicitly requested post-validation failure observation open.

#### Evidence assessment

- **Inspected:** The mission, OWNER AMENDMENT 1, repository instructions, developer report, transcript notice, prior findings ledger, full feature diff, and round-10 commit.; The production project, pin checks, package validator, runner and ZIP helper, both provenance suites, and the compatibility and validation records.
- **Executed verification:** Verified the controller receipt for the exact candidate and its log SHA-256. The test gate exited 0 in 65.9 seconds with 55 unit, 70 provenance, and 33 package-provenance checks passing.; The gate recorded both pinned compiler inputs, a clean production build and package, rejection of the 0.33.0.0 reference, extraction of a baseline-compiled probe, and refusal of write, rename, and delete operations on the held copy.; A read-only Push-Location check confirmed that PowerShell and the process current directory selected different same-named Info.json files with different hashes.; Verified all 11 exported evidence hashes against their Git blobs. The retained build, published-package validation, and four-profile static audit identify the same production DLL digest.
- **Source inspection only:** The runner opens the product ZIP before acquiring its runtime lock, records the held stream's digest, and extracts through that stream.; Evidence and backup directory creation now sit inside the runner's setup try block. Its catch calls Close-ValidatedProductZip. The gate did not execute that catch after successful validation.
- **Required gaps:** Correct relative ZIP selection and demonstrate handoff of the receipt-bound production package.; Demonstrate resource cleanup on a setup failure after the preflight returns a validated archive.
- **Limitations:** The supplied transcript points to the controller receipt. The separate 67-second direct run appears only in the developer report.; Reviewer execution was read-only. Native results for 0.31.1, 0.32.4, and owner 0.33.0 are historical observations on the frozen DLL. The 0.33.4 row has static evidence only.

#### Summary

- **Delivered behavior:** Cutscene Skip declares UMM 0.31.1 and builds against UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. Packaging checks the shipped manifest, DLL references, and build receipt. Once the ZIP helper selects a file, it protects the validated bytes through extraction.
- **Scope reviewed:** The final Cutscene Skip candidate against the amended mission, with correction review focused on ZIP selection, validation, extraction, cleanup, and the evidence for the four pending findings.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Decide whether to authorize further review of draft PR #3 after the ten-submission cap.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: revision 1, sha256 `a2f26787968fd209dccca023305660a73ad7dbba2bbb1c15dff0131891965f67`.

Codex CLI `0.170.0`, thread `01a21854-a540-7560-bdf2-7a7ba8c4543e`, duration 720.1s, response sha256 `b001ccbb9d22832626c9d115dae6d840154482bd90fff8d3f8e37471c53fdee7`, request `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r10-9c4dd7`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "4f3ef4aa68ba70363d8803af70f088911f5475a2",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "A relative -ProductZip can select a different archive from the one the caller named. The controller gate passed, but two requested observations are still missing: the production package reaching handoff and cleanup after successful validation followed by a setup failure.\n\nContinuation for Claude\n\nRound 10 uses the last Skip review authorized by OWNER AMENDMENT 1. Record the stop against draft PR #3. If the owner authorizes further review, resolve the supplied ZIP using PowerShell literal-path semantics before copying it. Reuse the production ZIP already created by the package-provenance test for a relative-path handoff check, and compare its ZIP and extracted DLL digests with its package manifest. Exercise the setup-failure cleanup after validation has returned successfully. Keep these checks inside the disposable fixture, preserve the verified refusal and file-sharing controls, and use the configured candidate gate within the authorized allowance.",
  "evidence_assessment": {
    "executed_verification": [
      "Verified the controller receipt for the exact candidate and its log SHA-256. The test gate exited 0 in 65.9 seconds with 55 unit, 70 provenance, and 33 package-provenance checks passing.",
      "The gate recorded both pinned compiler inputs, a clean production build and package, rejection of the 0.33.0.0 reference, extraction of a baseline-compiled probe, and refusal of write, rename, and delete operations on the held copy.",
      "A read-only Push-Location check confirmed that PowerShell and the process current directory selected different same-named Info.json files with different hashes.",
      "Verified all 11 exported evidence hashes against their Git blobs. The retained build, published-package validation, and four-profile static audit identify the same production DLL digest."
    ],
    "inspected": [
      "The mission, OWNER AMENDMENT 1, repository instructions, developer report, transcript notice, prior findings ledger, full feature diff, and round-10 commit.",
      "The production project, pin checks, package validator, runner and ZIP helper, both provenance suites, and the compatibility and validation records."
    ],
    "limitations": [
      "The supplied transcript points to the controller receipt. The separate 67-second direct run appears only in the developer report.",
      "Reviewer execution was read-only. Native results for 0.31.1, 0.32.4, and owner 0.33.0 are historical observations on the frozen DLL. The 0.33.4 row has static evidence only."
    ],
    "required_gaps": [
      "Correct relative ZIP selection and demonstrate handoff of the receipt-bound production package.",
      "Demonstrate resource cleanup on a setup failure after the preflight returns a validated archive."
    ],
    "source_inspection_only": [
      "The runner opens the product ZIP before acquiring its runtime lock, records the held stream's digest, and extracts through that stream.",
      "Evidence and backup directory creation now sit inside the runner's setup try block. Its catch calls Close-ValidatedProductZip. The gate did not execute that catch after successful validation."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "mission \u00a76 supplied-ZIP validation",
        "OWNER AMENDMENT 1 package accuracy and correction of regressions"
      ],
      "actual": "The runner checks the argument with Test-Path -LiteralPath. The new helper then passes the original string to System.IO.File.Copy, which resolves it against the process current directory. The previous Copy-Item -LiteralPath used the caller's PowerShell location. Both handoff fixtures supply absolute paths.",
      "blocking_rationale": "A valid relative invocation can fail or silently validate and stage another worktree's same-named ZIP. The recorded digest then identifies the wrong candidate for that run.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The existence check, copy, validation, and extraction all use the ZIP selected from the caller's PowerShell location.",
      "id": "R10-F1",
      "location": {
        "file": "scripts/runtime/ProductZip.ps1",
        "line": 22
      },
      "priority": "P1",
      "requested_correction": "Resolve the supplied literal path to its absolute filesystem path before passing it to File.Copy.",
      "requested_evidence": "Use a relative ZIP name in a disposable fixture whose PowerShell location differs from the process current directory. Verify that the held digest and extracted DLL match the selected package.",
      "title": "A relative product ZIP can resolve to another worktree's archive",
      "trigger": "Invoke the runner directly from a PowerShell session after changing directory and supply a relative -ProductZip."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "R8-F1 requested passing handoff"
      ],
      "actual": "The positive case packages $genuine, compiled at line 140 from the small Probe class. It compares the extracted DLL with that probe. The separate package-provenance suite builds and validates the production ZIP but never passes it to the handoff helper.",
      "blocking_rationale": "The gate establishes that a baseline-compiled fixture reaches extraction. The requested observation for the actual Cutscene Skip package remains outstanding.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "The genuine production ZIP reaches the same preflight and extraction boundary exercised by the refusal case.",
      "id": "R8-F1",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 281
      },
      "priority": "P2",
      "requested_correction": "Pass the ZIP from the existing clean production packaging case through Open-ValidatedProductZip and Expand-ValidatedProductZip in the fixture.",
      "requested_evidence": "Record a candidate-bound passing case that matches the held ZIP and extracted production DLL to the package manifest. Retain the specific 0.33.0.0 refusal.",
      "title": "Only the probe DLL was observed at the ZIP handoff",
      "trigger": "Inspect the positive control reported as a genuine baseline package handoff."
    },
    {
      "acceptance_ids": [
        "R9-F3 requested post-validation setup failure",
        "OWNER AMENDMENT 1 focused validation"
      ],
      "actual": "The failure fixture supplies missing-validator.ps1. Open-ValidatedProductZip throws before the validator runs and cleans up internally. The successful case closes its own handle in a test finally. Both cases would pass if the runner's setup catch omitted cleanup.",
      "blocking_rationale": "Source inspection shows the original failure site is now covered. The gate still lacks the requested observation that cleanup runs after ownership of the validated archive transfers to the caller.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "A fixture admits a valid ZIP, forces a later setup error, and observes the caller's cleanup of the acquired resource.",
      "id": "R9-F3",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 298
      },
      "priority": "P2",
      "requested_correction": "Exercise the runner's package cleanup path in a disposable fixture with a setup failure after Open-ValidatedProductZip returns successfully.",
      "requested_evidence": "Show successful validation, the intended later setup error, and an empty fixture work folder or released input handle. Keep the test independent of the native transaction.",
      "title": "The cleanup failure fixture stops before validation succeeds",
      "trigger": "Evaluate cleanup when setup fails after a valid ZIP has been handed to the caller."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_rejected",
      "finding_id": "R8-F1",
      "rationale": "The negative case now checks the underlying 0.33.0.0 diagnostic. The passing extraction compares a generated Probe DLL with itself after handoff. The production ZIP was observed only at standalone validation."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R9-F1",
      "rationale": "The package tests call the real ZIP helper in fixture-owned directories. Even unexpected admission ends inside the fixture. The runner is read as text, so the test cannot acquire the native lock or launch Kingmaker."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R9-F2",
      "rationale": "The validator reads the copy while a FileShare.Read handle protects it. Hashing and extraction consume that handle. The gate confirmed refusal of writes, rename, and deletion through extraction. R10-F1 concerns selection of the source before that protection begins."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R9-F3",
      "rationale": "The runner now calls cleanup if evidence or backup directory creation throws. The submitted failure test exercises the helper before handoff, leaving the explicitly requested post-validation failure observation open."
    }
  ],
  "request_id": "ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r10-9c4dd7",
  "round": 10,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "Cutscene Skip declares UMM 0.31.1 and builds against UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. Packaging checks the shipped manifest, DLL references, and build receipt. Once the ZIP helper selects a file, it protects the validated bytes through extraction.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Decide whether to authorize further review of draft PR #3 after the ten-submission cap."
    ],
    "scope_reviewed": "The final Cutscene Skip candidate against the amended mission, with correction review focused on ZIP selection, validation, extraction, cleanup, and the evidence for the four pending findings.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
