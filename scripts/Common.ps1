Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:ProductId = 'KingmakerCutsceneSkip'

function Get-RepositoryRoot { return $script:RepositoryRoot }

function Assert-FileExists([string] $Path, [string] $Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label was not found: $Path" }
}

function Get-KingmakerConfiguration([string] $PropsPath = (Join-Path $script:RepositoryRoot 'GamePath.props')) {
    Assert-FileExists $PropsPath 'GamePath.props (copy GamePath.props.example and set KingmakerInstallDir)'
    [xml] $xml = Get-Content -LiteralPath $PropsPath -Raw
    $group = @($xml.Project.PropertyGroup) | Where-Object { $_.KingmakerInstallDir } | Select-Object -First 1
    if (-not $group) { throw 'GamePath.props does not define KingmakerInstallDir.' }
    $install = [Environment]::ExpandEnvironmentVariables([string] $group.KingmakerInstallDir)
    $managed = ([string] $group.KingmakerManagedDir).Replace('$(KingmakerInstallDir)', $install)
    if (-not $managed) { $managed = Join-Path $install 'Kingmaker_Data\Managed' }
    $umm = ([string] $group.UnityModManagerDir).Replace('$(KingmakerManagedDir)', $managed).Replace('$(KingmakerInstallDir)', $install)
    if (-not $umm) { $umm = Join-Path $managed 'UnityModManager' }
    $configuration = [pscustomobject]@{
        InstallDir = [IO.Path]::GetFullPath($install)
        ManagedDir = [IO.Path]::GetFullPath($managed)
        UnityModManagerDir = [IO.Path]::GetFullPath($umm)
        ModsDir = [IO.Path]::GetFullPath((Join-Path $install 'Mods'))
    }
    Assert-FileExists (Join-Path $configuration.ManagedDir 'Assembly-CSharp.dll') 'Kingmaker Assembly-CSharp.dll'
    Assert-FileExists (Join-Path $configuration.UnityModManagerDir 'UnityModManager.dll') 'UnityModManager.dll'
    Assert-FileExists (Join-Path $configuration.UnityModManagerDir '0Harmony12.dll') '0Harmony12.dll'
    return $configuration
}

function Get-Sha256([string] $Path) {
    Assert-FileExists $Path 'Hash input'
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-MSBuildChecked([string] $Project, [string] $Configuration) {
    $arguments = @($Project, '/nologo', '/m', '/t:Rebuild', "/p:Configuration=$Configuration", '/p:Platform=AnyCPU')
    $output = & dotnet msbuild @arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    $warnings = @($output | Where-Object { $_ -match ': warning [A-Z]+\d+:' }).Count
    $errors = @($output | Where-Object { $_ -match ': error [A-Z]+\d+:' }).Count
    if ($exitCode -ne 0 -or $warnings -ne 0 -or $errors -ne 0) {
        throw "Build of $Project failed or emitted diagnostics (exit=$exitCode warnings=$warnings errors=$errors)."
    }
}

function Get-ProductInfo {
    return Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'Info.json') -Raw | ConvertFrom-Json
}

function Get-GitMetadata {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $commit = (& git -C $script:RepositoryRoot rev-parse --verify --quiet HEAD 2>$null)
        $status = (& git -C $script:RepositoryRoot status --porcelain 2>$null) -join "`n"
    }
    finally { $ErrorActionPreference = $previous }
    if (-not $commit) { $commit = 'UNBORN' }
    return [pscustomobject]@{ Commit = ([string] $commit).Trim(); Dirty = [bool] $status }
}

# Repository paths whose content determines the product DLL or the packaged mod identity. Changes anywhere else
# (documentation, tests, native tooling) do not require rebuilding the validated binary.
$script:ProductInputPaths = @('src/KingmakerCutsceneSkip', 'Directory.Build.props', 'KingmakerCutsceneSkip.sln', 'Info.json')

function Invoke-Git([string[]] $Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & git -C $script:RepositoryRoot @Arguments 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($output) }
}

# Uncommitted (staged, unstaged or untracked) changes to product inputs.
function Get-UncommittedProductChanges {
    $status = Invoke-Git (@('status', '--porcelain', '--untracked-files=all', '--') + $script:ProductInputPaths)
    if ($status.ExitCode -ne 0) { throw "git status failed: $($status.Output -join ' ')" }
    return @($status.Output | Where-Object { $_ })
}

# Product inputs that differ between two commits. Throws when either commit is unknown to the repository.
function Get-ProductChangesBetween([string] $FromCommit, [string] $ToCommit) {
    foreach ($commit in @($FromCommit, $ToCommit)) {
        $verify = Invoke-Git @('cat-file', '-e', "$commit^{commit}")
        if ($verify.ExitCode -ne 0) { throw "Commit $commit is not in this repository." }
    }
    $diff = Invoke-Git (@('diff', '--name-only', $FromCommit, $ToCommit, '--') + $script:ProductInputPaths)
    if ($diff.ExitCode -ne 0) { throw "git diff failed: $($diff.Output -join ' ')" }
    return @($diff.Output | Where-Object { $_ })
}

function Write-JsonFile([string] $Path, [object] $Value) {
    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

# Rejects binaries, saves, logs and personal or installed-game absolute paths anywhere in the source tree.
function Assert-RepositoryHygiene {
    $root = $script:RepositoryRoot
    $info = Get-ProductInfo
    if ($info.Id -ne $script:ProductId -or $info.AssemblyName -ne "$($script:ProductId).dll" -or $info.EntryMethod -ne "$($script:ProductId).Main.Load") {
        throw 'Info.json product identity is inconsistent.'
    }
    $files = Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {
        $_.FullName -notmatch '[\\/](\.git|artifacts|bin|obj)[\\/]' -and $_.Name -ne 'GamePath.props'
    }
    foreach ($file in $files) {
        if ($file.Extension -in @('.dll', '.exe', '.zks', '.zip', '.sav', '.save', '.log', '.pdb', '.assets')) {
            throw "Forbidden repository file: $($file.FullName)"
        }
        if ($file.Length -lt 2MB -and $file.Extension -in @('.cs', '.ps1', '.md', '.json', '.props', '.csproj', '.sln', '.txt')) {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            if ($text -match '(?i)C:\\Users\\') { throw "Personal absolute path found in $($file.FullName)" }
            if ($file.Name -ne 'GamePath.props.example' -and $text -match '(?i)steamapps\\common\\Pathfinder Kingmaker') {
                throw "Installed-game absolute path found in $($file.FullName)"
            }
        }
    }
}
