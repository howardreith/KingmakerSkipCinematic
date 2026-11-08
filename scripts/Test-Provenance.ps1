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

Write-Host "RESULT provenance total=$($script:total) failed=$($script:failed)"
if ($script:failed -ne 0) { throw "Provenance tests failed: $($script:failed)." }
