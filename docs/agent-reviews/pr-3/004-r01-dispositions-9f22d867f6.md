<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r01-dispositions-9f22d867f6 part=1/1 sha256=9f22d867f6ff64aeac05f09e11e7585aeec815a2111fc605b01e9763f7d84693 -->
### Claude Opus — finding dispositions — round 1

Candidate after corrections: `ccd7a2b2de6e7ccb5f2aeab5de08426b0eb20ad7`

- **R1-F1** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json package_provenance_cases: GenuineBuildAndPackageWithoutOverride, BuildHelperChangeInvalidatesThePriorReceipt (committed scripts/Build.ps1 change refused: 'product inputs changed since build commit ... scripts/Build.ps1'), FreshBuildAfterHelperChangePasses, DocumentationOnlyChangeReusesTheFrozenDll (build and package commits differ, same DLL).
- **R1-F2** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json provenance_cases: PackagedWrongAssemblyTargetIsRejected, PackagedWrongEntryMethodIsRejected, PackagedDllWithConflictingFileVersionIsRejected, PackageWithPinnedReferencesIsAccepted; published-0.1.2-validation.json is the genuine frozen 0.1.2 control.
- **R1-F3** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json provenance_cases: SameNameSameVersionDifferentBindingIdentityIsRejected (UnityModManager 0.31.1.0 with Culture=fr), AdditionalUmmFamilyReferenceIsRejected (UnityModManagerExtensions), PackagedDllWithHarmony2ReferenceIsRejected, PackageWithPinnedReferencesIsAccepted.
- **R1-F4** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json provenance_cases: BareDllRouteStagesTheValidatedBytesAfterTheBuildOutputChanged (real temporary files: the build output is replaced after validation; the staged DLL is the validated bytes; summary records validatedProductDllSha256 and the staged digest).
- **R1-F5** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json provenance_cases: every fixture is compiled against the pinned files (baseline) or disposable stubs of known identity: PackagedDllCompiledAgainstNewerStubLoaderIsRejected (stub UnityModManager 0.33.0.0), BuiltDllCompiledAgainstNewerStubLoaderIsRejected, PackageWithPinnedReferencesIsAccepted, BuiltDllWithPinnedReferencesIsAccepted; Test-Provenance no longer reads the installed loader.
- **R1-F6** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json provenance_cases: NoProductWithZipIsAComparisonOnly (mode none, comparison recorded, nothing validated or staged), NoProductWithoutZipNeedsNoProduct; Invoke-NativeRun summary noProduct/productMode/comparisonZipSha256 follow the same plan.
- **R1-F7** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json provenance_cases: ReportDigestAndMetadataComeFromOneSnapshot, ReportPathEqualToPackageIsRejected, ReportPathHardLinkToPackageIsRejected (input unchanged); package-manifest.json zip_sha256 equals package-validation.json input_sha256.
- **R1-F8** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json provenance_cases: PreparationFailureRemovesThePrivateCopy, PostLockSetupFailureReleasesOwnLockAndKeepsForeignLock (disposable lab object; the evidence path blocked by a file; own lock removed, another lab's lock file kept).
- **R1-F9** — `fixed` — commits: `42b61a9`, `65a182e`, `ccd7a2b`
  docs/evidence/umm-0311/test-results.json package_provenance_cases: CorruptCacheEntryRefusedBeforeCompilation ('does not match its pin', no compile), DllDifferingFromItsReceiptRefusedAtPackaging, GenuineBuildAndPackageWithoutOverride.
- **R1-F10** — `fixed` — commits: `65a182e`
  docs/COMPATIBILITY.md 'Current checks': the guarded disposable-copy harness has no umm-0.33.4 profile (scripts/runtime/loader-profiles.json lists umm-0.27.12, umm-0.31.1, umm-0.32.3, umm-0.32.4, the synthetic set, plus owner-0.33.0), so -LoaderProfile umm-0.33.4 is refused ('Unknown loader profile'); the unmet prerequisite is a reviewed 0.33.4 profile with verified UMM 0.33.4, Harmony 2.4.3 and matching dnlib/doorstop components. No native run was made; the 0.33.4 row is static-only.
- **R1-F11** — `fixed` — commits: `65a182e`, `ccd7a2b`
  docs/COMPATIBILITY.md: 0.33.4 row, four-profile static audit (api-audit.json, loader-profiles.md) with the frozen artifact identity, tool sources (loader-api-audit-Program.cs.txt, loader-api-audit-csproj.txt) and the exact build/invocation, the guarded native command, and the 2026-11-08 combined-stack runs identified as historical.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f --gate test | yes | pass | 20.1s | Controller receipt on ccd7a2b: unit 55/55, provenance 32/32, package provenance 6/6 (gate log RESULT lines). |
| scripts/Test.ps1 on 42b61a9 | no | pass | ~3 min | docs/evidence/umm-0311/test-results.json lists every case. |
| scripts/Build.ps1 + scripts/Package.ps1 on 65a182e | no | pass | ~1 min | package-validation.json, package-manifest.json, build-receipt.json. |
| scripts/Validate-Package.ps1 -PackagePath <published v0.1.2 ZIP> | no | pass | ~2s | published-0.1.2-validation.json (file version 0.1.2.0; full reference identities). |
| Native checks (0.33.4 and others) | no | not_run | 0 | Product unchanged; 0.33.4 prerequisite recorded in docs/COMPATIBILITY.md. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
