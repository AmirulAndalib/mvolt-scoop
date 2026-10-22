<#
.SYNOPSIS
    Writes the three WinGet manifest files for b00nz.mVolt for one release.

.DESCRIPTION
    The manifests are generated from scratch on every run, so nothing depends on
    patching an earlier file with regular expressions. Every value that comes from
    upstream is validated against a strict pattern before it is written, because it
    ends up in YAML that is submitted to microsoft/winget-pkgs.

    Output uses LF line endings and UTF-8 without BOM, which is what winget-pkgs uses.

.PARAMETER Version
    Package version, for example 0.50.6.

.PARAMETER Tag
    Upstream release tag, for example v0.50.6.

.PARAMETER InstallerUrl
    The release asset URL for mVolt+.exe on github.com/b00nz/mVolt.

.PARAMETER Sha256
    SHA256 of the asset, 64 hex characters.

.PARAMETER ReleaseDate
    Upstream publish date, yyyy-MM-dd.

.PARAMETER OutDir
    Folder to write the manifests into. Created if missing. Only the three
    b00nz.mVolt manifest files in it are replaced.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Tag,
    [Parameter(Mandatory)][string]$InstallerUrl,
    [Parameter(Mandatory)][string]$Sha256,
    [Parameter(Mandatory)][string]$ReleaseDate,
    [Parameter(Mandatory)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# PowerShell variables are case-insensitive: never name a local after a parameter (e.g. $version vs $Version).
$Id = 'b00nz.mVolt'
$ManifestVersion = '1.12.0'

# Use \A and \z, not ^ and $: in .NET, $ also matches before a trailing newline.
if ($Version -cnotmatch '\A[0-9]+(\.[0-9]+){1,3}\z') { throw "Unexpected version '$Version'" }
if ($Tag -cne "v$Version") { throw "Tag '$Tag' does not match version '$Version'" }
$urlPattern = '\Ahttps://github\.com/b00nz/mVolt/releases/download/' + [regex]::Escape($Tag) + '/mVolt(\+|%2B)\.exe\z'
if ($InstallerUrl -cnotmatch $urlPattern) { throw "Unexpected installer URL '$InstallerUrl'" }
if ($Sha256 -notmatch '\A[0-9a-fA-F]{64}\z') { throw "Unexpected SHA256 '$Sha256'" }
if ($ReleaseDate -cnotmatch '\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z') { throw "Unexpected release date '$ReleaseDate'" }
$null = [datetime]::ParseExact($ReleaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

$hash = $Sha256.ToUpperInvariant()

$versionYaml = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.$ManifestVersion.schema.json
PackageIdentifier: $Id
PackageVersion: $Version
DefaultLocale: en-US
ManifestType: version
ManifestVersion: $ManifestVersion
"@

$installerYaml = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.$ManifestVersion.schema.json
PackageIdentifier: $Id
PackageVersion: $Version
Platform:
- Windows.Desktop
MinimumOSVersion: 10.0.0.0
InstallerType: portable
Commands:
- mvolt
InstallModes:
- interactive
- silent
- silentWithProgress
ReleaseDate: $ReleaseDate
Installers:
- Architecture: x64
  InstallerUrl: $InstallerUrl
  InstallerSha256: $hash
ManifestType: installer
ManifestVersion: $ManifestVersion
"@

$localeYaml = @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.defaultLocale.$ManifestVersion.schema.json
PackageIdentifier: $Id
PackageVersion: $Version
PackageLocale: en-US
Publisher: b00nz
PublisherUrl: https://github.com/b00nz
PublisherSupportUrl: https://github.com/b00nz/mVolt/issues
Author: b00nz
PackageName: mVolt+
PackageUrl: https://github.com/b00nz/mVolt
License: Freeware
ShortDescription: NVIDIA GPU tuning and monitoring tool with voltage, clock, power and fan control.
Description: |-
  mVolt+ is a Windows tool for tuning and monitoring NVIDIA GPUs. It controls core and fabric voltage limits, clock offsets, power limits, V/F curves and fan curves, shows live telemetry, and saves settings as profiles. RTX 50 series is the primary target; earlier GeForce generations are supported experimentally.
Moniker: mvolt
Tags:
- nvidia
- gpu
- geforce
- overclock
- undervolt
- voltage
- fan-control
- monitoring
ReleaseNotesUrl: https://github.com/b00nz/mVolt/releases/tag/$Tag
Documentations:
- DocumentLabel: User guide
  DocumentUrl: https://github.com/b00nz/mVolt/blob/main/docs/guide.md
InstallationNotes: |-
  Run 'mvolt' from a terminal to start mVolt+. Tuning needs administrator rights; mVolt+ asks for them when it starts.
  WinGet portable packages do not create Start Menu or desktop shortcuts.
  Profiles and settings are stored in %LOCALAPPDATA%\mVolt+ and are kept when you upgrade or uninstall.
  Exit mVolt+ from the tray before upgrading. If you use Start with Windows, open mVolt+ as administrator once after each upgrade so its startup copy in %ProgramFiles%\mVolt+ is refreshed.
  Package maintained by AmirulAndalib (https://github.com/AmirulAndalib/mvolt-scoop).
ManifestType: defaultLocale
ManifestVersion: $ManifestVersion
"@

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
foreach ($pair in @(
        @("$Id.yaml", $versionYaml),
        @("$Id.installer.yaml", $installerYaml),
        @("$Id.locale.en-US.yaml", $localeYaml))) {
    $text = ($pair[1] -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $OutDir $pair[0]), $text, $utf8)
}
Write-Host "Wrote $Id $Version manifests to $OutDir"
