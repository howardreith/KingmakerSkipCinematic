[CmdletBinding()]
param([string] $ReportPath)

# The real build and packaging commands in a temporary checkout of the committed HEAD (GamePath.props and the verified
# reference cache copied from this checkout, so nothing is downloaded): a genuine package without any provenance
# override; a committed build-helper change invalidating the old receipt and a fresh build passing; a
# documentation-only commit reusing the frozen DLL; a corrupt cache entry refused before compilation; and packaging
# refused for a DLL that differs from its receipt. This checkout's artifacts are not touched.
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
    $manifest = Get-Content -LiteralPath (Join-Path $clone 'artifacts\package\KingmakerCutsceneSkip-0.1.2.manifest.json') -Raw | ConvertFrom-Json
    Add-Case 'DocumentationOnlyChangeReusesTheFrozenDll' ($p.ExitCode -eq 0 -and $manifest.dll_sha256 -eq $frozenDll -and $manifest.build_commit -ne $manifest.package_commit) "build $($manifest.build_commit.Substring(0, 7)), package $($manifest.package_commit.Substring(0, 7)), DLL $($manifest.dll_sha256)"

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

    $failedCases = @($cases | Where-Object { -not $_.passed })
    $summary = [ordered]@{ schema = 'ksc.package-provenance-tests.v1'; commit = $commit; frozen_dll_sha256 = $frozenDll; passed = $cases.Count - $failedCases.Count; total = $cases.Count; cases = @($cases) }
    if ($ReportPath) { Write-JsonFile $ReportPath $summary }
    Write-Host "RESULT package-provenance total=$($cases.Count) failed=$($failedCases.Count)"
    if ($failedCases.Count -ne 0) { throw "Package provenance tests failed: $($failedCases.Count)." }
}
finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
