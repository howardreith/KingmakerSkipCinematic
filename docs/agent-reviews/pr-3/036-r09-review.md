<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r09-review part=1/1 sha256=79b250fe56c5663cba3fc653d7daffec64200c1d2deb0ada9ba94e21e18cfad3 -->
### Codex GPT-6.2 Astra — review — round 9 — candidate `8d2cfd38d1`

**Decision:** `changes_required` — The candidate gate passed, and the duplicate-manifest correction is verified. The supplied-ZIP path now rejects the tested invalid archive, but the gate lacks a successful runner handoff and can enter the owner's native installation if rejection regresses. The runner also leaves the validated ZIP open to modification before extraction and can leave its temporary copy behind on setup failure.

## Continuation for Claude

Keep the correction within the product-ZIP preflight and its tests. Keep the admitted bytes stable from validation through extraction and cover the lifetime of any temporary copy. Use a disposable fixture with a hard stop before native locking or staging. Exercise the exact UMM 0.33.0.0 mismatch and a genuine baseline ZIP through the same preflight. Preserve the comparison-only `-NoProduct` route and existing runtime guards. Record the observations and rerun the configured `test` gate within the existing allowance.

#### Findings

**R9-F1** · P1 · defect · blocks readiness — The package gate can enter a live native run when its refusal regresses
- Location: `scripts/Test-Provenance.ps1:282`; acceptance: mission §6, OWNER AMENDMENT 1 scope freeze and validation allowance
- Trigger: Run `scripts/Test.ps1` on a prepared lab when the expected product-ZIP rejection fails.
- Expected: Both acceptance and rejection end at a fixture-owned boundary before any native lock, staging or launch.
- Actual: The test invokes the real runner with `chain-lifecycle.json`, the worktree's game configuration and the default owner installation. It reads the user's Steam registry before ZIP validation. On a prepared lab with a built harness and clear guards, an unexpected admission can move the owner's Mods directory and launch Kingmaker before the test checks its result. The lock check and shared TEMP file counts happen after the child exits.
- Why it blocks / does not: A failure of the condition under test can turn the required package gate into a native transaction against the owner's installation.
- Requested correction: Exercise the real package preflight in a disposable fixture that cannot proceed into the native transaction. Confine its temporary-file and lock observations to that fixture.
- Requested evidence: Show that even a successfully admitted ZIP reaches only the fixture handoff and that the check runs independently of the owner's Steam registry and runtime lock.

**R8-F1** · P2 · evidence_gap · blocks readiness — A genuine baseline ZIP has no observed runner handoff
- Location: `scripts/Test-Provenance.ps1:285`; acceptance: mission §6, R8-F1 requested evidence
- Trigger: Verify the product-present `-ProductZip` procedure with the round-9 gate.
- Expected: The same runner preflight rejects the newer-reference ZIP for its UMM identity and hands a genuine baseline ZIP to the next step.
- Actual: The runner is invoked only with `newer-umm.zip`. Its assertion accepts the generic standalone-validation failure message. Genuine ZIP controls invoke the validator separately. A runner invocation that fails validation for every ZIP would pass this test.
- Why it blocks / does not: The requested passing control at the installation handoff is missing, and the negative runner assertion cannot distinguish the intended metadata mismatch from an unrelated validator error.
- Requested correction: Add the passing baseline control to the isolated runner fixture and assert the underlying reference diagnostic in the refusal case.
- Requested evidence: A candidate-bound gate showing the 0.33.0.0 mismatch before handoff and the genuine 0.31.1.0 package reaching handoff before any native transaction.

**R9-F2** · P2 · defect · blocks readiness — Extraction reopens the validated ZIP without protecting its contents
- Location: `scripts/runtime/Invoke-NativeRun.ps1:166`; acceptance: mission §6, OWNER AMENDMENT 1 package accuracy
- Trigger: The prepared ZIP changes after the standalone validator returns and before extraction.
- Expected: Validation, the recorded digest and extraction all refer to the same archive bytes.
- Actual: The validator closes its snapshot and exits. The runner hashes the temporary pathname at line 106 and reopens it for `Expand-Archive` at line 166. It holds no handle preventing writes or replacement and does not compare extraction with the validator's digest. The earlier replacement fixtures exercised the implementation removed in round 8.
- Why it blocks / does not: A changed prepared archive can stage a manifest or file set that never passed standalone validation. A change after the summary hash is taken also makes the recorded ZIP identity inaccurate.
- Requested correction: Keep the input protected against writes and replacement through extraction, or consume one verified snapshot for both validation and handoff.
- Requested evidence: In a disposable fixture, confirm that a change to the prepared file cannot change the manifest or file set handed to staging. Retain the passing baseline control.

