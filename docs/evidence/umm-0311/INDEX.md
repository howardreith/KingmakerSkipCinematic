# UMM 0.31.1 baseline evidence

Machine-generated outputs exported 2026-11-24 05:54 UTC for candidate commit `d2ca1d9`. Each row names what produced that output (its
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
| `package-validation.json` | 50a92c9 (Package.ps1; docs only after d2ca1d9) | `f65d0209761d97734c3434981e07407b32fc6d9e304bd069fcf8a0841f6cce47` | `952d63a9cb05db0971d896e37d42684870e1d258f75870fed6e68b48f9bd3ac0` |
| `package-manifest.json` | 50a92c9 (Package.ps1; docs only after d2ca1d9) | `588495e45036dece361e9c3093b26cbc0f453df0210bf329f096acd78c42ab9a` | `0cb9215527ac3af8dff51ef615d48402ff1d7de4a70b30b0f71b8a8126a766fe` |
| `build-receipt.json` | 50a92c9 (Build.ps1, clean tree; docs only after d2ca1d9) | `a0531db6e11ee21e6bfa6144fd8c8d59d43b6f95c3957a456f579443f247b3e1` | `1ca722d29344f68f4e433806b4a7a06ac6b550fa7cc780d8e265ab1b8a691956` |
| `published-0.1.2-validation.json` | published v0.1.2 ZIP c1be6ae2, validated by the validator at d2ca1d9 | `f4fb4649d1ca3ca27c5f82c488170dca781899c1ea1c396061dd8689091d6732` | `d59acf92a806a5f7daf0ed42a59e09ee47202b1738508ef33ab9dbfaccc2a8ae` |
| `test-results.json` | `d2ca1d9` | `44aee78783a6c4e000441f2d17f182b5946268940452a3e774acb652445896e1` | `74465289d4a1c53ffb10ebfbe64d88af253ed13d37b27498cc46b8cace79a99a` |
| `package-provenance.json` | `d2ca1d9` | `0324447b139e386045337bae10c0026091e968b0a19c74a6e12b667cad26558b` | `6c5f949fd545a75152e9216511798a3b98ddd6832fd32191c452669ba9bd1d38` |
| `api-audit.json` | reused static audit of the unchanged frozen DLL a2a8706b, recorded for 5efdcb0 (first exported in f7e5387) | `bc2aeeb451f7f3eae71abc77416e310b2687becae957a6e12bdf4f1ac18a9a60` (original output, from its first export) | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` |
| `onboarding-check-project.json` | controller check-project record from enrollment (reused, first exported in f7e5387) | `d1efccf5122383446e591cd2c224b550118f724da51e42418a1db529800e2581` (original output, from its first export) | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` |
| `loader-profiles.md` | fleet loader-profile record (reused) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | audit tool source (reused) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | audit tool project (reused) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
