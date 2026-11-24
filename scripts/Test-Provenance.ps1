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

# The standalone package validator against fixture packages (stub assemblies compiled with the .NET Framework compiler
# against the pinned loader files and, for the refusals, the installed loader). Each validation runs in its own process.
$validator = Join-Path $PSScriptRoot 'Validate-Package.ps1'
$pinnedDir = Initialize-PinnedReferences
$installed = (Get-KingmakerConfiguration).UnityModManagerDir
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$fixtures = Join-Path ([IO.Path]::GetTempPath()) ('kmcs-package-' + [guid]::NewGuid().ToString('N'))
function Invoke-Validator([string[]] $Arguments) {
    $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $output = (($null | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $validator @Arguments 2>&1) | ForEach-Object { "$_" }) -join ' ' }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -replace '\s+', ' ') }
}
function New-Stub([string] $Name, [string] $AssemblyName, [string[]] $References, [string] $Types) {
    $dir = Join-Path $fixtures $Name; New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $source = Join-Path $dir 'Probe.cs'
    [IO.File]::WriteAllText($source, "public static class Probe { public static System.Type[] Types = { $Types }; }")
    $out = Join-Path $dir "$AssemblyName.dll"
    $o = & $csc /nologo /target:library "/out:$out" @($References | ForEach-Object { "/reference:$_" }) $source 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Stub compile failed: $($o -join ' ')" }
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
        foreach ($extra in @($Extra | Where-Object { $_ })) { $entries["KingmakerCutsceneSkip/$([IO.Path]::GetFileName($extra))"] = $extra }
        foreach ($e in $entries.GetEnumerator()) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $e.Value, $e.Key) }
    }
    finally { $archive.Dispose() }
    return $zip
}
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
try {
    New-Item -ItemType Directory -Path $fixtures | Out-Null
    $loaderTypes = 'typeof(UnityModManagerNet.UnityModManager), typeof(Harmony12.HarmonyInstance)'
    $pinnedRefs = @((Join-Path $pinnedDir 'UnityModManager.dll'), (Join-Path $pinnedDir '0Harmony12.dll'))
    $genuine = New-Stub 'genuine' 'KingmakerCutsceneSkip' $pinnedRefs $loaderTypes
    $installedUmm = New-Stub 'installed-umm' 'KingmakerCutsceneSkip' @((Join-Path $installed 'UnityModManager.dll'), (Join-Path $pinnedDir '0Harmony12.dll')) $loaderTypes
    $withHarmony2 = New-Stub 'harmony2' 'KingmakerCutsceneSkip' ($pinnedRefs + @(Join-Path $installed '0Harmony.dll')) ($loaderTypes + ', typeof(HarmonyLib.Harmony)')
    $otherName = New-Stub 'other-name' 'NotCutsceneSkip' $pinnedRefs $loaderTypes
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'genuine' $genuine $null $null))
    Assert-Case 'PackageWithPinnedReferencesIsAccepted' ($r.ExitCode -eq 0 -and $r.Output -match 'loader references: 0Harmony12 1\.2\.0\.1, UnityModManager 0\.31\.1\.0')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'installed-umm' $installedUmm $null $null))
    Assert-Case 'PackagedDllCompiledAgainstInstalledLoaderIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'references UnityModManager \d+\.\d+\.\d+\.\d+, not the pinned 0\.31\.1\.0')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'harmony2' $withHarmony2 $null $null))
    Assert-Case 'PackagedDllWithHarmony2ReferenceIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'unpinned loader or Harmony assembly: 0Harmony ')
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'other-name' $otherName $null $null))
    Assert-Case 'PackagedDllWithAnotherAssemblyNameIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match "defines assembly 'NotCutsceneSkip'")
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'extra-loader' $genuine $null @(Join-Path $pinnedDir '0Harmony12.dll')))
    Assert-Case 'PackageCarryingALoaderAssemblyIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match "entries outside the mod's four files: KingmakerCutsceneSkip/0Harmony12\.dll")
    $r = Invoke-Validator @('-PackagePath', (New-FixtureZip 'raised-manager' $genuine { param($i) $i.ManagerVersion = '0.33.0' } $null))
    Assert-Case 'PackagedManagerVersionAbovePinIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'ManagerVersion 0\.33\.0 must equal the pinned loader floor 0\.31\.1')
    $r = Invoke-Validator @('-DllPath', $genuine)
    Assert-Case 'BuiltDllWithPinnedReferencesIsAccepted' ($r.ExitCode -eq 0)
    $r = Invoke-Validator @('-DllPath', $installedUmm)
    Assert-Case 'BuiltDllCompiledAgainstInstalledLoaderIsRejected' ($r.ExitCode -ne 0 -and $r.Output -match 'not the pinned 0\.31\.1\.0')
    $genuineZip = Join-Path $fixtures 'genuine.zip'
    $before = Get-Sha256 $genuineZip
    $r = Invoke-Validator @('-PackagePath', $genuineZip, '-ReportPath', $genuineZip)
    Assert-Case 'ReportPathEqualToPackageIsRejected' ($r.ExitCode -ne 0 -and (Get-Sha256 $genuineZip) -eq $before)
    $runner = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime\Invoke-NativeRun.ps1') -Raw
    Assert-Case 'NativeRunnerValidatesBeforeLockingAndInstallsTheValidatedCopy' ($runner.IndexOf("'Validate-Package.ps1'") -gt 0 -and $runner.IndexOf("'Validate-Package.ps1'") -lt $runner.IndexOf('Enter-RuntimeLock $lab $runId') -and
        $runner -match 'Expand-Archive -LiteralPath \$privateZip' -and $runner -notmatch 'Expand-Archive -LiteralPath \$ProductZip')
}
finally { Remove-Item -LiteralPath $fixtures -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "RESULT provenance total=$($script:total) failed=$($script:failed)"
if ($script:failed -ne 0) { throw "Provenance tests failed: $($script:failed)." }
