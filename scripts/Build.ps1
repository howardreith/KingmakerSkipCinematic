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
$result = [ordered]@{
    status = 'passed'
    configuration = $Configuration
    commit = $git.Commit
    dirty = $git.Dirty
    dll = $dll
    dll_sha256 = Get-Sha256 $dll
}
Write-JsonFile (Join-Path $root 'artifacts\qualification\build.json') $result
Write-Host "Build passed: $dll"
Write-Host "DLL SHA-256: $($result.dll_sha256)"
