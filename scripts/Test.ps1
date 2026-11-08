[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string] $Configuration = 'Release')

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$paths = Get-KingmakerConfiguration
$pinned = Initialize-PinnedReferences
Invoke-MSBuildChecked (Join-Path $root 'tests\KingmakerCutsceneSkip.Tests\KingmakerCutsceneSkip.Tests.csproj') $Configuration
$runner = Join-Path $root "artifacts\tests\$Configuration\KingmakerCutsceneSkip.Tests.exe"
Assert-FileExists $runner 'Test runner'
$prior = $env:KMCS_TEST_REFERENCE_DIRS
try {
    $env:KMCS_TEST_REFERENCE_DIRS = @($pinned, $paths.UnityModManagerDir, $paths.ManagedDir) -join [IO.Path]::PathSeparator
    $output = & $runner 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    $env:KMCS_TEST_REFERENCE_DIRS = $prior
}
$output | ForEach-Object { Write-Host $_ }
$summary = @($output | Where-Object { $_ -match '^RESULT total=(\d+) passed=(\d+) failed=(\d+)$' }) | Select-Object -Last 1
if (-not $summary) { throw 'Test runner did not emit its RESULT line.' }
$match = [regex]::Match([string] $summary, '^RESULT total=(\d+) passed=(\d+) failed=(\d+)$')
$status = 'failed'
if ($exitCode -eq 0) { $status = 'passed' }
Write-JsonFile (Join-Path $root 'artifacts\qualification\tests.json') ([ordered]@{
    status = $status
    total = [int] $match.Groups[1].Value
    passed = [int] $match.Groups[2].Value
    failed = [int] $match.Groups[3].Value
})
if ($exitCode -ne 0) { throw "Tests failed (exit=$exitCode)." }
& (Join-Path $PSScriptRoot 'Test-Provenance.ps1')
