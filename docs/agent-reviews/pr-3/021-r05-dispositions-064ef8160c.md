<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r05-dispositions-064ef8160c part=1/1 sha256=064ef8160c5450b4c3183b86926b744a93b8607b1d188fa8ab29f9c8f3931ec6 -->
### Claude Opus — finding dispositions — round 5

Candidate after corrections: `bdd506d0600a3d61382baa3232a713c5b0fb4fae`

- **R5-F1** — `fixed` — commits: `91da7b6`, `48cff41`, `bdd506d`
  docs/evidence/umm-0311/package-provenance.json (20/20 at 91da7b6): DifferentBaselineCompatibleDllBuilt (a real build of an uncommitted source change, reverted before packaging; other DLL c632b236), ReceiptBooleanDllDigestWithADifferentDllRefused and ReceiptEmptyArrayDllDigestWithADifferentDllRefused ('The build receipt dll_sha256 is not a SHA-256 string'; no override), GenuineReceiptAndDllPackageAgain; docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at 91da7b6): RecordedPinDigestBooleanIsAProblem, RecordedPinDigestEmptyArrayIsAProblem, RecordedPinDigestTrailingLineFeedIsAProblem.
- **R5-F2** — `fixed` — commits: `91da7b6`, `48cff41`, `bdd506d`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at 91da7b6): OrdinaryRecoveryWithTheLockHeldRestoresAndKeepsARetryableReleaseJournal (disposable lab, ordinary journal, owned lock held open with read sharing only: staged files restored, release fails, release-lock journal for that run and the lock kept), OrdinaryRecoveryRetryAfterTheHandleClosesClearsOnlyThatTransaction (lock and journal gone, another lab's lock kept); LockReleaseFailureIsAFailedSavedOutcomeWithARecoveryJournal and PostLockSetupFailureReleasesOwnLockAndKeepsForeignLock still pass. The normal run's restoration now ends with the release-lock journal, so no journal-free interval precedes the save and installation checks.
- **R5-F3** — `fixed` — commits: `91da7b6`, `48cff41`, `bdd506d`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at 91da7b6): OrdinaryJournalWithAnotherRunsLockLeavesStagedFilesUntouched (run A journal, run B lock: refused before restoration; staged file, journal digest and lock unchanged), ReleaseJournalWithAForeignLockPathPreservesBothLocks (journal names another lab's lock that records the journal's own run; refused against this lab's lock; both kept), ReleaseJournalWithAnEmptyRunIdPreservesBothLocks, LockReplacedBeforeTheExclusiveOpenIsKeptForItsOwner and LockReplacementAfterTheOwnershipCheckIsRefusedAndOnlyTheVerifiedLockIsRemoved (child process with a line breakpoint; no hook in the runner).
- **R5-F4** — `fixed` — commits: `91da7b6`, `48cff41`, `bdd506d`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at 91da7b6): PackagedManifestWithLowercaseManagerVersionMemberIsRejected (ZIP), BareManifestWithLowercaseEntryMethodMemberIsRejected (bare manifest), PackagedManifestWithDeclaredMemberNamesIsAccepted and GenuineBarePairIsAccepted (controls).
- **R5-F5** — `fixed` — commits: `91da7b6`, `48cff41`, `bdd506d`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at 91da7b6): ZipReplacedAfterValidationWithChangedManifestIsRefusedWithNothingStaged and ZipReplacedAfterValidationWithAdditionalEntryIsRefusedWithNothingStaged (same DLL and Id; destination empty), GenuineZipStagesExactlyTheValidatedEntries (only KingmakerCutsceneSkip with its four files; staged DLL and Info.json equal the validated digests).

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 64.0s | Controller receipt on bdd506d (log gate-test-bdd506d0600a-d74c4059be1-aee23aed1c6-20261124T153018818687Z.log): RESULT total=55 passed=55; provenance total=97 failed=0; package-provenance total=20 failed=0. |
| scripts/Test.ps1 at 91da7b6 (unit runner, Test-Provenance.ps1, Test-PackageProvenance.ps1) | no | pass | ~3 min | docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at 91da7b6): 55/55, 97/97, 20/20 with every case name and detail; docs/evidence/umm-0311/package-provenance.json (20/20 at 91da7b6). |
| Build.ps1 + Package.ps1 on the clean 48cff41 tree; Validate-Package.ps1 on the published v0.1.2 ZIP | no | pass | ~1 min | docs/evidence/umm-0311/build-receipt.json, package-validation.json, package-manifest.json (provenance_verified true, DLL a2a8706b, ZIP 8fcb0d5e, info_sha256 recorded), published-0.1.2-validation.json (c1be6ae2 accepted by the round-6 validator). |
| Native runs | no | not_run | 0 | Not run in this round; the lock and recovery behaviour is exercised in disposable labs without a game. No live-installation run. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
