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

function New-Identity([string] $File, [string] $Sha, [string] $Url, [string] $AssemblyVersion) {
    if (-not $AssemblyVersion) { $AssemblyVersion = switch ($File) { 'UnityModManager.dll' { '0.31.1.0' } '0Harmony12.dll' { '1.2.0.1' } default { '1.0.0.0' } } }
    return [pscustomobject]@{ role = 'pinned loader reference'; file = $File; assembly_version = $AssemblyVersion; sha256 = $Sha; source = $Url }
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
# The recorded assembly version must be the declared pin version: a receipt naming UnityModManager 0.33.0.0 (digest and
# source unchanged) is a problem.
$otherVersion = @((New-Identity 'UnityModManager.dll' $shaA 'u1' '0.33.0.0'), (New-Identity '0Harmony12.dll' $shaB 'u2'))
$found = @(Get-ReferencePinProblems ([pscustomobject]@{ references = $otherVersion }) $pins '0.31.1')
Assert-Case 'RecordedAssemblyVersionContradictingThePinIsAProblem' ($found.Count -gt 0 -and ($found -join ' ') -match 'recorded as assembly version 0\.33\.0\.0, but the pin declares 0\.31\.1\.0')
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
    # Repeated required members whose last declaration is genuine (ConvertFrom-Json would keep only that one) are refused,
    # in a ZIP manifest and in a bare manifest.
    $genuineInfoRaw = [IO.File]::ReadAllText((Join-Path (Get-RepositoryRoot) 'Info.json'))
    $dupManager = Join-Path $fixtures 'duplicate-managerversion Info.json'
    [IO.File]::WriteAllText($dupManager, $genuineInfoRaw.Replace('"ManagerVersion"', '"ManagerVersion": "0.33.0", "ManagerVersion"'), [Text.UTF8Encoding]::new($false))
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'duplicate-managerversion' $genuine $null @("KingmakerCutsceneSkip/Info.json|$dupManager")))
    Assert-Case 'PackagedManifestDeclaringManagerVersionTwiceIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'Packaged Info\.json declares ManagerVersion more than once')
    $dupEntry = Join-Path $fixtures 'duplicate-entrymethod Info.json'
    [IO.File]::WriteAllText($dupEntry, $genuineInfoRaw.Replace('"EntryMethod"', '"EntryMethod": "Other.Main.Load", "EntryMethod"'), [Text.UTF8Encoding]::new($false))
    $r = Invoke-Validator @('-DllPath', $genuine, '-InfoPath', $dupEntry)
    Assert-Case 'BareManifestDeclaringEntryMethodTwiceIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'Info\.json declares EntryMethod more than once')
    # R6-F4: a conflicting earlier declaration in another quoting form that Windows PowerShell's decoder accepts (single
    # quotes in the ZIP manifest, no quotes in the bare manifest), with the genuine value last, is refused on both routes.
    $mixedManager = Join-Path $fixtures 'mixed-quoting-managerversion Info.json'
    [IO.File]::WriteAllText($mixedManager, $genuineInfoRaw.Replace('"ManagerVersion"', "'ManagerVersion': `"0.33.0`", `"ManagerVersion`""), [Text.UTF8Encoding]::new($false))
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'mixed-quoting-managerversion' $genuine $null @("KingmakerCutsceneSkip/Info.json|$mixedManager")))
    Assert-Case 'PackagedManifestWithSingleQuotedConflictingManagerVersionIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'unsupported member-name syntax')
    $mixedEntry = Join-Path $fixtures 'mixed-quoting-entrymethod Info.json'
    [IO.File]::WriteAllText($mixedEntry, $genuineInfoRaw.Replace('"EntryMethod"', 'EntryMethod: "Other.Main.Load", "EntryMethod"'), [Text.UTF8Encoding]::new($false))
    $r = Invoke-Validator @('-DllPath', $genuine, '-InfoPath', $mixedEntry)
    Assert-Case 'BareManifestWithUnquotedConflictingEntryMethodIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'unsupported member-name syntax')
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

    # The bare route's manifest: Info.json with a mismatched Version, ManagerVersion or Id beside the genuine DLL is refused
    # by the standalone validator. (The native runner's product preparation and recovery cases were removed in round 8
    # with that runner machinery; scripts/runtime is unchanged from main.)
    foreach ($mismatch in @(@('Version', '9.9.9'), @('ManagerVersion', '0.33.0'), @('Id', 'Other'))) {
        $badInfo = Join-Path $fixtures "bare-$($mismatch[0]).json"
        $bi = Get-Content -LiteralPath (Join-Path (Get-RepositoryRoot) 'Info.json') -Raw | ConvertFrom-Json; $bi.($mismatch[0]) = $mismatch[1]
        $bi | ConvertTo-Json | Set-Content -LiteralPath $badInfo -Encoding UTF8
        $r = Invoke-Validator @('-DllPath', $genuine, '-InfoPath', $badInfo)
        Assert-Case "BareManifestWithMismatched$($mismatch[0])IsRefused" ($r.ExitCode -ne 0)
    }
}
finally { Remove-Item -LiteralPath $fixtures -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "RESULT provenance total=$($script:total) failed=$($script:failed)"
if ($script:failed -ne 0) { throw "Provenance tests failed: $($script:failed)." }
