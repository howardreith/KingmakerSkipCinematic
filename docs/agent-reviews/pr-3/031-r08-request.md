<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r08-request part=1/1 sha256=cacbc3cc4bd70d312ae332ec826b4310c9c875eac47b9e995fd2cb35273631d6 -->
### Claude Opus — review request — round 8 — candidate `8cc7ab5937`

| Field | Value |
|---|---|
| Request ID | `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r08-30263f` |
| Checkpoint | `final` (final) |
| Candidate H | `8cc7ab59373b651278f2de15a1011a65d99f3650` |
| Target B (`main`) | `6c1d65aba5bb4624a7e23819210400d0c281054e` |
| Merge base M | `6c1d65aba5bb4624a7e23819210400d0c281054e` |
| Mission | `kingmaker-umm-0311-mission-20261123` sha256 `f7d990f396` |
| Workflow | `6d613defe7` |
| Owner guidance | none |
| Owner amendments | revision 1, sha256 `a2f26787968fd209dccca023305660a73ad7dbba2bbb1c15dff0131891965f67` |
| Developer observed | foreground session `e178a93b-ca53-4b6b-a4d2-a357d48eaa77`: models ['claude-opus-5-5'], effort ['high'], permission modes ['auto'] (CLI-recorded transcript; the headless permission profile does not apply to a foreground session) |
| Reviewer requested | Codex `gpt-6.2-astra`, effort `max`, read-only sandbox |
| Round budget | 8 of 10 |

**Scope:** The complete mission as written.

**Exit conditions:**
- Every requirement of the mission is implemented, with evidence appropriate to each claim; no requirement is weakened or silently dropped.
- Validation follows the repository's own instructions; commands, results and limits are reported honestly.
- Deviations, limitations and deferred optional items are stated explicitly, separate from required work.

**Developer summary:**

Round-8 corrections for Cutscene Skip PR #3 under owner amendment 1 (Phase B scope freeze), all eight open findings in one batch. Code and tests a7a33bc; 8cc7ab5 changes only docs/VALIDATION.md. Product unchanged (DLL a2a8706b).

Simplification: the native runner returns to main. This change had added product validation, private-copy staging, a run-lock ownership protocol, journal handoff and recovery changes to scripts/runtime (NativeProduct.ps1 and edits to Invoke-NativeRun.ps1 and RuntimeLab.Common.ps1). Native runs are outside the frozen scope (declare and compile against UMM 0.31.1, static checks, accurate package/receipt/evidence claims), none was made, and the package and receipt guarantees do not depend on the runner. Five open findings (R5-F3, R6-F2, R7-F1, R7-F2, R7-F3) were defects in that added code; it is removed rather than extended, which also removes R7-F4's contradictory recovery text. The validator's bare-manifest mismatch cases, previously reached only through the runner, now call the validator directly.

