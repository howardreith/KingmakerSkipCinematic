<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r03-dispositions-1c2ddeb6d9 part=1/1 sha256=1c2ddeb6d9e297f72657fdbc01d15d06b0e9037432d24506a73ddde3156516de -->
### Claude Opus — finding dispositions — round 3

Candidate after corrections: `e300170b392a8c061d8acb53a53df657cd5afa2f`

- **R2-F4** — `fixed` — commits: `d2ca1d9`, `50a92c9`, `e300170`
  docs/evidence/umm-0311/test-results.json provenance_cases: DefaultCheckoutManifestWithChangedIdIsRefusedBeforeLocking, ...ChangedAssemblyNameIsRefusedBeforeLocking, ...ChangedEntryMethodIsRefusedBeforeLocking (disposable checkout = this scripts folder plus Info.json; preparation called with its default manifest path after the root Info.json was changed; refused by the validator, no private folder, nothing staged), DefaultCheckoutManifestGenuinePairStagesTheValidatedManifest (staged DLL = genuine digest; staged Info.json digest = validated info_sha256 = root Info.json); retained: BareManifestWithMismatched{Version,ManagerVersion,Id}IsRefused, ManifestChangedAfterPreparationDoesNotAlterTheStagedManifest. Install-ValidatedNativeProduct compares the staged manifest with info_sha256 before the runner's -ProductManagerVersion edit.
- **R2-F5** — `fixed` — commits: `d2ca1d9`, `50a92c9`, `e300170`
  docs/evidence/umm-0311/test-results.json provenance_cases: NoProductControlExcludesTheShippingIdUnderAnotherFolderNameWithComparisonZip and ...WithoutZip (temporary owner profile: Id KingmakerCutsceneSkip in folder 'Skip Under Another Name', Id 'kingmakercutsceneskip' in another folder, plus OtherOwnerMod; only OtherOwnerMod copied; the copy passes the control check), NoProductControlRefusesTheShippingIdUnderAnotherFolderNameAndKeepsTheSource (refusal names the UMM Id and folder; source listing and hashes unchanged); the canonical-folder cases still pass.
- **R3-F1** — `fixed` — commits: `d2ca1d9`, `e300170`
  docs/evidence/umm-0311/package-provenance.json cases: DirectoryBuildTargetsChangeInvalidatesThePriorReceipt (committed root Directory.Build.targets with a DefineConstants change: packaging the old DLL refused, 'product inputs changed since build commit ...: Directory.Build.targets'), FreshBuildAfterDirectoryBuildTargetsChangePasses; GenuineBuildAndPackageWithoutOverride and DocumentationOnlyChangeReusesTheFrozenDll retained. scripts/Common.ps1 ProductInputPaths.
- **R3-F2** — `fixed` — commits: `d2ca1d9`, `e300170`
  docs/evidence/umm-0311/package-provenance.json cases: DirectRebuildRefusesADeclaredVersionDisagreeingWithThePinnedBytes (0Harmony12 declared 1.2.0.2 with its genuine digest; direct dotnet msbuild rebuild refused before compilation: 'is 0Harmony12, Version=1.2.0.1 ... which disagrees with its declared pin 0Harmony12, Version=1.2.0.2'), DirectRebuildPassesAgainAfterRestoringTheCache. scripts/Assert-PinnedReferences.ps1 uses Common.ps1 Assert-PinnedReferenceBytes (digest and identity from one byte array) for the cache and the resolved compiler inputs.
- **R3-F3** — `fixed` — commits: `d2ca1d9`, `e300170`
  docs/evidence/umm-0311/test-results.json provenance_cases: ReportPathEqualToSuppliedInfoJsonIsRejected, ReportPathHardLinkToSuppliedInfoJsonIsRejected (both DLL and Info.json hashes unchanged), DistinctReportForTheBarePairIsWritten (records info_sha256 and input_sha256).
- **R3-F4** — `fixed` — commits: `e300170`
  docs/evidence/umm-0311/INDEX.md: api-audit.json raw bc2aeeb4... and onboarding-check-project.json raw d1efccf5..., labelled as original outputs, equal to the f7e5387 index; exported digests 1185ca9b... and c67b8d2b... equal the current Git blobs (git cat-file blob HEAD:docs/evidence/umm-0311/<file> | sha256sum).
- **R3-F5** — `fixed` — commits: `d2ca1d9`, `e300170`
  docs/evidence/umm-0311/test-results.json provenance_cases: PrivateCopyCleanupFailureIsAFailedOutcomeInTheSavedSummary (writable summary, private file held open, restoration successful: saved summary status integrity-failed, scenarioStatus passed, privateCopyRemoved false, one integrity failure naming the cleanup; owned lock released; foreign lock present; cleanup error surfaced), RestoredRunReleasesOwnLockDespiteSummaryAndCleanupFailures, IncompleteRestorationKeepsLockAndJournal.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 48.3s | Controller receipt on e300170 (log gate-test-e300170b392a-...-20261124T055520122251Z.log): unit 55/55, provenance 65/65, package provenance 13/13. |
| scripts/Test.ps1 on d2ca1d9 | no | pass | ~4 min | docs/evidence/umm-0311/test-results.json lists every case. |
| scripts/Test-PackageProvenance.ps1 -ReportPath on d2ca1d9 | no | pass | ~3 min | docs/evidence/umm-0311/package-provenance.json (13 cases with details). |
| scripts/Build.ps1 + scripts/Package.ps1 on 50a92c9 (clean tree) | no | pass | ~1 min | build-receipt.json (dirty false), package-manifest.json, package-validation.json. |
| scripts/Validate-Package.ps1 -PackagePath <published v0.1.2 ZIP> (validator at d2ca1d9) | no | pass | ~2s | published-0.1.2-validation.json. |
| Native checks | no | not_run | 0 | Product DLL unchanged; native prerequisites unchanged in docs/COMPATIBILITY.md. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