**R9-F3** · P2 · defect · blocks readiness — A setup error can strand the preflight's temporary ZIP
- Location: `scripts/runtime/Invoke-NativeRun.ps1:94`; acceptance: OWNER AMENDMENT 1 correction of mission-introduced regressions
- Trigger: A valid ZIP passes preflight and the runner cannot create its evidence or backup directory.
- Expected: Every handled setup failure releases the package resource acquired by this invocation.
- Actual: The preflight catch ends after lock acquisition. Evidence and backup directory creation occurs at line 94, before the `try` whose `finally` removes the ZIP. If directory creation throws, the newly copied `kmcs-validated-product-*.zip` remains in TEMP.
- Why it blocks / does not: An ordinary setup error leaks a resource introduced by this correction and contradicts the report's claim that the copy is removed on every outcome.
- Requested correction: Cover the temporary copy from creation through handoff with one cleanup scope, or use a protected input handle that eliminates the copy.
- Requested evidence: Force a post-validation setup error in a disposable fixture and verify that its temporary ZIP is gone or its input handle has been released.

#### Prior finding assessments

- **R6-F4** — `fix_verified` — The scanner rejects a single quote outside a double-quoted string before enclosed punctuation can alter its depth. The candidate gate confirms the specific syntax refusal on both manifest routes, rejection of double-quoted duplicate fields and acceptance of the genuine display name containing an apostrophe.
- **R8-F1** — `fix_rejected` — The missing preflight call has been restored, and the invalid fixture reached the runner's refusal. The requested verification is incomplete because the runner assertion checks only a generic error and no genuine baseline ZIP was observed reaching its handoff.

#### Evidence assessment

- **Inspected:** The mission, OWNER AMENDMENT 1, repository instructions, developer report, prior ledger, full 3,131-line feature diff and four-file correction since 8cc7ab5.; The production project and compiler targets, package and receipt checks, manifest scanner, runner preflight and extraction, test fixtures, compatibility records and candidate-bound gate log.
- **Executed verification:** Verified HEAD, merge base, mission and amendment digests. The gate log SHA-256 matched its controller receipt. `git diff --check` passed.; The controller ran `scripts/Test.ps1` at the exact candidate. It exited 0 in 70.3 seconds with 55/55 unit, 65/65 provenance and 33/33 package-provenance cases passing.; The log confirms both pinned compiler-input hashes, a genuine build and package without an override, rejection of a substituted cache file and rejection of a DLL that differed from its receipt.; Both single-quoted-brace fixtures passed on the ZIP and bare-manifest routes. The gate also recorded the standalone UMM 0.33.0.0 mismatch, genuine package acceptance and the runner's invalid-ZIP refusal.
- **Source inspection only:** The product-present branch validates before locking. The `-NoProduct` branch keeps the supplied ZIP for comparison. The only current gate invocation of the runner uses the invalid ZIP.; The unprotected interval before extraction, the temporary-copy cleanup gap and the test's route into a native transaction were identified by tracing the candidate source.; The archived audit records static resolution on 0.31.1, 0.32.4, owner 0.33.0 and 0.33.4 for DLL SHA-256 a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba. The candidate gate records the same frozen DLL hash.
- **Required gaps:** Observe a genuine baseline ZIP reaching the runner's post-validation handoff and the mismatched ZIP failing for its specific reference error in an isolated fixture.; Verify that the bytes handed to extraction remain the validated bytes and that a setup error releases the newly acquired package resource.
- **Limitations:** The review used a read-only snapshot. The shell's constrained language mode prevented an additional in-memory manifest-helper probe. The executed manifest results come from the controller gate.; The foreground transcript is withheld. The controller receipt confirms the required gate independently of the developer's account of the direct reruns.; Native gameplay and combined-stack checks were not run for this correction. The 0.33.4 evidence is static only.

#### Summary

- **Delivered behavior:** Cutscene Skip declares UMM 0.31.1 and builds against UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. The packaged-DLL reference checks pass, and the manifest scanner rejects the reported ambiguous declaration on both routes.
- **Scope reviewed:** Final correction review of KingmakerSkipCinematic PR #3 under OWNER AMENDMENT 1, including both pending findings and the directly affected package, runner and test paths.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Decide whether to accept draft PR #3 after the package-path corrections receive a current controller handoff.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: revision 1, sha256 `a2f26787968fd209dccca023305660a73ad7dbba2bbb1c15dff0131891965f67`.

