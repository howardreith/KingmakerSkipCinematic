# Product preparation for the native runner, kept separate so it can be exercised with temporary files.
Set-StrictMode -Version Latest

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
        if ((Get-Sha256 $copy) -cne [string]$validation.input_sha256) { throw 'The private product copy changed after validation.' }
        if ($infoCopy -and (Get-Sha256 $infoCopy) -cne [string]$validation.info_sha256) { throw 'The private manifest copy changed after validation.' }
        return [pscustomobject]@{ Mode = $Plan.Mode; PrivateDirectory = $private; File = $copy; Info = $infoCopy; Validation = $validation }
    }
    catch {
        if (Test-Path -LiteralPath $private) { Remove-Item -LiteralPath $private -Recurse -Force }
        throw
    }
}

# Stages exactly the validated bytes into <ModsDir>\KingmakerCutsceneSkip (ZIP: extracted; DLL: copied with the given
# Info.json) and returns the staged DLL digest, which must equal the validated DLL.
function Install-ValidatedNativeProduct($Product, [string] $ModsDir) {
    $target = Join-Path $ModsDir 'KingmakerCutsceneSkip'
    if ($Product.Mode -eq 'zip') { Expand-Archive -LiteralPath $Product.File -DestinationPath $ModsDir }
    else {
        New-Item -ItemType Directory -Path $target | Out-Null
        Copy-Item -LiteralPath $Product.File -Destination $target
        Copy-Item -LiteralPath $Product.Info -Destination (Join-Path $target 'Info.json')
        # The staged manifest is the validated one (before any explicit -ProductManagerVersion override is applied).
        if ((Get-Sha256 (Join-Path $target 'Info.json')) -cne [string]$Product.Validation.info_sha256) { throw 'The staged Info.json differs from the validated manifest.' }
    }
    $staged = Get-Sha256 (Join-Path $target 'KingmakerCutsceneSkip.dll')
    if ($staged -cne [string]$Product.Validation.dll_sha256) { throw 'The staged product DLL differs from the validated product.' }
    return $staged
}

# The UMM Id of each mod folder, from its Info.json (UMM's manifest), whatever the folder is called. A folder whose
# manifest cannot be read cannot be shown not to be Cutscene Skip.
function Get-ModFolderIds([string] $ModsDir) {
    $ids = [ordered]@{}
    if (-not (Test-Path -LiteralPath $ModsDir -PathType Container)) { return $ids }
    foreach ($folder in @(Get-ChildItem -LiteralPath $ModsDir -Directory)) {
        $manifest = Join-Path $folder.FullName 'Info.json'
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { $ids[$folder.Name] = $null; continue }
        try { $ids[$folder.Name] = [string]((Get-Content -LiteralPath $manifest -Raw) | ConvertFrom-Json).Id }
        catch { throw "The manifest of mod folder '$($folder.Name)' cannot be read: $($_.Exception.Message)" }
    }
    return $ids
}
# A no-product control must not include the shipping mod (UMM Id KingmakerCutsceneSkip, compared as UMM does, ignoring
# case) under any folder name.
function Assert-NoProductControlMods([string] $ModsDir) {
    $productId = [string](Get-ProductLoadIdentity).Id
    $ids = Get-ModFolderIds $ModsDir
    foreach ($folder in $ids.Keys) {
        if ([string]::Equals([string]$ids[$folder], $productId, [StringComparison]::OrdinalIgnoreCase)) {
            throw "The no-product control would include Cutscene Skip (UMM Id $productId in folder '$folder'); refusing the control."
        }
    }
}

# Final steps of a run, each independent. The private copy is removed first and its outcome is part of the saved host
# summary (a failed removal makes the run integrity-failed); then the summary is written; then this run's own lock is
# released whenever restoration succeeded, even if a step failed (the failures are surfaced afterwards). On incomplete
# restoration the lock and journal are kept for -RecoverOnly.
function Complete-NativeRun($Lab, [string] $Lock, [bool] $Restored, $Summary, [string] $SummaryPath, $Product) {
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
    try { Write-JsonFile $SummaryPath $Summary } catch { $failures.Add("summary write failed: $($_.Exception.Message)") }
    if ($Restored) { Exit-RuntimeLock $Lab $Lock }
    else { Write-Warning 'Run lock and recovery journal kept; run Invoke-NativeRun.ps1 -RecoverOnly after resolving the error.' }
    if ($failures.Count -gt 0) { throw ($failures -join '; ') }
}

function Remove-ValidatedNativeProduct($Product) {
    if ($null -eq $Product) { return }
    $private = [string]$Product.PrivateDirectory
    if ((Split-Path -Leaf $private) -like 'kmcs-product-*' -and (Test-Path -LiteralPath $private)) { Remove-Item -LiteralPath $private -Recurse -Force -ErrorAction Stop }
}

# The UMM Ids a game copy must not inherit from the profile it copies: the shipping mod, for a no-product control (with
# or without a comparison ZIP).
function Get-NoProductModExclusions($Plan) { if ($Plan.Mode -eq 'none') { return @([string](Get-ProductLoadIdentity).Id) } return @() }

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
        Exit-RuntimeLock $Lab $lock
        throw
    }
}
