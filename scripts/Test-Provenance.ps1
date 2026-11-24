[CmdletBinding()]
param()

# Deterministic checks of the build-contract comparison used by Package.ps1. No game or network access.
. (Join-Path $PSScriptRoot 'Common.ps1')

$script:failed = 0
$script:total = 0

function Assert-Case([string] $Name, [bool] $Condition) {
    $script:total++
    if ($Condition) { Write-Host "PASS Provenance.$Name" }
    else { $script:failed++; Write-Host "FAIL Provenance.$Name" }
}

function New-Pin([string] $File, [string] $Sha, [string] $Url, [string] $Name = $File, [string] $Version = '1.0') {
    return [pscustomobject]@{ Name = $Name; File = $File; Version = $Version; Url = $Url; Sha256 = $Sha }
}

function New-Identity([string] $File, [string] $Sha, [string] $Url) {
    return [pscustomobject]@{ role = 'pinned loader reference'; file = $File; assembly_version = '1.0.0.0'; sha256 = $Sha; source = $Url }
}

$shaA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; $shaB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
$pins = @((New-Pin 'UnityModManager.dll' $shaA 'u1' 'UnityModManager' '0.31.1'), (New-Pin '0Harmony12.dll' $shaB 'u2' '0Harmony12' '1.2.0.1'))
$game = [pscustomobject]@{ role = 'local game reference'; file = 'Assembly-CSharp.dll'; sha256 = 'ccc' }
$good = @((New-Identity 'UnityModManager.dll' $shaA 'u1'), (New-Identity '0Harmony12.dll' $shaB 'u2'), $game)

Assert-Case 'MatchingReceiptHasNoProblems' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $good }) $pins '0.31.1').Count -eq 0)

$changed = @((New-Identity 'UnityModManager.dll' 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' 'u1'), (New-Identity '0Harmony12.dll' $shaB 'u2'))
Assert-Case 'ChangedHashIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $changed }) $pins '0.31.1').Count -gt 0)

$otherSource = @((New-Identity 'UnityModManager.dll' $shaA 'elsewhere'), (New-Identity '0Harmony12.dll' $shaB 'u2'))
Assert-Case 'ChangedSourceIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $otherSource }) $pins '0.31.1').Count -gt 0)

$missing = @((New-Identity 'UnityModManager.dll' $shaA 'u1'))
Assert-Case 'MissingIdentityIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $missing }) $pins '0.31.1').Count -gt 0)

$extra = $good + @(New-Identity 'Unexpected.dll' 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd' 'u3')
Assert-Case 'UnpinnedIdentityIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $extra }) $pins '0.31.1').Count -gt 0)

Assert-Case 'ReceiptWithoutReferencesIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ status = 'passed' }) $pins '0.31.1').Count -gt 0)
Assert-Case 'ManagerVersionMustEqualThePinnedLoader' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $good }) $pins '0.33.0').Count -gt 0)
# Recorded pin digests are typed: a boolean, an empty array or a digest with a trailing line feed is a problem, never a match.
foreach ($malformed in @(@('Boolean', $true), @('EmptyArray', @()), @('TrailingLineFeed', ($shaA + "`n")))) {
    $typed = @([pscustomobject]@{ role = 'pinned loader reference'; file = 'UnityModManager.dll'; assembly_version = '1.0.0.0'; sha256 = $malformed[1]; source = 'u1' }, (New-Identity '0Harmony12.dll' $shaB 'u2'))
    $found = @(Get-ReferencePinProblems ([pscustomobject]@{ references = $typed }) $pins '0.31.1')
    Assert-Case "RecordedPinDigest$($malformed[0])IsAProblem" ($found.Count -gt 0 -and ($found -join ' ') -match 'not a SHA-256 string')
}

$productPaths = Get-ProductInputPaths
Assert-Case 'PinManifestIsAProductInput' ($productPaths -contains 'scripts/reference-pins.json')

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("kmcs-pins-" + [guid]::NewGuid().ToString('N') + '.json')
try {
    Set-Content -LiteralPath $temporary -Encoding UTF8 -Value '{ "references": [ { "Name": "X", "File": "X.dll", "Version": "9", "Url": "u", "ArchiveSha256": null, "ArchiveEntry": null, "Sha256": "s" } ] }'
    $loaded = @(Get-PinnedReferenceDefinitions $temporary)
    Assert-Case 'EffectivePinsComeFromTheManifest' ($loaded.Count -eq 1 -and $loaded[0].File -eq 'X.dll' -and $loaded[0].Sha256 -eq 's')
}
finally { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }

$current = @(Get-PinnedReferenceDefinitions)
Assert-Case 'CommittedManifestDeclaresBothLoaderReferences' ((@($current | ForEach-Object { $_.File }) -join ',') -eq 'UnityModManager.dll,0Harmony12.dll')
Assert-Case 'CommittedManifestAgreesWithInfoJson' (($current | Where-Object { $_.Name -eq 'UnityModManager' }).Version -eq (Get-ProductInfo).ManagerVersion)

