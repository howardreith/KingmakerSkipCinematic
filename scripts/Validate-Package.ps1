[CmdletBinding()]
param(
    # An installable ZIP (scripts\Package.ps1 output, or any candidate before installation).
    [string] $PackagePath,
    # Or a bare product DLL (the native runner's built-DLL route), optionally with its Info.json.
    [string] $DllPath,
    [string] $InfoPath,
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
if ($InfoPath) {
    if ($PackagePath) { throw '-InfoPath belongs to the bare -DllPath route.' }
    $InfoPath = Resolve-LiteralPath $InfoPath
    Assert-FileExists $InfoPath 'Info.json'
}
if ($ReportPath) {
    $ReportPath = Resolve-LiteralPath $ReportPath
    foreach ($protectedInput in @($inputPath, $InfoPath | Where-Object { $_ })) {
        $sameSpelling = [string]::Equals([IO.Path]::GetFullPath($ReportPath), [IO.Path]::GetFullPath($protectedInput), [StringComparison]::OrdinalIgnoreCase)
        if ($sameSpelling -or ([IO.File]::Exists($ReportPath) -and (Test-OrdinalEqual ([KmcsFileIdentity]::Of($ReportPath)) ([KmcsFileIdentity]::Of($protectedInput))))) { throw 'The report path must not be the validated input.' }
    }
}

function Get-BytesSha256([byte[]] $Bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
}
$inputBytes = $null
$inputId = [KmcsFileIdentity]::ReadSnapshot($inputPath, [ref]$inputBytes)
$info = Get-ProductInfo
$pins = @(Get-PinnedReferenceDefinitions)
# The expected binding identity of each pinned loader reference comes from the declared pin (name and version, neutral
# culture, no public key token). A cached pinned file, when present and authenticated by its digest, must agree with
# the declared identity; its digest and identity are taken from one read of the file.
$expected = @{}
foreach ($pin in $pins) {
    $declared = Get-PinnedDeclaredIdentity $pin
    $cached = Join-Path (Get-PinnedReferenceDirectory) $pin.File
    if (Test-Path -LiteralPath $cached -PathType Leaf) {
        $cachedBytes = [IO.File]::ReadAllBytes($cached)
        if (Test-OrdinalEqual (Get-BytesSha256 $cachedBytes) ([string]$pin.Sha256)) {
            # The same rule the compiler gate applies (Assert-PinnedReferenceBytes), on this one read.
            $cachedIdentity = [Reflection.Assembly]::ReflectionOnlyLoad($cachedBytes).GetName().FullName
            if (-not (Test-OrdinalEqual $cachedIdentity $declared)) { throw "The pinned file $($pin.File) is $cachedIdentity, which disagrees with its declared pin $declared." }
        }
    }
    $expected[$declared] = $true
}
$loaderPin = @($pins | Where-Object { Test-OrdinalEqual ([string]$_.Name) 'UnityModManager' })
if ($loaderPin.Count -ne 1) { throw 'The pins do not name exactly one UnityModManager reference.' }

$result = [ordered]@{ status = 'validated'; input = $inputPath; input_sha256 = Get-BytesSha256 $inputBytes }
# The load target is the product's fixed identity (Common.ps1), never taken from the manifest being checked.
$loadIdentity = Get-ProductLoadIdentity
# The top-level member names of a JSON object as written (before ConvertFrom-Json, which keeps only the last of repeated
# names): a small scanner over strings and nesting depth. Windows PowerShell's decoder also accepts single-quoted and
# unquoted member names; such a name at the top level is refused here, so every declaration the decoder accepts is one
# this scanner counts.
function Get-JsonTopLevelMemberNames([string] $Text) {
    $names = New-Object System.Collections.Generic.List[string]
    $depth = 0; $i = 0; $expectKey = $false
    while ($i -lt $Text.Length) {
        $c = $Text[$i]
        if ($expectKey -and $depth -eq 1 -and -not [char]::IsWhiteSpace($c) -and $c -ne '"' -and $c -ne '}') {
            throw 'The manifest uses an unsupported member-name syntax (top-level member names must be double-quoted JSON strings).'
        }
        # A single-quoted string (accepted by Windows PowerShell's decoder, not by JSON) could hide a brace or bracket
        # from this scanner's depth; it is refused wherever it occurs, as a name or a value.
        if ($c -eq "'") { throw 'The manifest uses an unsupported string syntax (single-quoted strings are not JSON).' }
        if ($c -eq '"') {
            $sb = New-Object System.Text.StringBuilder; $i++
            while ($i -lt $Text.Length -and $Text[$i] -ne '"') {
                if ($Text[$i] -eq '\') { [void]$sb.Append($Text[$i]); $i++ }
                if ($i -lt $Text.Length) { [void]$sb.Append($Text[$i]); $i++ }
            }
            $i++
            if ($depth -eq 1 -and $expectKey) {
                $j = $i; while ($j -lt $Text.Length -and [char]::IsWhiteSpace($Text[$j])) { $j++ }
                if ($j -lt $Text.Length -and $Text[$j] -eq ':') { $names.Add(('"' + $sb.ToString() + '"' | ConvertFrom-Json)) }
            }
            $expectKey = $false
            continue
        }
        if ($c -eq '{' -or $c -eq '[') { $depth++; $expectKey = ($c -eq '{' -and $depth -eq 1) }
        elseif ($c -eq '}' -or $c -eq ']') { $depth-- }
        elseif ($c -eq ',' -and $depth -eq 1) { $expectKey = $true }
        $i++
    }
    return $names.ToArray()
}
function Assert-ManifestMembersDeclaredOnce([string] $Text, [string] $Label) {
    $written = @(Get-JsonTopLevelMemberNames $Text)
    foreach ($field in @('Id', 'Version', 'ManagerVersion', 'AssemblyName', 'EntryMethod')) {
        if (@($written | Where-Object { Test-OrdinalEqual $_ $field }).Count -gt 1) { throw "$Label declares $field more than once." }
    }
}
function Assert-ManifestIdentity($Manifest, [string] $Label) {
    # Member names are compared ordinally (PowerShell member lookup ignores case): each required field must be present
    # under exactly its declared spelling, once, before any value is read.
    $memberNames = @($Manifest.PSObject.Properties | ForEach-Object { [string]$_.Name })
    foreach ($field in @('Id', 'Version', 'ManagerVersion', 'AssemblyName', 'EntryMethod')) {
        if (@($memberNames | Where-Object { Test-OrdinalEqual $_ $field }).Count -ne 1) { throw "$Label must contain the member $field with exactly that name." }
        if (-not ($Manifest.$field -is [string])) { throw "$Label $field must be a string." }
    }
    foreach ($field in @('Id', 'AssemblyName', 'EntryMethod')) {
        if (-not (Test-OrdinalEqual $Manifest.$field ([string]$loadIdentity[$field]))) { throw "$Label $field is '$($Manifest.$field)', not the product's '$($loadIdentity[$field])'." }
    }
    if (-not (Test-OrdinalEqual $Manifest.Version ([string]$info.Version))) { throw "$Label Version is '$($Manifest.Version)', not the shipping '$($info.Version)'." }
    if (-not (Test-OrdinalEqual $Manifest.ManagerVersion ([string]$loaderPin[0].Version))) { throw "$Label ManagerVersion $($Manifest.ManagerVersion) must equal the pinned loader floor $($loaderPin[0].Version)." }
}
$shippingVersion = [string]$info.Version
if ($PackagePath) {
    $allowed = @('KingmakerCutsceneSkip/Info.json', 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll', 'KingmakerCutsceneSkip/README.md', 'KingmakerCutsceneSkip/LICENSE')
    $stream = [IO.MemoryStream]::new($inputBytes, $false)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
    try {
        $names = @($archive.Entries | ForEach-Object { $_.FullName })
        $allowedSet = [Collections.Generic.HashSet[string]]::new([string[]]$allowed, [StringComparer]::Ordinal)
        $unexpected = @($names | Where-Object { -not $allowedSet.Contains($_) })
        if ($unexpected.Count -gt 0) { throw "Package contains entries outside the mod's four files: $($unexpected -join ', ')" }
        foreach ($name in $allowed) { if (@($names | Where-Object { Test-OrdinalEqual $_ $name }).Count -ne 1) { throw "Package must contain $name exactly once." } }
        function Read-Entry([string] $Name) {
            $entryStream = $archive.GetEntry($Name).Open(); $buffer = [IO.MemoryStream]::new()
            try { $entryStream.CopyTo($buffer); return , $buffer.ToArray() } finally { $buffer.Dispose(); $entryStream.Dispose() }
        }
        $packagedInfoBytes = Read-Entry 'KingmakerCutsceneSkip/Info.json'
        $packagedInfoText = [Text.Encoding]::UTF8.GetString($packagedInfoBytes).TrimStart([char]0xFEFF)
        Assert-ManifestMembersDeclaredOnce $packagedInfoText 'Packaged Info.json'
        $packagedInfo = $packagedInfoText | ConvertFrom-Json
        $dllBytes = Read-Entry 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll'
    }
    finally { $archive.Dispose(); $stream.Dispose() }
    Assert-ManifestIdentity $packagedInfo 'Packaged Info.json'
    $result.manager_version = $packagedInfo.ManagerVersion
    $result.info_sha256 = Get-BytesSha256 $packagedInfoBytes
    $shippingVersion = $packagedInfo.Version
}
else {
    $dllBytes = $inputBytes
    if ($InfoPath) {
        # The bare route's manifest, read once through one handle (its identity is protected like the input's).
        $infoBytes = $null
        $infoId = [KmcsFileIdentity]::ReadSnapshot($InfoPath, [ref]$infoBytes)
        $bareInfoText = [Text.Encoding]::UTF8.GetString($infoBytes).TrimStart([char]0xFEFF)
        Assert-ManifestMembersDeclaredOnce $bareInfoText 'Info.json'
        $bareInfo = $bareInfoText | ConvertFrom-Json
        Assert-ManifestIdentity $bareInfo 'Info.json'
        $result.info = $InfoPath
        $result.info_sha256 = Get-BytesSha256 $infoBytes
    }
}

$assembly = [Reflection.Assembly]::ReflectionOnlyLoad($dllBytes)
$assemblyName = $assembly.GetName().Name
if (-not (Test-OrdinalEqual $assemblyName 'KingmakerCutsceneSkip')) { throw "The product DLL defines assembly '$assemblyName', not KingmakerCutsceneSkip." }
$fileVersion = @([Reflection.CustomAttributeData]::GetCustomAttributes($assembly) | Where-Object { Test-OrdinalEqual $_.AttributeType.FullName 'System.Reflection.AssemblyFileVersionAttribute' } | ForEach-Object { [string]$_.ConstructorArguments[0].Value })
if ($fileVersion.Count -ne 1 -or -not $fileVersion[0].StartsWith($shippingVersion + '.', [StringComparison]::Ordinal)) { throw "The product DLL file version '$($fileVersion -join ',')' does not belong to the shipping version $shippingVersion." }
# Every reference in the UnityModManager or Harmony families (any case, any suffix) is a loader reference. Their full
# identities, compared ordinally (so a case variant is a different reference), must be exactly the declared pins.
$loaderRefs = @($assembly.GetReferencedAssemblies() | Where-Object { $_.Name -match '(?i)^(unitymodmanager|0?harmony)' } | Sort-Object { $_.FullName } -CaseSensitive)
$observedIdentities = [string[]]@($loaderRefs | ForEach-Object { $_.FullName })
$expectedIdentities = [string[]]@($expected.Keys)
[Array]::Sort($observedIdentities, [StringComparer]::Ordinal); [Array]::Sort($expectedIdentities, [StringComparer]::Ordinal)
foreach ($identity in $observedIdentities) {
    if ([Array]::IndexOf($expectedIdentities, $identity) -lt 0) {
        $name = ($identity -split ',')[0]
        $sameName = @($expectedIdentities | Where-Object { Test-OrdinalEqual ($_ -split ',')[0] $name })
        if ($sameName.Count -gt 0) { throw "The product DLL references $identity, not the pinned $($sameName[0])." }
        throw "The product DLL references an unpinned loader or Harmony assembly: $identity"
    }
}
if (-not (Test-OrdinalEqual ($observedIdentities -join "`n") ($expectedIdentities -join "`n"))) { throw "The product DLL must reference exactly the pinned loader assemblies [$($expectedIdentities -join '; ')]; found [$($observedIdentities -join '; ')]." }
$result.dll_assembly_name = $assemblyName
$result.dll_file_version = $fileVersion[0]
$result.dll_sha256 = Get-BytesSha256 $dllBytes
$result.dll_mvid = $assembly.ManifestModule.ModuleVersionId.ToString()
$result.dll_loader_references = @($loaderRefs | ForEach-Object { [ordered]@{ name = $_.Name; version = $_.Version.ToString(); identity = $_.FullName } })
if ($ReportPath) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $ReportPath))
    $reportBytes = [byte[]](@([Text.Encoding]::UTF8.GetPreamble()) + @([Text.Encoding]::UTF8.GetBytes(($result | ConvertTo-Json -Depth 5) + "`r`n")))
    $protectedIds = [string[]]@($inputId, $(if ($InfoPath) { $infoId }) | Where-Object { $_ })
    $protectedPaths = [string[]]@($inputPath, $InfoPath | Where-Object { $_ })
    [void][KmcsFileIdentity]::WriteChecked($ReportPath, $protectedIds, $protectedPaths, $reportBytes)
}
Write-Host "Package validation passed: $inputPath"
Write-Host ("DLL SHA-256: {0}; MVID: {1}; loader references: {2}" -f $result.dll_sha256, $result.dll_mvid, (($loaderRefs | ForEach-Object { $_.Name + ' ' + $_.Version }) -join ', '))
