[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string] $Configuration = 'Release',
    [string] $BuildReceipt,
    [switch] $AllowDirty
)

# Packages the already-built DLL (scripts\Build.ps1) as an installable Unity Mod Manager ZIP:
#   KingmakerCutsceneSkip\{Info.json, KingmakerCutsceneSkip.dll, README.md, LICENSE}
# No game assemblies, harness, saves or logs are included.
# Provenance: the DLL must be the one recorded in the build receipt (artifacts\qualification\build.json, written by
# Build.ps1), built from committed product inputs, and no product input may have changed between the build commit and
# the packaging commit (documentation-only commits are allowed). The manifest records both commits.

. (Join-Path $PSScriptRoot 'Common.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Get-RepositoryRoot
Assert-RepositoryHygiene
$git = Get-GitMetadata
if ($git.Dirty -and -not $AllowDirty) { throw 'Working tree has uncommitted changes; commit first so the package maps to a source revision (or pass -AllowDirty for a local trial).' }
if (-not $BuildReceipt) { $BuildReceipt = Join-Path $root 'artifacts\qualification\build.json' }

$info = Get-ProductInfo
$dll = Join-Path $root "artifacts\bin\$Configuration\KingmakerCutsceneSkip\KingmakerCutsceneSkip.dll"
Assert-FileExists $dll 'Built mod DLL (run scripts\Build.ps1 first)'
$fileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($dll).FileVersion
if (-not $fileVersion.StartsWith($info.Version + '.')) { throw "DLL file version $fileVersion does not match Info.json version $($info.Version)." }

# Bind the DLL to its build receipt and the receipt's commit to the packaging commit.
Assert-FileExists $BuildReceipt 'Build receipt (run scripts\Build.ps1)'
$receipt = Get-Content -LiteralPath $BuildReceipt -Raw | ConvertFrom-Json
$dllSha256 = Get-Sha256 $dll
if ($receipt.status -ne 'passed') { throw "Build receipt status is '$($receipt.status)', not passed." }
if ($receipt.configuration -ne $Configuration) { throw "Build receipt is for $($receipt.configuration), not $Configuration." }
if ($receipt.dll_sha256 -ne $dllSha256) { throw "DLL SHA-256 $dllSha256 does not match the build receipt ($($receipt.dll_sha256)); rebuild with scripts\Build.ps1." }
if (-not $receipt.commit -or $receipt.commit -eq 'UNBORN') { throw 'Build receipt has no source commit.' }
$receiptInputsDirty = if ($receipt.PSObject.Properties['product_inputs_dirty']) { [bool] $receipt.product_inputs_dirty } else { [bool] $receipt.dirty }
$problems = @()
if ($receiptInputsDirty) { $problems += "the DLL was built with uncommitted product changes" }
$changedSinceBuild = @(Get-ProductChangesBetween $receipt.commit $git.Commit)
if ($changedSinceBuild.Count -gt 0) { $problems += "product inputs changed since build commit $($receipt.commit): $($changedSinceBuild -join ', ')" }
$uncommittedProduct = @(Get-UncommittedProductChanges)
if ($uncommittedProduct.Count -gt 0) { $problems += "uncommitted product changes: $($uncommittedProduct -join '; ')" }
if ($problems.Count -gt 0) {
    if (-not $AllowDirty) { throw ('Package provenance check failed (rebuild from the current commit): ' + ($problems -join ' | ')) }
    Write-Warning ('Packaging despite provenance problems (-AllowDirty): ' + ($problems -join ' | '))
}

$outputDir = Join-Path $root 'artifacts\package'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$zipPath = Join-Path $outputDir "KingmakerCutsceneSkip-$($info.Version).zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

$entries = [ordered]@{
    'KingmakerCutsceneSkip/Info.json' = Join-Path $root 'Info.json'
    'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll' = $dll
    'KingmakerCutsceneSkip/README.md' = Join-Path $root 'README.md'
    'KingmakerCutsceneSkip/LICENSE' = Join-Path $root 'LICENSE'
}
$archive = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entry in $entries.GetEnumerator()) {
        Assert-FileExists $entry.Value $entry.Key
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $entry.Value, $entry.Key, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally { $archive.Dispose() }

$manifest = [ordered]@{
    product = $info.Id
    version = $info.Version
    build_commit = $receipt.commit
    package_commit = $git.Commit
    dirty = $git.Dirty
    provenance_verified = ($problems.Count -eq 0)
    provenance_problems = $problems
    zip = $zipPath
    zip_sha256 = Get-Sha256 $zipPath
    dll_sha256 = $dllSha256
    contents = @($entries.Keys)
}
Write-JsonFile (Join-Path $outputDir "KingmakerCutsceneSkip-$($info.Version).manifest.json") $manifest
Set-Content -LiteralPath "$zipPath.sha256" -Value ("{0}  {1}" -f $manifest.zip_sha256, [IO.Path]::GetFileName($zipPath)) -Encoding ASCII
Write-Host "Package: $zipPath"
Write-Host "ZIP SHA-256: $($manifest.zip_sha256)"
Write-Host "DLL SHA-256: $($manifest.dll_sha256) (built from $($receipt.commit), packaged at $($git.Commit))"
