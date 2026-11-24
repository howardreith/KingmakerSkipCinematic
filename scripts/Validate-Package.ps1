[CmdletBinding()]
param(
    # An installable ZIP (scripts\Package.ps1 output, or any candidate before installation).
    [string] $PackagePath,
    # Or a bare product DLL (the native runner's built-DLL route).
    [string] $DllPath,
    [string] $ReportPath
)

# Standalone check of what will actually be installed. The input is read once, through one handle, into memory; its
# digest and every inspection come from that one snapshot. For a ZIP: exactly the four package entries, and a packaged
# Info.json with this checkout's shipping identity (Id, Version, AssemblyName, EntryMethod) and ManagerVersion equal to
# the pinned loader floor. For the DLL (packaged or bare): the assembly KingmakerCutsceneSkip whose file version belongs
# to the shipping version, and whose AssemblyRef table names, within the UnityModManager and Harmony families, exactly
# the pinned loader references with their full binding identity (name, version, neutral culture, no public key token),
# and nothing else. The DLL is loaded reflection-only in this process; run the script in its own process.
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'FileIdentity.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if ([bool]$PackagePath -eq [bool]$DllPath) { throw 'Pass exactly one of -PackagePath or -DllPath.' }
# PowerShell literal path semantics: relative to the current PowerShell location, no wildcards.
function Resolve-LiteralPath([string] $Path) { return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) }
$inputPath = Resolve-LiteralPath $(if ($PackagePath) { $PackagePath } else { $DllPath })
Assert-FileExists $inputPath $(if ($PackagePath) { 'Package' } else { 'Product DLL' })
if ($ReportPath) {
    $ReportPath = Resolve-LiteralPath $ReportPath
    $sameSpelling = [string]::Equals([IO.Path]::GetFullPath($ReportPath), [IO.Path]::GetFullPath($inputPath), [StringComparison]::OrdinalIgnoreCase)
    if ($sameSpelling -or ([IO.File]::Exists($ReportPath) -and [KmcsFileIdentity]::Of($ReportPath) -ceq [KmcsFileIdentity]::Of($inputPath))) { throw 'The report path must not be the validated input.' }
}

$inputBytes = $null
$inputId = [KmcsFileIdentity]::ReadSnapshot($inputPath, [ref]$inputBytes)
$info = Get-ProductInfo
$pins = @(Get-PinnedReferenceDefinitions)
function ConvertTo-AssemblyVersion([string] $Version) {
    $v = [version]$Version
    return '{0}.{1}.{2}.{3}' -f $v.Major, $v.Minor, [Math]::Max($v.Build, 0), [Math]::Max($v.Revision, 0)
}
# The expected binding identity of each pinned loader reference: the verified cached file's own identity when it is
# present (it is, after any build), otherwise the pinned name and version with neutral culture and no key.
$expected = [ordered]@{}
foreach ($pin in $pins) {
    $cached = Join-Path (Get-PinnedReferenceDirectory) $pin.File
    if ((Test-Path -LiteralPath $cached -PathType Leaf) -and (Get-Sha256 $cached) -ceq [string]$pin.Sha256) { $expected[[string]$pin.Name] = [Reflection.AssemblyName]::GetAssemblyName($cached).FullName }
    else { $expected[[string]$pin.Name] = '{0}, Version={1}, Culture=neutral, PublicKeyToken=null' -f $pin.Name, (ConvertTo-AssemblyVersion ([string]$pin.Version)) }
}
$loaderPin = @($pins | Where-Object { $_.Name -ceq 'UnityModManager' })
if ($loaderPin.Count -ne 1) { throw 'The pins do not name exactly one UnityModManager reference.' }

function Get-BytesSha256([byte[]] $Bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
}

