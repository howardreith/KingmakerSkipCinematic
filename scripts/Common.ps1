Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:ProductId = 'KingmakerCutsceneSkip'
# The load target UMM reads from Info.json. Fixed for this product, independently of any Info.json file, so a manifest
# is never its own reference.
$script:ProductLoadIdentity = [ordered]@{ Id = 'KingmakerCutsceneSkip'; AssemblyName = 'KingmakerCutsceneSkip.dll'; EntryMethod = 'KingmakerCutsceneSkip.Main.Load' }
function Get-ProductLoadIdentity { return $script:ProductLoadIdentity }
# Exact ordinal string equality. PowerShell's -ceq/-cne compare with culture rules, under which ignorable characters
# (a soft hyphen, for example) make different strings equal; identities, digests and load targets use this instead.
function Test-OrdinalEqual([string] $A, [string] $B) { return [string]::Equals($A, $B, [StringComparison]::Ordinal) }
# A recorded digest is accepted only as a JSON string of 64 lowercase hexadecimal characters (no boolean, array, number,
# padding or trailing line feed), so a malformed receipt field can never compare as equal.
function Test-Sha256String($Value) { return ($Value -is [string]) -and [regex]::IsMatch($Value, '\A[0-9a-f]{64}\z') }

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

# Loader assemblies the product compiles against: scripts\reference-pins.json, a tracked product input.
$script:ReferencePinsPath = Join-Path $script:RepositoryRoot 'scripts\reference-pins.json'

function Get-PinnedReferenceDefinitions([string] $Path = $script:ReferencePinsPath) {
    Assert-FileExists $Path 'Reference pin manifest'
    $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    return @($document.references)
}

# The CLR identity a pin declares (name, four-part version, neutral culture, no public key token).
function Get-PinnedDeclaredIdentity($Pin) {
    $v = [version][string]$Pin.Version
    return '{0}, Version={1}.{2}.{3}.{4}, Culture=neutral, PublicKeyToken=null' -f $Pin.Name, $v.Major, $v.Minor, [Math]::Max($v.Build, 0), [Math]::Max($v.Revision, 0)
}
# One read of a pinned file: its SHA-256 must be the pin's and the CLR identity in those same bytes must be the declared
# identity. Returns the digest. (Loads the bytes reflection-only into this process.)
function Assert-PinnedReferenceBytes([string] $Path, $Pin) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
    if (-not (Test-OrdinalEqual $hash ([string]$Pin.Sha256))) { throw "The pinned file $Path does not match its pin." }
    $identity = [Reflection.Assembly]::ReflectionOnlyLoad($bytes).GetName().FullName
    $declared = Get-PinnedDeclaredIdentity $Pin
    if (-not (Test-OrdinalEqual $identity $declared)) { throw "The pinned file $($Pin.File) is $identity, which disagrees with its declared pin $declared." }
    return $hash
}

function Get-PinnedReferenceDirectory { return (Join-Path $script:RepositoryRoot 'artifacts\references') }

# Ensures every pinned loader reference is present and byte-exact; a hash mismatch fails the build.
function Initialize-PinnedReferences {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $directory = Get-PinnedReferenceDirectory
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    foreach ($reference in (Get-PinnedReferenceDefinitions)) {
        $target = Join-Path $directory $reference.File
        if (Test-Path -LiteralPath $target) {
            # An existing entry must already be byte-exact: a corrupt or substituted file is refused (remove it explicitly
            # to re-fetch), never silently replaced. Only an absent entry is acquired.
            if ((Get-Sha256 $target) -ne $reference.Sha256) { throw "Cached pinned reference $target does not match its pin; remove it explicitly before retrying." }
            continue
        }
        $download = Join-Path $directory ($reference.Name + '.download')
        Invoke-WebRequest -Uri $reference.Url -OutFile $download -UseBasicParsing
        try {
            if ($reference.ArchiveEntry) {
                if ((Get-Sha256 $download) -ne $reference.ArchiveSha256) { throw "Archive hash mismatch for $($reference.Url)" }
                $archive = [IO.Compression.ZipFile]::OpenRead($download)
                try { [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry($reference.ArchiveEntry), $target, $true) }
                finally { $archive.Dispose() }
            }
            else { Copy-Item -LiteralPath $download -Destination $target -Force }
        }
        finally { Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue }
        if ((Get-Sha256 $target) -ne $reference.Sha256) {
            Remove-Item -LiteralPath $target -Force
            throw "Pinned reference $($reference.File) does not match its expected SHA-256."
        }
    }
    return $directory
}

