param([string]$Source, [string]$Hash, [string]$Root, [string]$Version, [string]$Log)
# Runs elevated. Embedded into post_install by Update-Manifests.ps1 and passed with
# -EncodedCommand, so there is no script file a non-admin process could change.
$ErrorActionPreference = 'Stop'
function Out-Log([string]$Line) { Add-Content -LiteralPath $Log -Value $Line -Encoding UTF8 }
try {
    $copies = @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'mVolt+.exe' } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    foreach ($copy in $copies) {
        $old = (Get-Item -LiteralPath $copy).VersionInfo.FileVersion
        try { if ([version]$old -ge [version]$Version) { continue } } catch { continue }
        # Stage the new exe inside the admin-only folder and check it there, so a file swapped
        # in the user-writable Scoop folder can never end up as the startup copy.
        $staged = "$copy.new"
        Copy-Item -LiteralPath $Source -Destination $staged -Force
        if ((Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash -ne $Hash) {
            Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
            Out-Log "WARN|The new mVolt+ exe did not match the expected hash. The Start with Windows copy ($old) was left as it is."
            continue
        }
        $running = @(Get-Process -Name 'mVolt+' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $copy })
        foreach ($p in $running) { Stop-Process -Id $p.Id -Force; $null = $p.WaitForExit(10000) }
        try {
            Move-Item -LiteralPath $staged -Destination $copy -Force
            Out-Log "OK|Updated the Start with Windows copy of mVolt+ from $old to $Version."
        } catch {
            Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
            Out-Log "WARN|Could not update the Start with Windows copy of mVolt+ ($old): $($_.Exception.Message)"
        }
        if ($running.Count -gt 0) {
            $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { @($_.Actions | ForEach-Object { $_.Execute }) -contains $copy })
            if ($tasks.Count -gt 0) {
                $tasks | Start-ScheduledTask
                Out-Log 'OK|Restarted mVolt+ from its Start with Windows task.'
            } else {
                Out-Log 'WARN|mVolt+ was stopped to update it, but its Start with Windows task was not found. Start mVolt+ again.'
            }
        }
    }
} catch {
    Out-Log "WARN|Start with Windows refresh failed: $($_.Exception.Message)"
}
