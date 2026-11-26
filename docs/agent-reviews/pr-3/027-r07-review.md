<!-- agent-review:v1 enrollment=ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f key=r07-review part=1/1 sha256=a2cfae4bcaf2b5a6631972b6ba864b3e740f5e24eae9a4f61c2742f9587fd6f1 -->
### Codex GPT-6.2 Astra — review — round 7 — candidate `45f5c206a2`

**Decision:** `changes_required` — The controller gate passed all 196 checks and confirmed the pinned compiler inputs. Recovery can still act on a live successor, delete a directory claimed by another process, or report success with the test harness still installed. The package checks also admit contradictory receipt and manifest data.

## Continuation for Claude

Within the existing review budget, keep corrections in Skip’s packaging, recovery, fixtures, and validation record. Bind the recovery decision to the lock actually held. Record directory ownership durably across publication and check it before deletion in both profiles. Account for earlier journals and read journal text consistently as UTF-8. Apply the dirty-state consistency check to both receipt formats and use one parsing contract for manifest names and values. Exercise the cases in the findings in disposable directories, then bind the configured test gate to the corrected candidate. Preserve the production pins, gameplay behavior, and historical native evidence.

#### Findings

**R5-F3** · P1 · defect · blocks readiness — Recovery can use run A’s liveness check to restore live run B
- Location: `scripts/runtime/RuntimeLab.Common.ps1:343`; acceptance: mission §7, AGENTS.md native recovery
- Trigger: Two recoveries overlap for interrupted run A. One finishes and run B starts staging before the other reads the current journal.
- Expected: Recovery establishes that the owner of the exact lock it holds is inactive before restoring files, publishing a journal, or releasing that lock.
- Actual: Restore-InterruptedRun checks process liveness before reading the journal or taking the lock. It can check inactive A, then read B’s journal and acquire B’s lock using B’s run ID. B’s PID is never checked under that handle. An unreadable lock also makes the initial liveness check return. The passing handoff fixture installs B before invoking recovery, so it misses this interval.
- Why it blocks / does not: Recovery can remove a live run’s staged files and release its lock while that run is still using the installation.
- Requested correction: Bind owner liveness, run ID, and journal phase to the same held lock for both ordinary and release-only recovery. Ensure release-error and setup-rollback writers also hold ownership when publishing a journal.
- Requested evidence: Pause a recovery after its initial observation of A, complete the handoff to a live B, then resume it. Verify the contents of B’s staged files, journal, and lock through the attempted recovery. Also cover a recovery arriving while the live finalizer holds the lock exclusively.

**R6-F2** · P1 · defect · blocks readiness — Isolated rollback still deletes a product directory it failed to create
- Location: `scripts/runtime/RuntimeLab.Common.ps1:244`; acceptance: mission §7, AGENTS.md native transaction
- Trigger: In the default isolated profile, another process claims the planned product destination after the owner’s Mods tree has been moved aside.
- Expected: Both immediate and journal-driven cleanup preserve a foreign directory. A collision that prevents safe restoration leaves the backup and recovery instructions available.
- Actual: The isolated restoration branch admits every child named in journal.staged, including a destination this run planned but failed to create. It then recursively removes the Mods tree. The passing sentinel recovery fixture sets modsOriginal to null, which selects the other branch. That branch also stores ownership by pathname, so a later replacement at a formerly owned path can be deleted.
- Why it blocks / does not: Rollback can permanently delete another process’s mod files.
- Requested correction: Check the identity of the directory actually published by this transaction before recursive removal in both profile branches. Treat an unowned child of the isolated Mods tree as a restoration conflict.
- Requested evidence: Repeat the sentinel collision with a populated modsOriginal backup and exercise restoration. Verify the sentinel and original backup survive. Also verify that replacing an owned directory at the same pathname preserves the replacement.

