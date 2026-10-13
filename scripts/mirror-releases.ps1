<#
.SYNOPSIS
    Mirrors every mVolt+ release from b00nz/mVolt into this repository's GitHub Releases.

.DESCRIPTION
    Backup copy in case upstream releases disappear. The 'mvolt' Scoop app installs from the
    official upstream URL; the 'mvolt-mirror' app installs from these mirrored releases.

    Every published upstream release is mirrored, prereleases included (they stay marked as
    prereleases here). Drafts are never visible through the API and are never mirrored.

    For each release the script makes sure the mirror has:
      - mVolt+.exe, byte for byte, verified against GitHub's SHA256 digest for the upstream
        asset and checked to be an x64 PE executable, and verified again after upload;
      - mVolt-<tag>-source.zip, GitHub's archive of the upstream repository at that tag
        (README, user guide and screenshots for that version);
      - the upstream release notes, with the SHA256 of both files.

    The run is idempotent: existing mirrors are left alone, missing assets are added.
    Needs the GitHub CLI (gh) and a token with contents:write on the target repository.

.PARAMETER Repository
    Target repository in owner/name form. Defaults to $env:GITHUB_REPOSITORY.

.PARAMETER DryRun
    Download and verify, but do not create or change any release.
#>
[CmdletBinding()]
param(
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Upstream = 'b00nz/mVolt'
$AssetName = 'mVolt+.exe'

if ($Repository -cnotmatch '\A[A-Za-z0-9-]+/[A-Za-z0-9._-]+\z') {
    throw "Invalid target repository '$Repository'"
}

function Invoke-GhJson {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $out = & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw "gh $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
    return ($out -join "`n") | ConvertFrom-Json -NoEnumerate
}

function Get-ReleaseList([string]$Repo) {
    # --slurp wraps each page (an array) in an outer array; flatten both levels.
    $pages = Invoke-GhJson @('api', '--paginate', '--slurp', "repos/$Repo/releases?per_page=100")
    return @($pages | ForEach-Object { $_ } | ForEach-Object { $_ })
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Prop($Object, [string]$Name) {
    if ($Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $null
}

$upstreamReleases = @(Get-ReleaseList $Upstream | Where-Object { -not $_.draft } |
        Sort-Object { [datetime]$_.published_at })
if ($upstreamReleases.Count -eq 0) { throw "No releases found in $Upstream" }

# /releases/latest only ever returns a published, non-prerelease release.
$latestTag = (Invoke-GhJson @('api', "repos/$Upstream/releases/latest")).tag_name

$ours = @{}
foreach ($r in Get-ReleaseList $Repository) { $ours[$r.tag_name] = $r }

$work = Join-Path ([IO.Path]::GetTempPath()) "mvolt-mirror-$PID"
New-Item -ItemType Directory -Force -Path $work | Out-Null

$changed = 0
try {
    foreach ($rel in $upstreamReleases) {
        $tag = [string]$rel.tag_name
        # The tag ends up in file names, command arguments and titles, so only allow a strict format.
        if ($tag -cnotmatch '\Av[0-9]+(\.[0-9]+){1,3}\z') {
            Write-Warning "Skipping upstream release with unexpected tag format: '$tag'"
            continue
        }
        $sourceName = "mVolt-$tag-source.zip"
        $existing = if ($ours.ContainsKey($tag)) { $ours[$tag] } else { $null }
        $existingNames = if ($existing) { @($existing.assets | ForEach-Object { $_.name }) } else { @() }
        $hasExe = $existingNames -ccontains $AssetName
        $hasSource = $existingNames -ccontains $sourceName

        $asset = @($rel.assets | Where-Object { $_.name -ceq $AssetName })
        if ($asset.Count -ne 1) {
            Write-Warning "$tag has no single '$AssetName' asset upstream, skipping"
            continue
        }
        $asset = $asset[0]
        $digest = [string](Get-Prop $asset 'digest')

        if ($hasExe -and $hasSource) {
            # Already complete. Warn if upstream has since swapped the file under the same tag.
            $mine = @($existing.assets | Where-Object { $_.name -ceq $AssetName })[0]
            $myDigest = [string](Get-Prop $mine 'digest')
            if ($digest -and $myDigest -and $digest -cne $myDigest) {
                Write-Warning "$tag upstream asset changed since it was mirrored: upstream $digest, mirror $myDigest. The mirror keeps the original."
            } else {
                Write-Host "$tag already mirrored"
            }
            continue
        }

        $dir = Join-Path $work $tag
        New-Item -ItemType Directory -Force -Path $dir | Out-Null

        # The exe: download from upstream and verify before anything is published.
        $exe = Join-Path $dir $AssetName
        Invoke-WebRequest -Uri "https://github.com/$Upstream/releases/download/$tag/$AssetName" `
            -OutFile $exe -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 5
        $exeHash = Get-Sha256 $exe
        if (-not $digest) { throw "$tag has no upstream SHA256 digest, refusing to mirror an unverified file" }
        if ($digest -cne "sha256:$exeHash") { throw "$tag hash mismatch: upstream $digest, download sha256:$exeHash" }
        if ((Get-Item -LiteralPath $exe).Length -ne $asset.size) { throw "$tag size mismatch" }
        $bytes = [IO.File]::ReadAllBytes($exe)
        $pe = [BitConverter]::ToInt32($bytes, 0x3c)
        if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A -or [BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) {
            throw "$tag is not an x64 PE executable"
        }

        # The source archive for this tag.
        $src = Join-Path $dir $sourceName
        Invoke-WebRequest -Uri "https://github.com/$Upstream/archive/refs/tags/$tag.zip" `
            -OutFile $src -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 5
        $srcHash = Get-Sha256 $src
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($src)
        try { if ($zip.Entries.Count -eq 0) { throw "$tag source archive is empty" } } finally { $zip.Dispose() }

        $published = ([datetime]$rel.published_at).ToUniversalTime().ToString('yyyy-MM-dd')
        $kind = if ($rel.prerelease) { 'prerelease' } else { 'release' }
        $upstreamNotes = if ($rel.body) { [string]$rel.body } else { '_No release notes upstream._' }
        $notes = @(
            "Unmodified mirror of the mVolt+ $tag $kind ([upstream]($($rel.html_url))) by [b00nz](https://github.com/b00nz), published upstream on $published.",
            '',
            'This copy is a backup in case the upstream release disappears. `scoop install mvolt` downloads from upstream; `scoop install mvolt-mirror` downloads from here.',
            '',
            '| File | SHA256 |',
            '| --- | --- |',
            "| ``$AssetName`` | ``$exeHash`` |",
            "| ``$sourceName`` (upstream repository at $tag) | ``$srcHash`` |",
            '',
            '## Upstream release notes',
            '',
            $upstreamNotes
        ) -join "`n"
        $notesFile = Join-Path $dir 'notes.md'
        Set-Content -LiteralPath $notesFile -Value $notes -Encoding utf8NoBOM

        $isLatest = if ($tag -ceq $latestTag) { 'true' } else { 'false' }
        if ($DryRun) {
            Write-Host "[dry run] $tag ($kind): exe $exeHash, source $srcHash, latest=$isLatest, exists=$([bool]$existing)"
            continue
        }

        if (-not $existing) {
            $ghArgs = @('release', 'create', $tag, $exe, $src, '--repo', $Repository,
                '--title', "mVolt+ $tag (mirror)", '--notes-file', $notesFile, "--latest=$isLatest")
            if ($rel.prerelease) { $ghArgs += '--prerelease' }
            & gh @ghArgs
            if ($LASTEXITCODE -ne 0) { throw "gh release create $tag failed with exit code $LASTEXITCODE" }
        } else {
            $upload = @()
            if (-not $hasExe) { $upload += $exe }
            if (-not $hasSource) { $upload += $src }
            & gh release upload $tag @upload --repo $Repository
            if ($LASTEXITCODE -ne 0) { throw "gh release upload $tag failed with exit code $LASTEXITCODE" }
            & gh release edit $tag --repo $Repository --notes-file $notesFile
            if ($LASTEXITCODE -ne 0) { throw "gh release edit $tag failed with exit code $LASTEXITCODE" }
        }

        # Read the release back and check GitHub stored the exact bytes.
        $check = Invoke-GhJson @('api', "repos/$Repository/releases/tags/$tag")
        foreach ($pair in @(@($AssetName, $exeHash), @($sourceName, $srcHash))) {
            $a = @($check.assets | Where-Object { $_.name -ceq $pair[0] })
            if ($a.Count -ne 1) { throw "$tag mirror is missing '$($pair[0])' after upload" }
            $d = [string](Get-Prop $a[0] 'digest')
            if ($d -and $d -cne "sha256:$($pair[1])") { throw "$tag mirror '$($pair[0])' digest $d does not match sha256:$($pair[1])" }
        }
        Write-Host "Mirrored $tag ($kind) exe $exeHash"
        $changed++
    }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Done. Releases created or completed: $changed"
