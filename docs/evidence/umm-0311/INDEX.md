# UMM 0.31.1 baseline evidence

Machine-generated outputs for candidate commit `5efdcb068f29183c3b29fc007477fa2658b7c9b7`, exported 2026-11-24 03:21 UTC.
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
| `package-validation.json` | `9e5a6b7a9fda2537fd9a76002e72e69b1375520cc4aea88c514a12e5db67261a` | `070101357c7f646f37ddc312f72e7d1922788dcb45c5ae5ae8a4e6d1da29e4ea` |
| `package-manifest.json` | `06e21dcf594ac8aa17189b5d0ccbbb5784db9cd221be3ce0fb31bc40a5052bb3` | `737ba1d5f385336966d9568ef1eac1ca8167cf2f0c7cc083e109ab7cd58bc78d` |
| `build-receipt.json` | `766a97c05ec3cf1711ab6c4c917b6722fef8b3e3e6542f991f7cbe2577f4fcd1` | `9d218b9273b2b15eaba29ca53a68996c18a7cf608f35a56625328a316412fde8` |
| `published-0.1.2-validation.json` | `3ca82bc14103aa21852874687048ec301daef5d2b1b8a75f072f8441d5a70e6d` | `69baf21007578df24b66ee9131605155a0d2c8f497b4566287d14c8afb663836` |
| `test-results.json` | `dd6b159ed8fc954862bf5364f2177437ba8344dd9d7bbef6ce6cba88e4cbb463` | `1722e5654b5cf431a5a9da09a14c6a99571f1f69889c3b1fbb03fed1c7275323` |
| `api-audit.json` | `bc2aeeb451f7f3eae71abc77416e310b2687becae957a6e12bdf4f1ac18a9a60` | `1185ca9b388ef38f4c994d5c8455d3811965c31368a319d3bce1aefa0edfe1bf` |
| `onboarding-check-project.json` | `d1efccf5122383446e591cd2c224b550118f724da51e42418a1db529800e2581` | `c67b8d2bcb671cb58e940525f73943179d6cf39a3adcd2d77e540e0a018a5608` |
| `loader-profiles.md` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