**R7-F1** · P1 · defect · blocks readiness — Recovery can retire an older journal with the harness still installed
- Location: `scripts/runtime/RuntimeLab.Common.ps1:254`; acceptance: mission §7, AGENTS.md native recovery
- Trigger: Run the updated -RecoverOnly on an interrupted owner-profile transaction created by main or the previous candidate.
- Expected: Recovery handles the previous journal format safely and retains a retryable record whenever it cannot establish that the installation was restored.
- Actual: Earlier journals record deployed paths in staged and have no created member. The new fallback treats them as owning zero paths. Restore-RunJournal can then mark the Mods step complete, release the lock, and retire the only journal while the harness and product remain installed.
- Why it blocks / does not: Upgrading the recovery script can leave a test-only harness in the owner’s installation with a successful recovery result.
- Requested correction: Handle staged-only journals explicitly. Recover identifiable staged payloads and retain the lock and journal if ownership is ambiguous.
- Requested evidence: Use the owner-profile journal shape from main with a staged harness in a disposable Mods tree. Show successful cleanup of identifiable payloads and preservation of a foreign sentinel in an ambiguous case.

**R6-F1** · P1 · defect · blocks readiness — The legacy receipt branch ignores a recorded product change
- Location: `scripts/Package.ps1:48`; acceptance: mission §5, mission §6
- Trigger: A supplied receipt uses the legacy dirty flag while retaining a nonempty product_input_changes list.
- Expected: Whichever dirty flag applies, a clean claim is consistent with every recorded product change.
- Actual: Package.ps1 checks product_input_changes only inside the product_inputs_dirty branch. If that flag is absent, a boolean dirty value of false is accepted even when the same receipt lists the changed product source. With the source restored and the DLL matching the receipt digest, packaging can mark provenance verified.
- Why it blocks / does not: A receipt that contradicts its own source record can still certify different product bytes.
- Requested correction: Select and type-check the applicable dirty flag, then check any recorded product changes for both formats. Preserve genuine legacy receipts that omit the newer fields.
- Requested evidence: Use the alternate build’s matching DLL and receipt after restoring its source. Exercise the legacy dirty flag with a contradictory change list and retain a genuine clean legacy control.

**R7-F2** · P2 · defect · blocks readiness — Interruption between directory creation and journaling strands the target
- Location: `scripts/runtime/Invoke-NativeRun.ps1:150`; acceptance: mission §7, AGENTS.md native recovery
- Trigger: An owner-profile host stops after creating a staging directory and before its created record reaches disk.
- Expected: An interruption on either side of directory publication leaves enough durable information to clean up the run’s own directory while preserving a competing claimant.
- Actual: The runner creates the harness directory before publishing its entry in created. Product staging has the same interval before its OnCreated callback persists ownership. An interruption leaves an empty target recorded only in staged. Owner-profile recovery skips it, retires the journal, and the next run refuses the existing destination.
- Why it blocks / does not: A routine interruption can leave the installation altered and prevent the next guarded run.
- Requested correction: Make harness and product publication recoverable across the creation boundary. One option is to record the identity of a private prepared directory before moving it into an unoccupied destination.
- Requested evidence: Interrupt disposable staging at the directory-publication boundary. Show that recovery removes the run’s directory, preserves a competing claimant, and allows subsequent staging after successful cleanup.

**R7-F3** · P2 · defect · blocks readiness — Journal writes and reads disagree on the encoding of non-ASCII data
- Location: `scripts/runtime/RuntimeLab.Common.ps1:174`; acceptance: mission §7, AGENTS.md native recovery
- Trigger: A run label or recorded path contains a non-ASCII character on a Windows system using an ANSI default code page.
- Expected: Every reader recovers the exact run ID and filesystem paths written to the journal.
- Actual: Save-Journal now writes UTF-8 without a byte-order mark. Its existing-record check and both Restore-InterruptedRun reads use Get-Content without an encoding. Windows PowerShell 5.1 can decode those bytes using the system ANSI code page. A valid accented run ID then fails its ownership comparison, and a path can resolve to the wrong spelling.
- Why it blocks / does not: A supported label or installation path can strand the lock or cause recovery to overlook staged files.
- Requested correction: Use explicit UTF-8 decoding for every journal read, with support for both earlier BOM-bearing journals and the new BOM-less files.
- Requested evidence: On Windows PowerShell 5.1, publish, update, and recover a disposable journal with an accented run label and directory path. Verify exact path restoration and retirement.

