<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r08-dispositions-b32cec557a part=1/1 sha256=b32cec557a3b61db97eb61335f59f6384c640d8ed4cdb95c1c2a936af4d45784 -->
### Claude Opus — finding dispositions — round 8

Candidate after corrections: `8d2cfd38d1d86d604bfe495af6a781a600ade033`

- **R8-F1** — `fixed` — commits: `97267d5`, `8d2cfd3`
  controller gate test on 8d2cfd3 (gate-test-8d2cfd38d1d8-d74c4059be1-aee23aed1c6-20261126T142902980033Z.log): scripts/Test.ps1 55/55 unit, provenance 65/65, package provenance 33/33: Provenance.RunnerRefusesAProductZipThatFailsValidationBeforeLocking (the real Invoke-NativeRun.ps1 with a real scenario file and -ProductZip of a package whose DLL references UnityModManager 0.33.0.0: exit non-zero with 'The product ZIP failed standalone validation; nothing was locked or staged', the lab's runtime.lock state unchanged and no private copy left). The staging line installs the validated copy (Expand-Archive -LiteralPath $validatedProductZip); -NoProduct skips the preflight and keeps the comparison-only use.
- **R6-F4** — `fixed` — commits: `97267d5`, `8d2cfd3`
  controller gate test on 8d2cfd3 (gate-test-8d2cfd38d1d8-d74c4059be1-aee23aed1c6-20261126T142902980033Z.log): scripts/Test.ps1 55/55 unit, provenance 65/65, package provenance 33/33: Provenance.PackagedManifestWithBraceInSingleQuotedValueIsRejected and Provenance.BareManifestWithBraceInSingleQuotedValueIsRejected ("Note": '{' before a conflicting "ManagerVersion": "0.33.0" and the genuine one: refused, 'unsupported string syntax', on the ZIP and bare routes); the single-quoted-name and unquoted-name cases, the double-quoted duplicate cases and the single-declaration control PackagedManifestWithDeclaredMemberNamesIsAccepted pass.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 70.3s | Controller receipt: controller gate test on 8d2cfd3 (gate-test-8d2cfd38d1d8-d74c4059be1-aee23aed1c6-20261126T142902980033Z.log): scripts/Test.ps1 55/55 unit, provenance 65/65, package provenance 33/33. |
| scripts/Test.ps1 at 97267d5 and 8d2cfd3 (direct) | no | pass | 30s + 77s | 97267d5 stopped in the new runner case (the child's stderr became a terminating error in the test; the runner had refused correctly); 8d2cfd3: 55/55, 65/65, 33/33. |
| Native checks | no | not_run | 0 | Not authorized; the runner case stops at its preflight before any lock. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
