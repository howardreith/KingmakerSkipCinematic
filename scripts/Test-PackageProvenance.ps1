[CmdletBinding()]
param([string] $ReportPath)

# The real build and packaging commands in a temporary checkout of the committed HEAD (GamePath.props and the verified
# reference cache copied from this checkout, so nothing is downloaded): a genuine package without any provenance
# override; a committed build-helper change invalidating the old receipt and a fresh build passing; a
# documentation-only commit reusing the frozen DLL; a corrupt cache entry refused before compilation; and packaging
# refused for a DLL that differs from its receipt; direct MSBuild builds verifying their compiler inputs, refusing a
# substituted cache file, a declared version disagreeing with the pinned bytes and a rewritten resolved reference; a
# committed root or src-level Directory.Build.targets change invalidating the receipt. This checkout's artifacts are not touched.
. (Join-Path $PSScriptRoot 'Common.ps1')
$source = Get-RepositoryRoot
$commit = (& git -C $source rev-parse HEAD).Trim()
$cases = [Collections.Generic.List[object]]::new()
function Add-Case([string] $Name, [bool] $Passed, [string] $Detail) {
    $cases.Add([ordered]@{ name = $Name; passed = $Passed; detail = $Detail })
    Write-Host ("{0} PackageProvenance.{1} :: {2}" -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name, $Detail)
}
function Invoke-Script([string] $Path, [string[]] $Arguments = @()) {
    $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $output = (($null | & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1) | ForEach-Object { "$_" }) -join ' ' }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -replace '\s+', ' ') }
}
function Get-Reason([string] $Text) { $m = [regex]::Match($Text, '(?i)(provenance check failed|does not match|refus|changed since)[^.]{0,200}'); if ($m.Success) { $m.Value } else { $Text.Substring([Math]::Max(0, $Text.Length - 200)) } }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('kmcs-package-provenance-' + [guid]::NewGuid().ToString('N'))
$clone = Join-Path $temp 'checkout with space'
try {
    & git clone -q --no-hardlinks $source $clone
    & git -C $clone checkout -q -B package-provenance $commit
    if ((& git -C $clone rev-parse HEAD).Trim() -cne $commit) { throw 'The temporary checkout did not select the commit under test.' }
    Copy-Item -LiteralPath (Join-Path $source 'GamePath.props') -Destination $clone
    New-Item -ItemType Directory -Path (Join-Path $clone 'artifacts\references') -Force | Out-Null
    Copy-Item -Path (Join-Path $source 'artifacts\references\*.dll') -Destination (Join-Path $clone 'artifacts\references')
    $build = Join-Path $clone 'scripts\Build.ps1'; $package = Join-Path $clone 'scripts\Package.ps1'
    $git = { param([string[]] $a) & git -C $clone -c user.name=package-provenance -c user.email=package-provenance@invalid @a }
    $receiptPath = Join-Path $clone 'artifacts\qualification\build.json'
    $dll = Join-Path $clone 'artifacts\bin\Release\KingmakerCutsceneSkip\KingmakerCutsceneSkip.dll'

    $b = Invoke-Script $build; $p = Invoke-Script $package
    Add-Case 'GenuineBuildAndPackageWithoutOverride' ($b.ExitCode -eq 0 -and $p.ExitCode -eq 0 -and $p.Output -match 'Package validation passed') "build exit $($b.ExitCode); package exit $($p.ExitCode)"
    $frozenDll = Get-Sha256 $dll

    # A committed change to the build helper (same product sources): the old receipt no longer qualifies.
    [IO.File]::AppendAllText($build, "`r`n# package-provenance helper change`r`n")
    & $git @('commit', '-q', '-am', 'test: build helper change') | Out-Null
    $p = Invoke-Script $package
    Add-Case 'BuildHelperChangeInvalidatesThePriorReceipt' ($p.ExitCode -ne 0 -and $p.Output -match 'product inputs changed since build commit .*scripts/Build\.ps1') (Get-Reason $p.Output)
    $b = Invoke-Script $build; $p = Invoke-Script $package
    Add-Case 'FreshBuildAfterHelperChangePasses' ($b.ExitCode -eq 0 -and $p.ExitCode -eq 0) "build exit $($b.ExitCode); package exit $($p.ExitCode); DLL unchanged: $((Get-Sha256 $dll) -eq $frozenDll)"

    # A documentation-only commit: the frozen DLL and receipt are reused.
    [IO.File]::AppendAllText((Join-Path $clone 'README.md'), "`r`n<!-- documentation-only change -->`r`n")
    & $git @('commit', '-q', '-am', 'test: documentation only') | Out-Null
    $p = Invoke-Script $package
    $cloneVersion = [string](Get-Content -LiteralPath (Join-Path $clone 'Info.json') -Raw | ConvertFrom-Json).Version
    $manifest = Get-Content -LiteralPath (Join-Path $clone "artifacts\package\KingmakerCutsceneSkip-$cloneVersion.manifest.json") -Raw | ConvertFrom-Json
    Add-Case 'DocumentationOnlyChangeReusesTheFrozenDll' ($p.ExitCode -eq 0 -and $manifest.dll_sha256 -eq $frozenDll -and $manifest.build_commit -ne $manifest.package_commit) "build $($manifest.build_commit.Substring(0, 7)), package $($manifest.package_commit.Substring(0, 7)), DLL $($manifest.dll_sha256)"

    # A committed material root Directory.Build.targets change: the old DLL is not reused without an override; a fresh
    # build passes; removing the file again is also a product change, followed by a fresh build.
    $dbt = Join-Path $clone 'Directory.Build.targets'
    [IO.File]::WriteAllText($dbt, "<Project><PropertyGroup><DefineConstants>`$(DefineConstants);KMCS_PACKAGE_PROVENANCE_PROBE</DefineConstants></PropertyGroup></Project>`r`n")
    & $git @('add', 'Directory.Build.targets') | Out-Null; & $git @('commit', '-q', '-m', 'test: material Directory.Build.targets') | Out-Null
    $p = Invoke-Script $package
    Add-Case 'DirectoryBuildTargetsChangeInvalidatesThePriorReceipt' ($p.ExitCode -ne 0 -and $p.Output -match 'product inputs changed since build commit .*Directory\.Build\.targets') (Get-Reason $p.Output)
    $b = Invoke-Script $build; $p = Invoke-Script $package
    Add-Case 'FreshBuildAfterDirectoryBuildTargetsChangePasses' ($b.ExitCode -eq 0 -and $p.ExitCode -eq 0) "build exit $($b.ExitCode); package exit $($p.ExitCode)"
    & $git @('rm', '-q', 'Directory.Build.targets') | Out-Null; & $git @('commit', '-q', '-m', 'test: remove Directory.Build.targets') | Out-Null
    $b = Invoke-Script $build
    if ($b.ExitCode -ne 0) { throw 'The rebuild after removing Directory.Build.targets failed.' }

    # The same for a src-level MSBuild input (src/Directory.Build.targets): refused, rebuilt, then a documentation-only
    # commit still reuses the frozen DLL; removing it again is followed by a fresh build.
    $srcDbt = Join-Path $clone 'src\Directory.Build.targets'
    [IO.File]::WriteAllText($srcDbt, "<Project><PropertyGroup><DefineConstants>`$(DefineConstants);KMCS_SRC_PROBE</DefineConstants></PropertyGroup></Project>`r`n")
    & $git @('add', 'src/Directory.Build.targets') | Out-Null; & $git @('commit', '-q', '-m', 'test: material src/Directory.Build.targets') | Out-Null
    $p = Invoke-Script $package
    Add-Case 'SrcDirectoryBuildTargetsChangeInvalidatesThePriorReceipt' ($p.ExitCode -ne 0 -and $p.Output -match 'product inputs changed since build commit .*src/Directory\.Build\.targets') (Get-Reason $p.Output)
    $b = Invoke-Script $build; $p = Invoke-Script $package
    $srcFrozen = Get-Sha256 $dll
    Add-Case 'FreshBuildAfterSrcDirectoryBuildTargetsChangePasses' ($b.ExitCode -eq 0 -and $p.ExitCode -eq 0) "build exit $($b.ExitCode); package exit $($p.ExitCode)"
    [IO.File]::AppendAllText((Join-Path $clone 'README.md'), "`r`n<!-- documentation-only change after the src input change -->`r`n")
    & $git @('commit', '-q', '-am', 'test: documentation only') | Out-Null
    $p = Invoke-Script $package
    $srcManifest = Get-Content -LiteralPath (Join-Path $clone "artifacts\package\KingmakerCutsceneSkip-$cloneVersion.manifest.json") -Raw | ConvertFrom-Json
    Add-Case 'DocumentationOnlyChangeAfterTheSrcInputStillReusesTheFrozenDll' ($p.ExitCode -eq 0 -and $srcManifest.dll_sha256 -eq $srcFrozen -and $srcManifest.build_commit -ne $srcManifest.package_commit) "build $($srcManifest.build_commit.Substring(0, 7)), package $($srcManifest.package_commit.Substring(0, 7))"
    & $git @('rm', '-q', 'src/Directory.Build.targets') | Out-Null; & $git @('commit', '-q', '-m', 'test: remove src/Directory.Build.targets') | Out-Null
    $b = Invoke-Script $build
    if ($b.ExitCode -ne 0) { throw 'The rebuild after removing src/Directory.Build.targets failed.' }

    # A corrupt cache entry is refused before compilation (the DLL is not rebuilt).
    $cached = Join-Path $clone 'artifacts\references\0Harmony12.dll'
    $original = [IO.File]::ReadAllBytes($cached)
    $bytes = [byte[]]$original.Clone(); $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 0xFF
    [IO.File]::WriteAllBytes($cached, $bytes)
    $dllTime = (Get-Item -LiteralPath $dll).LastWriteTimeUtc
    $b = Invoke-Script $build
    Add-Case 'CorruptCacheEntryRefusedBeforeCompilation' ($b.ExitCode -ne 0 -and $b.Output -match 'does not match its pin' -and $b.Output -notmatch 'KingmakerCutsceneSkip -> ' -and (Get-Item -LiteralPath $dll).LastWriteTimeUtc -eq $dllTime) (Get-Reason $b.Output)
    [IO.File]::WriteAllBytes($cached, $original)

    # A DLL that differs from its receipt is refused at packaging.
    $dllBytes = [IO.File]::ReadAllBytes($dll)
    [IO.File]::WriteAllBytes($dll, [byte[]]($dllBytes + [byte[]](0)))
    $p = Invoke-Script $package
    Add-Case 'DllDifferingFromItsReceiptRefusedAtPackaging' ($p.ExitCode -ne 0 -and $p.Output -match 'does not match the build receipt') (Get-Reason $p.Output)
    [IO.File]::WriteAllBytes($dll, $dllBytes)

    # A receipt whose product digest is a boolean or an empty array, otherwise coherent with this commit, beside a
    # different baseline-compatible DLL (a real build of an uncommitted source change, reverted before packaging) is
    # refused without any override; the genuine receipt and DLL then package again.
    $genuineReceiptText = [IO.File]::ReadAllText($receiptPath)
    $genuineDllSha = Get-Sha256 $dll
    $probeSource = Join-Path $clone ((@(& git -C $clone ls-files 'src/KingmakerCutsceneSkip/*.cs')[0]).Replace('/', '\'))
    $probeOriginal = [IO.File]::ReadAllBytes($probeSource)
    [IO.File]::AppendAllText($probeSource, "`r`nnamespace KmcsReceiptProbe { internal static class Marker { internal const int Value = 7; } }`r`n")
    $b = Invoke-Script $build
    [IO.File]::WriteAllBytes($probeSource, $probeOriginal)
    $otherDll = [IO.File]::ReadAllBytes($dll)
    $otherDllSha = Get-Sha256 $dll
    Add-Case 'DifferentBaselineCompatibleDllBuilt' ($b.ExitCode -eq 0 -and $otherDllSha -ne $genuineDllSha -and @(& git -C $clone status --porcelain -- src).Count -eq 0) "build exit $($b.ExitCode); other DLL $otherDllSha"
    foreach ($malformed in @(@('Boolean', $true), @('EmptyArray', @()))) {
        $bad = $genuineReceiptText | ConvertFrom-Json
        $bad.dll_sha256 = $malformed[1]
        [IO.File]::WriteAllText($receiptPath, ($bad | ConvertTo-Json -Depth 8))
        [IO.File]::WriteAllBytes($dll, $otherDll)
        $p = Invoke-Script $package
        Add-Case "Receipt$($malformed[0])DllDigestWithADifferentDllRefused" ($p.ExitCode -ne 0 -and $p.Output -match 'dll_sha256 is not a SHA-256 string') ([regex]::Match($p.Output, 'The build receipt dll_sha256[^.]*').Value)
    }
    [IO.File]::WriteAllText($receiptPath, $genuineReceiptText)
    [IO.File]::WriteAllBytes($dll, $dllBytes)
    $p = Invoke-Script $package
    Add-Case 'GenuineReceiptAndDllPackageAgain' ($p.ExitCode -eq 0 -and $p.Output -match 'Package validation passed') "package exit $($p.ExitCode)"

    # Direct production builds (MSBuild on the project, without Build.ps1) apply the same pins: a genuine rebuild passes
    # and records its compiler inputs; a substituted cache file is refused before compilation; a repository-level hook at
    # the CoreCompile boundary that points a loader reference elsewhere is refused by the final check.
    $project = Join-Path $clone 'src\KingmakerCutsceneSkip\KingmakerCutsceneSkip.csproj'
    $direct = { param([string] $Target) $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $o = ((& dotnet msbuild $project '/nologo' "/t:$Target" '/p:Configuration=Release' '/p:Platform=AnyCPU' 2>&1) | ForEach-Object { "$_" }) } finally { $ErrorActionPreference = $previous }
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($o -join "`n") } }
    $pinsByFile = @{}; foreach ($pin in @(Get-PinnedReferenceDefinitions (Join-Path $clone 'scripts\reference-pins.json'))) { $pinsByFile[[string]$pin.File] = [string]$pin.Sha256 }
    $d = & $direct 'Rebuild'
    $inputs = @([regex]::Matches($d.Output, 'Loader compiler input: (\S.*?\.dll) ([0-9a-f]{64})') | ForEach-Object { [pscustomobject]@{ path = $_.Groups[1].Value; sha256 = $_.Groups[2].Value } })
    $inputsMatch = $inputs.Count -eq 2 -and @($inputs | Where-Object { $pinsByFile[[IO.Path]::GetFileName($_.path)] -ceq $_.sha256 -and $_.path.StartsWith((Join-Path $clone 'artifacts\references'), [StringComparison]::OrdinalIgnoreCase) }).Count -eq 2
    Add-Case 'DirectProductionRebuildVerifiesItsCompilerInputs' ($d.ExitCode -eq 0 -and $d.Output -match 'Pinned reference cache: PASS' -and $inputsMatch) (($inputs | ForEach-Object { $_.path.Substring($clone.Length + 1) + ' ' + $_.sha256 }) -join '; ')
    $umm = Join-Path $clone 'artifacts\references\UnityModManager.dll'; $ummBytes = [IO.File]::ReadAllBytes($umm)
    [IO.File]::Copy((Join-Path $clone 'artifacts\references\0Harmony12.dll'), $umm, $true)
    $d = & $direct 'Rebuild'
    [IO.File]::WriteAllBytes($umm, $ummBytes)
    Add-Case 'DirectRebuildRefusesASubstitutedCacheFile' ($d.ExitCode -ne 0 -and $d.Output -match 'UnityModManager\.dll does not match its pin' -and $d.Output -notmatch 'KingmakerCutsceneSkip -> ') (Get-Reason ($d.Output -replace '\s+', ' '))
    $elsewhere = Join-Path $temp 'elsewhere'; New-Item -ItemType Directory -Path $elsewhere | Out-Null
    $elsewhereUmm = Join-Path $elsewhere 'UnityModManager.dll'; [IO.File]::WriteAllBytes($elsewhereUmm, $ummBytes)
    $hook = Join-Path $clone 'Directory.Build.targets'
    [IO.File]::WriteAllText($hook, "<Project><Target Name=`"KmcsTestRewrite`" BeforeTargets=`"CoreCompile`"><ItemGroup><_KmcsTestUmm Include=`"@(ReferencePathWithRefAssemblies)`" Condition=`"'%(Filename)' == 'UnityModManager'`" /><ReferencePathWithRefAssemblies Remove=`"@(_KmcsTestUmm)`" /><ReferencePathWithRefAssemblies Include=`"$elsewhereUmm`" /></ItemGroup></Target></Project>")
    $d = & $direct 'Build'
    Remove-Item -LiteralPath $hook
    Add-Case 'ResolvedReferenceRewrittenAtTheCoreCompileBoundaryIsRefused' ($d.ExitCode -ne 0 -and $d.Output -match 'Loader compiler references must be the pinned files' -and $d.Output -notmatch 'KingmakerCutsceneSkip -> ') ([regex]::Match($d.Output, 'Loader compiler references must be the pinned files[^\n]*').Value)
    # A pin whose digest still matches but whose declared version disagrees with the authenticated bytes is refused by the
    # production gate before compilation; the coherent pin rebuilds.
    $clonePins = Join-Path $clone 'scripts\reference-pins.json'; $clonePinsText = [IO.File]::ReadAllText($clonePins)
    $disagree = $clonePinsText | ConvertFrom-Json
    @($disagree.references | Where-Object { $_.Name -eq '0Harmony12' })[0].Version = '1.2.0.2'
    [IO.File]::WriteAllText($clonePins, ($disagree | ConvertTo-Json -Depth 5))
    $d = & $direct 'Rebuild'
    [IO.File]::WriteAllText($clonePins, $clonePinsText)
    Add-Case 'DirectRebuildRefusesADeclaredVersionDisagreeingWithThePinnedBytes' ($d.ExitCode -ne 0 -and $d.Output -match 'disagrees with its declared pin 0Harmony12, Version=1\.2\.0\.2' -and $d.Output -notmatch 'KingmakerCutsceneSkip -> ') ([regex]::Match($d.Output, 'is 0Harmony12[^\n]*').Value)
    $d = & $direct 'Rebuild'
    Add-Case 'DirectRebuildPassesAgainAfterRestoringTheCache' ($d.ExitCode -eq 0 -and $d.Output -match 'Loader compiler input: ') "exit $($d.ExitCode)"

    $failedCases = @($cases | Where-Object { -not $_.passed })
    $summary = [ordered]@{ schema = 'ksc.package-provenance-tests.v1'; commit = $commit; frozen_dll_sha256 = $frozenDll; passed = $cases.Count - $failedCases.Count; total = $cases.Count; cases = @($cases) }
    if ($ReportPath) { Write-JsonFile $ReportPath $summary }
    Write-Host "RESULT package-provenance total=$($cases.Count) failed=$($failedCases.Count)"
    if ($failedCases.Count -ne 0) { throw "Package provenance tests failed: $($failedCases.Count)." }
}
finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
