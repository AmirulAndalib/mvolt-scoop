# Tests the post_install and pre_uninstall scripts in both manifests.
# %ProgramFiles% is pointed at a temporary folder, so nothing on the machine is touched.
# Two real mVolt+ builds are downloaded from upstream: the one in the manifest and v0.47.3,
# which plays the stale "Start with Windows" copy.

BeforeDiscovery {
    $script:apps = @('mvolt', 'mvolt-mirror')
}

BeforeAll {
    $bucketDir = Join-Path $PSScriptRoot '..\bucket'
    $script:sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:realProgramFiles = $env:ProgramFiles
    $script:work = Join-Path ([IO.Path]::GetTempPath()) "mvolt-hook-tests-$PID"
    New-Item -ItemType Directory -Force -Path $work | Out-Null

    $head = Get-Content (Join-Path $bucketDir 'mvolt.json') -Raw | ConvertFrom-Json
    $script:newDir = Join-Path $work 'new'
    New-Item -ItemType Directory -Force -Path $newDir | Out-Null
    $script:newExe = Join-Path $newDir 'mVolt+.exe'
    Invoke-WebRequest -Uri $head.architecture.'64bit'.url -OutFile $newExe -UseBasicParsing
    $script:newHash = (Get-FileHash -LiteralPath $newExe -Algorithm SHA256).Hash
    $script:oldExe = Join-Path $work 'old.exe'
    Invoke-WebRequest -Uri 'https://github.com/b00nz/mVolt/releases/download/v0.47.3/mVolt+.exe' -OutFile $oldExe -UseBasicParsing

    function script:warn($msg) { Write-Host "WARN  $msg" }

    function script:New-FakeProgramFiles([string]$CopyFrom) {
        $root = Join-Path $work "pf-$([guid]::NewGuid())"
        $adapter = Join-Path (Join-Path (Join-Path $root 'mVolt+') $sid) 'pci-test'
        New-Item -ItemType Directory -Force -Path $adapter | Out-Null
        $copy = Join-Path $adapter 'mVolt+.exe'
        if ($CopyFrom) { Copy-Item -LiteralPath $CopyFrom -Destination $copy }
        $env:ProgramFiles = $root
        return $copy
    }

    function script:Invoke-Hook([string]$Code, [string]$Version, [switch]$AsAdmin) {
        if ($AsAdmin) { $Code = $Code -replace '\$isAdmin = .*', '$isAdmin = $true' }
        $dir = $newDir
        $version = $Version
        $null = $dir, $version # used by the hook code
        $out = & { Invoke-Expression $Code } 6>&1 | Out-String
        return ($out -replace '\s+', ' ').Trim()
    }
}

AfterAll {
    $env:ProgramFiles = $realProgramFiles
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Start with Windows handling in <_>' -ForEach $apps {
    BeforeAll {
        $m = Get-Content (Join-Path $PSScriptRoot "..\bucket\$_.json") -Raw | ConvertFrom-Json
        $post = $m.post_install -join "`n"
        $pre = $m.pre_uninstall -join "`n"
        $version = $m.version
    }

    AfterEach { $env:ProgramFiles = $realProgramFiles }

    It 'warns without touching a stale copy when not elevated' {
        $copy = New-FakeProgramFiles $oldExe
        $out = Invoke-Hook $post $version -AsAdmin:$false
        if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Set-ItResult -Skipped -Because 'the test runner is elevated'
            return
        }
        $out | Should -Match 'still version 0\.47\.3'
        (Get-FileHash -LiteralPath $copy).Hash | Should -Not -Be $newHash
    }

    It 'replaces a stale copy and verifies it when elevated' {
        $copy = New-FakeProgramFiles $oldExe
        $out = Invoke-Hook $post $version -AsAdmin
        $out | Should -Match 'from 0\.47\.3 to'
        (Get-FileHash -LiteralPath $copy).Hash | Should -Be $newHash
    }

    It 'warns instead of failing when the copy is in use' {
        $copy = New-FakeProgramFiles $oldExe
        $lock = [IO.File]::Open($copy, 'Open', 'Read', 'Read')
        try { $out = Invoke-Hook $post $version -AsAdmin } finally { $lock.Dispose() }
        $out | Should -Match 'Could not update'
        (Get-FileHash -LiteralPath $copy).Hash | Should -Not -Be $newHash
    }

    It 'stays silent when the copy is already current' {
        New-FakeProgramFiles $newExe | Out-Null
        Invoke-Hook $post $version -AsAdmin | Should -BeNullOrEmpty
    }

    It 'never downgrades the copy when an older version is installed' {
        $copy = New-FakeProgramFiles $newExe
        Invoke-Hook $post '0.47.3' -AsAdmin | Should -BeNullOrEmpty
        (Get-FileHash -LiteralPath $copy).Hash | Should -Be $newHash
    }

    It 'stays silent when Start with Windows was never used' {
        $env:ProgramFiles = Join-Path $work "pf-empty-$([guid]::NewGuid())"
        Invoke-Hook $post $version -AsAdmin | Should -BeNullOrEmpty
    }

    It 'stops update and uninstall while the installed exe is running' {
        $env:ProgramFiles = Join-Path $work "pf-empty-$([guid]::NewGuid())"
        # Another open handle without write sharing behaves like a running image.
        $lock = [IO.File]::Open($newExe, 'Open', 'Read', 'Read')
        try { { Invoke-Hook $pre $version } | Should -Throw '*still running*' } finally { $lock.Dispose() }
        { Invoke-Hook $pre $version } | Should -Not -Throw
    }

    It 'warns on uninstall only when a startup copy exists' {
        New-FakeProgramFiles $oldExe | Out-Null
        Invoke-Hook $pre $version | Should -Match 'keeps starting at logon'
        $env:ProgramFiles = Join-Path $work "pf-empty-$([guid]::NewGuid())"
        Invoke-Hook $pre $version | Should -BeNullOrEmpty
    }
}
