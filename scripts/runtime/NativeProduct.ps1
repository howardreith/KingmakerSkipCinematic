# Product preparation for the native runner, kept separate so it can be exercised with temporary files.
Set-StrictMode -Version Latest
if (-not ('KmcsFileIdentity' -as [type])) { . (Join-Path $PSScriptRoot '..\FileIdentity.ps1') }

# One decision for requirements, summary and staging: no product (-NoProduct; a supplied ZIP is then only a comparison
# archive, recorded but never validated or staged), the packaged candidate (-ProductZip) or the built DLL.
function Resolve-NativeProductPlan([switch] $NoProduct, [string] $ProductZip, [string] $ProductDll) {
    if ($NoProduct) {
        $comparison = $null
        if ($ProductZip) { $comparison = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProductZip); Assert-FileExists $comparison 'Comparison ZIP' }
        return [pscustomobject]@{ Mode = 'none'; Source = $null; ComparisonZip = $comparison }
    }
    if ($ProductZip) {
        $zip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProductZip)
        Assert-FileExists $zip 'Product ZIP'
        return [pscustomobject]@{ Mode = 'zip'; Source = $zip; ComparisonZip = $null }
    }
    Assert-FileExists $ProductDll 'Built product DLL (run scripts\Build.ps1)'
    return [pscustomobject]@{ Mode = 'dll'; Source = [IO.Path]::GetFullPath($ProductDll); ComparisonZip = $null }
}

# Freezes the product first (a private copy of the ZIP or of the built DLL), validates that copy with the standalone
# validator in its own process and returns it with the validator's report. The private folder is removed on any failure.
# The bare-DLL route freezes Info.json with the DLL (-InfoPath, default the checkout's) and validates the pair.
function New-ValidatedNativeProduct($Plan, [string] $Validator, [string] $InfoPath = (Join-Path (Get-RepositoryRoot) 'Info.json'), [string] $TempRoot = [IO.Path]::GetTempPath()) {
    if ($Plan.Mode -eq 'none') { return $null }
    $private = Join-Path $TempRoot ('kmcs-product-' + [Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $private | Out-Null
        $copy = Join-Path $private $(if ($Plan.Mode -eq 'zip') { 'product.zip' } else { 'KingmakerCutsceneSkip.dll' })
        [IO.File]::Copy($Plan.Source, $copy)
        $report = Join-Path $private 'validation.json'
        $kind = if ($Plan.Mode -eq 'zip') { '-PackagePath' } else { '-DllPath' }
        $extra = @()
        $infoCopy = $null
        if ($Plan.Mode -eq 'dll') { $infoCopy = Join-Path $private 'Info.json'; [IO.File]::Copy($InfoPath, $infoCopy); $extra = @('-InfoPath', $infoCopy) }
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Validator $kind $copy @extra -ReportPath $report | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'The product failed package validation; nothing was locked or staged.' }
        $validation = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        if (-not (Test-OrdinalEqual (Get-Sha256 $copy) ([string]$validation.input_sha256))) { throw 'The private product copy changed after validation.' }
        if ($infoCopy -and -not (Test-OrdinalEqual (Get-Sha256 $infoCopy) ([string]$validation.info_sha256))) { throw 'The private manifest copy changed after validation.' }
        return [pscustomobject]@{ Mode = $Plan.Mode; PrivateDirectory = $private; File = $copy; Info = $infoCopy; Validation = $validation }
    }
    catch {
        if (Test-Path -LiteralPath $private) { Remove-Item -LiteralPath $private -Recurse -Force }
        throw
    }
}

