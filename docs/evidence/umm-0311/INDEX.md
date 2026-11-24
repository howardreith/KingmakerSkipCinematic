# UMM 0.31.1 baseline evidence

Machine-generated outputs exported 2026-11-24 06:16 UTC for candidate commit `883fb6e`. Each row names what produced that output (its
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
| `package-validation.json` | 50bac0d (Package.ps1; docs only after 883fb6e) | `8e27700bc1014de822ed9bbd0f9654a5f7f62aa2a70bc40fc52c82d0e7946845` | `f4d90156ff6403ea3b09ba74fb34afc42605923c7e255e05e15134208ef00588` |
| `package-manifest.json` | 50bac0d (Package.ps1; docs only after 883fb6e) | `c8bbe970a404f63c1a789b0eaa70aed495b79ee6fedb0b8a56e3a6eb462a1be4` | `4340393738bee30c58a6ceff45764eba6bd06893b44874d75de810d2df1f7df9` |
| `build-receipt.json` | 50bac0d (Build.ps1, clean tree; docs only after 883fb6e) | `16eb981ebc80d74f258f3ecca611526f204cd6f34654c07a79ca3564d6e7a9b6` | `768584be30bbabd8c47a08c12322af7d95e90bae5cd506983e78a2d6d69f059b` |
| `published-0.1.2-validation.json` | published v0.1.2 ZIP c1be6ae2, validated by the validator at 883fb6e | `f4fb4649d1ca3ca27c5f82c488170dca781899c1ea1c396061dd8689091d6732` | `d59acf92a806a5f7daf0ed42a59e09ee47202b1738508ef33ab9dbfaccc2a8ae` |
| `test-results.json` | `883fb6e` | `fe7780bc60918bb733a94e97ec89d3aa7d7d1c1932e8b140881f64e8d186dfcb` | `0d09684ed9cde1e6d98aa63fe237cc7a513be4de71e381a0b14303d51536808c` |
| `package-provenance.json` | `883fb6e` | `b76aed599575bc9735a4878fa6feed4d80b5b48703a81474da3595c258fc662e` | `21717765a3f8c6869b6d96d6a71498d1192be087d4e81c4e483ce5f785ba95c4` |
| `api-audit.json` | reused static audit of the unchanged frozen DLL a2a8706b, recorded for 5efdcb0 (first exported in f7e5387) | `bc2aeeb451f7f3eae71abc77416e310b2687becae957a6e12bdf4f1ac18a9a60` (original output, from its first export) | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` |
| `onboarding-check-project.json` | controller check-project record from enrollment (reused, first exported in f7e5387) | `d1efccf5122383446e591cd2c224b550118f724da51e42418a1db529800e2581` (original output, from its first export) | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` |
| `loader-profiles.md` | fleet loader-profile record (reused) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | audit tool source (reused) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | audit tool project (reused) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
