<#
.SYNOPSIS
    Rebuilds bucket/mvolt.json and bucket/mvolt-mirror.json from one definition.

.DESCRIPTION
    Both manifests share the same hook scripts, so edit them here, not in the JSON.
    The version, URL and hash are read from the current manifests (Excavator updates
    those), and refresh-helper.ps1 is embedded into post_install. Output is formatted
    with Scoop's formatjson.ps1. CI fails if the committed manifests differ from the
    output of this script.
#>
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
if (!$env:SCOOP_HOME) { $env:SCOOP_HOME = Convert-Path (scoop prefix scoop) }

# Shared by post_install of both apps. Runs with Scoop's $dir and $version in scope.
# mVolt+'s "Start with Windows" keeps its own copy of the exe in
# %ProgramFiles%\mVolt+\<user SID>\<adapter id>\mVolt+.exe and a logon task that runs it.
# Opening mVolt+ as administrator refreshes that copy, and testing showed the refresh is a
# plain file copy (the task is unchanged). When the copy is older than this version, run
# refresh-helper.ps1 elevated (directly if Scoop is elevated, otherwise behind one UAC
# prompt): it stops an instance running from the copy, overwrites it, verifies the hash and
# restarts the instance through its own logon task. A declined or unanswered prompt
# (3 minute timeout) changes nothing and prints a warning.
$helperLines = @(Get-Content (Join-Path $PSScriptRoot 'refresh-helper.ps1'))
$postInstall = @(
    '$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value',
    '$root = Join-Path (Join-Path $env:ProgramFiles ''mVolt+'') $sid',
    '$new = Join-Path $dir ''mVolt+.exe''',
    '$copies = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName ''mVolt+.exe'' } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })',
    '$stale = @($copies | Where-Object { try { [version](Get-Item -LiteralPath $_).VersionInfo.FileVersion -lt [version]$version } catch { $false } })',
    'if ($stale.Count -gt 0) {',
    '$helper = @''') + $helperLines + @(
    '''@',
    '    $work = Join-Path ([IO.Path]::GetTempPath()) ("mvolt-refresh-" + [guid]::NewGuid().ToString(''N''))',
    '    New-Item -ItemType Directory -Force -Path $work | Out-Null',
    '    $log = Join-Path $work ''result.log''',
    '    $expected = $null',
    '    try { $expected = [string]$manifest.architecture.''64bit''.hash } catch { }',
    '    if ($expected -notmatch ''^[0-9a-fA-F]{64}$'') { $expected = (Get-FileHash -LiteralPath $new -Algorithm SHA256).Hash }',
    '    $hostExe = (Get-Process -Id $PID).Path',
    '    $quote = { param($s) "''" + ($s -replace "''", "''''") + "''" }',
    '    $command = "& {`n$helper`n} -Source $(& $quote $new) -Hash $(& $quote $expected) -Root $(& $quote $root) -Version $(& $quote $version) -Log $(& $quote $log)"',
    '    $helperArgs = ''-NoProfile -ExecutionPolicy Bypass -EncodedCommand '' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))',
    '    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
    '    if ($isAdmin) {',
    '        Start-Process -FilePath $hostExe -ArgumentList $helperArgs -WindowStyle Hidden -Wait',
    '    } elseif (-not [Environment]::UserInteractive) {',
    '        warn "Your Start with Windows copy of mVolt+ is out of date. Open mVolt+ as administrator once to update it to $version."',
    '    } else {',
    '        Write-Host ''Your Start with Windows copy of mVolt+ is out of date. Approve the administrator prompt to update it.''',
    '        $job = Start-Job -ScriptBlock { param($exe, $a) try { $p = Start-Process -FilePath $exe -ArgumentList $a -Verb RunAs -WindowStyle Hidden -PassThru -ErrorAction Stop; $p.WaitForExit(); ''ran'' } catch { ''declined'' } } -ArgumentList $hostExe, $helperArgs',
    '        $finished = Wait-Job -Job $job -Timeout 180',
    '        $state = if ($finished) { Receive-Job -Job $job } else { ''timeout'' }',
    '        Remove-Job -Job $job -Force',
    '        if ($state -ne ''ran'') { warn "The administrator prompt was not approved ($state). Your Start with Windows copy of mVolt+ was left as it is. Open mVolt+ as administrator once to update it to $version." }',
    '    }',
    '    if (Test-Path -LiteralPath $log) {',
    '        foreach ($line in Get-Content -LiteralPath $log) {',
    '            $kind, $text = $line -split ''\|'', 2',
    '            if ($kind -eq ''OK'') { Write-Host $text } else { warn $text }',
    '        }',
    '    }',
    '    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue',
    '}'
)

