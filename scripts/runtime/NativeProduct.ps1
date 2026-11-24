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
function New-ValidatedNativeProduct($Plan, [string] $Validator) {
    if ($Plan.Mode -eq 'none') { return $null }
    $private = Join-Path ([IO.Path]::GetTempPath()) ('kmcs-product-' + [Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $private | Out-Null
        $copy = Join-Path $private $(if ($Plan.Mode -eq 'zip') { 'product.zip' } else { 'KingmakerCutsceneSkip.dll' })
        [IO.File]::Copy($Plan.Source, $copy)
        $report = Join-Path $private 'validation.json'
        $kind = if ($Plan.Mode -eq 'zip') { '-PackagePath' } else { '-DllPath' }
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Validator $kind $copy -ReportPath $report | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'The product failed package validation; nothing was locked or staged.' }
        $validation = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        if ((Get-Sha256 $copy) -cne [string]$validation.input_sha256) { throw 'The private product copy changed after validation.' }
        return [pscustomobject]@{ Mode = $Plan.Mode; PrivateDirectory = $private; File = $copy; Validation = $validation }
    }
    catch {
        if (Test-Path -LiteralPath $private) { Remove-Item -LiteralPath $private -Recurse -Force }
        throw
    }
}

# Stages exactly the validated bytes into <ModsDir>\KingmakerCutsceneSkip (ZIP: extracted; DLL: copied with the given
# Info.json) and returns the staged DLL digest, which must equal the validated DLL.
function Install-ValidatedNativeProduct($Product, [string] $ModsDir, [string] $InfoPath) {
    $target = Join-Path $ModsDir 'KingmakerCutsceneSkip'
    if ($Product.Mode -eq 'zip') { Expand-Archive -LiteralPath $Product.File -DestinationPath $ModsDir }
    else {
        New-Item -ItemType Directory -Path $target | Out-Null
        Copy-Item -LiteralPath $Product.File -Destination $target
        Copy-Item -LiteralPath $InfoPath -Destination (Join-Path $target 'Info.json')
    }
    $staged = Get-Sha256 (Join-Path $target 'KingmakerCutsceneSkip.dll')
    if ($staged -cne [string]$Product.Validation.dll_sha256) { throw 'The staged product DLL differs from the validated product.' }
    return $staged
}

function Remove-ValidatedNativeProduct($Product) {
    if ($null -eq $Product) { return }
    $private = [string]$Product.PrivateDirectory
    if ((Split-Path -Leaf $private) -like 'kmcs-product-*' -and (Test-Path -LiteralPath $private)) { Remove-Item -LiteralPath $private -Recurse -Force }
}

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
