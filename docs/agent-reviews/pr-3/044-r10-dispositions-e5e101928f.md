<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r10-dispositions-e5e101928f part=1/1 sha256=e5e101928fecd802014ee91c52ce0811a97fa09431580422d20ca455aa1dd7d5 -->
### Claude Opus — finding dispositions — round 10

Candidate after corrections: `58cc4870ff84e54dc290540977bb9017a4d96ecf`

- **R10-F1** — `fixed` — commits: `58cc487`
  controller gate test on 58cc487 (gate-test-58cc4870ff84-d74c4059be1-aee23aed1c6-20261126T163311435364Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 35/35: PackageProvenance.RunnerPreflightAdmitsTheCallerSelectedProductionZipForARelativePath (child process: [Environment]::CurrentDirectory set to a folder holding a different ZIP named KingmakerCutsceneSkip-0.1.2.zip, PowerShell location set to the folder holding the production ZIP, -ProductZip .\KingmakerCutsceneSkip-0.1.2.zip: the recorded SourcePath is the selected production ZIP, the process directory is the decoy folder, and the decoy's digest differs from the admitted one). With the previous File.Copy($ProductZip) the copy would have been the decoy.
- **R8-F1** — `fixed` — commits: `58cc487`
  controller gate test on 58cc487 (gate-test-58cc4870ff84-d74c4059be1-aee23aed1c6-20261126T163311435364Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 35/35: the same case uses the clean production ZIP from PackageProvenance.GenuineBuildAndPackageWithoutOverride (real Build.ps1 and Package.ps1 in the disposable checkout of the commit under test): the held copy's digest equals the production manifest's zip_sha256, and the DLL extracted through the held handle equals its dll_sha256; the private work folder is empty afterwards.
- **R9-F3** — `fixed` — commits: `58cc487`
  controller gate test on 58cc487 (gate-test-58cc4870ff84-d74c4059be1-aee23aed1c6-20261126T163311435364Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 35/35: PackageProvenance.RunnerSetupFailureAfterValidationAndHandoffRemovesItsPrivateCopy (the real Invoke-NativeRun.ps1 with -ProductZip set to the production ZIP and TEMP/TMP set to a fixture folder: its output shows 'Package validation passed'; the overridden runtime preflight records exactly one kmcs-validated-product-<guid> folder holding product.zip at the failure point and throws 'FIXTURE: setup failure after validation and handoff'; the runner exits non-zero; afterwards its temporary folder holds no kmcs-validated-product-* folder, the fixture Mods folder is empty, the overridden run lock was never reached, and RuntimeLab.Common.ps1 is restored byte-for-byte). The fixture never calls Close-ValidatedProductZip; only the runner's catch does.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 75.6s | Controller receipt: controller gate test on 58cc487 (gate-test-58cc4870ff84-d74c4059be1-aee23aed1c6-20261126T163311435364Z.log): scripts/Test.ps1 55/55 unit, provenance 70/70, package provenance 35/35. |
| scripts/Test.ps1 at 58cc487 (direct) | no | pass | 78s | 55/55, 70/70, 35/35. |
| Native checks | no | not_run | 0 | Not authorized; the runner case cannot reach a lock or game folder (fixture overrides). |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
