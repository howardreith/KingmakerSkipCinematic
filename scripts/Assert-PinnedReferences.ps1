[CmdletBinding()]
param(
    # The pinned reference cache the project compiles against (before reference resolution).
    [string] $ReferenceDirectory,
    # The exact compiler inputs MSBuild resolved (UnityModManager.dll|0Harmony12.dll), checked immediately before CoreCompile.
    [string] $CompilerInputs
)

# Called by the product project in every MSBuild compile (Build.ps1 and direct builds alike). Hashes come from the parsed
# pin definition (scripts\reference-pins.json); a cache file or compiler input that differs is refused before
# compilation. Nothing is downloaded here.
. (Join-Path $PSScriptRoot 'Common.ps1')
try {
    $pins = @(Get-PinnedReferenceDefinitions)
    if ($ReferenceDirectory) {
        foreach ($pin in $pins) {
            $path = Join-Path $ReferenceDirectory $pin.File
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Pinned reference $path is missing; build with scripts\Build.ps1." }
            if ((Get-Sha256 $path) -cne [string]$pin.Sha256) { throw "Cached pinned reference $path does not match its pin." }
        }
        Write-Host 'Pinned reference cache: PASS'
    }
    if ($CompilerInputs) {
        $inputs = @($CompilerInputs.Split('|') | Where-Object { $_ })
        if ($inputs.Count -ne $pins.Count) { throw "Expected exactly $($pins.Count) loader compiler inputs; got: $($inputs -join ', ')" }
        foreach ($pin in $pins) {
            $match = @($inputs | Where-Object { [IO.Path]::GetFileName($_) -ceq $pin.File })
            if ($match.Count -ne 1) { throw "The compiler input for $($pin.File) is missing or duplicated." }
            $hash = Get-Sha256 $match[0]
            if ($hash -cne [string]$pin.Sha256) { throw "The compiler input $($match[0]) differs from its pin." }
            Write-Host "Loader compiler input: $($match[0]) $hash"
        }
    }
}
catch {
    [Console]::Error.WriteLine('error KMCSPIN: ' + $_.Exception.Message)
    exit 1
}
