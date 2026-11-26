<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r02-dispositions-0f16e7b906 part=1/1 sha256=0f16e7b906613fe0c07827ef045127c4d16452df0587dd477d550f47208ae92d -->
### Claude Opus — finding dispositions — round 2

Candidate after corrections: `f208636276367222fb33390905be19a2800c3b47`

- **R2-F1** — `fixed` — commits: `4e4a8e5`, `8fba66d`, `f208636`
  docs/evidence/umm-0311/package-provenance.json cases: DirectProductionRebuildVerifiesItsCompilerInputs (detail lists artifacts\references\UnityModManager.dll 2e038ff2... and 0Harmony12.dll aa1cd483..., matching the parsed pins), DirectRebuildRefusesASubstitutedCacheFile ('UnityModManager.dll does not match its pin', no compile line), ResolvedReferenceRewrittenAtTheCoreCompileBoundaryIsRefused (Directory.Build.targets hook at BeforeTargets=CoreCompile pointing UnityModManager to a same-bytes copy elsewhere: 'Loader compiler references must be the pinned files ...'), DirectRebuildPassesAgainAfterRestoringTheCache. Common.ps1 ProductInputPaths include scripts/Assert-PinnedReferences.ps1 and LoaderReferences.Final.targets; docs/VALIDATION.md 'Compiler inputs'.
- **R1-F3** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases: AdditionalCaseVariantLoaderReference0_31_1_0IsRejected and ...0_33_0_0IsRejected (package route), BareDllWithCaseVariantLoaderReference...IsRejected (bare route): fixture compiled with genuine references plus a stub whose AssemblyRef name is rewritten to 'unitymodmanager' -> 'unpinned loader or Harmony assembly: unitymodmanager, Version=...'; PackageWithPinnedReferencesIsAccepted and BuiltDllWithPinnedReferencesIsAccepted retained.
- **R2-F2** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases (disposable validator root with its own pins and cache): GenuinePackageAcceptedWithoutACache, GenuinePackageAcceptedWithTheCache, DeclaredPinVersionDisagreeingWithTheCachedAssemblyIsRefused ('The pinned file 0Harmony12.dll is 0Harmony12, Version=1.2.0.1 ... which disagrees with its declared pin 0Harmony12, Version=1.2.0.2'), WithoutACacheTheDllIsCheckedAgainstTheDeclaredPin.
- **R2-F3** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases: RestoredRunReleasesOwnLockDespiteSummaryAndCleanupFailures (summary target blocked by a file, a private-copy file held open exclusively: both failures surfaced, own lock removed, foreign lock present), IncompleteRestorationKeepsLockAndJournal. scripts/runtime/NativeProduct.ps1 Complete-NativeRun, used by Invoke-NativeRun.ps1's final block.
- **R2-F4** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases: BareManifestWithMismatchedVersionIsRefused, ...ManagerVersionIsRefused, ...IdIsRefused (no private folder left), ManifestChangedAfterPreparationDoesNotAlterTheStagedManifest (staged Info.json equals the validated digest after the source manifest changed). The -ProductManagerVersion override (Invoke-NativeRun.ps1) still edits only the staged Info.json and is recorded in the summary.
- **R2-F5** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases: NoProductControlExcludesInheritedCutsceneSkipWithComparisonZip, ...WithoutZip (owner-profile fixture containing KingmakerCutsceneSkip and another mod), NoProductControlWithAnInstalledCutsceneSkipIsRefusedAndTheSourceIsIntact (source listing and hashes unchanged). Runner: Get-NoProductModExclusions for game copies, Assert-NoProductControlMods before deployment.
- **R1-F7** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases (validator run in its own process with a PowerShell line breakpoint; no test hook in the validator): InputReplacedInPlaceDuringValidationReportsOnlyTheSnapshot and InputReplacedByRenameDuringValidationReportsOnlyTheSnapshot (every report field except the input path equals the genuine snapshot's report while the file on disk is the other package), ReportAliasingTheInputAtPublicationIsRefused (hard link created just before the write; bytes intact), ReportAliasingTheReplacedCurrentInputIsRefused ('must not be the current input file'; the current input survives). FileIdentity.ps1 WriteChecked protects the input path's current identity.
- **R2-F6** — `fixed` — commits: `4e4a8e5`, `f208636`
  scripts/Test-PackageProvenance.ps1 derives the manifest name from the checkout's Info.json version; docs/evidence/umm-0311/package-provenance.json DocumentationOnlyChangeReusesTheFrozenDll passed.
- **R2-F7** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases: ReportBelowAFreshSubdirectoryIsWritten; the alias refusal cases still pass.
- **R2-F8** — `fixed` — commits: `f208636`
  docs/evidence/umm-0311/INDEX.md 'Produced by' column: test-results and package-provenance 879c19d; build receipt and package records 4e4a8e5; published validation by the validator at 4e4a8e5; api-audit identified as the reused audit of the unchanged frozen DLL a2a8706b recorded for 5efdcb0; onboarding record and fleet files identified as reused.
- **R2-F9** — `fixed` — commits: `4e4a8e5`, `f208636`
  docs/evidence/umm-0311/test-results.json provenance_cases: PreparationFailureRemovesThePrivateCopy counts only below the invocation's own temporary root and passes with another invocation's kmcs-product-* folder present in the shared temporary directory.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 39.9s | Controller receipt on f208636 (log gate-test-f20863627636-...-20261124T053157125273Z.log): unit 55/55, provenance 54/54, package provenance 10/10. |
| scripts/Test.ps1 on 4e4a8e5 and on 879c19d | no | pass | ~4 min each | docs/evidence/umm-0311/test-results.json lists every case (879c19d). |
| scripts/Test-PackageProvenance.ps1 -ReportPath on 879c19d | no | pass | ~2 min | docs/evidence/umm-0311/package-provenance.json (10 cases with details, including the recorded compiler-input paths and hashes). |
| scripts/Build.ps1 + scripts/Package.ps1 on 4e4a8e5 | no | pass | ~1 min | build-receipt.json, package-manifest.json, package-validation.json (producer 4e4a8e5 in INDEX.md). |
| scripts/Validate-Package.ps1 -PackagePath <published v0.1.2 ZIP> (validator at 4e4a8e5) | no | pass | ~2s | published-0.1.2-validation.json. |
| Native checks | no | not_run | 0 | Product DLL unchanged; native prerequisites unchanged in docs/COMPATIBILITY.md. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