# The standalone package validator against fixture packages. Every assembly is compiled here with the .NET Framework
# compiler: the product stubs reference either the pinned loader files (the baseline) or disposable stub loader
# assemblies with a known newer or otherwise different identity, so no case depends on the installed loader.
$validator = Join-Path $PSScriptRoot 'Validate-Package.ps1'
$pinnedDir = Initialize-PinnedReferences
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$fixtures = Join-Path ([IO.Path]::GetTempPath()) ('kmcs-package-' + [guid]::NewGuid().ToString('N'))
function Invoke-Validator([string[]] $Arguments) {
    $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $output = (($null | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $validator @Arguments 2>&1) | ForEach-Object { "$_" }) -join ' ' }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -replace '\s+', ' ') }
}
function New-Assembly([string] $Name, [string] $Code, [string[]] $References = @()) {
    $dir = Join-Path $fixtures ($Name + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)); New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $source = Join-Path $dir 'Source.cs'; [IO.File]::WriteAllText($source, $Code)
    $assemblyName = ($Code | Select-String -Pattern 'AssemblyTitle\("([^"]+)"\)').Matches.Groups[1].Value
    if (-not $assemblyName) { $assemblyName = 'KingmakerCutsceneSkip' }
    $out = Join-Path $dir "$assemblyName.dll"
    $o = & $csc /nologo /target:library "/out:$out" @($References | ForEach-Object { "/reference:$_" }) $source 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fixture compile failed ($Name): $($o -join ' ')" }
    return $out
}
function New-FixtureZip([string] $Name, [string] $Dll, [scriptblock] $EditInfo, [string[]] $Extra) {
    $zip = Join-Path $fixtures "$Name.zip"
    $info = Get-Content -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Raw | ConvertFrom-Json
    if ($EditInfo) { & $EditInfo $info }
    $infoFile = Join-Path $fixtures "$Name-Info.json"; $info | ConvertTo-Json | Set-Content -LiteralPath $infoFile -Encoding UTF8
    $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $entries = [ordered]@{ 'KingmakerCutsceneSkip/Info.json' = $infoFile; 'KingmakerCutsceneSkip/KingmakerCutsceneSkip.dll' = $Dll
            'KingmakerCutsceneSkip/README.md' = (Join-Path (Get-RepositoryRoot) 'README.md'); 'KingmakerCutsceneSkip/LICENSE' = (Join-Path (Get-RepositoryRoot) 'LICENSE') }
        foreach ($extra in @($Extra | Where-Object { $_ })) { $entries[$extra.Split('|')[0]] = $extra.Split('|')[1] }
        foreach ($e in $entries.GetEnumerator()) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $e.Value, $e.Key) }
    }
    finally { $archive.Dispose() }
    return $zip
}
# Runs the validator in its own process with an action at the first execution of the line starting with $Anchor (a
# PowerShell line breakpoint: no hook in the validator). Used to replace or alias files mid-validation.
function Invoke-ValidatorWithAction([string] $Anchor, [string] $Action, [string[]] $Arguments) {
    $lines = [IO.File]::ReadAllLines($validator)
    $line = 0; for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i].TrimStart().StartsWith($Anchor)) { $line = $i + 1; break } }
    if ($line -eq 0) { throw "Validator anchor not found: $Anchor" }
    $q = { param([string] $t) "'" + $t.Replace("'", "''") + "'" }
    $driver = Join-Path $fixtures ('driver-' + [guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllText($driver, ("`$ErrorActionPreference = 'Stop'`r`n`$global:kmcsHit = `$false`r`n" +
        "Set-PSBreakpoint -Script $(& $q $validator) -Line $line -Action { if (-not `$global:kmcsHit) { `$global:kmcsHit = `$true; $Action } } | Out-Null`r`n" +
        "& $(& $q $validator) $(($Arguments | ForEach-Object { if ($_ -cmatch '\A-[A-Za-z]+\z') { $_ } else { & $q $_ } }) -join ' ')`r`n" +
        "if (-not `$global:kmcsHit) { throw 'The validation action was never reached.' }`r`n"))
    $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $output = (($null | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $driver 2>&1) | ForEach-Object { "$_" }) -join ' ' }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -replace '\s+', ' ') }
}
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot 'runtime\NativeProduct.ps1')
. (Join-Path $PSScriptRoot 'runtime\RuntimeLab.Common.ps1')
try {
    New-Item -ItemType Directory -Path $fixtures | Out-Null
    $version = [string](Get-ProductInfo).Version
    $productHeader = "[assembly: System.Reflection.AssemblyTitle(`"KingmakerCutsceneSkip`")] [assembly: System.Reflection.AssemblyFileVersion(`"$version.0`")] "
    $loaderUse = 'public static class Probe { public static System.Type[] Types = { typeof(UnityModManagerNet.UnityModManager), typeof(Harmony12.HarmonyInstance) }; }'
    $pinnedRefs = @((Join-Path $pinnedDir 'UnityModManager.dll'), (Join-Path $pinnedDir '0Harmony12.dll'))
    # Disposable stub loader assemblies with known identities.
    $stubUmm033 = New-Assembly 'stub-umm-0.33.0' '[assembly: System.Reflection.AssemblyTitle("UnityModManager")] [assembly: System.Reflection.AssemblyVersion("0.33.0.0")] namespace UnityModManagerNet { public class UnityModManager { } }'
    $stubUmmFr = New-Assembly 'stub-umm-0.31.1-fr' '[assembly: System.Reflection.AssemblyTitle("UnityModManager")] [assembly: System.Reflection.AssemblyVersion("0.31.1.0")] [assembly: System.Reflection.AssemblyCulture("fr")] namespace UnityModManagerNet { public class UnityModManager { } }'
    $stubHarmony2 = New-Assembly 'stub-harmony2' '[assembly: System.Reflection.AssemblyTitle("0Harmony")] [assembly: System.Reflection.AssemblyVersion("2.3.6.0")] namespace HarmonyLib { public class Harmony { } }'
    $stubUmmFamily = New-Assembly 'stub-umm-family' '[assembly: System.Reflection.AssemblyTitle("UnityModManagerExtensions")] [assembly: System.Reflection.AssemblyVersion("1.0.0.0")] namespace UnityModManagerExtensions { public class Helper { } }'
    $genuine = New-Assembly 'genuine' ($productHeader + $loaderUse) $pinnedRefs
    $newerUmm = New-Assembly 'newer-umm' ($productHeader + $loaderUse) @($stubUmm033, (Join-Path $pinnedDir '0Harmony12.dll'))
    $otherBinding = New-Assembly 'other-binding' ($productHeader + $loaderUse) @($stubUmmFr, (Join-Path $pinnedDir '0Harmony12.dll'))
    $withHarmony2 = New-Assembly 'harmony2' ($productHeader + 'public static class Probe { public static System.Type[] Types = { typeof(UnityModManagerNet.UnityModManager), typeof(Harmony12.HarmonyInstance), typeof(HarmonyLib.Harmony) }; }') ($pinnedRefs + @($stubHarmony2))
    $withUmmFamily = New-Assembly 'umm-family' ($productHeader + 'public static class Probe { public static System.Type[] Types = { typeof(UnityModManagerNet.UnityModManager), typeof(Harmony12.HarmonyInstance), typeof(UnityModManagerExtensions.Helper) }; }') ($pinnedRefs + @($stubUmmFamily))
    $otherName = New-Assembly 'other-name' ("[assembly: System.Reflection.AssemblyTitle(`"NotCutsceneSkip`")] [assembly: System.Reflection.AssemblyFileVersion(`"$version.0`")] " + $loaderUse) $pinnedRefs
    $otherVersion = New-Assembly 'other-version' ('[assembly: System.Reflection.AssemblyTitle("KingmakerCutsceneSkip")] [assembly: System.Reflection.AssemblyFileVersion("9.9.9.0")] ' + $loaderUse) $pinnedRefs

    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'genuine' $genuine $null $null))
    Assert-Case 'PackageWithPinnedReferencesIsAccepted' ($r.ExitCode -eq 0 -and $r.Output -match 'loader references: 0Harmony12 1\.2\.0\.1, UnityModManager 0\.31\.1\.0')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'newer-umm' $newerUmm $null $null))
    Assert-Case 'PackagedDllCompiledAgainstNewerStubLoaderIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'references UnityModManager, Version=0\.33\.0\.0, Culture=neutral, PublicKeyToken=null, not the pinned')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'other-binding' $otherBinding $null $null))
    Assert-Case 'SameNameSameVersionDifferentBindingIdentityIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'Culture=fr')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'harmony2' $withHarmony2 $null $null))
    Assert-Case 'PackagedDllWithHarmony2ReferenceIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'unpinned loader or Harmony assembly: 0Harmony, ')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'umm-family' $withUmmFamily $null $null))
    Assert-Case 'AdditionalUmmFamilyReferenceIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'unpinned loader or Harmony assembly: UnityModManagerExtensions')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'other-name' $otherName $null $null))
    Assert-Case 'PackagedDllWithAnotherAssemblyNameIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match "defines assembly 'NotCutsceneSkip'")
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'other-version' $otherVersion $null $null))
    Assert-Case 'PackagedDllWithConflictingFileVersionIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match "file version '9\.9\.9\.0' does not belong to the shipping version")
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'wrong-assembly-target' $genuine { param($i) $i.AssemblyName = 'Other.dll' } $null))
    Assert-Case 'PackagedWrongAssemblyTargetIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'AssemblyName is .Other\.dll., not the product.s .KingmakerCutsceneSkip\.dll.')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'wrong-entry' $genuine { param($i) $i.EntryMethod = 'KingmakerCutsceneSkip.Main.Other' } $null))
    Assert-Case 'PackagedWrongEntryMethodIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'EntryMethod is .KingmakerCutsceneSkip\.Main\.Other., not the product.s .KingmakerCutsceneSkip\.Main\.Load.')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'extra-loader' $genuine $null @("KingmakerCutsceneSkip/0Harmony12.dll|$(Join-Path $pinnedDir '0Harmony12.dll')")))
    Assert-Case 'PackageCarryingALoaderAssemblyIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match "entries outside the mod's four files: KingmakerCutsceneSkip/0Harmony12\.dll")
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'raised-manager' $genuine { param($i) $i.ManagerVersion = '0.33.0' } $null))
    Assert-Case 'PackagedManagerVersionAbovePinIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'ManagerVersion 0\.33\.0 must equal the pinned loader floor 0\.31\.1')
    # An additional loader reference that differs from a pin only by case (a distinct binding identity under ordinal
    # comparison), beside the genuine references. The fixture is compiled against a stub of the same name length and its
    # AssemblyRef name is then rewritten in the #Strings heap.
    foreach ($variantVersion in @('0.31.1.0', '0.33.0.0')) {
        $stubQ = New-Assembly "stub-case-$variantVersion" "[assembly: System.Reflection.AssemblyTitle(`"QnityModManager`")] [assembly: System.Reflection.AssemblyVersion(`"$variantVersion`")] namespace QStub { public class Helper { } }"
        $builtQ = New-Assembly "case-variant-$variantVersion" ($productHeader + 'public static class Probe { public static System.Type[] Types = { typeof(UnityModManagerNet.UnityModManager), typeof(Harmony12.HarmonyInstance), typeof(QStub.Helper) }; }') ($pinnedRefs + @($stubQ))
        $bytesQ = [IO.File]::ReadAllBytes($builtQ)
        $latin = [Text.Encoding]::GetEncoding(28591).GetString($bytesQ)
        $hits = [regex]::Matches($latin, "QnityModManager`0").Count
        if ($hits -ne 1) { throw "Case-variant fixture: expected one AssemblyRef name, found $hits." }
        $patch = [Text.Encoding]::ASCII.GetBytes('unitymodmanager')
        [Array]::Copy($patch, 0, $bytesQ, $latin.IndexOf("QnityModManager`0"), $patch.Length)
        $patchedDir = Join-Path $fixtures "case-variant-patched-$variantVersion"; New-Item -ItemType Directory -Path $patchedDir | Out-Null
        $patched = Join-Path $patchedDir 'KingmakerCutsceneSkip.dll'; [IO.File]::WriteAllBytes($patched, $bytesQ)
        $r = Invoke-Validator @('-PackagePath', (New-FixtureZip "case-variant-$variantVersion" $patched $null $null))
        Assert-Case "AdditionalCaseVariantLoaderReference$($variantVersion.Replace('.', '_'))IsRejected" ($r.ExitCode -ne 0 -and $r.Output -match "unpinned loader or Harmony assembly: unitymodmanager, Version=$([regex]::Escape($variantVersion))")
        $r = Invoke-Validator @('-DllPath', $patched)
        Assert-Case "BareDllWithCaseVariantLoaderReference$($variantVersion.Replace('.', '_'))IsRejected" ($r.ExitCode -ne 0 -and $r.Output -match 'unpinned loader or Harmony assembly: unitymodmanager')
    }
    # Declared pins are authoritative: in a disposable validator root, the genuine package passes with and without a
    # cache; a declared version that disagrees with the authenticated cached assembly is refused, and without a cache the
    # DLL is checked against the declaration.
    $altRoot = Join-Path $fixtures 'alternate root'
    New-Item -ItemType Directory -Path $altRoot | Out-Null
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $altRoot 'scripts') -Recurse
    Copy-Item -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Destination $altRoot
    $altValidator = Join-Path $altRoot 'scripts\Validate-Package.ps1'
    $altPins = Join-Path $altRoot 'scripts\reference-pins.json'; $altPinsGenuine = [IO.File]::ReadAllText($altPins)
    $altCache = Join-Path $altRoot 'artifacts\references'
    $genuineZipPath = Join-Path $fixtures 'genuine.zip'
    $saved = $validator; $validator = $altValidator
    try {
        $r = Invoke-Validator @('-PackagePath', $genuineZipPath)
        Assert-Case 'GenuinePackageAcceptedWithoutACache' ($r.ExitCode -eq 0 -and -not (Test-Path -LiteralPath $altCache))
        [void][IO.Directory]::CreateDirectory($altCache)
        Copy-Item -Path (Join-Path $pinnedDir '*.dll') -Destination $altCache
        $r = Invoke-Validator @('-PackagePath', $genuineZipPath)
        Assert-Case 'GenuinePackageAcceptedWithTheCache' ($r.ExitCode -eq 0)
        $disagreeing = $altPinsGenuine | ConvertFrom-Json
        @($disagreeing.references | Where-Object { $_.Name -eq '0Harmony12' })[0].Version = '1.2.0.2'
        [IO.File]::WriteAllText($altPins, ($disagreeing | ConvertTo-Json -Depth 5))
        $r = Invoke-Validator @('-PackagePath', $genuineZipPath)
        Assert-Case 'DeclaredPinVersionDisagreeingWithTheCachedAssemblyIsRefused' ($r.ExitCode -ne 0 -and $r.Output -match 'The pinned file 0Harmony12\.dll is 0Harmony12, Version=1\.2\.0\.1, Culture=neutral, PublicKeyToken=null, which disagrees with its declared pin 0Harmony12, Version=1\.2\.0\.2')
        Remove-Item -LiteralPath $altCache -Recurse -Force
        $r = Invoke-Validator @('-PackagePath', $genuineZipPath)
        Assert-Case 'WithoutACacheTheDllIsCheckedAgainstTheDeclaredPin' ($r.ExitCode -ne 0 -and $r.Output -match 'references 0Harmony12, Version=1\.2\.0\.1, Culture=neutral, PublicKeyToken=null, not the pinned 0Harmony12, Version=1\.2\.0\.2')
    }
    finally { $validator = $saved }
    # Fixed fields are compared ordinally: a soft hyphen (U+00AD, ignorable under culture rules) in an otherwise correct
    # EntryMethod or ManagerVersion is refused, for a ZIP and for a bare manifest.
    $softHyphen = [string][char]0x00AD
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'soft-hyphen-entry' $genuine { param($i) $i.EntryMethod = 'KingmakerCutsceneSkip.Main.Lo' + $softHyphen + 'ad' } $null))
    Assert-Case 'PackagedEntryMethodWithASoftHyphenIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'EntryMethod is .KingmakerCutsceneSkip\.Main\.Lo.?ad., not the product')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'soft-hyphen-manager' $genuine { param($i) $i.ManagerVersion = '0.31' + $softHyphen + '.1' } $null))
    Assert-Case 'PackagedManagerVersionWithASoftHyphenIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'ManagerVersion 0\.31.\.1 must equal the pinned loader floor')
    foreach ($soft in @(@('EntryMethod', ('KingmakerCutsceneSkip.Main.Lo' + $softHyphen + 'ad')), @('ManagerVersion', ('0.31' + $softHyphen + '.1')))) {
        $softInfo = Join-Path $fixtures "soft-hyphen-$($soft[0]).json"
        $si = Get-Content -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Raw | ConvertFrom-Json; $si.($soft[0]) = $soft[1]
        [IO.File]::WriteAllText($softInfo, ($si | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
        $r = Invoke-Validator @('-DllPath', $genuine, '-InfoPath', $softInfo)
        Assert-Case "BareManifest$($soft[0])WithASoftHyphenIsRejected" ($r.ExitCode -ne 0 -and $r.Output -match "$($soft[0])")
    }
    # Required members are matched by their declared names: ManagerVersion spelled managerversion in a ZIP manifest and
    # EntryMethod spelled entrymethod in a bare manifest (values unchanged) are refused.
    $renameMember = { param($i, [string] $From, [string] $To) $v = $i.$From; [void]$i.PSObject.Properties.Remove($From); $i | Add-Member -NotePropertyName $To -NotePropertyValue $v }
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'lowercase-managerversion' $genuine { param($i) & $renameMember $i 'ManagerVersion' 'managerversion' } $null))
    Assert-Case 'PackagedManifestWithLowercaseManagerVersionMemberIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'must contain the member ManagerVersion with exactly that name')
    $lowerInfo = Join-Path $fixtures 'lowercase-entrymethod Info.json'
    $li = Get-Content -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Raw | ConvertFrom-Json; & $renameMember $li 'EntryMethod' 'entrymethod'
    [IO.File]::WriteAllText($lowerInfo, ($li | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    $r = Invoke-Validator @('-DllPath', $genuine, '-InfoPath', $lowerInfo)
    Assert-Case 'BareManifestWithLowercaseEntryMethodMemberIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'must contain the member EntryMethod with exactly that name')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'declared-names-control' $genuine $null $null))
    Assert-Case 'PackagedManifestWithDeclaredMemberNamesIsAccepted' ($r.ExitCode -eq 0)
    $genuineInfoCopy = Join-Path $fixtures 'genuine bare Info.json'; Copy-Item -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Destination $genuineInfoCopy
    $r = Invoke-Validator @('-DllPath', $genuine, '-InfoPath', $genuineInfoCopy)
    Assert-Case 'GenuineBarePairIsAccepted' ($r.ExitCode -eq 0)
    $r = Invoke-Validator @('-DllPath', $genuine)
    Assert-Case 'BuiltDllWithPinnedReferencesIsAccepted' ($r.ExitCode -eq 0)
    $r = Invoke-Validator @('-DllPath', $newerUmm)
    Assert-Case 'BuiltDllCompiledAgainstNewerStubLoaderIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'not the pinned')
    # Report destination: the input itself, by spelling or by a hard link, is refused and left intact; a distinct report is written.
    $genuineZip = Join-Path $fixtures 'genuine.zip'
    $before = Get-Sha256 $genuineZip
    $r = Invoke-Validator @('-PackagePath', $genuineZip, '-ReportPath', $genuineZip)
    Assert-Case 'ReportPathEqualToPackageIsRejected' ($r.ExitCode -ne 0 -and (Get-Sha256 $genuineZip) -eq $before)
    $alias = Join-Path $fixtures 'alias of genuine.zip'
    New-Item -ItemType HardLink -Path $alias -Target $genuineZip | Out-Null
    $r = Invoke-Validator @('-PackagePath', $genuineZip, '-ReportPath', $alias)
    Assert-Case 'ReportPathHardLinkToPackageIsRejected' ($r.ExitCode -ne 0 -and (Get-Sha256 $genuineZip) -eq $before)
    $reportFile = Join-Path $fixtures 'report.json'
    $r = Invoke-Validator @('-PackagePath', $genuineZip, '-ReportPath', $reportFile)
    $report = Get-Content -LiteralPath $reportFile -Raw | ConvertFrom-Json
    Assert-Case 'ReportDigestAndMetadataComeFromOneSnapshot' ($r.ExitCode -eq 0 -and $report.input_sha256 -eq $before -and $report.dll_sha256 -eq (Get-Sha256 $genuine))
    # The bare route's supplied Info.json is protected like the input: a report path equal to it or hard-linked to it is
    # refused with both inputs intact; a distinct report records the manifest digest.
    $bareDir = Join-Path $fixtures 'bare pair'; New-Item -ItemType Directory -Path $bareDir | Out-Null
    $bareDll = Join-Path $bareDir 'KingmakerCutsceneSkip.dll'; Copy-Item -LiteralPath $genuine -Destination $bareDll
    $bareInfo = Join-Path $bareDir 'Info.json'; Copy-Item -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Destination $bareInfo
    $bareDllSha = Get-Sha256 $bareDll; $bareInfoSha = Get-Sha256 $bareInfo
    $r = Invoke-Validator @('-DllPath', $bareDll, '-InfoPath', $bareInfo, '-ReportPath', $bareInfo)
    Assert-Case 'ReportPathEqualToSuppliedInfoJsonIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'must not be the validated input' -and (Get-Sha256 $bareInfo) -eq $bareInfoSha -and (Get-Sha256 $bareDll) -eq $bareDllSha)
    $infoAlias = Join-Path $bareDir 'alias of Info.json'
    New-Item -ItemType HardLink -Path $infoAlias -Target $bareInfo | Out-Null
    $r = Invoke-Validator @('-DllPath', $bareDll, '-InfoPath', $bareInfo, '-ReportPath', $infoAlias)
    Assert-Case 'ReportPathHardLinkToSuppliedInfoJsonIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'must not be the validated input' -and (Get-Sha256 $bareInfo) -eq $bareInfoSha -and (Get-Sha256 $bareDll) -eq $bareDllSha)
    $bareReport = Join-Path $bareDir 'report.json'
    $r = Invoke-Validator @('-DllPath', $bareDll, '-InfoPath', $bareInfo, '-ReportPath', $bareReport)
    $bareResult = if (Test-Path -LiteralPath $bareReport) { Get-Content -LiteralPath $bareReport -Raw | ConvertFrom-Json } else { $null }
    Assert-Case 'DistinctReportForTheBarePairIsWritten' ($r.ExitCode -eq 0 -and $null -ne $bareResult -and $bareResult.info_sha256 -eq $bareInfoSha -and $bareResult.input_sha256 -eq $bareDllSha)
    $nestedReport = Join-Path $fixtures ('fresh ' + [guid]::NewGuid().ToString('N') + '\nested\report.json')
    $r = Invoke-Validator @('-PackagePath', $genuineZip, '-ReportPath', $nestedReport)
    Assert-Case 'ReportBelowAFreshSubdirectoryIsWritten' ($r.ExitCode -eq 0 -and (Test-Path -LiteralPath $nestedReport -PathType Leaf))
    # The input replaced during validation (right after its snapshot), in place and by rename: every report field still
    # comes from the genuine snapshot (the reference report above, apart from the input path), while the file on disk is
    # now the other package.
    $genuineFields = ($report | Select-Object -Property * -ExcludeProperty input | ConvertTo-Json -Depth 5 -Compress)
    $otherZip = Join-Path $fixtures 'newer-umm.zip'
    $replacements = [ordered]@{
        'InPlace' = { param($target) "[IO.File]::WriteAllBytes('$($target.Replace("'", "''"))', [IO.File]::ReadAllBytes('$($otherZip.Replace("'", "''"))'))" }
        'ByRename' = { param($target) "Remove-Item -LiteralPath '$($target.Replace("'", "''"))'; Copy-Item -LiteralPath '$($otherZip.Replace("'", "''"))' -Destination '$($target.Replace("'", "''")).new'; Move-Item -LiteralPath '$($target.Replace("'", "''")).new' -Destination '$($target.Replace("'", "''"))'" } }
    foreach ($kind in $replacements.Keys) {
        $target = Join-Path $fixtures "replaced $kind.zip"; Copy-Item -LiteralPath $genuineZip -Destination $target
        $replacedReport = Join-Path $fixtures "replaced $kind report.json"
        $r = Invoke-ValidatorWithAction '$info = Get-ProductInfo' (& $replacements[$kind] $target) @('-PackagePath', $target, '-ReportPath', $replacedReport)
        $fields = if (Test-Path -LiteralPath $replacedReport) { Get-Content -LiteralPath $replacedReport -Raw | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty input | ConvertTo-Json -Depth 5 -Compress } else { '' }
        Assert-Case "InputReplaced${kind}DuringValidationReportsOnlyTheSnapshot" ($r.ExitCode -eq 0 -and $fields -ceq $genuineFields -and (Get-Sha256 $target) -eq (Get-Sha256 $otherZip))
    }
    # A report destination that becomes an alias of the input at publication (hard link created just before the write) is
    # refused and the package bytes survive; likewise when the input was replaced by rename and the destination aliases
    # the current input file.
    $aliasInput = Join-Path $fixtures 'alias input.zip'; Copy-Item -LiteralPath $genuineZip -Destination $aliasInput
    $aliasReport = Join-Path $fixtures 'alias at publication.json'
    $r = Invoke-ValidatorWithAction '$reportBytes = ' "New-Item -ItemType HardLink -Path '$($aliasReport.Replace("'", "''"))' -Target '$($aliasInput.Replace("'", "''"))' | Out-Null" @('-PackagePath', $aliasInput, '-ReportPath', $aliasReport)
    Assert-Case 'ReportAliasingTheInputAtPublicationIsRefused' ($r.ExitCode -ne 0 -and $r.Output -match 'must not be the validated input' -and (Get-Sha256 $aliasInput) -eq $before)
    $currentInput = Join-Path $fixtures 'current input.zip'; Copy-Item -LiteralPath $genuineZip -Destination $currentInput
    $currentReport = Join-Path $fixtures 'alias of current input.json'
    $swap = "Remove-Item -LiteralPath '$($currentInput.Replace("'", "''"))'; Copy-Item -LiteralPath '$($otherZip.Replace("'", "''"))' -Destination '$($currentInput.Replace("'", "''"))'; New-Item -ItemType HardLink -Path '$($currentReport.Replace("'", "''"))' -Target '$($currentInput.Replace("'", "''"))' | Out-Null"
    $r = Invoke-ValidatorWithAction '$reportBytes = ' $swap @('-PackagePath', $currentInput, '-ReportPath', $currentReport)
    Assert-Case 'ReportAliasingTheReplacedCurrentInputIsRefused' ($r.ExitCode -ne 0 -and $r.Output -match 'must not be the current input file' -and (Get-Sha256 $currentInput) -eq (Get-Sha256 $otherZip))

    # Native runner product preparation (scripts/runtime/NativeProduct.ps1) with real temporary files.
    # Private copies of this invocation go below its own temporary root, so other runs' folders cannot affect a case.
    $runTemp = Join-Path $fixtures 'run temp'; New-Item -ItemType Directory -Path $runTemp | Out-Null
    $plan = Resolve-NativeProductPlan -NoProduct -ProductZip $genuineZip -ProductDll (Join-Path $fixtures 'absent.dll')
    Assert-Case 'NoProductWithZipIsAComparisonOnly' ($plan.Mode -eq 'none' -and $plan.ComparisonZip -eq $genuineZip -and $null -eq (New-ValidatedNativeProduct $plan $validator -TempRoot $runTemp))
    $plan = Resolve-NativeProductPlan -NoProduct -ProductDll (Join-Path $fixtures 'absent.dll')
    Assert-Case 'NoProductWithoutZipNeedsNoProduct' ($plan.Mode -eq 'none' -and $null -eq $plan.ComparisonZip)
    $buildOutput = Join-Path $fixtures 'build output'; New-Item -ItemType Directory -Path $buildOutput | Out-Null
    Copy-Item -LiteralPath $genuine -Destination (Join-Path $buildOutput 'KingmakerCutsceneSkip.dll')
    $plan = Resolve-NativeProductPlan -ProductDll (Join-Path $buildOutput 'KingmakerCutsceneSkip.dll')
    # The bare route's manifest: a mismatched Info.json is refused before anything is staged.
    foreach ($mismatch in @(@('Version', '9.9.9'), @('ManagerVersion', '0.33.0'), @('Id', 'Other'))) {
        $badInfo = Join-Path $fixtures "bare-$($mismatch[0]).json"
        $bi = Get-Content -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Raw | ConvertFrom-Json; $bi.($mismatch[0]) = $mismatch[1]
        $bi | ConvertTo-Json | Set-Content -LiteralPath $badInfo -Encoding UTF8
        $refusedBare = $false; try { New-ValidatedNativeProduct $plan $validator -InfoPath $badInfo -TempRoot $runTemp | Out-Null } catch { $refusedBare = $_.Exception.Message -match 'failed package validation' }
        Assert-Case "BareManifestWithMismatched$($mismatch[0])IsRefused" ($refusedBare -and @(Get-ChildItem -LiteralPath $runTemp -Directory -Filter 'kmcs-product-*').Count -eq 0)
    }
    # In a disposable checkout (this scripts folder and Info.json copied), preparation with its default manifest path:
    # a root Info.json changed after the build to another Id, AssemblyName or EntryMethod is refused before anything is
    # locked, because the expected load target is the product's fixed identity; the genuine frozen pair stages with the
    # validated manifest digest.
    $checkoutRoot = Join-Path $fixtures 'disposable checkout'
    New-Item -ItemType Directory -Path $checkoutRoot | Out-Null
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $checkoutRoot 'scripts') -Recurse
    $checkoutRootInfo = Join-Path $checkoutRoot 'Info.json'
    $genuineInfoText = [IO.File]::ReadAllText((Join-Path (Get-RepositoryRoot) 'Info.json'))
    $prepare = Join-Path $fixtures 'prepare-default-manifest.ps1'
    [IO.File]::WriteAllText($prepare, @'
param([string] $Root, [string] $Dll, [string] $TempRoot, [string] $Mods)
$ErrorActionPreference = 'Stop'
. (Join-Path $Root 'scripts\Common.ps1')
. (Join-Path $Root 'scripts\runtime\NativeProduct.ps1')
$plan = Resolve-NativeProductPlan -ProductDll $Dll
try { $product = New-ValidatedNativeProduct $plan (Join-Path $Root 'scripts\Validate-Package.ps1') -TempRoot $TempRoot 6>$null }
catch { Write-Output ('REFUSED ' + $_.Exception.Message); exit 0 }
$staged = Install-ValidatedNativeProduct $product $Mods
Write-Output ('STAGED ' + $staged + ' ' + (Get-Sha256 (Join-Path $Mods 'KingmakerCutsceneSkip\Info.json')) + ' ' + $product.Validation.info_sha256)
Remove-ValidatedNativeProduct $product
'@)
    $prepTemp = Join-Path $fixtures 'prepare temp'; New-Item -ItemType Directory -Path $prepTemp | Out-Null
    $runPrepare = { param([string] $Mods) $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { (($null | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $prepare -Root $checkoutRoot -Dll $genuine -TempRoot $prepTemp -Mods $Mods 2>&1) | ForEach-Object { "$_" }) -join ' ' } finally { $ErrorActionPreference = $previous } }
    foreach ($changed in @(@('Id', 'OtherMod'), @('AssemblyName', 'Other.dll'), @('EntryMethod', 'KingmakerCutsceneSkip.Main.Other'))) {
        $ci = $genuineInfoText | ConvertFrom-Json; $ci.($changed[0]) = $changed[1]
        $ci | ConvertTo-Json | Set-Content -LiteralPath $checkoutRootInfo -Encoding UTF8
        $o = & $runPrepare (Join-Path $fixtures "unused mods $($changed[0])")
        Assert-Case "DefaultCheckoutManifestWithChanged$($changed[0])IsRefusedBeforeLocking" ($o -match 'REFUSED The product failed package validation' -and @(Get-ChildItem -LiteralPath $prepTemp -Directory).Count -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $fixtures "unused mods $($changed[0])")))
    }
    [IO.File]::WriteAllText($checkoutRootInfo, $genuineInfoText)
    $prepMods = Join-Path $fixtures 'prepare mods'; New-Item -ItemType Directory -Path $prepMods | Out-Null
    $o = & $runPrepare $prepMods
    $m = [regex]::Match($o, 'STAGED ([0-9a-f]{64}) ([0-9a-f]{64}) ([0-9a-f]{64})')
    Assert-Case 'DefaultCheckoutManifestGenuinePairStagesTheValidatedManifest' ($m.Success -and $m.Groups[1].Value -eq (Get-Sha256 $genuine) -and $m.Groups[2].Value -eq $m.Groups[3].Value -and $m.Groups[2].Value -eq (Get-Sha256 $checkoutRootInfo))
    # The checkout's manifest (here a fixture copy) is frozen with the DLL: changing it after preparation does not change
    # what is staged.
    $checkoutInfo = Join-Path $fixtures 'checkout Info.json'; Copy-Item -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Destination $checkoutInfo
    $checkoutInfoSha = Get-Sha256 $checkoutInfo
    $product = New-ValidatedNativeProduct $plan $validator -InfoPath $checkoutInfo -TempRoot $runTemp
    (Get-Content -LiteralPath $checkoutInfo -Raw).Replace('"ManagerVersion"', '"Unvalidated": "x", "ManagerVersion"') | Set-Content -LiteralPath $checkoutInfo -Encoding UTF8
    Copy-Item -LiteralPath $otherVersion -Destination (Join-Path $buildOutput 'KingmakerCutsceneSkip.dll') -Force
    $mods = Join-Path $fixtures 'Mods'; New-Item -ItemType Directory -Path $mods | Out-Null
    $staged = Install-ValidatedNativeProduct $product $mods
    Assert-Case 'ManifestChangedAfterPreparationDoesNotAlterTheStagedManifest' ((Get-Sha256 (Join-Path $mods 'KingmakerCutsceneSkip\Info.json')) -eq $checkoutInfoSha -and (Get-Sha256 $checkoutInfo) -ne $checkoutInfoSha -and $product.Validation.info_sha256 -eq $checkoutInfoSha)
    $privateDir = $product.PrivateDirectory
    Remove-ValidatedNativeProduct $product
    Assert-Case 'BareDllRouteStagesTheValidatedBytesAfterTheBuildOutputChanged' ($staged -eq (Get-Sha256 $genuine) -and (Get-Sha256 (Join-Path $mods 'KingmakerCutsceneSkip\KingmakerCutsceneSkip.dll')) -eq (Get-Sha256 $genuine) -and -not (Test-Path -LiteralPath $privateDir))
    # ZIP route: the prepared private ZIP replaced after validation by an archive with the same product DLL and Id but a
    # changed manifest, or with an additional top-level entry, is refused and nothing is left in the destination; the
    # genuine ZIP stages exactly its four entries with the validated DLL and manifest.
    $zipPlan = Resolve-NativeProductPlan -ProductZip $genuineZip
    $swaps = @(@('ChangedManifest', (New-FixtureZip 'swap-manifest' $genuine { param($i) $i | Add-Member -NotePropertyName Unvalidated -NotePropertyValue 'x' } $null)),
        @('AdditionalEntry', (New-FixtureZip 'swap-extra' $genuine $null @("Extra/added.txt|$(Join-Path (Get-RepositoryRoot) 'README.md')"))))
    foreach ($swap in $swaps) {
        $swapProduct = New-ValidatedNativeProduct $zipPlan $validator -TempRoot $runTemp 6>$null
        [IO.File]::Copy($swap[1], $swapProduct.File, $true)
        $swapMods = Join-Path $fixtures "swap mods $($swap[0])"; New-Item -ItemType Directory -Path $swapMods | Out-Null
        $swapError = ''; try { Install-ValidatedNativeProduct $swapProduct $swapMods | Out-Null } catch { $swapError = $_.Exception.Message }
        Remove-ValidatedNativeProduct $swapProduct
        Assert-Case "ZipReplacedAfterValidationWith$($swap[0])IsRefusedWithNothingStaged" ($swapError -match 'not the validated archive; nothing was staged' -and @(Get-ChildItem -LiteralPath $swapMods -Force).Count -eq 0)
    }
    $zipProduct = New-ValidatedNativeProduct $zipPlan $validator -TempRoot $runTemp 6>$null
    $zipMods = Join-Path $fixtures 'zip mods'; New-Item -ItemType Directory -Path $zipMods | Out-Null
    $zipStaged = Install-ValidatedNativeProduct $zipProduct $zipMods
    $zipTop = @(Get-ChildItem -LiteralPath $zipMods -Force | ForEach-Object { $_.Name })
    $zipFiles = @(Get-ChildItem -LiteralPath (Join-Path $zipMods 'KingmakerCutsceneSkip') -Force | ForEach-Object { $_.Name } | Sort-Object)
    Assert-Case 'GenuineZipStagesExactlyTheValidatedEntries' ($zipStaged -eq [string]$zipProduct.Validation.dll_sha256 -and ($zipTop -join ',') -eq 'KingmakerCutsceneSkip' -and ($zipFiles -join ',') -eq 'Info.json,KingmakerCutsceneSkip.dll,LICENSE,README.md' -and (Get-Sha256 (Join-Path $zipMods 'KingmakerCutsceneSkip\Info.json')) -eq [string]$zipProduct.Validation.info_sha256)
    Remove-ValidatedNativeProduct $zipProduct
    $badPlan = Resolve-NativeProductPlan -ProductZip (Join-Path $fixtures 'newer-umm.zip')
    $before = @(Get-ChildItem -LiteralPath $runTemp -Directory -Filter 'kmcs-product-*').Count
    # Another invocation creating its private folder in the shared temporary directory meanwhile cannot change the result.
    $decoy = Join-Path ([IO.Path]::GetTempPath()) ('kmcs-product-decoy-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $decoy | Out-Null
    $refused = $false; try { New-ValidatedNativeProduct $badPlan $validator -TempRoot $runTemp | Out-Null } catch { $refused = $_.Exception.Message -match 'failed package validation' }
    Remove-Item -LiteralPath $decoy -Recurse -Force
    $after = @(Get-ChildItem -LiteralPath $runTemp -Directory -Filter 'kmcs-product-*').Count
    Assert-Case 'PreparationFailureRemovesThePrivateCopy' ($refused -and $before -eq 0 -and $after -eq 0)
    # A failure after this run took its lock (an evidence path that cannot be created) releases only its own lock.
    $labRoot = Join-Path $fixtures 'lab'; $foreign = Join-Path $fixtures 'other lab\runtime.lock'
    New-Item -ItemType Directory -Path (Split-Path -Parent $foreign) -Force | Out-Null; Set-Content -LiteralPath $foreign -Value 'foreign'
    $fakeLab = [pscustomobject]@{ State = Join-Path $labRoot 'state'; Lock = Join-Path $labRoot 'state\runtime.lock'; Evidence = Join-Path $labRoot 'evidence'; Backups = Join-Path $labRoot 'backups' }
    New-Item -ItemType Directory -Path $labRoot -Force | Out-Null; Set-Content -LiteralPath $fakeLab.Evidence -Value 'a file where the evidence folder belongs'
    $setupFailed = $false; try { Enter-NativeRunDirectories $fakeLab 'fixture-run' | Out-Null } catch { $setupFailed = $true }
    Assert-Case 'PostLockSetupFailureReleasesOwnLockAndKeepsForeignLock' ($setupFailed -and -not (Test-Path -LiteralPath $fakeLab.Lock) -and (Test-Path -LiteralPath $foreign))
    # Final cleanup after a successful restoration: a summary-write failure and a private-copy deletion failure are both
    # surfaced, and this run's lock is still released (a foreign lock survives). On incomplete restoration the lock and
    # the recovery journal are kept.
    $doneLab = [pscustomobject]@{ State = Join-Path $fixtures 'done lab\state'; Lock = Join-Path $fixtures 'done lab\state\runtime.lock'; Journal = Join-Path $fixtures 'done lab\state\journal.json' }
    $doneLock = Enter-RuntimeLock $doneLab 'fixture-complete'
    Set-Content -LiteralPath $doneLab.Journal -Value '{"runId":"fixture-complete"}'
    $heldPrivate = Join-Path $runTemp ('kmcs-product-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $heldPrivate | Out-Null
    Set-Content -LiteralPath (Join-Path $heldPrivate 'product.zip') -Value 'copy'
    $held = [IO.File]::Open((Join-Path $heldPrivate 'held.bin'), [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $blocked = Join-Path $fixtures 'summary blocked'; Set-Content -LiteralPath $blocked -Value 'a file where the evidence folder belongs'
    $completeError = ''
    try { Complete-NativeRun $doneLab $doneLock $true ([ordered]@{ status = 'passed' }) (Join-Path $blocked 'host-summary.json') ([pscustomobject]@{ PrivateDirectory = $heldPrivate }) 'fixture-complete' 3>$null }
    catch { $completeError = $_.Exception.Message }
    finally { $held.Dispose() }
    Assert-Case 'RestoredRunReleasesOwnLockDespiteSummaryAndCleanupFailures' ($completeError -match 'summary write failed' -and $completeError -match 'private product cleanup failed' -and -not (Test-Path -LiteralPath $doneLock) -and (Test-Path -LiteralPath $foreign))
    Remove-Item -LiteralPath $heldPrivate -Recurse -Force
    # A writable summary with a private file held open: the saved summary records the failed cleanup as an integrity
    # failure (scenario status kept), the owned lock is still released after restoration and the error is surfaced.
    $cleanupLock = Enter-RuntimeLock $doneLab 'fixture-cleanup'
    $heldPrivate = Join-Path $runTemp ('kmcs-product-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $heldPrivate | Out-Null
    $held = [IO.File]::Open((Join-Path $heldPrivate 'held.bin'), [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $cleanupSummaryPath = Join-Path $fixtures 'cleanup evidence\host-summary.json'
    $cleanupError = ''
    try { Complete-NativeRun $doneLab $cleanupLock $true ([ordered]@{ status = 'passed'; restored = $true }) $cleanupSummaryPath ([pscustomobject]@{ PrivateDirectory = $heldPrivate }) 'fixture-cleanup' 3>$null }
    catch { $cleanupError = $_.Exception.Message }
    finally { $held.Dispose() }
    $saved = if (Test-Path -LiteralPath $cleanupSummaryPath) { Get-Content -LiteralPath $cleanupSummaryPath -Raw | ConvertFrom-Json } else { $null }
    Assert-Case 'PrivateCopyCleanupFailureIsAFailedOutcomeInTheSavedSummary' ($cleanupError -match 'private product cleanup failed' -and $cleanupError -notmatch 'summary write failed' -and $null -ne $saved -and $saved.status -eq 'integrity-failed' -and $saved.scenarioStatus -eq 'passed' -and $saved.privateCopyRemoved -eq $false -and @($saved.integrityFailures | Where-Object { $_ -match 'private product cleanup failed' }).Count -eq 1 -and $saved.restored -eq $true -and -not (Test-Path -LiteralPath $cleanupLock) -and (Test-Path -LiteralPath $foreign))
    Remove-Item -LiteralPath $heldPrivate -Recurse -Force
    $keptLock = Enter-RuntimeLock $doneLab 'fixture-incomplete'
    $incompleteError = ''
    try { Complete-NativeRun $doneLab $keptLock $false ([ordered]@{ status = 'failed' }) (Join-Path $fixtures 'incomplete summary.json') $null 'fixture-incomplete' 3>$null } catch { $incompleteError = $_.Exception.Message }
    Assert-Case 'IncompleteRestorationKeepsLockAndJournal' ($incompleteError -eq '' -and (Test-Path -LiteralPath $keptLock) -and (Test-Path -LiteralPath $doneLab.Journal) -and (Test-Path -LiteralPath (Join-Path $fixtures 'incomplete summary.json')))
    Exit-RuntimeLock $doneLab $keptLock 'fixture-incomplete'
    Remove-Item -LiteralPath $doneLab.Journal -Force
    # The owned lock cannot be deleted after a successful restoration (held open without delete sharing): the saved summary
    # is a failed host outcome with the scenario result kept, a release-only journal is written, and guarded recovery,
    # once the handle is released, removes only that run's lock (another run's lock is refused and kept).
    $releaseLock = Enter-RuntimeLock $doneLab 'fixture-release'
    $holder = [IO.File]::Open($releaseLock, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $releaseSummaryPath = Join-Path $fixtures 'release evidence\host-summary.json'
    $releaseError = ''
    try { Complete-NativeRun $doneLab $releaseLock $true ([ordered]@{ status = 'passed'; restored = $true }) $releaseSummaryPath $null 'fixture-release' 3>$null }
    catch { $releaseError = $_.Exception.Message }
    finally { $holder.Dispose() }
    $releaseSaved = if (Test-Path -LiteralPath $releaseSummaryPath) { Get-Content -LiteralPath $releaseSummaryPath -Raw | ConvertFrom-Json } else { $null }
    $releaseJournal = if (Test-Path -LiteralPath $doneLab.Journal) { Get-Content -LiteralPath $doneLab.Journal -Raw | ConvertFrom-Json } else { $null }
    Assert-Case 'LockReleaseFailureIsAFailedSavedOutcomeWithARecoveryJournal' ($releaseError -match 'lock release failed' -and $null -ne $releaseSaved -and $releaseSaved.status -eq 'integrity-failed' -and $releaseSaved.scenarioStatus -eq 'passed' -and $releaseSaved.lockReleased -eq $false -and $releaseSaved.restored -eq $true -and (Test-Path -LiteralPath $releaseLock) -and $null -ne $releaseJournal -and $releaseJournal.phase -eq 'release-lock' -and $releaseJournal.runId -eq 'fixture-release')
    $otherRunLock = [IO.File]::ReadAllText($releaseLock)
    [IO.File]::WriteAllText($releaseLock, "runId=another-run`n")
    $refusedRecovery = ''; try { Restore-InterruptedRun $doneLab 6>$null } catch { $refusedRecovery = $_.Exception.Message }
    Assert-Case 'ReleaseRecoveryRefusesAnotherRunsLock' ($refusedRecovery -match "belongs to run 'another-run'" -and (Test-Path -LiteralPath $releaseLock) -and (Test-Path -LiteralPath $doneLab.Journal))
    [IO.File]::WriteAllText($releaseLock, $otherRunLock)
    Restore-InterruptedRun $doneLab 6>$null
    Assert-Case 'ReleaseRecoveryClearsOnlyThatRunsLock' (-not (Test-Path -LiteralPath $releaseLock) -and -not (Test-Path -LiteralPath $doneLab.Journal) -and (Test-Path -LiteralPath $foreign))
    # Ordinary interrupted-run recovery in disposable labs (fixture Mods folders; no Params or registry backup). These labs
    # have no game, so inside these blocks only, the shared wait for a running Kingmaker sees an empty process list.
    $noGame = { function Get-Process { } }
    $newLab = { param([string] $Name) $state = Join-Path $fixtures "$Name\state"; [pscustomobject]@{ State = $state; Lock = Join-Path $state 'runtime.lock'; Journal = Join-Path $state 'active-run.json' } }
    $newOrdinary = { param($Lab, [string] $RunId)
        $modsDir = Join-Path (Split-Path -Parent $Lab.State) 'Mods'; $stagedDir = Join-Path $modsDir 'KingmakerCutsceneSkip'
        New-Item -ItemType Directory -Path $stagedDir -Force | Out-Null; Set-Content -LiteralPath (Join-Path $stagedDir 'staged.txt') -Value 'staged'
        New-Item -ItemType Directory -Path $Lab.State -Force | Out-Null
        Save-Journal $Lab ([ordered]@{ runId = $RunId; modsDir = $modsDir; staged = @($stagedDir); modsOriginal = $null; paramsBackup = $null; paramsTarget = $null; registryBackup = $null; completedSteps = @() })
        return $stagedDir }
    # The owned lock held open (read sharing only) during recovery: restoration completes, the first attempt fails at the
    # release and leaves a release-lock journal for this run with the lock; after the handle closes, a second attempt
    # clears only that transaction.
    $heldLab = & $newLab 'held lab'
    $heldStaged = & $newOrdinary $heldLab 'fixture-held'
    $heldLock = Enter-RuntimeLock $heldLab 'fixture-held'
    $holder = [IO.File]::Open($heldLock, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $firstError = ''
    try { & { . $noGame; Restore-InterruptedRun $heldLab 6>$null } } catch { $firstError = $_.Exception.Message } finally { $holder.Dispose() }
    $heldJournal = if (Test-Path -LiteralPath $heldLab.Journal) { Get-Content -LiteralPath $heldLab.Journal -Raw | ConvertFrom-Json } else { $null }
    Assert-Case 'OrdinaryRecoveryWithTheLockHeldRestoresAndKeepsARetryableReleaseJournal' ($firstError -match 'cannot be opened exclusively' -and -not (Test-Path -LiteralPath $heldStaged) -and (Test-Path -LiteralPath $heldLock) -and $null -ne $heldJournal -and $heldJournal.phase -eq 'release-lock' -and $heldJournal.runId -eq 'fixture-held')
    & { . $noGame; Restore-InterruptedRun $heldLab 6>$null }
    Assert-Case 'OrdinaryRecoveryRetryAfterTheHandleClosesClearsOnlyThatTransaction' (-not (Test-Path -LiteralPath $heldLock) -and -not (Test-Path -LiteralPath $heldLab.Journal) -and (Test-Path -LiteralPath $foreign))
    # Ownership before change: an ordinary journal for run A while this lab's lock records run B is refused before any
    # restoration (staged files, journal and lock unchanged).
    $labA = & $newLab 'lab A'; $labB = & $newLab 'lab B'
    $stagedA = & $newOrdinary $labA 'fixture-A'
    [void](Enter-RuntimeLock $labA 'fixture-B')
    $journalBefore = Get-Sha256 $labA.Journal
    $ownerError = ''; try { & { . $noGame; Restore-InterruptedRun $labA 6>$null } } catch { $ownerError = $_.Exception.Message }
    Assert-Case 'OrdinaryJournalWithAnotherRunsLockLeavesStagedFilesUntouched' ($ownerError -match "belongs to run 'fixture-B', not 'fixture-A'; nothing was changed" -and (Test-Path -LiteralPath (Join-Path $stagedA 'staged.txt')) -and (Get-Sha256 $labA.Journal) -eq $journalBefore -and (Test-Path -LiteralPath $labA.Lock))
    # A release-only journal naming another lab's lock path: only this lab's lock is the authority (here another run's),
    # so it is refused and both locks are kept, including the other lab's lock that records the journal's own run.
    [void](Enter-RuntimeLock $labB 'fixture-A')
    Save-Journal $labA ([ordered]@{ runId = 'fixture-A'; phase = 'release-lock'; lock = $labB.Lock })
    $foreignPathError = ''; try { Restore-InterruptedRun $labA 6>$null } catch { $foreignPathError = $_.Exception.Message }
    Assert-Case 'ReleaseJournalWithAForeignLockPathPreservesBothLocks' ($foreignPathError -match "belongs to run 'fixture-B', not 'fixture-A'" -and (Test-Path -LiteralPath $labA.Lock) -and (Test-Path -LiteralPath $labB.Lock) -and (Test-Path -LiteralPath $labA.Journal))
    Save-Journal $labA ([ordered]@{ runId = ''; phase = 'release-lock'; lock = $labA.Lock })
    $emptyIdError = ''; try { Restore-InterruptedRun $labA 6>$null } catch { $emptyIdError = $_.Exception.Message }
    Assert-Case 'ReleaseJournalWithAnEmptyRunIdPreservesBothLocks' ($emptyIdError -match 'names no run' -and (Test-Path -LiteralPath $labA.Lock) -and (Test-Path -LiteralPath $labB.Lock) -and (Test-Path -LiteralPath $labA.Journal))
    # Replacement of the lock between inspection and removal, in a child process with a line breakpoint (no hook in the
    # runner). Before the exclusive open: a successor's lock written there is read through the handle and kept. After the
    # ownership check, before the deletion: the replacement is refused by the exclusive handle and the verified lock is
    # removed.
    $raceScript = Join-Path $PSScriptRoot 'runtime\RuntimeLab.Common.ps1'
    $raceLines = [IO.File]::ReadAllLines($raceScript)
    $lineOf = { param([string] $Anchor) for ($i = 0; $i -lt $raceLines.Length; $i++) { if ($raceLines[$i].TrimStart().StartsWith($Anchor)) { return $i + 1 } }; throw "Anchor not found: $Anchor" }
    $q = { param([string] $t) "'" + $t.Replace("'", "''") + "'" }
    foreach ($race in @(@('BeforeTheExclusiveOpen', '$lockStream = [KmcsRuntimeLock]::OpenExclusive($lock)'), @('AfterTheOwnershipCheck', '[KmcsRuntimeLock]::DeleteWhenClosed($lockStream)'))) {
        $raceLab = & $newLab "race lab $($race[0])"
        $driver = Join-Path $fixtures ('race-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [IO.File]::WriteAllText($driver, ("`$ErrorActionPreference = 'Stop'`r`n" +
            ". $(& $q (Join-Path $PSScriptRoot 'Common.ps1'))`r`n. $(& $q $raceScript)`r`n" +
            "`$lab = [pscustomobject]@{ State = $(& $q $raceLab.State); Lock = $(& $q $raceLab.Lock); Journal = $(& $q $raceLab.Journal) }`r`n" +
            "[void](Enter-RuntimeLock `$lab 'fixture-race')`r`n`$global:replaced = 'not reached'`r`n" +
            "Set-PSBreakpoint -Script $(& $q $raceScript) -Line $(& $lineOf $race[1]) -Action { if (`$global:replaced -eq 'not reached') { try { [IO.File]::WriteAllText(`$lab.Lock, ""runId=fixture-successor``n""); `$global:replaced = 'written' } catch { `$global:replaced = 'refused' } } } | Out-Null`r`n" +
            "try { Exit-RuntimeLock `$lab `$lab.Lock 'fixture-race'; `$outcome = 'released' } catch { `$outcome = 'refused: ' + `$_.Exception.Message }`r`n" +
            "Write-Output (""REPLACEMENT="" + `$global:replaced + "" OUTCOME="" + `$outcome + "" LOCK="" + `$(if (Test-Path -LiteralPath `$lab.Lock) { [IO.File]::ReadAllText(`$lab.Lock).Trim() } else { 'absent' }))`r`n"))
        $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $raceOutput = (($null | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $driver 2>&1) | ForEach-Object { "$_" }) -join ' ' } finally { $ErrorActionPreference = $previous }
        if ($race[0] -eq 'BeforeTheExclusiveOpen') {
            Assert-Case 'LockReplacedBeforeTheExclusiveOpenIsKeptForItsOwner' ($raceOutput -match "REPLACEMENT=written OUTCOME=refused: .*belongs to run 'fixture-successor'.* LOCK=runId=fixture-successor")
        }
        else {
            Assert-Case 'LockReplacementAfterTheOwnershipCheckIsRefusedAndOnlyTheVerifiedLockIsRemoved' ($raceOutput -match 'REPLACEMENT=refused OUTCOME=released LOCK=absent')
        }
    }
    # A no-product control never inherits Cutscene Skip from the owner profile it copies (with or without a comparison
    # ZIP); the owner's source set is left intact; a profile already containing it is refused.
    $pristine = Join-Path $fixtures 'owner pristine'
    foreach ($modName in @('KingmakerCutsceneSkip', 'OtherOwnerMod')) { $d = Join-Path $pristine "Mods\$modName"; New-Item -ItemType Directory -Path $d -Force | Out-Null; Set-Content -LiteralPath (Join-Path $d 'Info.json') -Value "{`"Id`":`"$modName`"}" }
    $sourceListing = { (Get-ChildItem -LiteralPath (Join-Path $pristine 'Mods') -Recurse -File | ForEach-Object { $_.FullName.Substring($pristine.Length) + '=' + (Get-Sha256 $_.FullName) }) -join ';' }
    $sourceBefore = & $sourceListing
    foreach ($withZip in @($true, $false)) {
        $npPlan = if ($withZip) { Resolve-NativeProductPlan -NoProduct -ProductZip $genuineZip } else { Resolve-NativeProductPlan -NoProduct }
        $copyPaths = [pscustomobject]@{ ModsDir = Join-Path $fixtures "copy mods $withZip"; Pristine = $pristine }
        $copied = @(Set-GameCopyMods $copyPaths 'owner' @() -ExcludeModIds @(Get-InheritedModExclusions $npPlan))
        $controlOk = $true; try { Assert-NoProductControlMods $copyPaths.ModsDir } catch { $controlOk = $false }
        Assert-Case "NoProductControlExcludesInheritedCutsceneSkip$(if ($withZip) { 'WithComparisonZip' } else { 'WithoutZip' })" ($copied -notcontains 'KingmakerCutsceneSkip' -and $copied -contains 'OtherOwnerMod' -and -not (Test-Path -LiteralPath (Join-Path $copyPaths.ModsDir 'KingmakerCutsceneSkip')) -and $controlOk)
    }
    $refusedControl = $false; try { Assert-NoProductControlMods (Join-Path $pristine 'Mods') } catch { $refusedControl = $_.Exception.Message -match 'refusing before staging' }
    Assert-Case 'NoProductControlWithAnInstalledCutsceneSkipIsRefusedAndTheSourceIsIntact' ($refusedControl -and (& $sourceListing) -ceq $sourceBefore)
    # The shipping UMM Id under another folder name (and in another case): identified from the manifest, excluded from the
    # copy with or without a comparison ZIP, refused in a profile that contains it; the unrelated mod and the source stay.
    $renamed = Join-Path $fixtures 'owner pristine renamed'
    $renamedMods = @{ 'Skip Under Another Name' = 'KingmakerCutsceneSkip'; 'lowercase id copy' = 'kingmakercutsceneskip'; 'OtherOwnerMod' = 'OtherOwnerMod' }
    foreach ($folder in $renamedMods.Keys) { $d = Join-Path $renamed "Mods\$folder"; New-Item -ItemType Directory -Path $d -Force | Out-Null; Set-Content -LiteralPath (Join-Path $d 'Info.json') -Value "{`"Id`":`"$($renamedMods[$folder])`",`"DisplayName`":`"$folder`"}" }
    $renamedListing = { (Get-ChildItem -LiteralPath (Join-Path $renamed 'Mods') -Recurse -File | ForEach-Object { $_.FullName.Substring($renamed.Length) + '=' + (Get-Sha256 $_.FullName) }) -join ';' }
    $renamedBefore = & $renamedListing
    foreach ($withZip in @($true, $false)) {
        $npPlan = if ($withZip) { Resolve-NativeProductPlan -NoProduct -ProductZip $genuineZip } else { Resolve-NativeProductPlan -NoProduct }
        $copyPaths = [pscustomobject]@{ ModsDir = Join-Path $fixtures "renamed copy mods $withZip"; Pristine = $renamed }
        $copied = @(Set-GameCopyMods $copyPaths 'owner' @() -ExcludeModIds @(Get-InheritedModExclusions $npPlan))
        $controlOk = $true; try { Assert-NoProductControlMods $copyPaths.ModsDir } catch { $controlOk = $false }
        Assert-Case "NoProductControlExcludesTheShippingIdUnderAnotherFolderName$(if ($withZip) { 'WithComparisonZip' } else { 'WithoutZip' })" ($copied -notcontains 'Skip Under Another Name' -and $copied -notcontains 'lowercase id copy' -and $copied -contains 'OtherOwnerMod' -and @(Get-ChildItem -LiteralPath $copyPaths.ModsDir -Directory).Count -eq 1 -and $controlOk)
    }
    $refusedRenamed = ''; try { Assert-NoProductControlMods (Join-Path $renamed 'Mods') } catch { $refusedRenamed = $_.Exception.Message }
    Assert-Case 'NoProductControlRefusesTheShippingIdUnderAnotherFolderNameAndKeepsTheSource' ($refusedRenamed -match 'UMM Id KingmakerCutsceneSkip in folder' -and (& $renamedListing) -ceq $renamedBefore)
    # Product runs: an owner profile carrying an older Cutscene Skip under another folder name. Game copies (ZIP and bare
    # DLL routes) never inherit it, so after staging the validated candidate is the only folder with the shipping Id; a
    # live profile containing it is refused before staging; the source is unchanged.
    $older = Join-Path $fixtures 'owner pristine older skip'
    foreach ($entry in @(@('Older Skip 0.1.1', 'KingmakerCutsceneSkip'), @('OtherOwnerMod', 'OtherOwnerMod'))) { $d = Join-Path $older "Mods\$($entry[0])"; New-Item -ItemType Directory -Path $d -Force | Out-Null; Set-Content -LiteralPath (Join-Path $d 'Info.json') -Value "{`"Id`":`"$($entry[1])`",`"Version`":`"0.1.1`"}"; Set-Content -LiteralPath (Join-Path $d 'KingmakerCutsceneSkip.dll') -Value 'older build' }
    $olderListing = { (Get-ChildItem -LiteralPath (Join-Path $older 'Mods') -Recurse -File | ForEach-Object { $_.FullName.Substring($older.Length) + '=' + (Get-Sha256 $_.FullName) }) -join ';' }
    $olderBefore = & $olderListing
    $dllOutput = Join-Path $fixtures 'older test build output'; New-Item -ItemType Directory -Path $dllOutput | Out-Null
    Copy-Item -LiteralPath $genuine -Destination (Join-Path $dllOutput 'KingmakerCutsceneSkip.dll')
    foreach ($route in @(@('Zip', (Resolve-NativeProductPlan -ProductZip $genuineZip)), @('BareDll', (Resolve-NativeProductPlan -ProductDll (Join-Path $dllOutput 'KingmakerCutsceneSkip.dll'))))) {
        $copyPaths = [pscustomobject]@{ ModsDir = Join-Path $fixtures "older copy mods $($route[0])"; Pristine = $older }
        $copied = @(Set-GameCopyMods $copyPaths 'owner' @() -ExcludeModIds @(Get-InheritedModExclusions $route[1]))
        $beforeStaging = $true; try { Assert-NoInstalledShippingMod $copyPaths.ModsDir } catch { $beforeStaging = $false }
        $routeProduct = New-ValidatedNativeProduct $route[1] $validator -TempRoot $runTemp
        $stagedDll = Install-ValidatedNativeProduct $routeProduct $copyPaths.ModsDir
        Remove-ValidatedNativeProduct $routeProduct
        $onlyStaged = $true; try { Assert-OnlyStagedShippingMod $copyPaths.ModsDir 'KingmakerCutsceneSkip' } catch { $onlyStaged = $false }
        Assert-Case "ProductRun$($route[0])LoadsOnlyTheValidatedCandidate" ($copied -notcontains 'Older Skip 0.1.1' -and $copied -contains 'OtherOwnerMod' -and $beforeStaging -and $onlyStaged -and $stagedDll -eq (Get-Sha256 $genuine) -and @(Get-ShippingModFolders $copyPaths.ModsDir).Count -eq 1)
    }
    $refusedLive = ''; try { Assert-NoInstalledShippingMod (Join-Path $older 'Mods') } catch { $refusedLive = $_.Exception.Message }
    $twoCopies = Join-Path $fixtures 'two copies mods'; Copy-Item -LiteralPath (Join-Path $older 'Mods') -Destination $twoCopies -Recurse
    New-Item -ItemType Directory -Path (Join-Path $twoCopies 'KingmakerCutsceneSkip') | Out-Null; Copy-Item -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Destination (Join-Path $twoCopies 'KingmakerCutsceneSkip\Info.json')
    $refusedTwo = ''; try { Assert-OnlyStagedShippingMod $twoCopies 'KingmakerCutsceneSkip' } catch { $refusedTwo = $_.Exception.Message }
    Assert-Case 'ProductRunRefusesALiveProfileWithAnOlderShippingIdAndKeepsTheSource' ($refusedLive -match "refusing before staging" -and $refusedLive -match 'Older Skip 0\.1\.1' -and $refusedTwo -match 'only in' -and (& $olderListing) -ceq $olderBefore)
    # Name-independent inventory: the shipping manifest in a folder named Keys and in a hidden folder is found; a profile
    # with only an unrelated mod passes.
    foreach ($case in @(@('Keys', $false), @('Hidden Skip', $true))) {
        $profileDir = Join-Path $fixtures "effective $($case[0])"
        $d = Join-Path $profileDir $case[0]; New-Item -ItemType Directory -Path $d -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Destination (Join-Path $d 'Info.json')
        $u = Join-Path $profileDir 'OtherOwnerMod'; New-Item -ItemType Directory -Path $u | Out-Null; Set-Content -LiteralPath (Join-Path $u 'Info.json') -Value '{"Id":"OtherOwnerMod"}'
        if ($case[1]) { (Get-Item -LiteralPath $d).Attributes = [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::Hidden }
        $listing = (Get-ChildItem -LiteralPath $profileDir -Recurse -File -Force | ForEach-Object { $_.FullName + '=' + (Get-Sha256 $_.FullName) }) -join ';'
        $refusedCase = ''; try { Assert-NoProductControlMods $profileDir } catch { $refusedCase = $_.Exception.Message }
        Assert-Case "NoProductControlFindsTheShippingIdInFolder$($case[0].Replace(' ', ''))" ($refusedCase -match "in folder '$($case[0])'" -and ((Get-ChildItem -LiteralPath $profileDir -Recurse -File -Force | ForEach-Object { $_.FullName + '=' + (Get-Sha256 $_.FullName) }) -join ';') -ceq $listing)
    }
    $unrelatedOnly = Join-Path $fixtures 'effective unrelated'; $u = Join-Path $unrelatedOnly 'OtherOwnerMod'; New-Item -ItemType Directory -Path $u -Force | Out-Null; Set-Content -LiteralPath (Join-Path $u 'Info.json') -Value '{"Id":"OtherOwnerMod"}'
    $unrelatedOk = $true; try { Assert-NoProductControlMods $unrelatedOnly } catch { $unrelatedOk = $false }
    Assert-Case 'NoProductControlWithOnlyAnUnrelatedModPasses' $unrelatedOk
    # Only the selected folders' manifests are read: a malformed manifest in an unselected folder does not block an empty
    # isolated selection or a valid named subset; selecting it refuses.
    $malformed = Join-Path $fixtures 'pristine with malformed'
    foreach ($entry in @(@('Broken', '{ not json'), @('OtherOwnerMod', '{"Id":"OtherOwnerMod"}'))) { $d = Join-Path $malformed "Mods\$($entry[0])"; New-Item -ItemType Directory -Path $d -Force | Out-Null; Set-Content -LiteralPath (Join-Path $d 'Info.json') -Value $entry[1] }
    $npPlan = Resolve-NativeProductPlan -NoProduct
    $emptyOk = $true; try { $emptyCopy = @(Set-GameCopyMods ([pscustomobject]@{ ModsDir = Join-Path $fixtures 'malformed empty'; Pristine = $malformed }) 'isolated' @() -ExcludeModIds @(Get-InheritedModExclusions $npPlan)) } catch { $emptyOk = $false }
    $subsetOk = $true; try { $subsetCopy = @(Set-GameCopyMods ([pscustomobject]@{ ModsDir = Join-Path $fixtures 'malformed subset'; Pristine = $malformed }) 'isolated' @('OtherOwnerMod') -ExcludeModIds @(Get-InheritedModExclusions $npPlan)) } catch { $subsetOk = $false }
    $selectedRefusal = ''; try { Set-GameCopyMods ([pscustomobject]@{ ModsDir = Join-Path $fixtures 'malformed selected'; Pristine = $malformed }) 'isolated' @('Broken') -ExcludeModIds @(Get-InheritedModExclusions $npPlan) | Out-Null } catch { $selectedRefusal = $_.Exception.Message }
    Assert-Case 'UnselectedMalformedManifestDoesNotBlockAnIsolatedSelection' ($emptyOk -and $emptyCopy.Count -eq 0 -and $subsetOk -and ($subsetCopy -join ',') -eq 'OtherOwnerMod')
    Assert-Case 'SelectedMalformedManifestIsRefused' ($selectedRefusal -match "manifest of mod folder 'Broken' cannot be read")
}
finally { Remove-Item -LiteralPath $fixtures -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "RESULT provenance total=$($script:total) failed=$($script:failed)"
if ($script:failed -ne 0) { throw "Provenance tests failed: $($script:failed)." }
