[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string] $Configuration = 'Release',
    [switch] $AllowDirty
)

# Packages the already-built DLL (scripts\Build.ps1) as an installable Unity Mod Manager ZIP:
#   KingmakerCutsceneSkip\{Info.json, KingmakerCutsceneSkip.dll, README.md, LICENSE}
# No game assemblies, harness, saves or logs are included. The package records the source commit and hashes.

. (Join-Path $PSScriptRoot 'Common.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Get-RepositoryRoot
Assert-RepositoryHygiene
$git = Get-GitMetadata
if ($git.Dirty -and -not $AllowDirty) { throw 'Working tree has uncommitted changes; commit first so the package maps to a source revision (or pass -AllowDirty for a local trial).' }

$info = Get-ProductInfo
$dll = Join-Path $root "artifacts\bin\$Configuration\KingmakerCutsceneSkip\KingmakerCutsceneSkip.dll"
Assert-FileExists $dll 'Built mod DLL (run scripts\Build.ps1 first)'
$fileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($dll).FileVersion
if (-not $fileVersion.StartsWith($info.Version + '.')) { throw "DLL file version $fileVersion does not match Info.json version $($info.Version)." }

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
    commit = $git.Commit
    dirty = $git.Dirty
    zip = $zipPath
    zip_sha256 = Get-Sha256 $zipPath
    dll_sha256 = Get-Sha256 $dll
    contents = @($entries.Keys)
}
Write-JsonFile (Join-Path $outputDir "KingmakerCutsceneSkip-$($info.Version).manifest.json") $manifest
Set-Content -LiteralPath "$zipPath.sha256" -Value ("{0}  {1}" -f $manifest.zip_sha256, [IO.Path]::GetFileName($zipPath)) -Encoding ASCII
Write-Host "Package: $zipPath"
Write-Host "ZIP SHA-256: $($manifest.zip_sha256)"
Write-Host "DLL SHA-256: $($manifest.dll_sha256) (commit $($git.Commit))"
