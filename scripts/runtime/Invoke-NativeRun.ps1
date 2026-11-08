<#
.SYNOPSIS
    Runs one scripted native Kingmaker test of Cutscene Skip and always restores the installation afterwards.

.DESCRIPTION
    Safety model (shared-machine aware):
      * refuses to start while Kingmaker runs or another lab holds a runtime lock; holds its own lock for the run;
      * requires Steam Cloud sync to be disabled/offline for App 640820;
      * hashes the owner's real "Saved Games" before and after; any change fails the run;
      * the harness redirects all persistent data to a disposable per-run profile (saves and area cache);
      * backs up UMM Params.xml and the game's registry settings, stages mods transactionally, and restores all of
        it in a finally block, driven by a recovery journal that -RecoverOnly can replay after an interruption.
        Every change to the installation is recorded in the journal before it is made. The journal is kept until every
        restoration step succeeded; a failed restoration also keeps the run lock and fails the run.
      * the run passes only when the scenario passed, the installation was restored and the owner's saves are unchanged;
        otherwise the script exits with an error.

.PARAMETER Scenario
    Path to a scenario JSON: { "save": "<file in fixture dir or owner saves>", "steps": [ ... ], "captureEveryFrames": 4 }.

.PARAMETER ModProfile
    isolated: only Cutscene Skip and the harness are installed. owner: the owner's normal Mods set plus both.
#>
[CmdletBinding()]
param(
    [string] $Scenario,
    [ValidateSet('isolated', 'owner')][string] $ModProfile = 'isolated',
    [ValidateSet('Debug', 'Release')][string] $Configuration = 'Release',
    [string] $Label,
    [int] $TimeoutSeconds = 900,
    [switch] $NoProduct,
    [switch] $RecoverOnly
)

. (Join-Path $PSScriptRoot '..\Common.ps1')
. (Join-Path $PSScriptRoot 'RuntimeLab.Common.ps1')

$lab = Get-LabPaths
if ($RecoverOnly) {
    Restore-InterruptedRun $lab
    return
}

if (-not $Scenario) { throw '-Scenario is required.' }
$scenarioData = Get-Content -LiteralPath $Scenario -Raw | ConvertFrom-Json
if (-not $Label) { $Label = [IO.Path]::GetFileNameWithoutExtension($Scenario) }
$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') + '-' + $Label + '-' + $ModProfile + $(if ($NoProduct) { '-noproduct' } else { '' })
$game = Get-KingmakerConfiguration
$root = Get-RepositoryRoot
$productDir = Join-Path $root "artifacts\bin\$Configuration\KingmakerCutsceneSkip"
$harnessDir = Join-Path $root "artifacts\bin\$Configuration\RuntimeHarness"
Assert-FileExists (Join-Path $productDir 'KingmakerCutsceneSkip.dll') 'Built product DLL (run scripts\Build.ps1)'
Assert-FileExists (Join-Path $harnessDir 'KingmakerCutsceneSkip.RuntimeHarness.dll') 'Built harness DLL'