**R6-F4** · P2 · defect · blocks readiness — The manifest scanner and decoder recognize different property names
- Location: `scripts/Validate-Package.ps1:79`; acceptance: mission §5, mission §6
- Trigger: A required member appears twice using two quoting forms accepted by ConvertFrom-Json, with the expected value last.
- Expected: Every accepted manifest has exactly one declaration of each required member under the syntax its decoder accepts.
- Actual: The raw scanner recognizes only double-quoted keys. Windows PowerShell 5.1 also accepts single-quoted and unquoted keys and retains the last value of a repeated property. A conflicting declaration in one of those forms can pass the scanner and disappear during conversion on both manifest routes.
- Why it blocks / does not: The standalone validator can certify a supplied manifest containing conflicting loader minimums or entry methods.
- Requested correction: Use a consistent parsing contract for member names and values. Reject unsupported syntax or count every accepted declaration before duplicate names are collapsed.
- Requested evidence: Exercise conflicting repeated required members using mixed quoting on the ZIP and bare paths. Retain the existing single-declaration passing controls.

**R7-F4** · P2 · defect · blocks readiness — The validation record gives opposite outcomes for held-lock recovery
- Location: `docs/VALIDATION.md:113`; acceptance: mission §8, AGENTS.md validation record
- Trigger: An operator consults the current validation record after recovery encounters a held lock.
- Expected: Current recovery outcomes match the candidate-bound tests, and superseded behavior is attributed to its original commit.
- Actual: Lines 102–103 correctly say that a held lock prevents restoration. Lines 113–114 attribute completed restoration and a release-lock journal to the same condition under the fd1ac03 results. The current test checks that the ordinary journal and staged files survive the first attempt. The handoff description also claims byte-identical staged content where the fixture checks only the sentinel’s existence.
- Why it blocks / does not: The required validation record gives conflicting instructions about whether the installation was restored and overstates what the handoff fixture measured.
- Requested correction: Correct the current held-lock description or label it as the earlier result. Match the staged-content claim to the assertion actually executed.
- Requested evidence: Cross-check the revised descriptions against the held-lock and handoff assertions and their controller log entries. A byte-preservation claim needs a content comparison.

#### Prior finding assessments

- **R5-F2** — `fix_verified` — Save-Journal writes a complete sibling file before replacement. The gate exercised failed replacement, preservation of the ordinary journal and lock, and successful retry. Setup rollback now surfaces failure to establish a recovery journal. R7-F3 concerns decoding of the newly written file.
- **R5-F3** — `fix_rejected` — Same-handle lock deletion and journal retirement protect the objects already verified. The recovery admission still uses a liveness observation made before selecting the journal and acquiring that run’s lock.
- **R6-F1** — `fix_rejected` — The gate confirms rejection of malformed modern flags and a modern clean claim listing a changed file. The legacy fallback bypasses the same consistency check.
- **R6-F2** — `fix_rejected` — Immediate cleanup and the tested owner-profile collision preserve the sentinel. The isolated restoration branch still recursively deletes a planned target the run failed to create.
- **R6-F3** — `fix_verified` — The retirement-denial test confirmed saved status integrity-failed, scenarioStatus passed, lockReleased true, and journalRetired false. Recovery retired the journal after the denying handle closed.
- **R6-F4** — `fix_rejected` — Both double-quoted duplicate fixtures now fail as requested. The raw scan still misses declarations accepted by the subsequent Windows PowerShell decoder, leaving the same ambiguity on accepted inputs.
- **R6-F5** — `fix_verified` — Configuration remains a scalar string and uses ordinal case-insensitive comparison. The gate packaged Release with lowercase release and refused a Debug receipt for Release.
- **R6-F6** — `fix_verified` — The receipt comparison checks the four-part declared version for each current pin. The gate refused a receipt changing only the recorded UMM version to 0.33.0.0 and accepted the genuine control.

#### Evidence assessment