function Get-AssemblyIdentity([string] $Path, [string] $Role) {
    return [ordered]@{
        role = $Role
        file = [IO.Path]::GetFileName($Path)
        assembly_version = [Reflection.AssemblyName]::GetAssemblyName($Path).Version.ToString()
        sha256 = Get-Sha256 $Path
    }
}

# Identity of every assembly the product compiles against, for the build receipt.
function Get-BuildReferenceIdentities($Game) {
    $identities = @()
    $pinnedDirectory = Get-PinnedReferenceDirectory
    foreach ($reference in (Get-PinnedReferenceDefinitions)) {
        $identity = Get-AssemblyIdentity (Join-Path $pinnedDirectory $reference.File) 'pinned loader reference'
        $identity.source = $reference.Url
        $identities += $identity
    }
    foreach ($name in @('Assembly-CSharp.dll', 'Assembly-CSharp-firstpass.dll', 'UnityEngine.dll', 'UnityEngine.CoreModule.dll', 'UnityEngine.IMGUIModule.dll')) {
        $identities += Get-AssemblyIdentity (Join-Path $Game.ManagedDir $name) 'local game reference'
    }
    return $identities
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

# Repository paths whose content determines the product DLL or the packaged mod identity, including the build and
# reference helpers that select and verify what the compiler receives (scripts/Build.ps1, scripts/Common.ps1). Changes anywhere else
# (documentation, tests, native tooling) do not require rebuilding the validated binary.
$script:ProductInputPaths = @('src', 'Directory.Build.props', 'KingmakerCutsceneSkip.sln', 'Info.json', 'scripts/reference-pins.json', 'scripts/Build.ps1', 'scripts/Common.ps1', 'scripts/Assert-PinnedReferences.ps1', 'LoaderReferences.Final.targets', 'Directory.Build.targets')

function Get-ProductInputPaths { return $script:ProductInputPaths }

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

# Differences between a build receipt's loader references and the configured pins (empty when they agree).
function Get-ReferencePinProblems($Receipt, $Pins, [string] $ManagerVersion) {
    $problems = @()
    $recorded = @()
    if ($Receipt.PSObject.Properties['references']) {
        $recorded = @($Receipt.references | Where-Object { $_.role -eq 'pinned loader reference' })
    }
    foreach ($pin in $Pins) {
        $matches = @($recorded | Where-Object { ($_.file -is [string]) -and (Test-OrdinalEqual $_.file ([string]$pin.File)) })
        if ($matches.Count -ne 1) { $problems += "the build receipt has $($matches.Count) identities for pinned reference $($pin.File)"; continue }
        if (-not (Test-Sha256String $matches[0].sha256)) { $problems += "the build receipt's SHA-256 for $($pin.File) is not a SHA-256 string" }
        elseif (-not (Test-OrdinalEqual $matches[0].sha256 ([string]$pin.Sha256))) { $problems += "$($pin.File) was built with SHA-256 $($matches[0].sha256), but the pin is $($pin.Sha256)" }
        if (-not ($matches[0].source -is [string]) -or -not (Test-OrdinalEqual $matches[0].source ([string]$pin.Url))) { $problems += "$($pin.File) was built from $($matches[0].source), but the pin is $($pin.Url)" }
        # The recorded assembly version must be the declared pin version (normalized to four parts).
        $declaredParts = @(([string]$pin.Version).Split('.')); while ($declaredParts.Count -lt 4) { $declaredParts += '0' }
        $declaredVersion = $declaredParts -join '.'
        if (-not ($matches[0].PSObject.Properties['assembly_version']) -or -not ($matches[0].assembly_version -is [string]) -or -not (Test-OrdinalEqual $matches[0].assembly_version $declaredVersion)) {
            $problems += "$($pin.File) was recorded as assembly version $($matches[0].assembly_version), but the pin declares $declaredVersion"
        }
    }
    foreach ($identity in $recorded) {
        if (@($Pins | Where-Object { ($identity.file -is [string]) -and (Test-OrdinalEqual $identity.file ([string]$_.File)) }).Count -eq 0) { $problems += "the build receipt records an unpinned loader reference: $($identity.file)" }
    }
    $loader = @($Pins | Where-Object { $_.Name -eq 'UnityModManager' })
    if ($loader.Count -ne 1) { $problems += 'the pins do not name exactly one UnityModManager reference' }
    elseif ($loader[0].Version -ne $ManagerVersion) { $problems += "Info.json declares ManagerVersion $ManagerVersion, but the pinned loader is $($loader[0].Version)" }
    return $problems
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
