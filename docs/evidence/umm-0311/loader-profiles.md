# Loader profiles used for the static API audit (component-assembled; NOT official UMM distribution ZIPs)

Each profile = the author's (newman55) NuGet `unitymodmanager` package `lib/net35/UnityModManager.dll`
+ the Harmony2 that UnityModManager.dll itself references, taken from the official `Lib.Harmony` NuGet
package's `lib/net48/0Harmony.dll` (the variant UMM installs: the owner's installed 0Harmony 2.3.6.0 is
byte-identical to Lib.Harmony 2.3.6 net48) + 0Harmony12 1.2.0.1 (pinned newman55 commit 10cfb1cc bytes,
identical to the owner's installed copy). `owner-0.33.0` is a copy of the owner's live install (read-only copy).

| Profile | UnityModManager | Harmony2 (0Harmony) | 0Harmony12 | Provenance |
|---|---|---|---|---|
| 0.31.1 | 0.31.1.0 sha 2e038ff2… (nupkg 05a82b66…) | 2.3.1.1 net48 sha 5f7ad0df… (nupkg b9096d3e…) | 1.2.0.1 aa1cd483… | component-assembled from official NuGet packages |
| 0.32.4 | 0.32.4.0 sha 1387468b… (nupkg a8438e92…) | 2.3.6.0 net48 sha df043f05… (nupkg 498f99c5…) | 1.2.0.1 aa1cd483… | component-assembled from official NuGet packages |
| owner-0.33.0 | 0.33.0.0 sha 63e5baf7… | 2.3.6.0 sha df043f05… | 1.2.0.1 aa1cd483… (+0Harmony-1.2 e6bf8079…) | owner-install copy (measured 2026-11-23) |
| 0.33.4 (newest stable: author NuGet 2026-11-19; GitHub HEAD 3d14bf0d csproj Version 0.33.4) | 0.33.4.0 sha c5ed5617… (nupkg 7cbab8ed…) | 2.4.3.0 net48 sha ddc070b5… (nupkg f07af11a…) | 1.2.0.1 aa1cd483… | component-assembled from official NuGet packages |
