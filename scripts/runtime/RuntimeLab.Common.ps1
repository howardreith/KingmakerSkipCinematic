Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Locks held by sibling Kingmaker labs on this machine. A run never starts while any exists.
$script:ForeignRuntimeLocks = @(
    'C:\Dev\KingmakerBuffPlannerLab\runtime-state\deployment.lock',
    'C:\Dev\KingmakerBuffPlannerLab\runtime-fixture-state\fixture.lock',
    'C:\Dev\KingmakerGunslingerLab\compatibility-state\compatibility.lock',
    'C:\Dev\KingmakerMemoryLeakResearchLab\runtime-state\kmld-runtime.lock',
    'C:\Dev\KingmakerMountedCombatLab\runtime-state\active-transaction.lock')

# Runs a native tool judged only by its exit code (reg.exe reports success on stderr).
function Invoke-NativeTool([string] $FilePath, [string[]] $Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & $FilePath @Arguments 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Get-OptionalProperty($object, [string] $name, $default) {
    $property = $object.PSObject.Properties[$name]
    if ($null -eq $property -or $null -eq $property.Value) { return $default }
    return $property.Value
}

function Get-LabPaths {
    $labRoot = [IO.Path]::GetFullPath((Join-Path (Get-RepositoryRoot) '..\..'))
    $ownerData = Join-Path $env:USERPROFILE 'AppData\LocalLow\Owlcat Games\Pathfinder Kingmaker'
    $steamExe = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam').SteamExe
    return [pscustomobject]@{
        Root = $labRoot
        State = Join-Path $labRoot 'runtime-state'
        Lock = Join-Path $labRoot 'runtime-state\runtime.lock'
        Journal = Join-Path $labRoot 'runtime-state\active-run.json'
        Evidence = Join-Path $labRoot 'runtime-evidence'
        Backups = Join-Path $labRoot 'runtime-backups'
        Profiles = Join-Path $labRoot 'runtime-profiles'
        Fixtures = Join-Path $labRoot 'fixtures'
        OwnerData = $ownerData
        OwnerSaves = Join-Path $ownerData 'Saved Games'
        PlayerLog = Join-Path $ownerData 'output_log.txt'
        RegistryKey = 'HKCU\Software\Owlcat Games\Pathfinder Kingmaker'
        RegistryPath = 'HKCU:\Software\Owlcat Games\Pathfinder Kingmaker'
        SteamExe = [IO.Path]::GetFullPath($steamExe)
        SteamRoot = Split-Path -Parent ([IO.Path]::GetFullPath($steamExe))
    }
}

function Assert-RuntimePreflight($lab) {
    if (Get-Process -Name Kingmaker -ErrorAction SilentlyContinue) { throw 'Kingmaker is already running; refusing to take over another session.' }
    foreach ($lock in $script:ForeignRuntimeLocks) {
        if (Test-Path -LiteralPath $lock) { throw "Another lab holds a runtime lock: $lock" }
    }
    if (Test-Path -LiteralPath $lab.Journal) { throw "An interrupted run journal exists ($($lab.Journal)); run with -RecoverOnly first." }
    $cloudLog = Join-Path $lab.SteamRoot 'logs\cloud_log.txt'
    $last = @(Select-String -LiteralPath $cloudLog -Pattern '\[AppID 640820\]' | Select-Object -Last 6 | ForEach-Object Line)
    if (-not ($last | Where-Object { $_ -match 'Sync Disabled' })) {
        throw 'Steam Cloud sync for Kingmaker is not proven disabled (cloud_log.txt); refusing to launch.'
    }
}

function Enter-RuntimeLock($lab, [string] $runId) {
    New-Item -ItemType Directory -Force -Path $lab.State | Out-Null
    $stream = [IO.File]::Open($lab.Lock, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $bytes = [Text.Encoding]::UTF8.GetBytes("runId=$runId`npid=$PID`nstartedUtc=$((Get-Date).ToUniversalTime().ToString('o'))`n")
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Dispose()
    return $lab.Lock
}

function Exit-RuntimeLock($lab, [string] $lock) {
    if ($lock -and (Test-Path -LiteralPath $lock)) { Remove-Item -LiteralPath $lock -Force }
}

function Save-Journal($lab, $journal) {
    $journal | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lab.Journal -Encoding UTF8
}

function Get-SaveManifest([string] $directory) {
    return @(Get-ChildItem -LiteralPath $directory -File -Force | Sort-Object Name | ForEach-Object {
        "{0}|{1}|{2}|{3}" -f $_.Name, $_.Length, $_.LastWriteTimeUtc.Ticks, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    })
}

function Compare-SaveManifest([string[]] $before, [string[]] $after) {
    $changes = @()
    $changes += @($before | Where-Object { $after -notcontains $_ } | ForEach-Object { 'changed/removed: ' + $_.Split('|')[0] })
    $changes += @($after | Where-Object { $before -notcontains $_ } | ForEach-Object { 'new/changed: ' + $_.Split('|')[0] })
    return ,$changes
}

function Resolve-FixtureSave($lab, [string] $name) {
    foreach ($candidate in @((Join-Path $lab.Fixtures $name), (Join-Path $lab.OwnerSaves $name))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw "Fixture save not found: $name"
}

function Start-OwnedKingmaker($lab, [string] $requestPath) {
    $launchedAt = Get-Date
    $arguments = @('-applaunch', '640820', '-popupwindow', '-screen-width', '1280', '-screen-height', '720', "-kmcsRequest=$requestPath")
    Start-Process -FilePath $lab.SteamExe -ArgumentList $arguments | Out-Null
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) {
        $process = Get-Process -Name Kingmaker -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -ge $launchedAt.AddSeconds(-2) } | Select-Object -First 1
        if ($process) { return $process }
        Start-Sleep -Milliseconds 500
    }
    throw 'Kingmaker did not start within 180s of the Steam launch.'
}

function Stop-OwnedKingmaker($process) {
    if ($process.HasExited) { return }
    $process.CloseMainWindow() | Out-Null
    if (-not $process.WaitForExit(20000)) {
        $process.Refresh()
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(20000) | Out-Null }
    }
}

