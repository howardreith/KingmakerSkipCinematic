# The packaged candidate a native run installs (Invoke-NativeRun.ps1 -ProductZip without -NoProduct).
#
# The supplied ZIP is copied once into a private folder and that copy is opened read-only with FileShare.Read, so while
# the handle is open no process can write, rename or delete it. The standalone validator then reads the held copy, and
# extraction reads the archive through the same handle: the bytes installed are the bytes validated. One cleanup scope
# covers the private folder from its creation until the handle is returned; after that, Close-ValidatedProductZip
# (called by the runner's finally) releases the handle and removes the folder.
$KmcsProductZipValidator = Join-Path (Split-Path -Parent $PSScriptRoot) 'Validate-Package.ps1'

function Open-ValidatedProductZip {
    param(
        [Parameter(Mandatory = $true)] [string] $ProductZip,
        [string] $WorkRoot = [IO.Path]::GetTempPath(),
        [string] $ValidatorPath = $KmcsProductZipValidator
    )
    # The caller's path is resolved with PowerShell's literal file-system semantics (relative to the PowerShell location,
    # not the process working directory, which Windows PowerShell does not keep in step) before .NET sees it.
    $resolved = @(Resolve-Path -LiteralPath $ProductZip -ErrorAction Stop)
    if ($resolved.Count -ne 1 -or $resolved[0].Provider.Name -ne 'FileSystem') { throw "The product ZIP must name one file-system file: $ProductZip" }
    $sourcePath = $resolved[0].ProviderPath
    if (-not [IO.File]::Exists($sourcePath)) { throw "The product ZIP is not a file: $sourcePath" }
    $folder = Join-Path $WorkRoot ('kmcs-validated-product-' + [Guid]::NewGuid().ToString('N'))
    $stream = $null
    $handedOff = $false
    try {
        [void][IO.Directory]::CreateDirectory($folder)
        $copy = Join-Path $folder 'product.zip'
        [IO.File]::Copy($sourcePath, $copy)
        $stream = [IO.FileStream]::new($copy, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if (-not (Test-Path -LiteralPath $ValidatorPath -PathType Leaf)) { throw "The package validator was not found: $ValidatorPath" }
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = @($null | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $ValidatorPath -PackagePath $copy 2>&1 | ForEach-Object { "$_" })
            $exitCode = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $previous }
        foreach ($line in $output) { Write-Host $line }
        if ($exitCode -ne 0) {
            throw ('The product ZIP failed standalone validation; nothing was locked or staged. Validator: ' + ((@($output | Where-Object { $_ }) -join ' ') -replace '\s+', ' '))
        }
        $stream.Position = 0
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $sha256 = ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
        $validated = [pscustomobject]@{ Folder = $folder; Path = $copy; Stream = $stream; Sha256 = $sha256; SourcePath = $sourcePath }
        $handedOff = $true
        return $validated
    }
    finally {
        if (-not $handedOff) {
            if ($stream) { $stream.Dispose() }
            Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Expand-ValidatedProductZip {
    param([Parameter(Mandatory = $true)] $Validated, [Parameter(Mandatory = $true)] [string] $DestinationPath)
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $Validated.Stream.Position = 0
    $archive = [IO.Compression.ZipArchive]::new($Validated.Stream, [IO.Compression.ZipArchiveMode]::Read, $true)
    try { [IO.Compression.ZipFileExtensions]::ExtractToDirectory($archive, $DestinationPath) } finally { $archive.Dispose() }
}

function Close-ValidatedProductZip {
    param($Validated)
    if (-not $Validated) { return }
    try { $Validated.Stream.Dispose() } catch { }
    Remove-Item -LiteralPath $Validated.Folder -Recurse -Force -ErrorAction SilentlyContinue
}
