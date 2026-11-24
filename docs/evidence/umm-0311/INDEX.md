# UMM 0.31.1 baseline evidence

Machine-generated outputs exported 2026-11-24 05:30 UTC for candidate commit `879c19d`. Each row names what produced that output (its
source commit, or the reused input it describes); outputs produced at another commit are identified there.
Only local path prefixes were replaced: `<repo>` (this checkout or its temporary clone root), `<temp>`, `<game>`
(the Kingmaker installation, read-only), `<buildtools>`, `<reference-assemblies>`, `<dotnet>`, `<controller>` (the agent-review controller), `<dev>` (the owner's development folder), `<steam>`, `<user-profile>`, `<fleet>` (the owner's fleet mission folder,
outside this repository). Line endings were normalized to LF and a UTF-8 byte-order mark was dropped; nothing else was
edited. Raw SHA-256 is of the original output bytes. Exported SHA-256 is of the committed Git blob of each file in this
folder (LF bytes; a Windows checkout with `core.autocrlf` may show CRLF in the working tree, so hash the blob, not the
checked-out file). To verify one, from the repository root (Git Bash or any POSIX shell with sha256sum; the second
command, with Python, works in Windows PowerShell and cmd.exe):

```
git cat-file blob HEAD:docs/evidence/umm-0311/<file> | sha256sum
python -c "import hashlib,subprocess,sys; print(hashlib.sha256(subprocess.check_output(['git','cat-file','blob','HEAD:docs/evidence/umm-0311/'+sys.argv[1]])).hexdigest())" <file>
```

| File | Produced by | Raw SHA-256 | Exported SHA-256 (Git blob) |
| --- | --- | --- | --- |
| `package-validation.json` | 4e4a8e5 (Package.ps1; 879c19d changes only a test) | `4d46b2655b61cd088354ded0e2279caea89afbc9c91ecc5bd7f223bae04afbc3` | `759ecef7ca5b3ff2bbabdc195e331271596ea7d85b45a3856384ffae5decf2a4` |
| `package-manifest.json` | 4e4a8e5 (Package.ps1; 879c19d changes only a test) | `b21fb4a579907d3fe5c4ec9bf15c8fe7b820405145edf925ba0df184d3ed6020` | `ae751b3000b53281d6871bc771752e1bb605eeb433f56c602c1c5f18bbff0642` |
| `build-receipt.json` | 4e4a8e5 (Build.ps1; 879c19d changes only a test) | `1c126ae5f55cd6348bb3a720ac242ec9b7382d4cf4e3358c5cd5ca18b3ebc35b` | `7d77f6914627421366b5d64caaa6ed13796ebfb7dd2f40edd67cac43d2f6b44b` |
| `published-0.1.2-validation.json` | published v0.1.2 ZIP c1be6ae2, validated by the validator at 4e4a8e5 | `f4fb4649d1ca3ca27c5f82c488170dca781899c1ea1c396061dd8689091d6732` | `d59acf92a806a5f7daf0ed42a59e09ee47202b1738508ef33ab9dbfaccc2a8ae` |
| `test-results.json` | `879c19d` | `faaaff8214dae6284d8a37b6a04df726b0ff732e8c45fc174a8fadf59db7cef1` | `b7de7eb001058e6ebe66c56a7770f27e9f03911de804b35197d7c35201af94fa` |
| `package-provenance.json` | `879c19d` | `3dee4f343a1b9a6f7057948d7940df75fd13d18a1f12b2b5d1d6e0e0adf57e4c` | `adc8269c7e52f201fb8d799b6b0e1f112b31c36ed527eaf515b814225af3aa45` |
| `api-audit.json` | reused static audit of the unchanged frozen DLL a2a8706b, recorded for 5efdcb0 (committed in f7e5387) | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` |
| `onboarding-check-project.json` | controller check-project record from enrollment (reused, committed in f7e5387) | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` |
| `loader-profiles.md` | fleet loader-profile record (reused) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | audit tool source (reused) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | audit tool project (reused) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
