# UMM 0.31.1 baseline evidence

Machine-generated outputs exported 2026-11-24 15:57 UTC for candidate commit `9f35cb26d58038e0511b15953c4a62de154a7f2d`. Each row names what produced that output (its
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
| `package-validation.json` | 9f35cb2 (Package.ps1, clean tree; docs only after fd1ac03) | `834d87aed0484cb3236301d8c8ac7a70254d73914a1929e5d3267590a230477c` | `bfc6b24c130d698f0c773050fc6e5e6bcf9ebb1f3ff1342be0e47bdbc1f0e884` |
| `package-manifest.json` | 9f35cb2 (Package.ps1, clean tree; docs only after fd1ac03) | `6103b733d6c204656446f4d44912587df62858637cceede66f670c45fa8d4041` | `6d0d3ccd006c235be432c9aafe6a5e65a0c6046426fe6632f2c5efb384511e75` |
| `build-receipt.json` | 9f35cb2 (Build.ps1, clean tree; docs only after fd1ac03) | `f9aa859b757e5b14c02199a4bcdb4e8c2b1c47104f32bfcffc1479e006ddeb17` | `3b9d3b76944d0da2f6576e2af2b2c45cef11484dcf2f0ae77a8acabb70daa216` |
| `published-0.1.2-validation.json` | published v0.1.2 ZIP c1be6ae2, validated by the validator at fd1ac03 | `607cf86ce4b1d984426763ed68147487caad205598cd95be761b92aebfea0417` | `af9e9c30e129f2e28f4384053ecd1bccf5bac96cecaf8d17ad834d74823784d2` |
| `test-results.json` | `fd1ac039f6afea8fff4b3109c9ae687c34107150` | `7285f31e13b18b4a29b7dd7de9016c28db2ccbca09ab39197de8b3220340385d` | `03660e8f7486df004d439105772c656aa321841ce0b9e16e566f68a8117a19dc` |
| `package-provenance.json` | `fd1ac039f6afea8fff4b3109c9ae687c34107150` | `05c328cd1868958ae11f6dcc8170871acdf4ac5df024f706ff5fd602483b2279` | `7d3c47b9ce44f3322b7ac62f694dc0b16a808fac6898771f42ec4825d1647b40` |
| `api-audit.json` | reused static audit of the unchanged frozen DLL a2a8706b, recorded for 5efdcb0 (first exported in f7e5387) | `bc2aeeb451f7f3eae71abc77416e310b2687becae957a6e12bdf4f1ac18a9a60` (original output, from its first export) | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` |
| `onboarding-check-project.json` | controller check-project record from enrollment (reused, first exported in f7e5387) | `d1efccf5122383446e591cd2c224b550118f724da51e42418a1db529800e2581` (original output, from its first export) | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` |
| `loader-profiles.md` | fleet loader-profile record (reused) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` (original output, from its first export) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | audit tool source (reused) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` (original output, from its first export) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | audit tool project (reused) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` (original output, from its first export) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
