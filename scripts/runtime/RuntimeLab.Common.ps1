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

# The lock is opened once, exclusively (no sharing) and with delete access; its owner is read through that handle and
# the file is deleted through the same handle, so it cannot be replaced between the ownership check and the removal.
if (-not ('KmcsRuntimeLock' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class KmcsRuntimeLock {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);
    [StructLayout(LayoutKind.Sequential)] struct FileDispositionInfo { [MarshalAs(UnmanagedType.U1)] public bool DeleteFile; }
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetFileInformationByHandle(SafeFileHandle handle, int infoClass, ref FileDispositionInfo info, uint size);
    public static FileStream OpenExclusive(string path) {
        SafeFileHandle handle = CreateFileW(path, 0x80000000u | 0x00010000u, 0u, IntPtr.Zero, 3u, 0u, IntPtr.Zero);
        if (handle.IsInvalid) throw new IOException("The runtime lock cannot be opened exclusively: " + new Win32Exception(Marshal.GetLastWin32Error()).Message);
        return new FileStream(handle, FileAccess.Read);
    }
    public static void DeleteWhenClosed(FileStream lockStream) { SetDelete(lockStream, true); }
    public static void SetDelete(FileStream stream, bool delete) {
        FileDispositionInfo info = new FileDispositionInfo(); info.DeleteFile = delete;
        if (!SetFileInformationByHandle(stream.SafeFileHandle, 4, ref info, 1u)) throw new IOException("The file cannot be marked for deletion: " + new Win32Exception(Marshal.GetLastWin32Error()).Message);
    }
}
'@
}

function Get-RuntimeLockRunIds([string] $Text) {
    return @($Text -split "`r?`n" | Where-Object { $_.StartsWith('runId=', [StringComparison]::Ordinal) } | ForEach-Object { $_.Substring(6) })
}