- **Inspected:** The mission, AGENTS.md, CLAUDE.md, engine notes, developer report, transcript notice, controller receipt and log, and all eight pending ledger entries.; The complete feature diff and the correction from bdd506d, including the production project, compiler targets, package and receipt checks, native staging and recovery callers, integration fixtures, and compatibility records.
- **Executed verification:** Verified HEAD, merge base, mission digest, and the byte-for-byte match between the supplied 4,029-line feature diff and Git’s diff.; Verified the controller receipt and its log digest. At the candidate commit, scripts/Test.ps1 exited 0 in 86.6 seconds with 55/55 unit, 110/110 provenance, and 31/31 package-provenance checks. All 196 recorded case names appear in the log.; The gate logged both genuine compiler-input hashes, a successful build and package without an override, and refusals for a substituted cache file, a rewritten compiler input, a mismatched DLL receipt, and an incompatible packaged loader reference.; Verified all 11 exported evidence hashes against the Git blobs. Only documentation and evidence changed after the tested tooling commit fd1ac03, and only evidence changed after the recorded clean package build at 9f35cb2.; Read-only Windows PowerShell 5.1 checks confirmed that alternate quoting of a repeated property retains its last value, that JSON serialization preserves a literal accented character, and that default and explicit UTF-8 reads differ on BOM-less repository text.
- **Source inspection only:** The remaining recovery interleavings and staging failures were traced through Invoke-NativeRun.ps1, NativeProduct.ps1, and RuntimeLab.Common.ps1. The gate exercised adjacent cases in disposable labs.; The legacy receipt branch and manifest scanner were inspected against their consumers. The reviewer’s parser check used in-memory data. Candidate package execution evidence comes from the controller gate.; The committed build, package, static audit, and historical native records identify product DLL a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba, MVID a494d31e-dfb6-469f-b2a7-787e3094639d.
- **Required gaps:** Disposable recovery evidence for a handoff during admission, an isolated-profile destination collision, an earlier staged-only journal, interruption at directory creation, and non-ASCII journal data.; Standalone rejection of conflicting manifest members using syntax accepted by the decoder, and package rejection of a legacy-form clean receipt that lists a product change.; A validation record that attributes the held-lock result to the commit that produced it and limits file-preservation claims to the observations made.
- **Limitations:** The foreground developer transcript was withheld. The candidate-bound controller gate supplies the independent execution record. The reviewer used read-only inspection and did not run a build or native transaction.; The clean package record at 9f35cb2 identifies ZIP 8c6279b113c0f340549e9eb96a53bc8cfdafa06adefd0c5dadf73388a9fefd9c. Historical skip and persistence observations belong to the released ZIP c1be6ae2 and its recorded scenarios.; Native and combined-stack testing for this round was NOT RUN. The reused static audit covers 0.31.1, 0.32.4, owner 0.33.0, and 0.33.4. Historical native rows cover the first three on the same product DLL. The repository documents the missing reviewed native profile for 0.33.4.

#### Summary

- **Delivered behavior:** Cutscene Skip declares UMM 0.31.1. The build verifies UnityModManager 0.31.1.0 and Harmony12 1.2.0.1 at compiler input, and the package validator inspects the shipped DLL. Four prior corrections are verified. Recovery safety, receipt consistency, manifest uniqueness, and the validation record still block readiness.
- **Scope reviewed:** Final correction review of KingmakerSkipCinematic PR #3 at the fixed candidate, covering the Skip-specific mission, all eight pending findings, and the directly affected build, package, recovery, and evidence paths.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Any extension of the enrolled review budget and the eventual disposition of draft PR #3, including merge or release, are owner decisions.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: none.

