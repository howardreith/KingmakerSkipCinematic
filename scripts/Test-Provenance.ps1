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

$pins = @((New-Pin 'UnityModManager.dll' 'aaa' 'u1' 'UnityModManager' '0.31.1'), (New-Pin '0Harmony12.dll' 'bbb' 'u2' '0Harmony12' '1.2.0.1'))
$game = [pscustomobject]@{ role = 'local game reference'; file = 'Assembly-CSharp.dll'; sha256 = 'ccc' }
$good = @((New-Identity 'UnityModManager.dll' 'aaa' 'u1'), (New-Identity '0Harmony12.dll' 'bbb' 'u2'), $game)

Assert-Case 'MatchingReceiptHasNoProblems' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $good }) $pins '0.31.1').Count -eq 0)

$changed = @((New-Identity 'UnityModManager.dll' 'zzz' 'u1'), (New-Identity '0Harmony12.dll' 'bbb' 'u2'))
Assert-Case 'ChangedHashIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $changed }) $pins '0.31.1').Count -gt 0)

$otherSource = @((New-Identity 'UnityModManager.dll' 'aaa' 'elsewhere'), (New-Identity '0Harmony12.dll' 'bbb' 'u2'))
Assert-Case 'ChangedSourceIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $otherSource }) $pins '0.31.1').Count -gt 0)

$missing = @((New-Identity 'UnityModManager.dll' 'aaa' 'u1'))
Assert-Case 'MissingIdentityIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $missing }) $pins '0.31.1').Count -gt 0)

$extra = $good + @(New-Identity 'Unexpected.dll' 'ddd' 'u3')
Assert-Case 'UnpinnedIdentityIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $extra }) $pins '0.31.1').Count -gt 0)

Assert-Case 'ReceiptWithoutReferencesIsRejected' (@(Get-ReferencePinProblems ([pscustomobject]@{ status = 'passed' }) $pins '0.31.1').Count -gt 0)
Assert-Case 'ManagerVersionMustEqualThePinnedLoader' (@(Get-ReferencePinProblems ([pscustomobject]@{ references = $good }) $pins '0.33.0').Count -gt 0)

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
    Assert-Case 'PackagedWrongAssemblyTargetIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'AssemblyName is .Other\.dll., not the shipping')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'wrong-entry' $genuine { param($i) $i.EntryMethod = 'KingmakerCutsceneSkip.Main.Other' } $null))
    Assert-Case 'PackagedWrongEntryMethodIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'EntryMethod is .KingmakerCutsceneSkip\.Main\.Other., not the shipping')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'extra-loader' $genuine $null @("KingmakerCutsceneSkip/0Harmony12.dll|$(Join-Path $pinnedDir '0Harmony12.dll')")))
    Assert-Case 'PackageCarryingALoaderAssemblyIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match "entries outside the mod's four files: KingmakerCutsceneSkip/0Harmony12\.dll")
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'raised-manager' $genuine { param($i) $i.ManagerVersion = '0.33.0' } $null))
    Assert-Case 'PackagedManagerVersionAbovePinIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'ManagerVersion 0\.33\.0 must equal the pinned loader floor 0\.31\.1')
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

    # Native runner product preparation (scripts/runtime/NativeProduct.ps1) with real temporary files.
    $plan = Resolve-NativeProductPlan -NoProduct -ProductZip $genuineZip -ProductDll (Join-Path $fixtures 'absent.dll')
    Assert-Case 'NoProductWithZipIsAComparisonOnly' ($plan.Mode -eq 'none' -and $plan.ComparisonZip -eq $genuineZip -and $null -eq (New-ValidatedNativeProduct $plan $validator))
    $plan = Resolve-NativeProductPlan -NoProduct -ProductDll (Join-Path $fixtures 'absent.dll')
    Assert-Case 'NoProductWithoutZipNeedsNoProduct' ($plan.Mode -eq 'none' -and $null -eq $plan.ComparisonZip)
    $buildOutput = Join-Path $fixtures 'build output'; New-Item -ItemType Directory -Path $buildOutput | Out-Null
    Copy-Item -LiteralPath $genuine -Destination (Join-Path $buildOutput 'KingmakerCutsceneSkip.dll')
    $plan = Resolve-NativeProductPlan -ProductDll (Join-Path $buildOutput 'KingmakerCutsceneSkip.dll')
    $product = New-ValidatedNativeProduct $plan $validator
    Copy-Item -LiteralPath $otherVersion -Destination (Join-Path $buildOutput 'KingmakerCutsceneSkip.dll') -Force
    $mods = Join-Path $fixtures 'Mods'; New-Item -ItemType Directory -Path $mods | Out-Null
    $staged = Install-ValidatedNativeProduct $product $mods (Join-Path (Get-RepositoryRoot) 'Info.json')
    $privateDir = $product.PrivateDirectory
    Remove-ValidatedNativeProduct $product
    Assert-Case 'BareDllRouteStagesTheValidatedBytesAfterTheBuildOutputChanged' ($staged -eq (Get-Sha256 $genuine) -and (Get-Sha256 (Join-Path $mods 'KingmakerCutsceneSkip\KingmakerCutsceneSkip.dll')) -eq (Get-Sha256 $genuine) -and -not (Test-Path -LiteralPath $privateDir))
    $badPlan = Resolve-NativeProductPlan -ProductZip (Join-Path $fixtures 'newer-umm.zip')
    $before = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'kmcs-product-*').Count
    $refused = $false; try { New-ValidatedNativeProduct $badPlan $validator | Out-Null } catch { $refused = $_.Exception.Message -match 'failed package validation' }
    $after = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'kmcs-product-*').Count
    Assert-Case 'PreparationFailureRemovesThePrivateCopy' ($refused -and $after -eq $before)
    # A failure after this run took its lock (an evidence path that cannot be created) releases only its own lock.
    $labRoot = Join-Path $fixtures 'lab'; $foreign = Join-Path $fixtures 'other lab\runtime.lock'
    New-Item -ItemType Directory -Path (Split-Path -Parent $foreign) -Force | Out-Null; Set-Content -LiteralPath $foreign -Value 'foreign'
    $fakeLab = [pscustomobject]@{ State = Join-Path $labRoot 'state'; Lock = Join-Path $labRoot 'state\runtime.lock'; Evidence = Join-Path $labRoot 'evidence'; Backups = Join-Path $labRoot 'backups' }
    New-Item -ItemType Directory -Path $labRoot -Force | Out-Null; Set-Content -LiteralPath $fakeLab.Evidence -Value 'a file where the evidence folder belongs'
    $setupFailed = $false; try { Enter-NativeRunDirectories $fakeLab 'fixture-run' | Out-Null } catch { $setupFailed = $true }
    Assert-Case 'PostLockSetupFailureReleasesOwnLockAndKeepsForeignLock' ($setupFailed -and -not (Test-Path -LiteralPath $fakeLab.Lock) -and (Test-Path -LiteralPath $foreign))
}
finally { Remove-Item -LiteralPath $fixtures -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "RESULT provenance total=$($script:total) failed=$($script:failed)"
if ($script:failed -ne 0) { throw "Provenance tests failed: $($script:failed)." }
