[CmdletBinding()]
param(
    # The pinned reference cache the project compiles against (before reference resolution).
    [string] $ReferenceDirectory,
    # The exact compiler inputs MSBuild resolved (UnityModManager.dll|0Harmony12.dll), checked immediately before CoreCompile.
    [string] $CompilerInputs
)

# Called by the product project in every MSBuild compile (Build.ps1 and direct builds alike). Hashes come from the parsed
# pin definition (scripts\reference-pins.json), and the CLR identity in the same bytes must be the declared one; a cache
# file or compiler input that differs is refused before compilation. Nothing is downloaded here.
. (Join-Path $PSScriptRoot 'Common.ps1')
try {
    $pins = @(Get-PinnedReferenceDefinitions)
    if ($ReferenceDirectory) {
        foreach ($pin in $pins) {
            $path = Join-Path $ReferenceDirectory $pin.File
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Pinned reference $path is missing; build with scripts\Build.ps1." }
            try { [void](Assert-PinnedReferenceBytes $path $pin) } catch { throw "Cached pinned reference: $($_.Exception.Message)" }
        }
        Write-Host 'Pinned reference cache: PASS'
    }
    if ($CompilerInputs) {
        $inputs = @($CompilerInputs.Split('|') | Where-Object { $_ })
        if ($inputs.Count -ne $pins.Count) { throw "Expected exactly $($pins.Count) loader compiler inputs; got: $($inputs -join ', ')" }
        foreach ($pin in $pins) {
            $match = @($inputs | Where-Object { Test-OrdinalEqual ([IO.Path]::GetFileName($_)) ([string]$pin.File) })
            if ($match.Count -ne 1) { throw "The compiler input for $($pin.File) is missing or duplicated." }
            try { $hash = Assert-PinnedReferenceBytes $match[0] $pin } catch { throw "The compiler input $($match[0]) differs from its pin: $($_.Exception.Message)" }
            Write-Host "Loader compiler input: $($match[0]) $hash"
        }
    }
}
catch {
    [Console]::Error.WriteLine('error KMCSPIN: ' + $_.Exception.Message)
    exit 1
}
