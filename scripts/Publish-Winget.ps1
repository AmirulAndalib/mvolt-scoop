<#
.SYNOPSIS
    Submits one mVolt+ version to microsoft/winget-pkgs, with the guards learned in nvpi-r-auto.

.DESCRIPTION
    Guards, in order:
      1. The version folder is already merged in winget-pkgs: nothing to do (reports "merged").
      2. An open PR for this version by the token owner exists: nothing to do, unless -Force,
         which closes it and submits fresh. PRs by anyone else never block a submission.
    Then: winget validate (success is read from the text, because warnings return a nonzero
    code), then wingetcreate submit, whose exit code is checked.

    Writes "result=merged|open|submitted" to $env:GITHUB_OUTPUT when set. The caller only
    records a version as shipped on merged or submitted.

.PARAMETER Version
    Package version.

.PARAMETER ManifestDir
    Folder holding the three b00nz.mVolt manifests for that version.

.PARAMETER Token
    GitHub token with public_repo scope. Defaults to $env:WINGET_TOKEN.

.PARAMETER Force
    Close our own open PR for this version and resubmit.

.PARAMETER DryRun
    Run every check but do not close, submit or write output.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$ManifestDir,
    [string]$Token = $env:WINGET_TOKEN,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Id = 'b00nz.mVolt'
$PkgPath = 'b/b00nz/mVolt'

if ($Version -cnotmatch '\A[0-9]+(\.[0-9]+){1,3}\z') { throw "Unexpected version '$Version'" }
if (-not $Token) { throw 'No token. Set the WINGET_TOKEN repository secret.' }
foreach ($f in "$Id.yaml", "$Id.installer.yaml", "$Id.locale.en-US.yaml") {
    if (-not (Test-Path -LiteralPath (Join-Path $ManifestDir $f))) { throw "Missing $f in $ManifestDir" }
}

function Set-Result([string]$Value) {
    Write-Host "result=$Value"
    if ($env:GITHUB_OUTPUT -and -not $DryRun) { Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "result=$Value" }
}

$headers = @{
    Authorization          = "Bearer $Token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent'           = 'mvolt-scoop-workflow'
}

# The account that owns the token. wingetcreate opens PRs as this user, so it is the only
# author whose open PR may suppress a submission.
$me = (Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -MaximumRetryCount 2 -RetryIntervalSec 5).login
Write-Host "Token owner: $me"

# Guard 1: already merged.
try {
    $null = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$PkgPath/$Version" `
        -Headers $headers -MaximumRetryCount 2 -RetryIntervalSec 5
    Write-Host "$Id $Version is already merged in microsoft/winget-pkgs."
    Set-Result 'merged'
    return
} catch {
    $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { -1 }
    if ($code -ne 404) { throw "winget-pkgs contents check returned HTTP $code; not submitting blind." }
}

# Guard 2: our own open PR for this version. Match on the exact title wingetcreate uses.
$q = [Uri]::EscapeDataString("repo:microsoft/winget-pkgs is:pr is:open author:$me $Id $Version in:title")
$search = Invoke-RestMethod -Uri "https://api.github.com/search/issues?q=$q" -Headers $headers -MaximumRetryCount 2 -RetryIntervalSec 5
$ours = @($search.items | Where-Object { $_.user.login -eq $me -and $_.title -match "(^|\s)$([regex]::Escape($Id))\s+(version\s+)?$([regex]::Escape($Version))(\s|$)" })
if ($ours.Count -gt 0) {
    $pr = $ours[0].number
    if (-not $Force) {
        Write-Host "$Id $Version already has our open PR #$pr. Leaving it alone."
        Set-Result 'open'
        return
    }
    Write-Host "Force: closing our PR #$pr to resubmit."
    if (-not $DryRun) {
        Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr" -Method PATCH `
            -Body '{"state":"closed"}' -ContentType 'application/json' -Headers $headers | Out-Null
    }
}

# Validate. winget returns a nonzero code when validation passes with warnings.
$validate = (& winget validate --manifest $ManifestDir 2>&1 | Out-String)
Write-Host $validate.Trim()
if ($validate -notmatch 'Manifest validation succeeded') { throw 'winget validate failed' }

if ($DryRun) {
    Write-Host "[dry run] would submit $Id $Version from $ManifestDir as $me"
    return
}

$wingetcreate = Join-Path ([IO.Path]::GetTempPath()) 'wingetcreate.exe'
if (-not (Test-Path -LiteralPath $wingetcreate)) {
    Invoke-WebRequest -Uri 'https://aka.ms/wingetcreate/latest' -OutFile $wingetcreate -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 5
}
# Pass the token through the environment, not --token, so it never appears in a command line.
$env:WINGET_CREATE_GITHUB_TOKEN = $Token
try { & $wingetcreate submit $ManifestDir } finally { Remove-Item Env:WINGET_CREATE_GITHUB_TOKEN -ErrorAction SilentlyContinue }
if ($LASTEXITCODE -ne 0) { throw "wingetcreate submit failed (exit $LASTEXITCODE)" }
Write-Host "$Id $Version submitted to microsoft/winget-pkgs."
Set-Result 'submitted'
