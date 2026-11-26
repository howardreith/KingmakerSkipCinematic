<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r08-review part=1/1 sha256=13a30288c37620b9f29fccad1a5be1e05eb201ea4dbb3a03288351e9507c539b -->
### Codex GPT-6.2 Astra — review — round 8 — candidate `8cc7ab5937`

**Decision:** `changes_required` — The candidate passed the controller gate and fixed the legacy receipt check. Two package issues remain. The manifest validator can still certify conflicting loader minimums, and the documented `-ProductZip` installation path can stage a supplied archive without checking its DLL references.

Continuation for Claude

Use one parsing rule for manifest strings and member names on the ZIP and bare-DLL paths. Add a regression case where a brace inside a single-quoted value precedes conflicting declarations, alongside a genuine passing control. For supplied ZIPs, make successful standalone validation of the exact archive part of the documented installation procedure before staging. Keep that correction limited to product-present ZIP admission and preserve the base runner’s lock, journal, and recovery protocol. Exercise both corrections with temporary files, record the specific refusal reasons, and run the configured test gate on the corrected commit within the existing allowance.

#### Findings

**R6-F4** · P2 · defect · blocks readiness — A brace inside a single-quoted value can hide a duplicate manifest field
- Location: `scripts/Validate-Package.ps1:98`; acceptance: mission §5, mission §6
- Trigger: A supplied Info.json contains a single-quoted display value with a literal opening brace, followed by conflicting ManagerVersion declarations whose final value is 0.31.1.
- Expected: Every accepted manifest has one unambiguous declaration of each required member. Punctuation inside a string has no effect on which declarations are counted.
- Actual: The scanner skips double-quoted strings only. It treats a brace inside a single-quoted value as object structure and can consequently skip an earlier ManagerVersion declaration. Windows PowerShell accepts that value syntax and keeps the last ManagerVersion. The post-conversion identity check then sees one correctly named property with the expected value. Both manifest routes use these steps.
- Why it blocks / does not: The standalone validator can report success for an archive or bare manifest containing conflicting loader minimums. This contradicts the package contract documented in `docs/VALIDATION.md`.
- Requested correction: Use consistent token handling for counting and decoding. Reject unsupported string syntax wherever a value or member name can occur, or use a reader that exposes duplicate declarations before conversion collapses them.
- Requested evidence: Exercise the ZIP and bare-manifest paths with a single-quoted text value containing a brace before conflicting required fields. Assert the specific syntax or duplicate-declaration refusal. Retain a passing control with punctuation inside an ordinary double-quoted display name.

**R8-F1** · P2 · required_gap · blocks readiness — The supplied-ZIP installation path bypasses standalone validation
- Location: `scripts/runtime/Invoke-NativeRun.ps1:147`; acceptance: mission §6, OWNER AMENDMENT 1 package scope
- Trigger: Use the documented `-ProductZip` route with an archive acquired independently of `Package.ps1`.
- Expected: The supported procedure for installing a supplied ZIP checks the actual packaged DLL references with the standalone validator and stops before staging if validation fails.
- Actual: Round 8 removed the pre-install validator call. The runner checks that the ZIP exists, records its hash, expands it into Mods, and then hashes the extracted DLL. The README provides a separate manual validation command, but the `-ProductZip` invocation documented in `docs/COMPATIBILITY.md` proceeds directly to extraction.
- Why it blocks / does not: An ordinary supplied archive can install a DLL that targets a newer UMM while declaring the baseline minimum. This is a missing package check on a documented installation path and requires no archive replacement or concurrent operation to trigger.
- Requested correction: Make successful validation of the exact supplied archive a prerequisite of the documented product-present ZIP installation path. A narrow preflight or a checked entry point around the base runner is sufficient. Preserve the comparison-only use of a ZIP with `-NoProduct`.
- Requested evidence: Use a temporary four-file ZIP declaring 0.31.1 whose DLL references UMM 0.33.0. Show that the supplied-ZIP procedure stops on the reference mismatch before staging, and that a genuine baseline ZIP reaches the handoff. This can be checked before any native transaction.

#### Prior finding assessments