# Restores Mods, UMM Params.xml and game registry settings exactly as recorded in the journal.
function Restore-RunJournal($lab, $journal) {
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Process -Name Kingmaker -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1 }
    if (Get-Process -Name Kingmaker -ErrorAction SilentlyContinue) { throw 'Kingmaker is still running; restoration deferred. Re-run with -RecoverOnly once it exits.' }

    $modsDir = [string] $journal.modsDir
    if ($journal.modsMoved) {
        $stagedRoot = [IO.Path]::GetFullPath($modsDir)
        if (Test-Path -LiteralPath $stagedRoot) {
            $unexpected = @(Get-ChildItem -LiteralPath $stagedRoot -Force | Where-Object { @($journal.staged) -notcontains $_.FullName })
            if ($unexpected.Count -gt 0) { throw "Staged Mods folder contains unexpected entries: $($unexpected.Name -join ', ')" }
            Remove-Item -LiteralPath $stagedRoot -Recurse -Force
        }
        Move-Item -LiteralPath $journal.modsOriginal -Destination $modsDir
    }
    else {
        foreach ($target in @($journal.staged)) {
            $full = [IO.Path]::GetFullPath($target)
            if (-not $full.StartsWith([IO.Path]::GetFullPath($modsDir) + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove outside Mods: $full" }
            if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
        }
    }

    if ($journal.paramsBackup -and $journal.paramsTarget -and (Test-Path -LiteralPath $journal.paramsBackup)) {
        Copy-Item -LiteralPath $journal.paramsBackup -Destination $journal.paramsTarget -Force
    }
    if ($journal.registryBackup -and (Test-Path -LiteralPath $journal.registryBackup)) {
        $import = Invoke-NativeTool 'reg.exe' @('import', [string] $journal.registryBackup)
        if ($import.ExitCode -ne 0) { Write-Warning "Registry import of the game settings failed: $($import.Output)" }
    }
    Remove-Item -LiteralPath $lab.Journal -Force -ErrorAction SilentlyContinue
}

function Restore-InterruptedRun($lab) {
    if (-not (Test-Path -LiteralPath $lab.Journal)) { Write-Host 'No interrupted run journal.'; return }
    $journal = Get-Content -LiteralPath $lab.Journal -Raw | ConvertFrom-Json
    Restore-RunJournal $lab $journal
    Exit-RuntimeLock $lab $lab.Lock
    Write-Host "Recovered interrupted run $($journal.runId)."
}

function Copy-RunLogs($lab, $game, [string] $evidence) {
    $umm = Join-Path $game.UnityModManagerDir 'Log.txt'
    if (Test-Path -LiteralPath $umm) { Copy-Item -LiteralPath $umm -Destination (Join-Path $evidence 'umm-log.txt') -Force }
    if (Test-Path -LiteralPath $lab.PlayerLog) { Copy-Item -LiteralPath $lab.PlayerLog -Destination (Join-Path $evidence 'player-log.txt') -Force }
}
