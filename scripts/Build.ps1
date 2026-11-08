[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
Assert-RepositoryHygiene
Get-KingmakerConfiguration | Out-Null
Invoke-MSBuildChecked (Join-Path $root 'src\KingmakerCutsceneSkip\KingmakerCutsceneSkip.csproj') $Configuration
$dll = Join-Path $root "artifacts\bin\$Configuration\KingmakerCutsceneSkip\KingmakerCutsceneSkip.dll"
Assert-FileExists $dll 'Built mod DLL'
$git = Get-GitMetadata
# Build receipt consumed by Package.ps1: binds the DLL hash to the commit whose product inputs produced it.
$productChanges = @(Get-UncommittedProductChanges)
$result = [ordered]@{
    status = 'passed'
    configuration = $Configuration
    commit = $git.Commit
    dirty = $git.Dirty
    product_inputs_dirty = ($productChanges.Count -gt 0)
    product_input_changes = $productChanges
    dll = $dll
    dll_sha256 = Get-Sha256 $dll
    built_utc = (Get-Date).ToUniversalTime().ToString('o')
}
if ($result.product_inputs_dirty) { Write-Warning ('Built with uncommitted product changes; Package.ps1 will refuse this DLL: ' + ($productChanges -join '; ')) }
Write-JsonFile (Join-Path $root 'artifacts\qualification\build.json') $result
Write-Host "Build passed: $dll"
Write-Host "DLL SHA-256: $($result.dll_sha256)"