- **R5-F3** — `fix_verified` — OWNER AMENDMENT 1 permits removal of unnecessary mission-added recovery machinery. The two-stage liveness check and journal handoff are gone, and Git confirms the runner matches the merge base. This verifies removal of the PR-specific recovery change.
- **R6-F1** — `fix_verified` — Package.ps1 now checks recorded product changes after selecting and type-checking either dirty flag. The gate confirms the alternate DLL’s matching legacy receipt was refused for its contradictory change list and the genuine clean legacy receipt packaged successfully.
- **R6-F2** — `fix_verified` — The mission-added directory publication and cleanup in NativeProduct.ps1 were removed under OWNER AMENDMENT 1. Main’s existing path-based rollback over `staged` is still present. The verified correction is removal of the added staging path and its ownership claim.
- **R6-F4** — `fix_rejected` — The new guard catches single-quoted and unquoted names while the scanner is at depth one. An accepted single-quoted value can still change the scanner’s apparent depth and hide a conflicting declaration on either route.
- **R7-F1** — `fix_verified` — The restored reader consumes the `staged` member written by main. The `created`-only fallback that treated an older journal as owning zero paths was removed.
- **R7-F2** — `fix_verified` — The runner records `staged` before directory creation or ZIP extraction. Removing the later `created` callback eliminates the reported interruption window between creation and that required record.
- **R7-F3** — `fix_verified` — The restored writer uses Windows PowerShell’s `Set-Content -Encoding UTF8`, which emits the byte-order mark recognized by the existing reader. The mission-added BOM-less writer was removed.
- **R7-F4** — `fix_verified` — The validation record removes both conflicting held-lock outcomes and the unsupported byte-preservation claim. It attributes the earlier suite to fd1ac03 and identifies the runner cases removed in round 8.

#### Evidence assessment

- **Inspected:** The complete feature diff, round-8 correction diff, eight pending ledger entries, developer report, transcript notice, controller gate receipt, AGENTS.md, and CLAUDE.md.; The shipping manifest, reference pins, production MSBuild targets, build and package scripts, standalone validator, affected test fixtures, restored runner, compatibility guide, validation record, and artifact evidence.
- **Executed verification:** The controller receipt records `scripts/Test.ps1` exiting 0 on 8cc7ab59373b651278f2de15a1011a65d99f3650 in 80.3 seconds with the worktree unchanged. Its output tail shows 33 package-provenance cases with zero failures, including rejection of the contradictory legacy receipt, acceptance of the genuine legacy receipt, and verification of both pinned compiler inputs.; In a read-only Windows PowerShell 5.1.19041.7844 check, `ConvertFrom-Json` accepted single-quoted text values containing braces and two declarations of ManagerVersion. It returned the final value, 0.31.1, alongside the expected product identity.; Git confirmed that the complete `scripts/runtime` tree is identical at the merge base and candidate, and that 8cc7ab5 changes only `docs/VALIDATION.md` after a7a33bc. The recorded production build inputs are unchanged from 9f35cb2.; Verified the supplied mission and amendment hashes and the indexed hashes of all nine JSON and Markdown evidence exports. The build receipt, package records, and static audit identify the same DLL SHA-256, a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba.
- **Source inspection only:** Traced the shared declaration scanner and identity check on both manifest routes. The decoder observation was executed in memory. The resulting ZIP and bare-DLL admission behavior was established from source.; Traced `-ProductZip` from its existence check through hashing and extraction. Reviewed the removal of the mission-added recovery paths by comparison with the merge base.
- **Required gaps:** Show that both manifest routes reject the conflicting declarations described in R6-F4 for the intended reason and accept the genuine controls.; Show that the supported supplied-ZIP installation procedure refuses an incompatible packaged DLL before staging and admits the genuine archive.
- **Limitations:** The full foreground transcript and gate log were withheld. The receipt confirms the complete gate passed. The reported 55 unit and 62 provenance totals precede the retained output tail, and the separate direct run at a7a33bc has no supplied controller receipt.; Reviewer checks were read-only. The static audit covers UMM 0.31.1, 0.32.4, owner-installed 0.33.0, and 0.33.4. Native and combined-stack results for the first three versions are historical observations on the frozen DLL. The 0.33.4 row has static evidence only and lacks a reviewed native profile.

#### Summary

- **Delivered behavior:** Cutscene Skip declares UMM 0.31.1. The wrapper and direct production builds verify UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. Packaging binds the DLL to its build receipt and inspects the four-entry ZIP. Modern and legacy receipts now receive the same clean-input consistency check.
- **Scope reviewed:** Cutscene Skip PR #3 at 8cc7ab5 against merge base 6c1d65a, including the corrections since 45f5c20 and the scope freeze in OWNER AMENDMENT 1.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Disposition of draft PR #3 after the two package findings clear independent review.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: revision 1, sha256 `a2f26787968fd209dccca023305660a73ad7dbba2bbb1c15dff0131891965f67`.

