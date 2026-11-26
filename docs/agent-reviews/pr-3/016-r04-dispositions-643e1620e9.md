<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r04-dispositions-643e1620e9 part=1/1 sha256=643e1620e98687e19ee521fbea7b643793c0dbdbc886a7159aa250cf2958b013 -->
### Claude Opus — finding dispositions — round 4

Candidate after corrections: `7360f8e08daaf1fbeab34f0a0e3e98811206a55f`

- **R4-F1** — `fixed` — commits: `883fb6e`, `7360f8e`
  docs/evidence/umm-0311/package-provenance.json cases: SrcDirectoryBuildTargetsChangeInvalidatesThePriorReceipt (committed src/Directory.Build.targets: packaging the old DLL refused, 'product inputs changed since build commit ...: src/Directory.Build.targets'), FreshBuildAfterSrcDirectoryBuildTargetsChangePasses, DocumentationOnlyChangeAfterTheSrcInputStillReusesTheFrozenDll (build commit differs from package commit, same DLL). scripts/Common.ps1 ProductInputPaths starts with 'src'.
- **R4-F2** — `fixed` — commits: `883fb6e`, `50bac0d`, `7360f8e`
  docs/evidence/umm-0311/test-results.json provenance_cases: ProductRunZipLoadsOnlyTheValidatedCandidate and ProductRunBareDllLoadsOnlyTheValidatedCandidate (temporary owner profile with an older Id KingmakerCutsceneSkip in folder 'Older Skip 0.1.1' plus OtherOwnerMod: the copy excludes the older folder, the pre-staging check passes, the validated candidate is staged and is the only folder with the shipping Id), ProductRunRefusesALiveProfileWithAnOlderShippingIdAndKeepsTheSource (live profile refused 'before staging' naming the folder; two shipping copies refused after staging; source listing unchanged). Runner: Assert-NoInstalledShippingMod after mod setup in every mode, Assert-OnlyStagedShippingMod after product staging.
- **R4-F3** — `fixed` — commits: `883fb6e`, `7360f8e`
  docs/evidence/umm-0311/test-results.json provenance_cases: NoProductControlFindsTheShippingIdInFolderKeys, NoProductControlFindsTheShippingIdInFolderHiddenSkip (hidden attribute set; both refused naming the folder, files unchanged), NoProductControlWithOnlyAnUnrelatedModPasses.
- **R4-F4** — `fixed` — commits: `883fb6e`, `7360f8e`
  docs/evidence/umm-0311/test-results.json provenance_cases: UnselectedMalformedManifestDoesNotBlockAnIsolatedSelection (empty isolated selection and the named subset OtherOwnerMod both succeed with a malformed manifest in folder Broken), SelectedMalformedManifestIsRefused ('manifest of mod folder 'Broken' cannot be read'). The final staged-Mods check (Assert-NoInstalledShippingMod) remains in the runner.
- **R4-F5** — `fixed` — commits: `883fb6e`, `7360f8e`
  docs/evidence/umm-0311/test-results.json provenance_cases: PackagedEntryMethodWithASoftHyphenIsRejected, PackagedManagerVersionWithASoftHyphenIsRejected, BareManifestEntryMethodWithASoftHyphenIsRejected, BareManifestManagerVersionWithASoftHyphenIsRejected (U+00AD inserted), GenuineBarePairIsAccepted and PackageWithPinnedReferencesIsAccepted retained.
- **R4-F6** — `fixed` — commits: `883fb6e`, `50bac0d`, `7360f8e`
  docs/evidence/umm-0311/test-results.json provenance_cases: LockReleaseFailureIsAFailedSavedOutcomeWithARecoveryJournal (owned lock held open without delete sharing after successful restoration: saved status integrity-failed, scenarioStatus passed, lockReleased false, restored true, lock kept, journal phase release-lock for this run), ReleaseRecoveryRefusesAnotherRunsLock (lock rewritten for another run: recovery refuses, lock and journal kept), ReleaseRecoveryClearsOnlyThatRunsLock (handle released: recovery removes this run's lock and journal; another lab's lock untouched); summary-write and private-copy cleanup cases still pass independently.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 60.0s | Controller receipt on 7360f8e (log gate-test-7360f8e08daa-...-20261124T061723628281Z.log): unit 55/55, provenance 81/81, package provenance 16/16. |
| scripts/Test.ps1 on 883fb6e | no | pass | ~4 min | docs/evidence/umm-0311/test-results.json lists every case. |
| scripts/Test-PackageProvenance.ps1 -ReportPath on 883fb6e | no | pass | ~4 min | docs/evidence/umm-0311/package-provenance.json (16 cases with details). |
| scripts/Build.ps1 + scripts/Package.ps1 on 50bac0d (clean tree) | no | pass | ~1 min | build-receipt.json (dirty false), package-manifest.json, package-validation.json. |
| scripts/Validate-Package.ps1 -PackagePath <published v0.1.2 ZIP> (validator at 883fb6e) | no | pass | ~2s | published-0.1.2-validation.json. |
| Native checks | no | not_run | 0 | Product DLL unchanged; native prerequisites unchanged in docs/COMPATIBILITY.md. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
