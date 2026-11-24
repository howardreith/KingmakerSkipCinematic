[CmdletBinding()]
param(
    # An installable ZIP (scripts\Package.ps1 output, or any candidate before installation).
    [string] $PackagePath,
    # Or a bare product DLL (the native runner's built-DLL route).
    [string] $DllPath,
    [string] $ReportPath
)

# Standalone check of what will actually be installed. For a ZIP: exactly the four package entries, the packaged
# Info.json (product Id and version of this checkout, ManagerVersion equal to the pinned loader floor) and the packaged
# DLL. For the DLL (packaged or bare): it must define the assembly KingmakerCutsceneSkip, and its AssemblyRef table must
# name exactly the pinned loader references (scripts\reference-pins.json: UnityModManager 0.31.1.0 and 0Harmony12
# 1.2.0.1) and no other UnityModManager or Harmony assembly. The DLL is loaded reflection-only in this process; run the
# script in its own process (Package.ps1 and the native runner do).
. (Join-Path $PSScriptRoot 'Common.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if ([bool]$PackagePath -eq [bool]$DllPath) { throw 'Pass exactly one of -PackagePath or -DllPath.' }
# PowerShell literal path semantics: relative to the current PowerShell location, no wildcards.
function Resolve-LiteralPath([string] $Path) { return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) }
$inputPath = Resolve-LiteralPath $(if ($PackagePath) { $PackagePath } else { $DllPath })
Assert-FileExists $inputPath $(if ($PackagePath) { 'Package' } else { 'Product DLL' })
if ($ReportPath) {
    $ReportPath = Resolve-LiteralPath $ReportPath
    if ([string]::Equals([IO.Path]::GetFullPath($ReportPath), [IO.Path]::GetFullPath($inputPath), [StringComparison]::OrdinalIgnoreCase)) { throw 'The report path must not be the validated input.' }
}

$info = Get-ProductInfo
$pins = @(Get-PinnedReferenceDefinitions)
function ConvertTo-AssemblyVersion([string] $Version) {
    $v = [version]$Version
    return '{0}.{1}.{2}.{3}' -f $v.Major, $v.Minor, [Math]::Max($v.Build, 0), [Math]::Max($v.Revision, 0)
}
$expected = [ordered]@{}
foreach ($pin in $pins) { $expected[[string]$pin.Name] = ConvertTo-AssemblyVersion ([string]$pin.Version) }
$loaderPin = @($pins | Where-Object { $_.Name -ceq 'UnityModManager' })
if ($loaderPin.Count -ne 1) { throw 'The pins do not name exactly one UnityModManager reference.' }

function Get-BytesSha256([byte[]] $Bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
}

$result = [ordered]@{ status = 'validated'; input = $inputPath; input_sha256 = Get-Sha256 $inputPath }
if ($PackagePath) {
    $allowed = @('KingmakerCutsceneSkip/Info.json', 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll', 'KingmakerCutsceneSkip/README.md', 'KingmakerCutsceneSkip/LICENSE')
    $archive = [IO.Compression.ZipFile]::OpenRead($inputPath)
    try {
        $names = @($archive.Entries | ForEach-Object { $_.FullName })
        $unexpected = @($names | Where-Object { $allowed -cnotcontains $_ })
        if ($unexpected.Count -gt 0) { throw "Package contains entries outside the mod's four files: $($unexpected -join ', ')" }
        foreach ($name in $allowed) { if (@($names | Where-Object { $_ -ceq $name }).Count -ne 1) { throw "Package must contain $name exactly once." } }
        function Read-Entry([string] $Name) {
            $stream = $archive.GetEntry($Name).Open(); $buffer = [IO.MemoryStream]::new()
            try { $stream.CopyTo($buffer); return , $buffer.ToArray() } finally { $buffer.Dispose(); $stream.Dispose() }
        }
        $packagedInfo = [Text.Encoding]::UTF8.GetString((Read-Entry 'KingmakerCutsceneSkip/Info.json')).TrimStart([char]0xFEFF) | ConvertFrom-Json
        $dllBytes = Read-Entry 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll'
    }
    finally { $archive.Dispose() }
    foreach ($field in @('Id', 'Version', 'ManagerVersion')) {
        if (-not $packagedInfo.PSObject.Properties[$field] -or -not ($packagedInfo.$field -is [string])) { throw "Packaged Info.json $field must be a string." }
    }
    if ($packagedInfo.Id -cne [string]$info.Id -or $packagedInfo.Version -cne [string]$info.Version) { throw "Packaged Info.json is $($packagedInfo.Id) $($packagedInfo.Version), not $($info.Id) $($info.Version)." }
    if ($packagedInfo.ManagerVersion -cne [string]$loaderPin[0].Version) { throw "Packaged Info.json ManagerVersion $($packagedInfo.ManagerVersion) must equal the pinned loader floor $($loaderPin[0].Version)." }
    $result.manager_version = $packagedInfo.ManagerVersion
}
else { $dllBytes = [IO.File]::ReadAllBytes($inputPath) }

$assembly = [Reflection.Assembly]::ReflectionOnlyLoad($dllBytes)
$assemblyName = $assembly.GetName().Name
if ($assemblyName -cne 'KingmakerCutsceneSkip') { throw "The product DLL defines assembly '$assemblyName', not KingmakerCutsceneSkip." }
$loaderRefs = @($assembly.GetReferencedAssemblies() | Where-Object { $_.Name -match '^(UnityModManager|0?Harmony.*)$' } | Sort-Object Name | ForEach-Object { [ordered]@{ name = $_.Name; version = $_.Version.ToString() } })
foreach ($ref in $loaderRefs) {
    if (-not $expected.Contains($ref.name)) { throw "The product DLL references an unpinned loader or Harmony assembly: $($ref.name) $($ref.version)" }
}
foreach ($name in $expected.Keys) {
    $match = @($loaderRefs | Where-Object { $_.name -ceq $name })
    if ($match.Count -ne 1) { throw "The product DLL must reference $name exactly once; found $($match.Count)." }
    if ($match[0].version -cne $expected[$name]) { throw "The product DLL references $name $($match[0].version), not the pinned $($expected[$name])." }
}
$result.dll_assembly_name = $assemblyName
$result.dll_sha256 = Get-BytesSha256 $dllBytes
$result.dll_mvid = $assembly.ManifestModule.ModuleVersionId.ToString()
$result.dll_loader_references = $loaderRefs
if ($ReportPath) { Write-JsonFile $ReportPath $result }
Write-Host "Package validation passed: $inputPath"
Write-Host ("DLL SHA-256: {0}; MVID: {1}; loader references: {2}" -f $result.dll_sha256, $result.dll_mvid, (($loaderRefs | ForEach-Object { $_.name + ' ' + $_.version }) -join ', '))