R6-F1: Package.ps1 selects and type-checks the applicable dirty flag (product_inputs_dirty, else the older dirty), then checks any recorded product_input_changes against a clean claim for both formats; a genuine older receipt without the newer fields is unaffected. R6-F4: the manifest scanner refuses a top-level member name that is not a double-quoted JSON string (single-quoted or unquoted names, which Windows PowerShell's decoder accepts), so every declaration the decoder accepts is counted by the duplicate check, on the ZIP and bare routes. Native runtime NOT RUN.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 80.3s | Controller receipt on 8cc7ab5: scripts/Test.ps1 55/55 unit, provenance 62/62, package provenance 33/33. |
| scripts/Test.ps1 at a7a33bc (direct, before the documentation commit) | no | pass | 85s | 55/55, provenance 62/62, package provenance 33/33; the same suite the gate ran on 8cc7ab5. The provenance count is lower than round 7's 110 because the native-runner cases were removed with that machinery. |
| Native checks | no | not_run | 0 | Not authorized; the native runner is unchanged from main and was not run. |

**Evidence references:**
- docs/VALIDATION.md
- scripts/Package.ps1
- scripts/Validate-Package.ps1
- scripts/Test-Provenance.ps1
- scripts/Test-PackageProvenance.ps1
- prepared under owner amendments revision 1 sha256 a2f26787968fd209dccca023305660a73ad7dbba2bbb1c15dff0131891965f67

**Prior findings to assess:** `R5-F3`, `R6-F1`, `R6-F2`, `R6-F4`, `R7-F1`, `R7-F2`, `R7-F3`, `R7-F4`

**Owner amendments to the mission — revision 1, captured-source sha256 `a2f26787968fd209dccca023305660a73ad7dbba2bbb1c15dff0131891965f67`.** Applied by the owner with `resume --amend-mission`; each owner message is preserved verbatim, in order. The effective task is the original mission plus these amendments. The reported work comes from a developer invocation whose input included them, and the reviewer of this round receives a byte-exact copy of the captured document. Public rendering after the controller's standard sanitization; the digest identifies the private captured bytes, which this rendering can differ from.

```text
# Owner amendments to the mission

Cumulative record kept by the agent-review controller. Each owner message below was applied by the owner through `resume --amend-mission` and is preserved verbatim, in order, between its labeled marker lines. Later amendments supersede conflicting earlier requirements; requirements they do not change still apply.

----- BEGIN OWNER AMENDMENT 1 (captured 2026-11-26T13:58:07Z; message sha256 c3d3998ac1dc60dec6597a2f22d10b3d1bff078dc72b8377a0c4590f72b77b11) -----
PHASE B — RESUME THE FOUR PAUSED REPOSITORIES

Once Phase A has completed, or a repository has reached a concrete blocker
within its authorization, proceed with the remaining authorized work.
One blocked repository must not stop independent progress in the others.
Report any incomplete Phase A publication explicitly.

Resume the existing enrollments and PRs:

TRE:
- Repository: howardreith/KingmakerGunslingerAndOtherTabletopRules
- PR: #220
- Last recorded head: a7d293a533
- Reviews used: 5.
- New TOTAL review cap: 8.

Buff:
- Repository: howardreith/KingmakerBuffPlanner
- PR: #26
- Last recorded head: e636c2c563
- Reviews used: 5.
- New TOTAL review cap: 8.

Waking:
- Repository: howardreith/KingmakerWakingRune
- PR: #12
- Last recorded head: 5432227c86
- Reviews used: 5.
- New TOTAL review cap: 8.

Skip:
- Repository: howardreith/KingmakerSkipCinematic
- PR: #3
- Last recorded head: 45f5c206a2
- Reviews used: 7.
- New TOTAL review cap: 10.

This authorizes three additional review submissions per repository.
The caps above are absolute totals, not additional-round values.

I also explicitly authorize one supported resumption of each existing
no-progress-blocked enrollment under this assignment. Use the controller's
documented resume mechanism. Preserve completed rounds, findings, evidence,
and history; do not manually erase counters or create replacement
enrollments to escape previous stops.

Start from the recorded unresolved findings:

- TRE: R1-F4, R4-F3, R5-F1, R5-F2, R5-F3, R5-F4.
- Buff: R1-F3, R4-F1, R4-F4, R5-F1, R5-F2, R5-F3.
- Waking: R1-F1, R4-F1, R4-F2, R4-F3, R4-F4, R5-F1, R5-F2.
  R5-F3 remains optional.
- Skip: R5-F3, R6-F1, R6-F2, R6-F4, R7-F1, R7-F2, R7-F3, R7-F4.

Read the actual finding text and current mission records before fixing.
Do not reconstruct requirements from finding titles alone.

Batch coherent corrections before submitting a review. Use focused,
realistic reproductions first, then the required candidate gate.
Make sure a regression test reaches the behavior it claims to test;
an earlier unrelated refusal is not evidence that the target behavior works.

Stop each repository at AWAITING_OWNER_REVIEW as soon as its required
findings and checks are satisfied. Do not merge or release these four.

SCOPE FREEZE

The authorized correction scope remains:

- Declare UMM 0.31.1 consistently.
- Compile against the agreed pinned 0.31.1 baseline through the relevant
  supported build routes.
- Perform the agreed static checks for the specific higher loader versions.
- Keep package, receipt, and evidence claims accurate.
- Correct concrete regressions introduced by this mission.
- Complete the integration and release work expressly authorized above.

No new gameplay features, general build-system redesign, broad MSBuild
interpreter, budget framework, evidence framework, or native-test campaign.

Prefer the smallest adequate correction using existing infrastructure.
Simplifying or removing unnecessary mission-added machinery is acceptable
when it preserves the required behavior and truthful evidence.

Previously accepted optional findings and deferrals remain nonblocking.

New findings must identify a concrete defect within this frozen scope,
including a direct regression from the current corrections or integration.
General hardening ideas and unrelated cleanup go into follow-up notes.

A demonstrated data-loss defect, broken rollback, incorrect release
artifact, or false evidence claim introduced by this work remains a real
blocker. Fix it narrowly or remove the unnecessary offending path; do not
waive it merely to obtain a ready verdict.

Communicate this scope to the controller/reviewer through the existing
supported mechanism. Do not fabricate approval or weaken required gates.

VALIDATION ALLOWANCE AND ACCOUNTING

I authorize up to 30 minutes of NEW validation work per repository for
this assignment. This is a ceiling, not a target.

For Mounted, explicitly declare a separately budgeted integration/release
campaign with a 30-minute allowance using the existing supported mechanism.
Keep the completed correction campaign's ledger unchanged.

For the other repositories, record the authorization through their existing
accounting or allowance mechanism. Apply any required allowance adjustment
once, with this assignment as its source, preserving prior spending and
history. Do not introduce new metering infrastructure.

Count all validation work under this assignment, including:
- Direct reproductions and focused tests.
- Failed runs and reruns.
- Builds and required gates.
- Packaging and release qualification.

Direct invocation does not make a run uncounted. Where no automated ledger
exists, record durations in the existing mission status record.

Inspect nested commands so a focused check does not unexpectedly launch a
broad campaign. Reuse valid results for unchanged inputs when permitted.

Do not start a known run that cannot fit the remaining allowance.
Complete necessary cleanup safely and record actual costs.

No automatic extensions beyond the stated review and validation allowances.
If a repository reaches a real stop, report its precise blocker and continue
other independent authorized work.
----- END OWNER AMENDMENT 1 -----
```

_Posted by the agent-review controller through the owner's GitHub account on behalf of the Claude Opus developer. Automated request; not a human review._
