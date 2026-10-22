# Tests scripts/New-WingetManifest.ps1 and the input checks that scripts/Publish-Winget.ps1 runs
# before it talks to GitHub. Nothing here uses the network; output goes to a temporary folder.

BeforeDiscovery {
    $script:hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

BeforeAll {
    $script:render = Join-Path $PSScriptRoot '..\scripts\New-WingetManifest.ps1'
    $script:publish = Join-Path $PSScriptRoot '..\scripts\Publish-Winget.ps1'
    $script:good = @{
        Version      = '0.50.6'
        Tag          = 'v0.50.6'
        InstallerUrl = 'https://github.com/b00nz/mVolt/releases/download/v0.50.6/mVolt%2B.exe'
        Sha256       = 'e1e2366dd66b19c0c60b34c7f8580f2b60664e5fe23bbb53c524f591e0470ca6'
        ReleaseDate  = '2026-10-21'
    }
    $script:work = Join-Path ([IO.Path]::GetTempPath()) "mvolt-winget-tests-$PID"

    function script:Invoke-Render([hashtable]$Override = @{}) {
        $p = $good.Clone()
        foreach ($k in $Override.Keys) { $p[$k] = $Override[$k] }
        $p.OutDir = Join-Path $work ([guid]::NewGuid())
        & $render @p 6>$null
        return $p.OutDir
    }
}

AfterAll {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'New-WingetManifest.ps1 with valid input' {
    BeforeAll {
        $script:out = Invoke-Render
        $script:files = @(Get-ChildItem $out)
        $script:installer = [IO.File]::ReadAllText((Join-Path $out 'b00nz.mVolt.installer.yaml'))
    }

    It 'writes exactly the three manifests' {
        ($files.Name | Sort-Object) -join ',' | Should -Be 'b00nz.mVolt.installer.yaml,b00nz.mVolt.locale.en-US.yaml,b00nz.mVolt.yaml'
    }

    It 'writes LF line endings, no BOM and a single final newline' {
        foreach ($f in $files) {
            $bytes = [IO.File]::ReadAllBytes($f.FullName)
            ($bytes[0..2] -join ',') | Should -Not -Be '239,187,191' -Because $f.Name
            $bytes -contains [byte]13 | Should -BeFalse -Because $f.Name
            $bytes[-1] | Should -Be 10 -Because $f.Name
            $bytes[-2] | Should -Not -Be 10 -Because $f.Name
        }
    }

    It 'puts the package version at the top level of every file' {
        # Guards against a local variable named like a parameter replacing -Version.
        # That bug nests one manifest inside another, so a plain match would still find the line.
        foreach ($f in $files) {
            $lines = @([IO.File]::ReadAllText($f.FullName).Split("`n") | Where-Object { $_ -clike 'PackageVersion:*' })
            $lines -join '|' | Should -BeExactly 'PackageVersion: 0.50.6' -Because $f.Name
        }
    }

    It 'writes the hash in upper case and keeps the URL and date' {
        $installer | Should -MatchExactly '(?m)^  InstallerSha256: E1E2366DD66B19C0C60B34C7F8580F2B60664E5FE23BBB53C524F591E0470CA6$'
        $installer | Should -MatchExactly '(?m)^  InstallerUrl: https://github\.com/b00nz/mVolt/releases/download/v0\.50\.6/mVolt%2B\.exe$'
        $installer | Should -MatchExactly '(?m)^ReleaseDate: 2026-10-21$'
    }

    It 'passes winget validate' -Skip:(-not $hasWinget) {
        $validate = (& winget validate --manifest $out 2>&1 | Out-String)
        $validate | Should -Match 'Manifest validation succeeded'
    }
}

Describe 'New-WingetManifest.ps1 rejects <Case>' -ForEach @(
    @{ Case = 'a one-part version'; Override = @{ Version = '1'; Tag = 'v1' } }
    @{ Case = 'a five-part version'; Override = @{ Version = '1.2.3.4.5'; Tag = 'v1.2.3.4.5' } }
    @{ Case = 'a version with a trailing newline'; Override = @{ Version = "0.50.6`n"; Tag = "v0.50.6`n" } }
    @{ Case = 'YAML in the version'; Override = @{ Version = '0.50.6: x'; Tag = 'v0.50.6: x' } }
    @{ Case = 'a tag that does not match the version'; Override = @{ Tag = 'v0.50.5' } }
    @{ Case = 'a URL from another repository'; Override = @{ InstallerUrl = 'https://github.com/someone/mVolt/releases/download/v0.50.6/mVolt%2B.exe' } }
    @{ Case = 'a URL for another tag'; Override = @{ InstallerUrl = 'https://github.com/b00nz/mVolt/releases/download/v0.50.5/mVolt%2B.exe' } }
    @{ Case = 'a plain HTTP URL'; Override = @{ InstallerUrl = 'http://github.com/b00nz/mVolt/releases/download/v0.50.6/mVolt%2B.exe' } }
    @{ Case = 'a URL with a trailing newline'; Override = @{ InstallerUrl = "https://github.com/b00nz/mVolt/releases/download/v0.50.6/mVolt%2B.exe`n" } }
    @{ Case = 'a short hash'; Override = @{ Sha256 = 'e1e2366dd66b19c0c60b34c7f8580f2b60664e5fe23bbb53c524f591e0470ca' } }
    @{ Case = 'a non-hex hash'; Override = @{ Sha256 = 'g1e2366dd66b19c0c60b34c7f8580f2b60664e5fe23bbb53c524f591e0470ca6' } }
    @{ Case = 'an impossible date'; Override = @{ ReleaseDate = '2026-13-01' } }
    @{ Case = 'a date without leading zeros'; Override = @{ ReleaseDate = '2026-1-01' } }
) {
    It 'throws and writes nothing' {
        $dir = Join-Path $work ([guid]::NewGuid())
        $p = $good.Clone()
        foreach ($k in $Override.Keys) { $p[$k] = $Override[$k] }
        { & $render @p -OutDir $dir 6>$null } | Should -Throw
        Test-Path -LiteralPath $dir | Should -BeFalse
    }
}

Describe 'Publish-Winget.ps1 checks its input before calling GitHub' {
    BeforeAll {
        $script:manifests = Invoke-Render
        $script:empty = Join-Path $work ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $empty | Out-Null
    }

    It 'rejects a malformed version' {
        { & $publish -Version '0.50.6; x' -ManifestDir $manifests -Token 'unused' 6>$null } | Should -Throw '*Unexpected version*'
    }

    It 'refuses to run without a token' {
        { & $publish -Version '0.50.6' -ManifestDir $manifests -Token '' 6>$null } | Should -Throw '*No token*'
    }

    It 'refuses a folder without the manifests' {
        { & $publish -Version '0.50.6' -ManifestDir $empty -Token 'unused' 6>$null } | Should -Throw '*Missing b00nz.mVolt.yaml*'
    }
}