Assert-RuntimePreflight $lab
$lock = Enter-RuntimeLock $lab $runId
$evidence = Join-Path $lab.Evidence $runId
$backup = Join-Path $lab.Backups $runId
New-Item -ItemType Directory -Force -Path $evidence, $backup | Out-Null
$summary = [ordered]@{ runId = $runId; modProfile = $ModProfile; scenario = $Scenario; noProduct = [bool] $NoProduct; status = 'started' }
$journal = [ordered]@{ runId = $runId; modProfile = $ModProfile; modsDir = $game.ModsDir; backup = $backup; staged = @(); modsMoved = $false; registryBackup = $null; paramsBackup = $null; paramsTarget = $null; modsOriginal = $null; completedSteps = @() }
$savesBefore = $null
try {
    $savesBefore = Get-SaveManifest $lab.OwnerSaves
    $summary.ownerSaveCount = @($savesBefore).Count
    $summary.productDllSha256 = Get-Sha256 (Join-Path $productDir 'KingmakerCutsceneSkip.dll')
    $summary.harnessDllSha256 = Get-Sha256 (Join-Path $harnessDir 'KingmakerCutsceneSkip.RuntimeHarness.dll')
    $summary.git = Get-GitMetadata

    # Configuration backups (restored in finally).
    $params = Join-Path $game.UnityModManagerDir 'Params.xml'
    # A backup is recorded in the journal only once it exists, so recovery never restores from a missing file.
    $paramsBackup = Join-Path $backup 'Params.xml'
    Copy-Item -LiteralPath $params -Destination $paramsBackup
    $journal.paramsBackup = $paramsBackup
    $journal.paramsTarget = $params
    Save-Journal $lab $journal
    $registryBackup = Join-Path $backup 'game-settings.reg'
    $export = Invoke-NativeTool 'reg.exe' @('export', $lab.RegistryKey, $registryBackup, '/y')
    if ($export.ExitCode -ne 0) { throw "Registry export of the game settings failed: $($export.Output)" }
    $journal.registryBackup = $registryBackup
    Save-Journal $lab $journal

    # Mod staging.
    if ($ModProfile -eq 'isolated') {
        # Persist the planned move first: recovery inspects both locations, so an interruption on either side of the
        # move is recoverable.
        $original = $game.ModsDir + '.kmcs-' + $runId + '.original'
        if (Test-Path -LiteralPath $original) { throw "Refusing to overwrite an existing Mods backup: $original" }
        $journal.modsOriginal = $original
        Save-Journal $lab $journal
        Move-Item -LiteralPath $game.ModsDir -Destination $original
        $journal.modsMoved = $true
        Save-Journal $lab $journal
        New-Item -ItemType Directory -Path $game.ModsDir | Out-Null
    }
    $deploy = @(@{ Source = $harnessDir; Name = 'KingmakerCutsceneSkipRuntimeHarness'; Info = Join-Path $root 'tools\RuntimeHarness\Info.json' })
    if (-not $NoProduct) { $deploy += @{ Source = $productDir; Name = 'KingmakerCutsceneSkip'; Info = Join-Path $root 'Info.json' } }
    foreach ($item in $deploy) {
        $target = Join-Path $game.ModsDir $item.Name
        if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite an existing mod folder: $target" }
        New-Item -ItemType Directory -Path $target | Out-Null
        $journal.staged += $target
        Save-Journal $lab $journal
        Copy-Item -LiteralPath (Join-Path $item.Source ($(if ($item.Name -eq 'KingmakerCutsceneSkip') { 'KingmakerCutsceneSkip.dll' } else { 'KingmakerCutsceneSkip.RuntimeHarness.dll' }))) -Destination $target
        Copy-Item -LiteralPath $item.Info -Destination (Join-Path $target 'Info.json')
    }

    # Disposable profile and request.
    $profile = Join-Path $lab.Profiles $runId
    $profileSaves = Join-Path $profile 'Saved Games'
    New-Item -ItemType Directory -Force -Path $profileSaves | Out-Null
    $fixtureSaves = @($scenarioData.save) + @(Get-OptionalProperty $scenarioData 'extraSaves' @())
    foreach ($name in $fixtureSaves) { Copy-Item -LiteralPath (Resolve-FixtureSave $lab $name) -Destination (Join-Path $profileSaves $name) }
    $request = [ordered]@{
        runId = $runId; evidenceDir = $evidence; profileDir = $profile; save = $scenarioData.save
        timeoutSeconds = $TimeoutSeconds - 60; exitAfterCompletion = $true
        captureEveryFrames = Get-OptionalProperty $scenarioData 'captureEveryFrames' 4
        steps = $scenarioData.steps
    }
    $requestPath = Join-Path $evidence 'runtime-request.json'
    $request | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $requestPath -Encoding UTF8

    $process = Start-OwnedKingmaker $lab $requestPath
    $summary.gamePid = $process.Id
    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) {
        $summary.timedOut = $true
        Stop-OwnedKingmaker $process
    }
    $resultPath = Join-Path $evidence 'runtime-result.json'
    if (Test-Path -LiteralPath $resultPath) {
        $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        $summary.status = $result.status
        $summary.failure = $result.failure
    }
    else { $summary.status = 'no-result' }
}
catch {
    $summary.status = 'host-error'
    $summary.failure = $_.ToString()
    throw
}
finally {
    $restored = $false
    try {
        Restore-RunJournal $lab $journal
        $restored = $true
    }
    catch {
        $summary.restorationError = $_.Exception.Message
        Write-Warning ("INSTALLATION RESTORATION FAILED: " + $_.Exception.Message)
    }
    $summary.restored = $restored
    try { Copy-RunLogs $lab $game $evidence } catch { Write-Warning "Could not copy run logs: $($_.Exception.Message)" }

    $integrityFailures = @()
    if (-not $restored) { $integrityFailures += 'installation restoration failed' }
    if ($null -ne $savesBefore) {
        try {
            $diff = Compare-SaveManifest $savesBefore (Get-SaveManifest $lab.OwnerSaves)
            $summary.ownerSavesUnchanged = ($diff.Count -eq 0)
            if ($diff.Count -gt 0) {
                $summary.ownerSaveChanges = $diff
                $integrityFailures += 'owner saves changed'
                Write-Warning ("OWNER SAVES CHANGED DURING RUN: " + ($diff -join '; '))
            }
        }
        catch {
            $summary.ownerSavesUnchanged = $null
            $integrityFailures += "owner save verification failed: $($_.Exception.Message)"
        }
    }

    $summary.scenarioStatus = $summary.status
    if ($integrityFailures.Count -gt 0) {
        $summary.status = 'integrity-failed'
        $summary.integrityFailures = $integrityFailures
    }
    Write-JsonFile (Join-Path $evidence 'host-summary.json') $summary
    if ($restored) { Exit-RuntimeLock $lab $lock }
    else { Write-Warning "Run lock and recovery journal kept; run '$PSCommandPath -RecoverOnly' after resolving the error." }
    Write-Host "Run $runId finished: $($summary.status) $($summary.failure) $(if ($integrityFailures.Count -gt 0) { '[' + ($integrityFailures -join '; ') + ']' })"
    Write-Host "Evidence: $evidence"
}

# Reached only when no exception escaped; a host error has already been rethrown above.
if ($summary.status -ne 'passed') { throw "Run $runId did not pass: $($summary.status)." }