# Stages exactly the validated bytes into <ModsDir>\KingmakerCutsceneSkip and returns the staged DLL digest, which must
# equal the validated DLL. ZIP: the private archive is read once into memory, that snapshot must have the validated
# digest, and only its four package entries are written, from the snapshot, into the product folder (any other entry
# refuses before anything is written). DLL: copied with the validated Info.json. In both routes the staged manifest must
# be the validated one before any explicit -ProductManagerVersion override; on any failure the product folder is removed.
function Install-ValidatedNativeProduct($Product, [string] $ModsDir, [scriptblock] $OnCreated = $null) {
    $target = Join-Path $ModsDir 'KingmakerCutsceneSkip'
    if (Test-Path -LiteralPath $target) { throw "The product folder already exists: $target" }
    $entries = $null
    if ($Product.Mode -eq 'zip') {
        Add-Type -AssemblyName System.IO.Compression
        $zipBytes = $null
        [void][KmcsFileIdentity]::ReadSnapshot([string]$Product.File, [ref]$zipBytes)
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $zipSha = ([BitConverter]::ToString($hasher.ComputeHash($zipBytes))).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
        if (-not (Test-OrdinalEqual $zipSha ([string]$Product.Validation.input_sha256))) { throw 'The private product ZIP is not the validated archive; nothing was staged.' }
        $allowed = @('KingmakerCutsceneSkip/Info.json', 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll', 'KingmakerCutsceneSkip/README.md', 'KingmakerCutsceneSkip/LICENSE')
        $entries = [ordered]@{}
        $stream = [IO.MemoryStream]::new($zipBytes, $false)
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
        try {
            foreach ($entry in $archive.Entries) {
                $name = [string]$entry.FullName
                if (@($allowed | Where-Object { Test-OrdinalEqual $_ $name }).Count -ne 1 -or $entries.Contains($name)) { throw "The product ZIP has an entry outside the validated package: $name; nothing was staged." }
                $reader = $entry.Open(); $buffer = [IO.MemoryStream]::new()
                try { $reader.CopyTo($buffer); $entries[$name] = $buffer.ToArray() } finally { $buffer.Dispose(); $reader.Dispose() }
            }
        }
        finally { $archive.Dispose(); $stream.Dispose() }
        if ($entries.Count -ne $allowed.Count) { throw 'The product ZIP does not contain the four package entries; nothing was staged.' }
    }
    $created = $false
    try {
        # New-Item refuses an existing folder, so a folder that appeared after the check above is never claimed.
        New-Item -ItemType Directory -Path $target | Out-Null
        $created = $true
        if ($OnCreated) { & $OnCreated $target }
        if ($Product.Mode -eq 'zip') {
            foreach ($name in @($entries.Keys)) { [IO.File]::WriteAllBytes((Join-Path $target ($name.Substring('KingmakerCutsceneSkip/'.Length))), [byte[]]$entries[$name]) }
        }
        else {
            Copy-Item -LiteralPath $Product.File -Destination $target
            Copy-Item -LiteralPath $Product.Info -Destination (Join-Path $target 'Info.json')
        }
        # The staged manifest is the validated one (before any explicit -ProductManagerVersion override is applied).
        if (-not (Test-Sha256String $Product.Validation.info_sha256) -or -not (Test-OrdinalEqual (Get-Sha256 (Join-Path $target 'Info.json')) ([string]$Product.Validation.info_sha256))) { throw 'The staged Info.json differs from the validated manifest.' }
        $staged = Get-Sha256 (Join-Path $target 'KingmakerCutsceneSkip.dll')
        if (-not (Test-OrdinalEqual $staged ([string]$Product.Validation.dll_sha256))) { throw 'The staged product DLL differs from the validated product.' }
        return $staged
    }
    catch {
        if ($created -and (Test-Path -LiteralPath $target)) { Remove-Item -LiteralPath $target -Recurse -Force }
        throw
    }
}

# The UMM Id in one mod folder's Info.json (UMM's manifest); $null when the folder has none. A manifest that cannot be
# read cannot be shown not to be Cutscene Skip, so it refuses.
function Get-ModManifestId([string] $Folder) {
    $manifest = Join-Path $Folder 'Info.json'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { return $null }
    try { return [string]((Get-Content -LiteralPath $manifest -Raw) | ConvertFrom-Json).Id }
    catch { throw "The manifest of mod folder '$(Split-Path -Leaf $Folder)' cannot be read: $($_.Exception.Message)" }
}
# One record per folder of a Mods directory, hidden folders included (UMM loads them), independent of folder names.
function Get-ModFolderRecords([string] $ModsDir) {
    if (-not (Test-Path -LiteralPath $ModsDir -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $ModsDir -Directory -Force | ForEach-Object { [pscustomobject]@{ Folder = $_.Name; Id = (Get-ModManifestId $_.FullName) } })
}
function Test-ShippingModId([string] $Id) { return [string]::Equals($Id, [string](Get-ProductLoadIdentity).Id, [StringComparison]::OrdinalIgnoreCase) }
# The folders of a Mods directory that carry the shipping UMM Id (compared as UMM does, ignoring case), any folder name.
function Get-ShippingModFolders([string] $ModsDir) { return @(Get-ModFolderRecords $ModsDir | Where-Object { Test-ShippingModId $_.Id } | ForEach-Object { $_.Folder }) }
# Before staging (with or without a product): the effective Mods directory must not already carry the shipping Id, so
# the validated candidate is the only Cutscene Skip that can load and a no-product control has none.
function Assert-NoInstalledShippingMod([string] $ModsDir) {
    $found = @(Get-ShippingModFolders $ModsDir)
    if ($found.Count -gt 0) { throw "The Mods directory already contains Cutscene Skip (UMM Id $((Get-ProductLoadIdentity).Id) in folder '$($found -join "', '")'); refusing before staging." }
}
function Assert-NoProductControlMods([string] $ModsDir) { Assert-NoInstalledShippingMod $ModsDir }
# After product staging: exactly one folder carries the shipping Id, and it is the staged one.
function Assert-OnlyStagedShippingMod([string] $ModsDir, [string] $StagedFolder) {
    $found = @(Get-ShippingModFolders $ModsDir)
    if ($found.Count -ne 1 -or -not (Test-OrdinalEqual $found[0] $StagedFolder)) { throw "After staging, the Mods directory must contain Cutscene Skip only in '$StagedFolder'; found: '$($found -join "', '")'." }
}

# Final steps of a run, each independent. The private copy is removed first and its outcome is part of the saved host
# summary (a failed removal makes the run integrity-failed); then the summary is written; then this run's own lock is
# released whenever restoration succeeded, even if a step failed (the failures are surfaced afterwards). On incomplete
# restoration the lock and journal are kept for -RecoverOnly.
function Complete-NativeRun($Lab, [string] $Lock, [bool] $Restored, $Summary, [string] $SummaryPath, $Product, [string] $RunId) {
    $ErrorActionPreference = 'Stop'
    $failures = New-Object System.Collections.Generic.List[string]
    try {
        Remove-ValidatedNativeProduct $Product
        $Summary['privateCopyRemoved'] = ($null -ne $Product)
    }
    catch {
        $failures.Add("private product cleanup failed: $($_.Exception.Message)")
        $Summary['privateCopyRemoved'] = $false
        $Summary['privateCopyCleanupError'] = $_.Exception.Message
        if (-not $Summary.Contains('scenarioStatus')) { $Summary['scenarioStatus'] = $Summary['status'] }
        $Summary['status'] = 'integrity-failed'
        $Summary['integrityFailures'] = @(@($(if ($Summary.Contains('integrityFailures')) { $Summary['integrityFailures'] })) + @("private product cleanup failed: $($_.Exception.Message)") | Where-Object { $_ })
    }
    if ($Restored) {
        # Only this run's lock is released. If that fails, the outcome is part of the summary and a release-only recovery
        # journal is kept, so -RecoverOnly can retry the release for this run (and only this run).
        $released = $false
        try {
            Exit-RuntimeLock $Lab $Lock $RunId
            $Summary['lockReleased'] = $true
            $released = $true
        }
        catch {
            $failures.Add("lock release failed: $($_.Exception.Message)")
            $Summary['lockReleased'] = $false
            $Summary['lockReleaseError'] = $_.Exception.Message
            if (-not $Summary.Contains('scenarioStatus')) { $Summary['scenarioStatus'] = $Summary['status'] }
            $Summary['status'] = 'integrity-failed'
            $Summary['integrityFailures'] = @(@($(if ($Summary.Contains('integrityFailures')) { $Summary['integrityFailures'] })) + @("lock release failed: $($_.Exception.Message)") | Where-Object { $_ })
            # The retryable release-lock journal is kept for this run only while this run still owns the lock (never over
            # another run's journal: Save-Journal refuses that).
            if ([string]::Equals((Get-RuntimeLockOwner $Lab), $RunId, [StringComparison]::Ordinal)) {
                try { Save-Journal $Lab ([ordered]@{ runId = $RunId; phase = 'release-lock' }) }
                catch { $failures.Add("release-lock journal write failed: $($_.Exception.Message)") }
            }
        }
        if ($released) {
            # Release confirmed: retire this run's release-lock journal. A failure is an integrity failure of the saved
            # outcome (the journal stays for -RecoverOnly, which retires it once it can).
            try { Remove-ReleaseLockJournal $Lab $RunId; $Summary['journalRetired'] = $true }
            catch {
                $failures.Add("release-lock journal retirement failed: $($_.Exception.Message)")
                $Summary['journalRetired'] = $false
                if (-not $Summary.Contains('scenarioStatus')) { $Summary['scenarioStatus'] = $Summary['status'] }
                $Summary['status'] = 'integrity-failed'
                $Summary['integrityFailures'] = @(@($(if ($Summary.Contains('integrityFailures')) { $Summary['integrityFailures'] })) + @("release-lock journal retirement failed: $($_.Exception.Message)") | Where-Object { $_ })
            }
        }
    }
    try { Write-JsonFile $SummaryPath $Summary } catch { $failures.Add("summary write failed: $($_.Exception.Message)") }
    if (-not $Restored) { Write-Warning 'Run lock and recovery journal kept; run Invoke-NativeRun.ps1 -RecoverOnly after resolving the error.' }
    if ($failures.Count -gt 0) { throw ($failures -join '; ') }
}

function Remove-ValidatedNativeProduct($Product) {
    if ($null -eq $Product) { return }
    $private = [string]$Product.PrivateDirectory
    if ((Split-Path -Leaf $private) -like 'kmcs-product-*' -and (Test-Path -LiteralPath $private)) { Remove-Item -LiteralPath $private -Recurse -Force -ErrorAction Stop }
}

# The UMM Ids a game copy never inherits from the profile it copies: the shipping mod, in every mode. A no-product control
# (with or without a comparison ZIP) then has none, and a product run has only the validated candidate staged later.
function Get-InheritedModExclusions($Plan) { return @([string](Get-ProductLoadIdentity).Id) }

# Takes this run's lock and creates its evidence and backup folders. A failure after the lock is taken releases only this
# invocation's lock (nothing was changed yet) and rethrows; another lab's lock is never touched.
function Enter-NativeRunDirectories($Lab, [string] $RunId) {
    $lock = Enter-RuntimeLock $Lab $RunId
    try {
        $evidence = Join-Path $Lab.Evidence $RunId
        $backup = Join-Path $Lab.Backups $RunId
        foreach ($directory in @($evidence, $backup)) { [void][IO.Directory]::CreateDirectory($directory) }
        if (-not (Test-Path -LiteralPath $evidence -PathType Container) -or -not (Test-Path -LiteralPath $backup -PathType Container)) { throw 'The run evidence or backup folder could not be created.' }
        return [pscustomobject]@{ Lock = $lock; Evidence = $evidence; Backup = $backup }
    }
    catch {
        $setupError = $_
        try { Exit-RuntimeLock $Lab $lock $RunId }
        catch {
            # The same recoverable handoff as a completed run: a release-only journal for this run.
            $releaseError = $_.Exception.Message
            try { Save-Journal $Lab ([ordered]@{ runId = $RunId; phase = 'release-lock' }) }
            catch { throw "Run setup failed ($($setupError.Exception.Message)), its lock could not be released ($releaseError) and no recovery journal could be written ($($_.Exception.Message)); the lock $lock needs manual inspection." }
            throw "Run setup failed ($($setupError.Exception.Message)) and its lock could not be released ($releaseError); run -RecoverOnly."
        }
        throw $setupError
    }
}
