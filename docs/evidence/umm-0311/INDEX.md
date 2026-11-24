# UMM 0.31.1 baseline evidence

Machine-generated outputs exported 2026-11-24 15:29 UTC for candidate commit `48cff414a3d8da07f693efd0f333a7d5272aa61f`. Each row names what produced that output (its
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
| `package-validation.json` | 48cff41 (Package.ps1, clean tree; docs only after 91da7b6) | `4700541aa1474c387755a7a329ad4c1ad64cf01643841890c354fb5d70eab9ff` | `8ae28c76376ae8604c3631021fab3da8ed6a1644b5953b23d6cb57a433e6c9b0` |
| `package-manifest.json` | 48cff41 (Package.ps1, clean tree; docs only after 91da7b6) | `027da23be0fe505d35915e30741b002997d0ae1ea5d475241df42576517d6dca` | `9ab192bc74822a3c467ca2f224036ea57d17e8bbf078fc19aa133b75d9edd940` |
| `build-receipt.json` | 48cff41 (Build.ps1, clean tree; docs only after 91da7b6) | `299b044aacde44019f63df9553fc85049031bdbd136d0a04a78a9c795332c78e` | `fe0e36d2c9684c29af35b07990327cbf776ca60c25fff747a8c115fe4e957b84` |
| `published-0.1.2-validation.json` | published v0.1.2 ZIP c1be6ae2, validated by the validator at 91da7b6 | `607cf86ce4b1d984426763ed68147487caad205598cd95be761b92aebfea0417` | `af9e9c30e129f2e28f4384053ecd1bccf5bac96cecaf8d17ad834d74823784d2` |
| `test-results.json` | `91da7b6335a4feb04b6e18cd2ada7d65a0ab9f47` | `2eb16824fc7882bfc73d10853e5343fbd9b2f4ec42b0c211f6a2b8b06edde2e7` | `ac0f51058cf1609650bd5fc38d8b4b6e53e4ba4db75e046fbee99e35ad347850` |
| `package-provenance.json` | `91da7b6335a4feb04b6e18cd2ada7d65a0ab9f47` | `dd2130cfc14f0b1e2088bd7e5b9a20d79aa4c63c578cb8efa65cc9df56802cbe` | `bc2413c3883ac2b9d6801b82a6ae913c097adbfd925c208d77586b742b8e0a14` |
| `api-audit.json` | reused static audit of the unchanged frozen DLL a2a8706b, recorded for 5efdcb0 (first exported in f7e5387) | `bc2aeeb451f7f3eae71abc77416e310b2687becae957a6e12bdf4f1ac18a9a60` (original output, from its first export) | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` |
| `onboarding-check-project.json` | controller check-project record from enrollment (reused, first exported in f7e5387) | `d1efccf5122383446e591cd2c224b550118f724da51e42418a1db529800e2581` (original output, from its first export) | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` |
| `loader-profiles.md` | fleet loader-profile record (reused) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` (original output, from its first export) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | audit tool source (reused) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` (original output, from its first export) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | audit tool project (reused) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` (original output, from its first export) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
