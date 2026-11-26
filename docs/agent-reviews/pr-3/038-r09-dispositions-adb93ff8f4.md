<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r09-dispositions-adb93ff8f4 part=1/1 sha256=adb93ff8f433f5076f9eaa319c32e0b467565a4ceb4a01d85bb198ff0e1c6b01 -->
### Claude Opus — finding dispositions — round 9

Candidate after corrections: `4f3ef4aa68ba70363d8803af70f088911f5475a2`

- **R9-F1** — `fixed` — commits: `4f3ef4a`
  controller gate test on 4f3ef4a (gate-test-4f3ef4aa68ba-d74c4059be1-aee23aed1c6-20261126T144815663740Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 33/33: the runner-launching case is removed. Provenance.PreflightRefusesAZipWhoseDllReferencesAnUnpinnedLoader, Provenance.PreflightPassesAGenuineZipAndExtractsTheValidatedBytes, Provenance.PreflightHoldsTheValidatedCopyAgainstWriteRenameAndDelete, Provenance.PreflightCloseLeavesNoPrivateCopy and Provenance.PreflightSetupFailureAfterTheCopyLeavesNoPrivateCopy call the real Open-/Expand-/Close-ValidatedProductZip with -WorkRoot set to the fixture's own folder, whose emptiness is the only temporary-file observation; no lock or game folder is involved. Provenance.RunnerValidatesBeforeLockingAndExtractsOnlyTheHeldCopy checks statically that the runner calls Open-ValidatedProductZip before Enter-RuntimeLock, extracts with Expand-ValidatedProductZip $validatedProduct and no longer uses Expand-Archive.
- **R8-F1** — `fixed` — commits: `4f3ef4a`
  controller gate test on 4f3ef4a (gate-test-4f3ef4aa68ba-d74c4059be1-aee23aed1c6-20261126T144815663740Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 33/33: Provenance.PreflightRefusesAZipWhoseDllReferencesAnUnpinnedLoader asserts the refusal and the validator's own diagnostic ('references UnityModManager, Version=0.33.0.0'), with no private copy left; the baseline control Provenance.PreflightPassesAGenuineZipAndExtractsTheValidatedBytes validates a genuine package, records the copy's digest equal to the supplied ZIP's, and extracts through the held handle into a fixture Mods folder, where the installed DLL equals the genuine DLL.
- **R9-F2** — `fixed` — commits: `4f3ef4a`
  controller gate test on 4f3ef4a (gate-test-4f3ef4aa68ba-d74c4059be1-aee23aed1c6-20261126T144815663740Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 33/33: Provenance.PreflightHoldsTheValidatedCopyAgainstWriteRenameAndDelete (while held, opening the copy for write, File.Move and File.Delete are all refused); extraction reads the archive through the same handle (ZipArchive over the held FileStream), not by reopening the path; Provenance.PreflightPassesAGenuineZipAndExtractsTheValidatedBytes confirms the extracted DLL.
- **R9-F3** — `fixed` — commits: `4f3ef4a`
  controller gate test on 4f3ef4a (gate-test-4f3ef4aa68ba-d74c4059be1-aee23aed1c6-20261126T144815663740Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 33/33: Provenance.PreflightSetupFailureAfterTheCopyLeavesNoPrivateCopy (a failure after the copy is made and held: the validator path is missing; the private folder is removed by the preflight's single try/finally) and Provenance.PreflightCloseLeavesNoPrivateCopy; in the runner one catch covers the preflight, harness check, runtime preflight, lock and setup up to the main try, whose finally closes the copy.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 65.9s | Controller receipt: controller gate test on 4f3ef4a (gate-test-4f3ef4aa68ba-d74c4059be1-aee23aed1c6-20261126T144815663740Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 33/33. |
| scripts/Test.ps1 at 4f3ef4a (direct) | no | pass | 67s | 55/55, 70/70, 33/33. |
| Native checks | no | not_run | 0 | Not authorized; the runner is not started by any test. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