$result = [ordered]@{ status = 'validated'; input = $inputPath; input_sha256 = Get-BytesSha256 $inputBytes }
$shippingVersion = [string]$info.Version
if ($PackagePath) {
    $allowed = @('KingmakerCutsceneSkip/Info.json', 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll', 'KingmakerCutsceneSkip/README.md', 'KingmakerCutsceneSkip/LICENSE')
    $stream = [IO.MemoryStream]::new($inputBytes, $false)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
    try {
        $names = @($archive.Entries | ForEach-Object { $_.FullName })
        $unexpected = @($names | Where-Object { $allowed -cnotcontains $_ })
        if ($unexpected.Count -gt 0) { throw "Package contains entries outside the mod's four files: $($unexpected -join ', ')" }
        foreach ($name in $allowed) { if (@($names | Where-Object { $_ -ceq $name }).Count -ne 1) { throw "Package must contain $name exactly once." } }
        function Read-Entry([string] $Name) {
            $entryStream = $archive.GetEntry($Name).Open(); $buffer = [IO.MemoryStream]::new()
            try { $entryStream.CopyTo($buffer); return , $buffer.ToArray() } finally { $buffer.Dispose(); $entryStream.Dispose() }
        }
        $packagedInfo = [Text.Encoding]::UTF8.GetString((Read-Entry 'KingmakerCutsceneSkip/Info.json')).TrimStart([char]0xFEFF) | ConvertFrom-Json
        $dllBytes = Read-Entry 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll'
    }
    finally { $archive.Dispose(); $stream.Dispose() }
    foreach ($field in @('Id', 'Version', 'ManagerVersion', 'AssemblyName', 'EntryMethod')) {
        if (-not $packagedInfo.PSObject.Properties[$field] -or -not ($packagedInfo.$field -is [string])) { throw "Packaged Info.json $field must be a string." }
    }
    foreach ($field in @('Id', 'Version', 'AssemblyName', 'EntryMethod')) {
        if ($packagedInfo.$field -cne [string]$info.$field) { throw "Packaged Info.json $field is '$($packagedInfo.$field)', not the shipping '$($info.$field)'." }
    }
    if ($packagedInfo.ManagerVersion -cne [string]$loaderPin[0].Version) { throw "Packaged Info.json ManagerVersion $($packagedInfo.ManagerVersion) must equal the pinned loader floor $($loaderPin[0].Version)." }
    $result.manager_version = $packagedInfo.ManagerVersion
    $shippingVersion = $packagedInfo.Version
}
else { $dllBytes = $inputBytes }

$assembly = [Reflection.Assembly]::ReflectionOnlyLoad($dllBytes)
$assemblyName = $assembly.GetName().Name
if ($assemblyName -cne 'KingmakerCutsceneSkip') { throw "The product DLL defines assembly '$assemblyName', not KingmakerCutsceneSkip." }
$fileVersion = @([Reflection.CustomAttributeData]::GetCustomAttributes($assembly) | Where-Object { $_.AttributeType.FullName -ceq 'System.Reflection.AssemblyFileVersionAttribute' } | ForEach-Object { [string]$_.ConstructorArguments[0].Value })
if ($fileVersion.Count -ne 1 -or -not $fileVersion[0].StartsWith($shippingVersion + '.')) { throw "The product DLL file version '$($fileVersion -join ',')' does not belong to the shipping version $shippingVersion." }
# Every reference in the UnityModManager or Harmony families (any case, any suffix) is a loader reference.
$loaderRefs = @($assembly.GetReferencedAssemblies() | Where-Object { $_.Name -match '(?i)^(unitymodmanager|0?harmony)' } | Sort-Object Name)
foreach ($ref in $loaderRefs) {
    if (-not $expected.Contains($ref.Name)) { throw "The product DLL references an unpinned loader or Harmony assembly: $($ref.FullName)" }
}
foreach ($name in $expected.Keys) {
    $match = @($loaderRefs | Where-Object { $_.Name -ceq $name })
    if ($match.Count -ne 1) { throw "The product DLL must reference $name exactly once; found $($match.Count)." }
    if ($match[0].FullName -cne $expected[$name]) { throw "The product DLL references $($match[0].FullName), not the pinned $($expected[$name])." }
}
$result.dll_assembly_name = $assemblyName
$result.dll_file_version = $fileVersion[0]
$result.dll_sha256 = Get-BytesSha256 $dllBytes
$result.dll_mvid = $assembly.ManifestModule.ModuleVersionId.ToString()
$result.dll_loader_references = @($loaderRefs | ForEach-Object { [ordered]@{ name = $_.Name; version = $_.Version.ToString(); identity = $_.FullName } })
if ($ReportPath) {
    $reportBytes = [byte[]](@([Text.Encoding]::UTF8.GetPreamble()) + @([Text.Encoding]::UTF8.GetBytes(($result | ConvertTo-Json -Depth 5) + "`r`n")))
    [void][KmcsFileIdentity]::WriteChecked($ReportPath, [string[]]@($inputId), $reportBytes)
}
Write-Host "Package validation passed: $inputPath"
Write-Host ("DLL SHA-256: {0}; MVID: {1}; loader references: {2}" -f $result.dll_sha256, $result.dll_mvid, (($loaderRefs | ForEach-Object { $_.Name + ' ' + $_.Version }) -join ', '))