Codex CLI `0.170.0`, thread `01a20e49-a7be-7f33-9ce3-ee50a4d62f3e`, duration 697.3s, response sha256 `97bda24938762060a2e7e4408d7d42a7ba17deda5b6a9564d3c1c4a7be5ff024`, request `ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r07-6d39ca`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "45f5c206a246592000fc91e5d5aa91fee4ea26d9",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The controller gate passed all 196 checks and confirmed the pinned compiler inputs. Recovery can still act on a live successor, delete a directory claimed by another process, or report success with the test harness still installed. The package checks also admit contradictory receipt and manifest data.\n\n## Continuation for Claude\n\nWithin the existing review budget, keep corrections in Skip\u2019s packaging, recovery, fixtures, and validation record. Bind the recovery decision to the lock actually held. Record directory ownership durably across publication and check it before deletion in both profiles. Account for earlier journals and read journal text consistently as UTF-8. Apply the dirty-state consistency check to both receipt formats and use one parsing contract for manifest names and values. Exercise the cases in the findings in disposable directories, then bind the configured test gate to the corrected candidate. Preserve the production pins, gameplay behavior, and historical native evidence.",
  "evidence_assessment": {
    "executed_verification": [
      "Verified HEAD, merge base, mission digest, and the byte-for-byte match between the supplied 4,029-line feature diff and Git\u2019s diff.",
      "Verified the controller receipt and its log digest. At the candidate commit, scripts/Test.ps1 exited 0 in 86.6 seconds with 55/55 unit, 110/110 provenance, and 31/31 package-provenance checks. All 196 recorded case names appear in the log.",
      "The gate logged both genuine compiler-input hashes, a successful build and package without an override, and refusals for a substituted cache file, a rewritten compiler input, a mismatched DLL receipt, and an incompatible packaged loader reference.",
      "Verified all 11 exported evidence hashes against the Git blobs. Only documentation and evidence changed after the tested tooling commit fd1ac03, and only evidence changed after the recorded clean package build at 9f35cb2.",
      "Read-only Windows PowerShell 5.1 checks confirmed that alternate quoting of a repeated property retains its last value, that JSON serialization preserves a literal accented character, and that default and explicit UTF-8 reads differ on BOM-less repository text."
    ],
    "inspected": [
      "The mission, AGENTS.md, CLAUDE.md, engine notes, developer report, transcript notice, controller receipt and log, and all eight pending ledger entries.",
      "The complete feature diff and the correction from bdd506d, including the production project, compiler targets, package and receipt checks, native staging and recovery callers, integration fixtures, and compatibility records."
    ],
    "limitations": [
      "The foreground developer transcript was withheld. The candidate-bound controller gate supplies the independent execution record. The reviewer used read-only inspection and did not run a build or native transaction.",
      "The clean package record at 9f35cb2 identifies ZIP 8c6279b113c0f340549e9eb96a53bc8cfdafa06adefd0c5dadf73388a9fefd9c. Historical skip and persistence observations belong to the released ZIP c1be6ae2 and its recorded scenarios.",
      "Native and combined-stack testing for this round was NOT RUN. The reused static audit covers 0.31.1, 0.32.4, owner 0.33.0, and 0.33.4. Historical native rows cover the first three on the same product DLL. The repository documents the missing reviewed native profile for 0.33.4."
    ],
    "required_gaps": [
      "Disposable recovery evidence for a handoff during admission, an isolated-profile destination collision, an earlier staged-only journal, interruption at directory creation, and non-ASCII journal data.",
      "Standalone rejection of conflicting manifest members using syntax accepted by the decoder, and package rejection of a legacy-form clean receipt that lists a product change.",
      "A validation record that attributes the held-lock result to the commit that produced it and limits file-preservation claims to the observations made."
    ],
    "source_inspection_only": [
      "The remaining recovery interleavings and staging failures were traced through Invoke-NativeRun.ps1, NativeProduct.ps1, and RuntimeLab.Common.ps1. The gate exercised adjacent cases in disposable labs.",
      "The legacy receipt branch and manifest scanner were inspected against their consumers. The reviewer\u2019s parser check used in-memory data. Candidate package execution evidence comes from the controller gate.",
      "The committed build, package, static audit, and historical native records identify product DLL a2a8706bbb8d8bd89a50fe4d005cd30ed22f7913685adcecd212f464bd15a1ba, MVID a494d31e-dfb6-469f-b2a7-787e3094639d."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "mission \u00a77",
        "AGENTS.md native recovery"
      ],
      "actual": "Restore-InterruptedRun checks process liveness before reading the journal or taking the lock. It can check inactive A, then read B\u2019s journal and acquire B\u2019s lock using B\u2019s run ID. B\u2019s PID is never checked under that handle. An unreadable lock also makes the initial liveness check return. The passing handoff fixture installs B before invoking recovery, so it misses this interval.",
      "blocking_rationale": "Recovery can remove a live run\u2019s staged files and release its lock while that run is still using the installation.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Recovery establishes that the owner of the exact lock it holds is inactive before restoring files, publishing a journal, or releasing that lock.",
      "id": "R5-F3",
      "location": {
        "file": "scripts/runtime/RuntimeLab.Common.ps1",
        "line": 343
      },
      "priority": "P1",
      "requested_correction": "Bind owner liveness, run ID, and journal phase to the same held lock for both ordinary and release-only recovery. Ensure release-error and setup-rollback writers also hold ownership when publishing a journal.",
      "requested_evidence": "Pause a recovery after its initial observation of A, complete the handoff to a live B, then resume it. Verify the contents of B\u2019s staged files, journal, and lock through the attempted recovery. Also cover a recovery arriving while the live finalizer holds the lock exclusively.",
      "title": "Recovery can use run A\u2019s liveness check to restore live run B",
      "trigger": "Two recoveries overlap for interrupted run A. One finishes and run B starts staging before the other reads the current journal."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "AGENTS.md native transaction"
      ],
      "actual": "The isolated restoration branch admits every child named in journal.staged, including a destination this run planned but failed to create. It then recursively removes the Mods tree. The passing sentinel recovery fixture sets modsOriginal to null, which selects the other branch. That branch also stores ownership by pathname, so a later replacement at a formerly owned path can be deleted.",
      "blocking_rationale": "Rollback can permanently delete another process\u2019s mod files.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Both immediate and journal-driven cleanup preserve a foreign directory. A collision that prevents safe restoration leaves the backup and recovery instructions available.",
      "id": "R6-F2",
      "location": {
        "file": "scripts/runtime/RuntimeLab.Common.ps1",
        "line": 244
      },
      "priority": "P1",
      "requested_correction": "Check the identity of the directory actually published by this transaction before recursive removal in both profile branches. Treat an unowned child of the isolated Mods tree as a restoration conflict.",
      "requested_evidence": "Repeat the sentinel collision with a populated modsOriginal backup and exercise restoration. Verify the sentinel and original backup survive. Also verify that replacing an owned directory at the same pathname preserves the replacement.",
      "title": "Isolated rollback still deletes a product directory it failed to create",
      "trigger": "In the default isolated profile, another process claims the planned product destination after the owner\u2019s Mods tree has been moved aside."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "AGENTS.md native recovery"
      ],
      "actual": "Earlier journals record deployed paths in staged and have no created member. The new fallback treats them as owning zero paths. Restore-RunJournal can then mark the Mods step complete, release the lock, and retire the only journal while the harness and product remain installed.",
      "blocking_rationale": "Upgrading the recovery script can leave a test-only harness in the owner\u2019s installation with a successful recovery result.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Recovery handles the previous journal format safely and retains a retryable record whenever it cannot establish that the installation was restored.",
      "id": "R7-F1",
      "location": {
        "file": "scripts/runtime/RuntimeLab.Common.ps1",
        "line": 254
      },
      "priority": "P1",
      "requested_correction": "Handle staged-only journals explicitly. Recover identifiable staged payloads and retain the lock and journal if ownership is ambiguous.",
      "requested_evidence": "Use the owner-profile journal shape from main with a staged harness in a disposable Mods tree. Show successful cleanup of identifiable payloads and preservation of a foreign sentinel in an ambiguous case.",
      "title": "Recovery can retire an older journal with the harness still installed",
      "trigger": "Run the updated -RecoverOnly on an interrupted owner-profile transaction created by main or the previous candidate."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "Package.ps1 checks product_input_changes only inside the product_inputs_dirty branch. If that flag is absent, a boolean dirty value of false is accepted even when the same receipt lists the changed product source. With the source restored and the DLL matching the receipt digest, packaging can mark provenance verified.",
      "blocking_rationale": "A receipt that contradicts its own source record can still certify different product bytes.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Whichever dirty flag applies, a clean claim is consistent with every recorded product change.",
      "id": "R6-F1",
      "location": {
        "file": "scripts/Package.ps1",
        "line": 48
      },
      "priority": "P1",
      "requested_correction": "Select and type-check the applicable dirty flag, then check any recorded product changes for both formats. Preserve genuine legacy receipts that omit the newer fields.",
      "requested_evidence": "Use the alternate build\u2019s matching DLL and receipt after restoring its source. Exercise the legacy dirty flag with a contradictory change list and retain a genuine clean legacy control.",
      "title": "The legacy receipt branch ignores a recorded product change",
      "trigger": "A supplied receipt uses the legacy dirty flag while retaining a nonempty product_input_changes list."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "AGENTS.md native recovery"
      ],
      "actual": "The runner creates the harness directory before publishing its entry in created. Product staging has the same interval before its OnCreated callback persists ownership. An interruption leaves an empty target recorded only in staged. Owner-profile recovery skips it, retires the journal, and the next run refuses the existing destination.",
      "blocking_rationale": "A routine interruption can leave the installation altered and prevent the next guarded run.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "An interruption on either side of directory publication leaves enough durable information to clean up the run\u2019s own directory while preserving a competing claimant.",
      "id": "R7-F2",
      "location": {
        "file": "scripts/runtime/Invoke-NativeRun.ps1",
        "line": 150
      },
      "priority": "P2",
      "requested_correction": "Make harness and product publication recoverable across the creation boundary. One option is to record the identity of a private prepared directory before moving it into an unoccupied destination.",
      "requested_evidence": "Interrupt disposable staging at the directory-publication boundary. Show that recovery removes the run\u2019s directory, preserves a competing claimant, and allows subsequent staging after successful cleanup.",
      "title": "Interruption between directory creation and journaling strands the target",
      "trigger": "An owner-profile host stops after creating a staging directory and before its created record reaches disk."
    },
    {
      "acceptance_ids": [
        "mission \u00a77",
        "AGENTS.md native recovery"
      ],
      "actual": "Save-Journal now writes UTF-8 without a byte-order mark. Its existing-record check and both Restore-InterruptedRun reads use Get-Content without an encoding. Windows PowerShell 5.1 can decode those bytes using the system ANSI code page. A valid accented run ID then fails its ownership comparison, and a path can resolve to the wrong spelling.",
      "blocking_rationale": "A supported label or installation path can strand the lock or cause recovery to overlook staged files.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Every reader recovers the exact run ID and filesystem paths written to the journal.",
      "id": "R7-F3",
      "location": {
        "file": "scripts/runtime/RuntimeLab.Common.ps1",
        "line": 174
      },
      "priority": "P2",
      "requested_correction": "Use explicit UTF-8 decoding for every journal read, with support for both earlier BOM-bearing journals and the new BOM-less files.",
      "requested_evidence": "On Windows PowerShell 5.1, publish, update, and recover a disposable journal with an accented run label and directory path. Verify exact path restoration and retirement.",
      "title": "Journal writes and reads disagree on the encoding of non-ASCII data",
      "trigger": "A run label or recorded path contains a non-ASCII character on a Windows system using an ANSI default code page."
    },
    {
      "acceptance_ids": [
        "mission \u00a75",
        "mission \u00a76"
      ],
      "actual": "The raw scanner recognizes only double-quoted keys. Windows PowerShell 5.1 also accepts single-quoted and unquoted keys and retains the last value of a repeated property. A conflicting declaration in one of those forms can pass the scanner and disappear during conversion on both manifest routes.",
      "blocking_rationale": "The standalone validator can certify a supplied manifest containing conflicting loader minimums or entry methods.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Every accepted manifest has exactly one declaration of each required member under the syntax its decoder accepts.",
      "id": "R6-F4",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 79
      },
      "priority": "P2",
      "requested_correction": "Use a consistent parsing contract for member names and values. Reject unsupported syntax or count every accepted declaration before duplicate names are collapsed.",
      "requested_evidence": "Exercise conflicting repeated required members using mixed quoting on the ZIP and bare paths. Retain the existing single-declaration passing controls.",
      "title": "The manifest scanner and decoder recognize different property names",
      "trigger": "A required member appears twice using two quoting forms accepted by ConvertFrom-Json, with the expected value last."
    },
    {
      "acceptance_ids": [
        "mission \u00a78",
        "AGENTS.md validation record"
      ],
      "actual": "Lines 102\u2013103 correctly say that a held lock prevents restoration. Lines 113\u2013114 attribute completed restoration and a release-lock journal to the same condition under the fd1ac03 results. The current test checks that the ordinary journal and staged files survive the first attempt. The handoff description also claims byte-identical staged content where the fixture checks only the sentinel\u2019s existence.",
      "blocking_rationale": "The required validation record gives conflicting instructions about whether the installation was restored and overstates what the handoff fixture measured.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Current recovery outcomes match the candidate-bound tests, and superseded behavior is attributed to its original commit.",
      "id": "R7-F4",
      "location": {
        "file": "docs/VALIDATION.md",
        "line": 113
      },
      "priority": "P2",
      "requested_correction": "Correct the current held-lock description or label it as the earlier result. Match the staged-content claim to the assertion actually executed.",
      "requested_evidence": "Cross-check the revised descriptions against the held-lock and handoff assertions and their controller log entries. A byte-preservation claim needs a content comparison.",
      "title": "The validation record gives opposite outcomes for held-lock recovery",
      "trigger": "An operator consults the current validation record after recovery encounters a held lock."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_verified",
      "finding_id": "R5-F2",
      "rationale": "Save-Journal writes a complete sibling file before replacement. The gate exercised failed replacement, preservation of the ordinary journal and lock, and successful retry. Setup rollback now surfaces failure to establish a recovery journal. R7-F3 concerns decoding of the newly written file."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R5-F3",
      "rationale": "Same-handle lock deletion and journal retirement protect the objects already verified. The recovery admission still uses a liveness observation made before selecting the journal and acquiring that run\u2019s lock."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R6-F1",
      "rationale": "The gate confirms rejection of malformed modern flags and a modern clean claim listing a changed file. The legacy fallback bypasses the same consistency check."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R6-F2",
      "rationale": "Immediate cleanup and the tested owner-profile collision preserve the sentinel. The isolated restoration branch still recursively deletes a planned target the run failed to create."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F3",
      "rationale": "The retirement-denial test confirmed saved status integrity-failed, scenarioStatus passed, lockReleased true, and journalRetired false. Recovery retired the journal after the denying handle closed."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R6-F4",
      "rationale": "Both double-quoted duplicate fixtures now fail as requested. The raw scan still misses declarations accepted by the subsequent Windows PowerShell decoder, leaving the same ambiguity on accepted inputs."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F5",
      "rationale": "Configuration remains a scalar string and uses ordinal case-insensitive comparison. The gate packaged Release with lowercase release and refused a Debug receipt for Release."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F6",
      "rationale": "The receipt comparison checks the four-part declared version for each current pin. The gate refused a receipt changing only the recorded UMM version to 0.33.0.0 and accepted the genuine control."
    }
  ],
  "request_id": "ksc-claude-umm-0311-package-refs-20261124-20261123222059-762f-r07-6d39ca",
  "round": 7,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "Cutscene Skip declares UMM 0.31.1. The build verifies UnityModManager 0.31.1.0 and Harmony12 1.2.0.1 at compiler input, and the package validator inspects the shipped DLL. Four prior corrections are verified. Recovery safety, receipt consistency, manifest uniqueness, and the validation record still block readiness.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Any extension of the enrolled review budget and the eventual disposition of draft PR #3, including merge or release, are owner decisions."
    ],
    "scope_reviewed": "Final correction review of KingmakerSkipCinematic PR #3 at the fixed candidate, covering the Skip-specific mission, all eight pending findings, and the directly affected build, package, recovery, and evidence paths.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
