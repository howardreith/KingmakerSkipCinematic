<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r06-dispositions-c1009bc573 part=1/1 sha256=c1009bc573b1afc8fd263dd916dee8b96c83c509e3291ee52b9f4e38b2874acc -->
### Claude Opus — finding dispositions — round 6

Candidate after corrections: `45f5c206a246592000fc91e5d5aa91fee4ea26d9`

- **R5-F3** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at fd1ac03): DelayedFinalizerOfAnotherRunLeavesTheSuccessorUntouched (after a handoff to run B, Complete-NativeRun for A refuses B's lock and B's lock, journal and staged folder are byte-identical), DelayedRestorationOfAnotherRunCannotHoldTheSuccessorsLock, RecoveryWhileTheOwningRunIsActiveChangesNothing (B's runner stood in for by a live helper process), RecoveryAfterTheOwningRunEndedClearsItsTransaction; retained LockReplacedBeforeTheExclusiveOpenIsKeptForItsOwner, LockReplacementAfterTheOwnershipCheckIsRefusedAndOnlyTheVerifiedLockIsRemoved, OrdinaryJournalWithAnotherRunsLockLeavesStagedFilesUntouched, ReleaseJournalWithAForeignLockPathPreservesBothLocks, ReleaseJournalWithAnEmptyRunIdPreservesBothLocks.
- **R5-F2** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at fd1ac03): FailedJournalPublicationLeavesTheCompleteJournalAndLock (journal held readable but not replaceable during the handoff: the complete ordinary journal remains readable, no temporary file left, lock kept), RecoveryAfterFailedPublicationClearsTheOwnedTransaction; the lock-sharing-denial retry case is kept (OrdinaryRecoveryWithTheLockHeldChangesNothingAndStaysRetryable, then OrdinaryRecoveryRetryAfterTheHandleClosesClearsOnlyThatTransaction): with ownership held, a recovery that cannot open the lock now changes nothing. Enter-NativeRunDirectories surfaces a recovery-journal write failure in its error.
- **R6-F1** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/package-provenance.json (31/31 at fd1ac03): AlternateBuildReceiptRecordsItsDirtyInputs (the alternate build's own receipt, digest matching its DLL, source restored), AlternateDirtyReceiptRefused, AlternateNullDirtyFlagRefused, AlternateEmptyArrayDirtyFlagRefused, AlternateStringFalseDirtyFlagRefused, AlternateCleanClaimListingChangesRefused, GenuineCleanReceiptPackagesAfterTheDirtyCases.
- **R6-F2** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at fd1ac03): ClaimedProductDestinationIsRefusedAndTheSentinelKept (a child process with a line breakpoint creates a folder with a sentinel at the destination just before creation; staging refuses and its cleanup keeps the sentinel), RecoveryKeepsAFolderTheRunDidNotCreate (journal staged but not created: recovery clears the lock and journal and keeps the sentinel); GenuineZipStagesExactlyTheValidatedEntries still passes.
- **R6-F3** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at fd1ac03): JournalRetirementFailureIsAFailedSavedOutcomeWithTheLockReleased (release-lock journal held readable but undeletable: saved status integrity-failed, scenarioStatus passed, lockReleased true, journalRetired false, lock gone, journal kept), RecoveryRetiresTheReleaseJournalAfterTheHandleCloses.
- **R6-F4** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at fd1ac03): PackagedManifestDeclaringManagerVersionTwiceIsRejected (raw ZIP manifest, last declaration genuine), BareManifestDeclaringEntryMethodTwiceIsRejected (raw bare manifest), PackagedManifestWithDeclaredMemberNamesIsAccepted and GenuineBarePairIsAccepted (single-declaration controls).
- **R6-F5** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/package-provenance.json (31/31 at fd1ac03): LowercaseReleaseConfigurationPackagesTheGenuineBuild (-Configuration release), DebugReceiptForAReleasePackageRefused.
- **R6-F6** — `fixed` — commits: `fd1ac03`, `9f35cb2`, `45f5c20`
  docs/evidence/umm-0311/package-provenance.json (31/31 at fd1ac03): ReceiptWithContradictoryLoaderAssemblyVersionRefused (only the recorded UnityModManager assembly_version changed to 0.33.0.0), GenuineReceiptPackagesAfterTheVersionCase; docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at fd1ac03): RecordedAssemblyVersionContradictingThePinIsAProblem and MatchingReceiptHasNoProblems with the real 0.31.1.0 / 1.2.0.1 identities.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 86.6s | Controller receipt on 45f5c20 (log gate-test-45f5c206a246-d74c4059be1-aee23aed1c6-20261124T155935606796Z.log): RESULT total=55 passed=55; provenance total=110 failed=0; package-provenance total=31 failed=0. |
| scripts/Test.ps1 at fd1ac03; scripts/Test-PackageProvenance.ps1 -ReportPath at fd1ac03 | no | pass | ~5 min | docs/evidence/umm-0311/test-results.json (scripts/Test.ps1 at fd1ac03): 55/55, 110/110, 31/31 with every case name and detail; docs/evidence/umm-0311/package-provenance.json (31/31 at fd1ac03). |
| Build.ps1 + Package.ps1 on the clean 9f35cb2 tree; Validate-Package.ps1 on the published v0.1.2 ZIP | no | pass | ~1 min | docs/evidence/umm-0311/build-receipt.json, package-validation.json, package-manifest.json (provenance_verified true, DLL a2a8706b, ZIP 8c6279b1), published-0.1.2-validation.json (c1be6ae2 accepted). |
| Native runs | no | not_run | 0 | Lock, journal and staging behaviour exercised in disposable labs and fixture Mods trees without a game. No live-installation run. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
