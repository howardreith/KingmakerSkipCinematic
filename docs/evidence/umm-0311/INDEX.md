# UMM 0.31.1 baseline evidence

Machine-generated outputs for candidate commit `42b61a9c33beac91a091e3cd24fac56da4d0fd15`, exported 2026-11-24 04:16 UTC.
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

| File | Raw SHA-256 | Exported SHA-256 (Git blob) |
| --- | --- | --- |
| `package-validation.json` | `dbc047e5b0c6fd87df7c5690e193ec62c9c8c6088ff16e864554b3e224001a5a` | `e547ddd9aab2005021361d394ff488916d98930f83967077481385320a72c981` |
| `package-manifest.json` | `cd7a7f232f48d81b4cd7f600a3ecafda6a81078969d4fab2b60d826403d71ccd` | `b4e86c806baf27f86fa26bdb2a3160ec23ad22980cb1480ad13e0d0ee00769a2` |
| `build-receipt.json` | `8d571dd42a01714c7d98c1325370eba6a5099c53d9ae26553ab6ca8d525cae86` | `efc0b56c6a7524483afcafac8d1a139b1df74ce32d23b391725485871961195a` |
| `published-0.1.2-validation.json` | `f4fb4649d1ca3ca27c5f82c488170dca781899c1ea1c396061dd8689091d6732` | `d59acf92a806a5f7daf0ed42a59e09ee47202b1738508ef33ab9dbfaccc2a8ae` |
| `test-results.json` | `6d0d1ac45e6b01bdc7f7375cb4de1769f78fcb479363c200a329cf6a5d575b99` | `5721d8fee6ce76c7ceceb92cb9df7418c0cb3a0cb7a0eb6718e38e9aba1be872` |
| `api-audit.json` | `bc2aeeb451f7f3eae71abc77416e310b2687becae957a6e12bdf4f1ac18a9a60` | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` |
| `onboarding-check-project.json` | `d1efccf5122383446e591cd2c224b550118f724da51e42418a1db529800e2581` | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` |
| `loader-profiles.md` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