Codex CLI `0.170.0`, thread `01a21842-fc6b-7571-8d1d-bee002594367`, duration 837.0s, response sha256 `b7c05e378577d39b0afdf6f8f736ca59998618f854d3cc8a8445935543df4009`, request `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r09-390b03`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "8d2cfd38d1d86d604bfe495af6a781a600ade033",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The candidate gate passed, and the duplicate-manifest correction is verified. The supplied-ZIP path now rejects the tested invalid archive, but the gate lacks a successful runner handoff and can enter the owner's native installation if rejection regresses. The runner also leaves the validated ZIP open to modification before extraction and can leave its temporary copy behind on setup failure.\n\n## Continuation for Claude\n\nKeep the correction within the product-ZIP preflight and its tests. Keep the admitted bytes stable from validation through extraction and cover the lifetime of any temporary copy. Use a disposable fixture with a hard stop before native locking or staging. Exercise the exact UMM 0.33.0.0 mismatch and a genuine baseline ZIP through the same preflight. Preserve the comparison-only `-NoProduct` route and existing runtime guards. Record the observations and rerun the configured `test` gate within the existing allowance.",
  "evidence_assessment": {
    "executed_verification": [
      "Verified HEAD, merge base, mission and amendment digests. The gate log SHA-256 matched its controller receipt. `git diff --check` passed.",
      "The controller ran `scripts/Test.ps1` at the exact candidate. It exited 0 in 70.3 seconds with 55/55 unit, 65/65 provenance and 33/33 package-provenance cases passing.",
      "The log confirms both pinned compiler-input hashes, a genuine build and package without an override, rejection of a substituted cache file and rejection of a DLL that differed from its receipt.",
      "Both single-quoted-brace fixtures passed on the ZIP and bare-manifest routes. The gate also recorded the standalone UMM 0.33.0.0 mismatch, genuine package acceptance and the runner's invalid-ZIP refusal."
    ],
    "inspected": [
      "The mission, OWNER AMENDMENT 1, repository instructions, developer report, prior ledger, full 3,131-line feature diff and four-file correction since 8cc7ab5.",
      "The production project and compiler targets, package and receipt checks, manifest scanner, runner preflight and extraction, test fixtures, compatibility records and candidate-bound gate log."
    ],
    "limitations": [
      "The review used a read-only snapshot. The shell's constrained language mode prevented an additional in-memory manifest-helper probe. The executed manifest results come from the controller gate.",
      "The foreground transcript is withheld. The controller receipt confirms the required gate independently of the developer's account of the direct reruns.",
      "Native gameplay and combined-stack checks were not run for this correction. The 0.33.4 evidence is static only."
    ],
    "required_gaps": [
      "Observe a genuine baseline ZIP reaching the runner's post-validation handoff and the mismatched ZIP failing for its specific reference error in an isolated fixture.",
      "Verify that the bytes handed to extraction remain the validated bytes and that a setup error releases the newly acquired package resource."
    ],
    "source_inspection_only": [
      "The product-present branch validates before locking. The `-NoProduct` branch keeps the supplied ZIP for comparison. The only current gate invocation of the runner uses the invalid ZIP.",
      "The unprotected interval before extraction, the temporary-copy cleanup gap and the test's route into a native transaction were identified by tracing the candidate source.",
      "The archived audit records static resolution on 0.31.1, 0.32.4, owner 0.33.0 and 0.33.4 for DLL SHA-256 a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba. The candidate gate records the same frozen DLL hash."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "mission \u00a76",
        "OWNER AMENDMENT 1 scope freeze and validation allowance"
      ],
      "actual": "The test invokes the real runner with `chain-lifecycle.json`, the worktree's game configuration and the default owner installation. It reads the user's Steam registry before ZIP validation. On a prepared lab with a built harness and clear guards, an unexpected admission can move the owner's Mods directory and launch Kingmaker before the test checks its result. The lock check and shared TEMP file counts happen after the child exits.",
      "blocking_rationale": "A failure of the condition under test can turn the required package gate into a native transaction against the owner's installation.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Both acceptance and rejection end at a fixture-owned boundary before any native lock, staging or launch.",
      "id": "R9-F1",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 282
      },
      "priority": "P1",
      "requested_correction": "Exercise the real package preflight in a disposable fixture that cannot proceed into the native transaction. Confine its temporary-file and lock observations to that fixture.",
      "requested_evidence": "Show that even a successfully admitted ZIP reaches only the fixture handoff and that the check runs independently of the owner's Steam registry and runtime lock.",
      "title": "The package gate can enter a live native run when its refusal regresses",
      "trigger": "Run `scripts/Test.ps1` on a prepared lab when the expected product-ZIP rejection fails."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "R8-F1 requested evidence"
      ],
      "actual": "The runner is invoked only with `newer-umm.zip`. Its assertion accepts the generic standalone-validation failure message. Genuine ZIP controls invoke the validator separately. A runner invocation that fails validation for every ZIP would pass this test.",
      "blocking_rationale": "The requested passing control at the installation handoff is missing, and the negative runner assertion cannot distinguish the intended metadata mismatch from an unrelated validator error.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "The same runner preflight rejects the newer-reference ZIP for its UMM identity and hands a genuine baseline ZIP to the next step.",
      "id": "R8-F1",
      "location": {
        "file": "scripts/Test-Provenance.ps1",
        "line": 285
      },
      "priority": "P2",
      "requested_correction": "Add the passing baseline control to the isolated runner fixture and assert the underlying reference diagnostic in the refusal case.",
      "requested_evidence": "A candidate-bound gate showing the 0.33.0.0 mismatch before handoff and the genuine 0.31.1.0 package reaching handoff before any native transaction.",
      "title": "A genuine baseline ZIP has no observed runner handoff",
      "trigger": "Verify the product-present `-ProductZip` procedure with the round-9 gate."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "OWNER AMENDMENT 1 package accuracy"
      ],
      "actual": "The validator closes its snapshot and exits. The runner hashes the temporary pathname at line 106 and reopens it for `Expand-Archive` at line 166. It holds no handle preventing writes or replacement and does not compare extraction with the validator's digest. The earlier replacement fixtures exercised the implementation removed in round 8.",
      "blocking_rationale": "A changed prepared archive can stage a manifest or file set that never passed standalone validation. A change after the summary hash is taken also makes the recorded ZIP identity inaccurate.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Validation, the recorded digest and extraction all refer to the same archive bytes.",
      "id": "R9-F2",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 166
      },
      "priority": "P2",
      "requested_correction": "Keep the input protected against writes and replacement through extraction, or consume one verified snapshot for both validation and handoff.",
      "requested_evidence": "In a disposable fixture, confirm that a change to the prepared file cannot change the manifest or file set handed to staging. Retain the passing baseline control.",
      "title": "Extraction reopens the validated ZIP without protecting its contents",
      "trigger": "The prepared ZIP changes after the standalone validator returns and before extraction."
    },
    {
      "acceptance_ids": [
        "OWNER AMENDMENT 1 correction of mission-introduced regressions"
      ],
      "actual": "The preflight catch ends after lock acquisition. Evidence and backup directory creation occurs at line 94, before the `try` whose `finally` removes the ZIP. If directory creation throws, the newly copied `kmcs-validated-product-*.zip` remains in TEMP.",
      "blocking_rationale": "An ordinary setup error leaks a resource introduced by this correction and contradicts the report's claim that the copy is removed on every outcome.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Every handled setup failure releases the package resource acquired by this invocation.",
      "id": "R9-F3",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 94
      },
      "priority": "P2",
      "requested_correction": "Cover the temporary copy from creation through handoff with one cleanup scope, or use a protected input handle that eliminates the copy.",
      "requested_evidence": "Force a post-validation setup error in a disposable fixture and verify that its temporary ZIP is gone or its input handle has been released.",
      "title": "A setup error can strand the preflight's temporary ZIP",
      "trigger": "A valid ZIP passes preflight and the runner cannot create its evidence or backup directory."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F4",
      "rationale": "The scanner rejects a single quote outside a double-quoted string before enclosed punctuation can alter its depth. The candidate gate confirms the specific syntax refusal on both manifest routes, rejection of double-quoted duplicate fields and acceptance of the genuine display name containing an apostrophe."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R8-F1",
      "rationale": "The missing preflight call has been restored, and the invalid fixture reached the runner's refusal. The requested verification is incomplete because the runner assertion checks only a generic error and no genuine baseline ZIP was observed reaching its handoff."
    }
  ],
  "request_id": "ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r09-390b03",
  "round": 9,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "Cutscene Skip declares UMM 0.31.1 and builds against UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. The packaged-DLL reference checks pass, and the manifest scanner rejects the reported ambiguous declaration on both routes.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Decide whether to accept draft PR #3 after the package-path corrections receive a current controller handoff."
    ],
    "scope_reviewed": "Final correction review of KingmakerSkipCinematic PR #3 under OWNER AMENDMENT 1, including both pending findings and the directly affected package, runner and test paths.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