# Releases this lab's runtime lock for one named run. Only the configured lab lock is ever removed, only when it records
# exactly that run (runId=<id>), and through the handle that read it. Another run's lock is refused and left in place; a
# failed removal is an error. An absent lock is already released.
function Read-ExclusiveText($Stream) {
    $reader = [IO.StreamReader]::new($Stream, [Text.Encoding]::UTF8, $true, 4096, $true)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

# Opens this lab's lock exclusively (no sharing, with delete access) and verifies through that handle that it records
# exactly this run. While the caller holds the returned handle nobody can release, replace or re-create the lock, so a
# successor cannot start. Returns $null when the lock is absent (already released).
function Open-OwnedRuntimeLock($lab, [string] $RunId) {
    if ([string]::IsNullOrEmpty($RunId)) { throw 'A runtime lock is held or released only for a named run.' }
    if (-not (Test-Path -LiteralPath $lab.Lock)) { return $null }
    $lockStream = [KmcsRuntimeLock]::OpenExclusive($lab.Lock)
    try {
        $recorded = @(Get-RuntimeLockRunIds (Read-ExclusiveText $lockStream))
        if ($recorded.Count -ne 1 -or -not [string]::Equals($recorded[0], $RunId, [StringComparison]::Ordinal)) { throw "The runtime lock $($lab.Lock) belongs to run '$($recorded -join ',')', not '$RunId'; it is left in place." }
        return $lockStream
    }
    catch { $lockStream.Dispose(); throw }
}

# Releases this lab's runtime lock for one named run. Only the configured lab lock is ever removed, only when it records
# exactly that run (runId=<id>), and through the handle that read it. Another run's lock is refused and left in place; a
# failed removal is an error. An absent lock is already released. A handle from Open-OwnedRuntimeLock may be passed.
function Exit-RuntimeLock($lab, [string] $lock, [string] $RunId, $HeldStream = $null) {
    if ([string]::IsNullOrEmpty($RunId)) { throw 'A runtime lock is released only for a named run.' }
    if (-not $lock -or -not [string]::Equals([IO.Path]::GetFullPath($lock), [IO.Path]::GetFullPath([string]$lab.Lock), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Only this lab's runtime lock ($($lab.Lock)) is released here; refused: $lock"
    }
    $lockStream = if ($null -ne $HeldStream) { $HeldStream } else { Open-OwnedRuntimeLock $lab $RunId }
    if ($null -eq $lockStream) { return }
    try { [KmcsRuntimeLock]::DeleteWhenClosed($lockStream) }
    finally { $lockStream.Dispose() }
}

# The run ID this lab's lock records now ('' when absent or unreadable); read-only.
function Get-RuntimeLockOwner($lab) {
    try { if (Test-Path -LiteralPath $lab.Lock) { $ids = @(Get-RuntimeLockRunIds ([IO.File]::ReadAllText($lab.Lock))); if ($ids.Count -eq 1) { return $ids[0] } } } catch { }
    return ''
}

# Retires this run's release-lock journal through one exclusive handle: the journal is read, checked (phase release-lock,
# this run) and deleted through that handle, so another run's journal is never removed.
function Remove-ReleaseLockJournal($lab, [string] $RunId) {
    if (-not (Test-Path -LiteralPath $lab.Journal)) { return }
    $journalStream = [KmcsRuntimeLock]::OpenExclusive($lab.Journal)
    try {
        $current = (Read-ExclusiveText $journalStream) | ConvertFrom-Json
        if ($current.PSObject.Properties['phase'] -and [string]$current.phase -ceq 'release-lock' -and [string]::Equals([string]$current.runId, $RunId, [StringComparison]::Ordinal)) {
            [KmcsRuntimeLock]::DeleteWhenClosed($journalStream)
        }
    }
    finally { $journalStream.Dispose() }
}

# Publishes a journal atomically: the complete document is written to a temporary file beside it and then replaces the
# journal in one operation, so a failed or interrupted publication leaves the previous complete journal. A journal that
# names another run is never overwritten.
function Save-Journal($lab, $journal) {
    $runId = if ($journal -is [Collections.IDictionary]) { [string]$journal['runId'] } else { [string]$journal.runId }
    if (Test-Path -LiteralPath $lab.Journal) {
        $existing = Get-Content -LiteralPath $lab.Journal -Raw | ConvertFrom-Json
        $existingRun = if ($existing -and $existing.PSObject.Properties['runId']) { [string]$existing.runId } else { '' }
        if (-not [string]::Equals($existingRun, $runId, [StringComparison]::Ordinal)) { throw "The recovery journal $($lab.Journal) belongs to run '$existingRun', not '$runId'; it is left in place." }
    }
    $temporary = $lab.Journal + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, ($journal | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $lab.Journal) { [IO.File]::Replace($temporary, $lab.Journal, [NullString]::Value) } else { [IO.File]::Move($temporary, $lab.Journal) }
    }
    finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue } }
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

    # Only folders this run created (recorded in 'created' right after creation) are removed; a recorded target this run
    # did not create (for example one that another process claimed first) is left in place.
    $owned = if ($journal.Contains('created')) { @($journal.created) } else { @() }
    foreach ($target in $owned) {
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
# and recorded in the journal when it completes. After every step succeeded the journal is replaced (one write) by this
# run's release-lock journal, so a record of the owned transaction exists until the lock release is confirmed; otherwise
# it is kept (with the completed steps and the error) and the function throws, so -RecoverOnly can retry the steps.
function Restore-RunJournal($lab, $journal, $OwnedLock) {
    # Ownership is held, not just checked: the caller passes this run's open lock handle (Open-OwnedRuntimeLock) and keeps
    # it until restoration and the journal handoff are complete.
    if ($null -eq $OwnedLock) { throw "Restoration needs this run's open runtime lock; nothing was changed." }
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
    Save-Journal $lab ([ordered]@{ runId = [string]$journal.runId; phase = 'release-lock' })
}

# -RecoverOnly. The configured lab lock is the authority: the journal must name a run, and that run must own this lab's
# lock, before anything is restored or released (a journal's own lock path is never used). Restoration hands over to a
# release-lock journal; the journal is retired only after the lock release is confirmed, so a failed release can be
# retried, and a successor's lock and journal are never touched.
# Recovery never acts for a run whose owning process is still alive (it is restoring or finishing on its own): the lock
# records the owner's process ID and start time; a live process with that ID that started no later than the lock is the
# owner. The current process is exempt (a run's own finalizer and in-process fixtures).
function Assert-RuntimeLockOwnerInactive($lab) {
    if (-not (Test-Path -LiteralPath $lab.Lock)) { return }
    $text = ''; try { $text = [IO.File]::ReadAllText($lab.Lock) } catch { return }
    $pidLine = @($text -split "`r?`n" | Where-Object { $_.StartsWith('pid=', [StringComparison]::Ordinal) } | ForEach-Object { $_.Substring(4) })
    $startLine = @($text -split "`r?`n" | Where-Object { $_.StartsWith('startedUtc=', [StringComparison]::Ordinal) } | ForEach-Object { $_.Substring(11) })
    $ownerPid = 0
    if ($pidLine.Count -ne 1 -or -not [int]::TryParse($pidLine[0], [ref]$ownerPid) -or $ownerPid -eq $PID) { return }
    $process = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
    if (-not $process) { return }
    $started = [DateTime]::MinValue
    if ($startLine.Count -eq 1 -and [DateTime]::TryParse($startLine[0], [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$started)) {
        try { if ($process.StartTime.ToUniversalTime() -gt $started.ToUniversalTime()) { return } } catch { }
    }
    throw "The run that owns $($lab.Lock) is still active (process $ownerPid); recovery changes nothing while it runs."
}

function Restore-InterruptedRun($lab) {
    if (-not (Test-Path -LiteralPath $lab.Journal)) { Write-Host 'No interrupted run journal.'; return }
    Assert-RuntimeLockOwnerInactive $lab
    $journal = Get-Content -LiteralPath $lab.Journal -Raw | ConvertFrom-Json
    $runId = if ($journal.PSObject.Properties['runId'] -and $journal.runId -is [string]) { [string]$journal.runId } else { '' }
    $releaseOnly = $journal.PSObject.Properties['phase'] -and [string]$journal.phase -ceq 'release-lock'
    if ($releaseOnly) {
        if ([string]::IsNullOrEmpty($runId)) { throw 'The release-lock journal names no run; the lock and journal are left in place.' }
        if (Test-Path -LiteralPath $lab.Lock) { Exit-RuntimeLock $lab $lab.Lock $runId }   # refuses another run's lock
        Remove-ReleaseLockJournal $lab $runId
        Write-Host "Released the runtime lock of run $runId."
        return
    }
    if ([string]::IsNullOrEmpty($runId)) { throw 'The recovery journal names no run; nothing was changed.' }
    # Ownership is established before any change and held through restoration, the handoff and the lock release.
    $owned = Open-OwnedRuntimeLock $lab $runId
    if ($null -eq $owned) { throw "The recovery journal's run '$runId' holds no runtime lock ($($lab.Lock)); nothing was changed." }
    try {
        # The journal is read again under the held lock: it is this run's current record.
        $journal = Get-Content -LiteralPath $lab.Journal -Raw | ConvertFrom-Json
        if (-not [string]::Equals([string]$journal.runId, $runId, [StringComparison]::Ordinal)) { throw 'The recovery journal changed while the lock was being taken; nothing was changed.' }
        Restore-RunJournal $lab $journal $owned   # throws (journal and lock kept) unless every step succeeded
    }
    catch { $owned.Dispose(); throw }
    Exit-RuntimeLock $lab $lab.Lock $runId $owned   # on failure the release-lock journal remains for a retry
    Remove-ReleaseLockJournal $lab $runId
    Write-Host "Recovered interrupted run $runId."
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
function Set-GameCopyMods($paths, [string] $modProfile, [string[]] $modSet, [string[]] $ExcludeModIds = @()) {
    if (Test-Path -LiteralPath $paths.ModsDir) { Remove-Item -LiteralPath $paths.ModsDir -Recurse -Force }
    New-Item -ItemType Directory -Path $paths.ModsDir | Out-Null
    $pristineMods = Join-Path $paths.Pristine 'Mods'
    $names = if ($modProfile -eq 'owner') { @(Get-ChildItem -LiteralPath $pristineMods -Directory -Force | ForEach-Object Name) } else { @($modSet | Where-Object { $_ }) }
    # Mods whose UMM Id is excluded (the shipping mod for a no-product control) are never copied, whatever their folder
    # is called. The Ids come from each folder's Info.json; an unreadable manifest refuses the copy.
    # Only the selected folders' manifests are read.
    if (@($ExcludeModIds).Count -gt 0) {
        $names = @($names | Where-Object {
            $source = Join-Path $pristineMods $_
            if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Mod not found in the pristine set: $_" }
            $id = Get-ModManifestId $source
            -not @($ExcludeModIds | Where-Object { [string]::Equals($_, $id, [StringComparison]::OrdinalIgnoreCase) })
        })
    }
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