Codex CLI `0.170.0`, thread `01a2182f-c516-7090-a42b-cc3771b6b36d`, duration 882.2s, response sha256 `84b1a894363b27743d50dc4aa8b49a83d76a515a78eb69ae7654a0bac99aaf2d`, request `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r08-30263f`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "8cc7ab59373b651278f2de15a1011a65d99f3650",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The candidate passed the controller gate and fixed the legacy receipt check. Two package issues remain. The manifest validator can still certify conflicting loader minimums, and the documented `-ProductZip` installation path can stage a supplied archive without checking its DLL references.\n\nContinuation for Claude\n\nUse one parsing rule for manifest strings and member names on the ZIP and bare-DLL paths. Add a regression case where a brace inside a single-quoted value precedes conflicting declarations, alongside a genuine passing control. For supplied ZIPs, make successful standalone validation of the exact archive part of the documented installation procedure before staging. Keep that correction limited to product-present ZIP admission and preserve the base runner\u2019s lock, journal, and recovery protocol. Exercise both corrections with temporary files, record the specific refusal reasons, and run the configured test gate on the corrected commit within the existing allowance.",
  "evidence_assessment": {
    "executed_verification": [
      "The controller receipt records `scripts/Test.ps1` exiting 0 on 8cc7ab59373b651278f2de15a1011a65d99f3650 in 80.3 seconds with the worktree unchanged. Its output tail shows 33 package-provenance cases with zero failures, including rejection of the contradictory legacy receipt, acceptance of the genuine legacy receipt, and verification of both pinned compiler inputs.",
      "In a read-only Windows PowerShell 5.1.19041.7844 check, `ConvertFrom-Json` accepted single-quoted text values containing braces and two declarations of ManagerVersion. It returned the final value, 0.31.1, alongside the expected product identity.",
      "Git confirmed that the complete `scripts/runtime` tree is identical at the merge base and candidate, and that 8cc7ab5 changes only `docs/VALIDATION.md` after a7a33bc. The recorded production build inputs are unchanged from 9f35cb2.",
      "Verified the supplied mission and amendment hashes and the indexed hashes of all nine JSON and Markdown evidence exports. The build receipt, package records, and static audit identify the same DLL SHA-256, a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba."
    ],
    "inspected": [
      "The complete feature diff, round-8 correction diff, eight pending ledger entries, developer report, transcript notice, controller gate receipt, AGENTS.md, and CLAUDE.md.",
      "The shipping manifest, reference pins, production MSBuild targets, build and package scripts, standalone validator, affected test fixtures, restored runner, compatibility guide, validation record, and artifact evidence."
    ],
    "limitations": [
      "The full foreground transcript and gate log were withheld. The receipt confirms the complete gate passed. The reported 55 unit and 62 provenance totals precede the retained output tail, and the separate direct run at a7a33bc has no supplied controller receipt.",
      "Reviewer checks were read-only. The static audit covers UMM 0.31.1, 0.32.4, owner-installed 0.33.0, and 0.33.4. Native and combined-stack results for the first three versions are historical observations on the frozen DLL. The 0.33.4 row has static evidence only and lacks a reviewed native profile."
    ],
    "required_gaps": [
      "Show that both manifest routes reject the conflicting declarations described in R6-F4 for the intended reason and accept the genuine controls.",
      "Show that the supported supplied-ZIP installation procedure refuses an incompatible packaged DLL before staging and admits the genuine archive."
    ],
    "source_inspection_only": [
      "Traced the shared declaration scanner and identity check on both manifest routes. The decoder observation was executed in memory. The resulting ZIP and bare-DLL admission behavior was established from source.",
      "Traced `-ProductZip` from its existence check through hashing and extraction. Reviewed the removal of the mission-added recovery paths by comparison with the merge base."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The scanner skips double-quoted strings only. It treats a brace inside a single-quoted value as object structure and can consequently skip an earlier ManagerVersion declaration. Windows PowerShell accepts that value syntax and keeps the last ManagerVersion. The post-conversion identity check then sees one correctly named property with the expected value. Both manifest routes use these steps.",
      "blocking_rationale": "The standalone validator can report success for an archive or bare manifest containing conflicting loader minimums. This contradicts the package contract documented in `docs/VALIDATION.md`.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Every accepted manifest has one unambiguous declaration of each required member. Punctuation inside a string has no effect on which declarations are counted.",
      "id": "R6-F4",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 98
      },
      "priority": "P2",
      "requested_correction": "Use consistent token handling for counting and decoding. Reject unsupported string syntax wherever a value or member name can occur, or use a reader that exposes duplicate declarations before conversion collapses them.",
      "requested_evidence": "Exercise the ZIP and bare-manifest paths with a single-quoted text value containing a brace before conflicting required fields. Assert the specific syntax or duplicate-declaration refusal. Retain a passing control with punctuation inside an ordinary double-quoted display name.",
      "title": "A brace inside a single-quoted value can hide a duplicate manifest field",
      "trigger": "A supplied Info.json contains a single-quoted display value with a literal opening brace, followed by conflicting ManagerVersion declarations whose final value is 0.31.1."
    },
    {
      "acceptance_ids": [
        "mission \u00a76",
        "OWNER AMENDMENT 1 package scope"
      ],
      "actual": "Round 8 removed the pre-install validator call. The runner checks that the ZIP exists, records its hash, expands it into Mods, and then hashes the extracted DLL. The README provides a separate manual validation command, but the `-ProductZip` invocation documented in `docs/COMPATIBILITY.md` proceeds directly to extraction.",
      "blocking_rationale": "An ordinary supplied archive can install a DLL that targets a newer UMM while declaring the baseline minimum. This is a missing package check on a documented installation path and requires no archive replacement or concurrent operation to trigger.",
      "blocks_readiness": true,
      "category": "required_gap",
      "expected": "The supported procedure for installing a supplied ZIP checks the actual packaged DLL references with the standalone validator and stops before staging if validation fails.",
      "id": "R8-F1",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 147
      },
      "priority": "P2",
      "requested_correction": "Make successful validation of the exact supplied archive a prerequisite of the documented product-present ZIP installation path. A narrow preflight or a checked entry point around the base runner is sufficient. Preserve the comparison-only use of a ZIP with `-NoProduct`.",
      "requested_evidence": "Use a temporary four-file ZIP declaring 0.31.1 whose DLL references UMM 0.33.0. Show that the supplied-ZIP procedure stops on the reference mismatch before staging, and that a genuine baseline ZIP reaches the handoff. This can be checked before any native transaction.",
      "title": "The supplied-ZIP installation path bypasses standalone validation",
      "trigger": "Use the documented `-ProductZip` route with an archive acquired independently of `Package.ps1`."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_verified",
      "finding_id": "R5-F3",
      "rationale": "OWNER AMENDMENT 1 permits removal of unnecessary mission-added recovery machinery. The two-stage liveness check and journal handoff are gone, and Git confirms the runner matches the merge base. This verifies removal of the PR-specific recovery change."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F1",
      "rationale": "Package.ps1 now checks recorded product changes after selecting and type-checking either dirty flag. The gate confirms the alternate DLL\u2019s matching legacy receipt was refused for its contradictory change list and the genuine clean legacy receipt packaged successfully."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F2",
      "rationale": "The mission-added directory publication and cleanup in NativeProduct.ps1 were removed under OWNER AMENDMENT 1. Main\u2019s existing path-based rollback over `staged` is still present. The verified correction is removal of the added staging path and its ownership claim."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R6-F4",
      "rationale": "The new guard catches single-quoted and unquoted names while the scanner is at depth one. An accepted single-quoted value can still change the scanner\u2019s apparent depth and hide a conflicting declaration on either route."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R7-F1",
      "rationale": "The restored reader consumes the `staged` member written by main. The `created`-only fallback that treated an older journal as owning zero paths was removed."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R7-F2",
      "rationale": "The runner records `staged` before directory creation or ZIP extraction. Removing the later `created` callback eliminates the reported interruption window between creation and that required record."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R7-F3",
      "rationale": "The restored writer uses Windows PowerShell\u2019s `Set-Content -Encoding UTF8`, which emits the byte-order mark recognized by the existing reader. The mission-added BOM-less writer was removed."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R7-F4",
      "rationale": "The validation record removes both conflicting held-lock outcomes and the unsupported byte-preservation claim. It attributes the earlier suite to fd1ac03 and identifies the runner cases removed in round 8."
    }
  ],
  "request_id": "ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r08-30263f",
  "round": 8,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "Cutscene Skip declares UMM 0.31.1. The wrapper and direct production builds verify UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. Packaging binds the DLL to its build receipt and inspects the four-entry ZIP. Modern and legacy receipts now receive the same clean-input consistency check.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Disposition of draft PR #3 after the two package findings clear independent review."
    ],
    "scope_reviewed": "Cutscene Skip PR #3 at 8cc7ab5 against merge base 6c1d65a, including the corrections since 45f5c20 and the scope freeze in OWNER AMENDMENT 1.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