# The startup copy is a separate file, so it keeps working after Scoop removes its own copy.
# Scoop cannot see an mVolt+ that runs elevated (its process path is hidden from a normal
# shell), so it would start removing files and leave a half-removed install. A running exe
# cannot be opened for writing, which works regardless of elevation. Stop before anything
# is removed. Only a sharing violation counts, so a permission problem never blocks.
$preUninstall = @(
    '$exe = Join-Path $dir ''mVolt+.exe''',
    '$busy = $false',
    'if (Test-Path -LiteralPath $exe -PathType Leaf) {',
    '    foreach ($attempt in 1..3) {',
    '        try { $stream = [IO.File]::Open($exe, ''Open'', ''ReadWrite'', ''None''); $stream.Dispose(); $busy = $false; break }',
    '        catch { $hr = if ($_.Exception.InnerException) { $_.Exception.InnerException.HResult } else { $_.Exception.HResult }; $busy = $hr -in @(-2147024864, -2147024863); if (-not $busy) { break }; Start-Sleep -Milliseconds 700 }',
    '    }',
    '}',
    'if ($busy) { throw ''mVolt+ is still running from this Scoop install. It may be running as administrator, which Scoop cannot detect. Exit it from the tray icon, then run the command again.'' }',
    '$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value',
    'if (Test-Path -LiteralPath (Join-Path (Join-Path $env:ProgramFiles ''mVolt+'') $sid)) {',
    '    warn ''mVolt+ Start with Windows is set up for this user. It runs its own copy from %ProgramFiles%\mVolt+ and keeps starting at logon after this uninstall. Turn Start with Windows off in mVolt+ if you no longer want it.''',
    '}'
)

$commonNotes = @(
    'Tuning needs administrator rights. Profiles and settings live in %LOCALAPPDATA%\mVolt+ and are kept on update and uninstall.',
    'If you opened mVolt+ from its Scoop shortcut, exit it from the tray before updating. A copy started by Start with Windows is updated for you after one administrator prompt.'
)

function New-Manifest($owner, $repo, $description, $extraNotes) {
    $current = Get-Content "bucket/$(if ($owner -eq 'b00nz') { 'mvolt' } else { 'mvolt-mirror' }).json" -Raw | ConvertFrom-Json
    $base = "https://github.com/$owner/$repo/releases/download"
    [ordered]@{
        version        = $current.version
        description    = $description
        homepage       = 'https://github.com/b00nz/mVolt'
        license        = 'Freeware'
        notes          = @($extraNotes) + $commonNotes
        architecture   = [ordered]@{ '64bit' = [ordered]@{ url = $current.architecture.'64bit'.url; hash = $current.architecture.'64bit'.hash } }
        bin            = @(, @('mVolt+.exe', 'mvolt'))
        shortcuts      = @(, @('mVolt+.exe', 'mVolt+'))
        post_install   = $postInstall
        pre_uninstall  = $preUninstall
        checkver       = [ordered]@{ github = "https://github.com/$owner/$repo" }
        autoupdate     = [ordered]@{
            architecture = [ordered]@{ '64bit' = [ordered]@{ url = "$base/v`$version/mVolt+.exe" } }
            hash         = [ordered]@{
                url      = "https://api.github.com/repos/$owner/$repo/releases/tags/v`$version"
                jsonpath = "`$.assets[?(@.name == 'mVolt+.exe')].digest"
            }
        }
    }
}

$desc = 'NVIDIA GPU tuning and monitoring tool with voltage, clock, power and fan control, V/F curves, live telemetry and saved profiles.'
$m1 = New-Manifest 'b00nz' 'mVolt' $desc @()
$m2 = New-Manifest 'AmirulAndalib' 'mvolt-scoop' "Backup mirror of mVolt+, the $desc" @('Same files as ''mvolt'', downloaded from the AmirulAndalib/mvolt-scoop backup mirror instead of the upstream release. Install mvolt or mvolt-mirror, not both.')
$m1 | ConvertTo-Json -Depth 10 | Set-Content bucket/mvolt.json -Encoding utf8NoBOM
$m2 | ConvertTo-Json -Depth 10 | Set-Content bucket/mvolt-mirror.json -Encoding utf8NoBOM
& "$env:SCOOP_HOME\bin\formatjson.ps1" -Dir bucket | Out-Null
} finally {
    Pop-Location
}
