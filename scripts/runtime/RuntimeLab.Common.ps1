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

# Journals arrive as an ordered hashtable (live run) or a PSCustomObject (read back for -RecoverOnly).
function ConvertTo-JournalTable($journal) {
    if ($journal -is [Collections.IDictionary]) { return $journal }
    $table = [ordered]@{}
    foreach ($property in $journal.PSObject.Properties) { $table[$property.Name] = $property.Value }
    return $table
}

# Mods step. Decided from the file system, not from flags, so it is correct whether an interruption happened before
# the owner's Mods folder was moved, after it, or half-way through an earlier restoration.
function Restore-JournalMods($journal) {
    $modsDir = [IO.Path]::GetFullPath([string] $journal.modsDir)
    if ($journal.modsOriginal) {
        # Isolated profile: the journal records the planned move before the owner's Mods folder is moved.
        $original = [IO.Path]::GetFullPath([string] $journal.modsOriginal)
        $originalExists = Test-Path -LiteralPath $original
        $modsExists = Test-Path -LiteralPath $modsDir
        if (-not $originalExists) {
            if ($modsExists) { return }   # move never happened, or an earlier restoration already moved it back
            throw "Neither the Mods folder ($modsDir) nor the moved original ($original) exists."
        }
        if ($modsExists) {
            $unexpected = @(Get-ChildItem -LiteralPath $modsDir -Force | Where-Object { @($journal.staged) -notcontains $_.FullName })
            if ($unexpected.Count -gt 0) { throw "Staged Mods folder contains unexpected entries: $($unexpected.Name -join ', ')" }
            Remove-Item -LiteralPath $modsDir -Recurse -Force
        }
        Move-Item -LiteralPath $original -Destination $modsDir
        return
    }

    foreach ($target in @($journal.staged)) {
        if (-not $target) { continue }
        $full = [IO.Path]::GetFullPath([string] $target)
        if (-not $full.StartsWith($modsDir + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove outside Mods: $full" }
        if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
    }
}

function Restore-JournalParams($journal) {
    if (-not $journal.paramsBackup) { return }
    if (-not (Test-Path -LiteralPath $journal.paramsBackup -PathType Leaf)) { throw "UMM Params.xml backup is missing: $($journal.paramsBackup)" }
    Copy-Item -LiteralPath $journal.paramsBackup -Destination $journal.paramsTarget -Force
    if ((Get-FileHash -LiteralPath $journal.paramsBackup).Hash -ne (Get-FileHash -LiteralPath $journal.paramsTarget).Hash) {
        throw "Params.xml does not match its backup after restoration: $($journal.paramsTarget)"
    }
}

function Restore-JournalRegistry($journal) {
    if (-not $journal.registryBackup) { return }
    if (-not (Test-Path -LiteralPath $journal.registryBackup -PathType Leaf)) { throw "Registry backup is missing: $($journal.registryBackup)" }
    $import = Invoke-NativeTool 'reg.exe' @('import', [string] $journal.registryBackup)
    if ($import.ExitCode -ne 0) { throw "Registry import of the game settings failed (exit $($import.ExitCode)): $($import.Output)" }
}

# Restores Mods, UMM Params.xml and game registry settings exactly as recorded in the journal. Every step is idempotent
# and recorded in the journal when it completes. The journal is deleted only after every step succeeded; otherwise it is
# kept (with the completed steps and the error) and the function throws, so -RecoverOnly can retry the remaining steps.
function Restore-RunJournal($lab, $journal) {
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Process -Name Kingmaker -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1 }
    if (Get-Process -Name Kingmaker -ErrorAction SilentlyContinue) { throw 'Kingmaker is still running; restoration deferred. Re-run with -RecoverOnly once it exits.' }

    $journal = ConvertTo-JournalTable $journal
    $completed = New-Object 'System.Collections.Generic.List[string]'
    foreach ($step in @($journal.completedSteps)) { if ($step) { $completed.Add([string] $step) } }
    $steps = [ordered]@{
        mods = { Restore-JournalMods $journal }
        params = { Restore-JournalParams $journal }
        registry = { Restore-JournalRegistry $journal }
    }
    $failures = @()
    foreach ($name in @($steps.Keys)) {
        if ($completed.Contains($name)) { continue }
        try {
            & $steps[$name]
            $completed.Add($name)
        }
        catch { $failures += "${name}: $($_.Exception.Message)" }
    }

    $journal.completedSteps = @($completed)
    if ($failures.Count -gt 0) {
        $journal.lastRestoreError = $failures -join '; '
        Save-Journal $lab $journal
        throw "Restoration incomplete; recovery journal kept at $($lab.Journal) (re-run with -RecoverOnly). $($failures -join '; ')"
    }
    if (Test-Path -LiteralPath $lab.Journal) { Remove-Item -LiteralPath $lab.Journal -Force }
}

function Restore-InterruptedRun($lab) {
    if (-not (Test-Path -LiteralPath $lab.Journal)) { Write-Host 'No interrupted run journal.'; return }
    $journal = Get-Content -LiteralPath $lab.Journal -Raw | ConvertFrom-Json
    Restore-RunJournal $lab $journal   # throws (journal and lock kept) unless every step succeeded
    Exit-RuntimeLock $lab $lab.Lock
    Write-Host "Recovered interrupted run $($journal.runId)."
}

function Copy-RunLogs($lab, $game, [string] $evidence) {
    $umm = Join-Path $game.UnityModManagerDir 'Log.txt'
    if (Test-Path -LiteralPath $umm) { Copy-Item -LiteralPath $umm -Destination (Join-Path $evidence 'umm-log.txt') -Force }
    if (Test-Path -LiteralPath $lab.PlayerLog) { Copy-Item -LiteralPath $lab.PlayerLog -Destination (Join-Path $evidence 'player-log.txt') -Force }
}

# ---------------------------------------------------------------------------------------------------------------------
# Disposable game copy and loader profiles. Replacing UMM affects the proxy DLL, its configuration and every file in the
# loader directory, so loader tests never touch the owner's installation: they run in a full copy under the lab, and the
# owner's installation is hashed before and after every run.
# ---------------------------------------------------------------------------------------------------------------------

function Get-LoaderProfileDocument {
    return Get-Content -LiteralPath (Join-Path $PSScriptRoot 'loader-profiles.json') -Raw | ConvertFrom-Json
}

function Get-GameCopyPaths([string] $copyRoot) {
    $managed = Join-Path $copyRoot 'Kingmaker_Data\Managed'
    return [pscustomobject]@{
        InstallDir = $copyRoot; ManagedDir = $managed; UnityModManagerDir = Join-Path $managed 'UnityModManager'
        ModsDir = Join-Path $copyRoot 'Mods'; Pristine = Join-Path $copyRoot '.lab-pristine'
    }
}

# Refuses anything but a copy inside the lab, so a mistyped path can never wipe the loader of a real installation.
function Assert-GameCopy($lab, [string] $copyRoot, [string] $ownerInstall) {
    $full = [IO.Path]::GetFullPath($copyRoot).TrimEnd('\')
    $owner = [IO.Path]::GetFullPath($ownerInstall).TrimEnd('\')
    $allowed = (Join-Path $lab.Root 'game-copies').TrimEnd('\') + '\'
    if ($full -ieq $owner -or $full.StartsWith($owner + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to use the owner's installation as a game copy: $full" }
    if (-not $full.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw "A game copy must live under $allowed (got $full)." }
    Assert-FileExists (Join-Path $full 'Kingmaker.exe') 'Game copy Kingmaker.exe'
    return $full
}

# One-time capture of the copy's as-copied loader state, so the owner's 0.33.0 set can be re-applied exactly.
function Initialize-GameCopy($paths) {
    $pristine = $paths.Pristine
    if (-not (Test-Path -LiteralPath $pristine)) {
        $building = "$pristine.building"
        if (Test-Path -LiteralPath $building) { Remove-Item -LiteralPath $building -Recurse -Force }
        New-Item -ItemType Directory -Path $building | Out-Null
        Copy-Item -LiteralPath $paths.UnityModManagerDir -Destination (Join-Path $building 'UnityModManager') -Recurse
        Copy-Item -LiteralPath $paths.ModsDir -Destination (Join-Path $building 'Mods') -Recurse
        foreach ($name in @('winhttp.dll', 'doorstop_config.ini')) { Copy-Item -LiteralPath (Join-Path $paths.InstallDir $name) -Destination $building }
        Move-Item -LiteralPath $building -Destination $pristine
    }
    Set-Content -LiteralPath (Join-Path $paths.InstallDir 'steam_appid.txt') -Value '640820' -Encoding ASCII -NoNewline
}

function Resolve-LoaderComponent($lab, $file) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $cache = Join-Path $lab.Root 'private\umm-distributions\cache'
    [IO.Directory]::CreateDirectory($cache) | Out-Null
    $sha = [Security.Cryptography.SHA256]::Create()
    $urlKey = (-join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($file.url)) | ForEach-Object { $_.ToString('x2') }))
    $sha.Dispose()
    $download = Join-Path $cache $urlKey
    if (-not (Test-Path -LiteralPath $download)) { Invoke-WebRequest -Uri $file.url -OutFile $download -UseBasicParsing }
    $archiveEntry = Get-OptionalProperty $file 'archiveEntry' $null
    if (-not $archiveEntry) { return $download }
    if ((Get-Sha256 $download) -ne $file.archiveSha256) { throw "Archive hash mismatch: $($file.url)" }
    $extracted = Join-Path $cache ($file.sha256 + '.bin')
    if (-not (Test-Path -LiteralPath $extracted)) {
        $archive = [IO.Compression.ZipFile]::OpenRead($download)
        try { [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry($archiveEntry), $extracted, $true) }
        finally { $archive.Dispose() }
    }
    return $extracted
}

# Clean install: the loader directory, proxy and proxy configuration are removed and rebuilt from one declared file set,
# so a profile can never be a mixture of old and new files. Returns the installed identity for the evidence directory.
function Install-LoaderProfile($lab, $paths, [string] $profileName) {
    $pristine = $paths.Pristine
    $installed = [ordered]@{ profile = $profileName; method = 'clean DoorstopProxy file set in a disposable game copy'; files = [ordered]@{} }
    Remove-Item -LiteralPath $paths.UnityModManagerDir -Recurse -Force
    foreach ($name in @('winhttp.dll', 'doorstop_config.ini')) { Remove-Item -LiteralPath (Join-Path $paths.InstallDir $name) -Force }

    if ($profileName -eq 'owner-0.33.0') {
        $installed.source = 'byte copy of the owner installation (UMM 0.33.0 Nexus distribution, Harmony 2.3.6)'
        Copy-Item -LiteralPath (Join-Path $pristine 'UnityModManager') -Destination $paths.UnityModManagerDir -Recurse
        foreach ($name in @('winhttp.dll', 'doorstop_config.ini')) { Copy-Item -LiteralPath (Join-Path $pristine $name) -Destination $paths.InstallDir }
        Remove-Item -LiteralPath (Join-Path $paths.UnityModManagerDir 'Log.txt') -Force -ErrorAction SilentlyContinue
    }
    else {
        $document = Get-LoaderProfileDocument
        $property = $document.profiles.PSObject.Properties[$profileName]
        if (-not $property) { throw "Unknown loader profile: $profileName" }
        $definition = $property.Value
        $installed.source = 'component-assembled from upstream NuGet packages and the UMM repository; not the Nexus ZIP'
        $installed.note = $definition.note
        $installed.ummVersion = $definition.ummVersion
        $installed.harmonyVersion = $definition.harmonyVersion
        New-Item -ItemType Directory -Path $paths.UnityModManagerDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $pristine 'UnityModManager\Config.xml') -Destination $paths.UnityModManagerDir
        foreach ($entry in $definition.files.PSObject.Properties) {
            $source = Resolve-LoaderComponent $lab $entry.Value
            if ((Get-Sha256 $source) -ne $entry.Value.sha256) { throw "Component hash mismatch for $($entry.Name)" }
            Copy-Item -LiteralPath $source -Destination (Join-Path $paths.InstallDir ($entry.Name -replace '/', '\')) -Force
        }
        [IO.File]::WriteAllText((Join-Path $paths.InstallDir 'doorstop_config.ini'), $document.doorstopConfig, [Text.Encoding]::ASCII)
    }

    foreach ($file in @(Get-ChildItem -LiteralPath $paths.UnityModManagerDir -File)) { $installed.files[$file.Name] = Get-Sha256 $file.FullName }
    foreach ($name in @('winhttp.dll', 'doorstop_config.ini')) { $installed.files[$name] = Get-Sha256 (Join-Path $paths.InstallDir $name) }
    return $installed
}

# Rebuilds the copy's Mods folder from the pristine set: none, the named mods, or all of them.
function Set-GameCopyMods($paths, [string] $modProfile, [string[]] $modSet) {
    if (Test-Path -LiteralPath $paths.ModsDir) { Remove-Item -LiteralPath $paths.ModsDir -Recurse -Force }
    New-Item -ItemType Directory -Path $paths.ModsDir | Out-Null
    $pristineMods = Join-Path $paths.Pristine 'Mods'
    $names = if ($modProfile -eq 'owner') { @(Get-ChildItem -LiteralPath $pristineMods -Directory | ForEach-Object Name) } else { @($modSet | Where-Object { $_ }) }
    foreach ($name in $names) {
        $source = Join-Path $pristineMods $name
        if (-not (Test-Path -LiteralPath $source)) { throw "Mod not found in the pristine set: $name" }
        Copy-Item -LiteralPath $source -Destination $paths.ModsDir -Recurse
    }
    return $names
}

# Every file a loader or mod change could affect in a real installation. Compared before and after each run.
function Get-InstallationManifest($game) {
    $files = New-Object System.Collections.ArrayList
    foreach ($name in @('winhttp.dll', 'doorstop_config.ini', 'Kingmaker.exe')) { [void] $files.Add((Get-Item -LiteralPath (Join-Path $game.InstallDir $name))) }
    [void] $files.Add((Get-Item -LiteralPath (Join-Path $game.ManagedDir 'Assembly-CSharp.dll')))
    foreach ($directory in @($game.UnityModManagerDir, $game.ModsDir)) {
        foreach ($file in @(Get-ChildItem -LiteralPath $directory -File -Recurse -Force)) { [void] $files.Add($file) }
    }
    return @($files | ForEach-Object { "{0}|{1}|{2}" -f $_.FullName, $_.Length, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } | Sort-Object)
}

function Start-KingmakerCopy($paths, [string] $requestPath) {
    $exe = Join-Path $paths.InstallDir 'Kingmaker.exe'
    $arguments = @('-popupwindow', '-screen-width', '1280', '-screen-height', '720', "-kmcsRequest=`"$requestPath`"")
    return Start-Process -FilePath $exe -WorkingDirectory $paths.InstallDir -ArgumentList $arguments -PassThru
}
