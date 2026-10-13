# mvolt-scoop

[![CI](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/ci.yml/badge.svg)](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/ci.yml)
[![Excavator](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/excavator.yml/badge.svg)](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/excavator.yml)
[![Mirror](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/mirror.yml/badge.svg)](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/mirror.yml)
[![Scoop Version](https://img.shields.io/scoop/v/mvolt?bucket=https%3A%2F%2Fgithub.com%2FAmirulAndalib%2Fmvolt-scoop)](https://github.com/AmirulAndalib/mvolt-scoop/blob/master/bucket/mvolt.json)
[![Upstream Release](https://img.shields.io/github/v/release/b00nz/mVolt)](https://github.com/b00nz/mVolt/releases/latest)

Unofficial [Scoop](https://scoop.sh) bucket for [mVolt+](https://github.com/b00nz/mVolt) by [b00nz](https://github.com/b00nz), a Windows tool for NVIDIA GPU tuning and monitoring (voltage, clocks, power, V/F and fan curves, telemetry and profiles).

This bucket is not affiliated with the mVolt+ author. The files are never modified. Every download is checked against a SHA256 hash.

## Install

```powershell
scoop bucket add mvolt https://github.com/AmirulAndalib/mvolt-scoop
scoop install mvolt/mvolt
```

There are two packages with the same files. Pick one:

| Package | Downloads from |
| --- | --- |
| `mvolt` | The official [b00nz/mVolt releases](https://github.com/b00nz/mVolt/releases). Use this one. |
| `mvolt-mirror` | The backup copies in [this repository's releases](https://github.com/AmirulAndalib/mvolt-scoop/releases). Use it if the upstream release is unavailable. |

```powershell
scoop install mvolt/mvolt-mirror
```

Both install the same exe with the same hash, the same `mvolt` command and the same shortcut, so install only one of them. To switch, uninstall one and install the other. Your settings are not affected.

The package is called `mvolt` because Scoop app names cannot contain `+`. The installed file keeps its original name, `mVolt+.exe`.

What you get:

- A Start Menu shortcut named **mVolt+** under Scoop Apps.
- An `mvolt` command for the built-in CLI. mVolt+ is a GUI program, so in PowerShell pipe its output like upstream does, for example `mvolt --status | Out-Host` or `mvolt --list-gpus | Out-Host`. In cmd and Git Bash a plain `mvolt --status` works.

Tuning needs administrator rights. Start mVolt+ as administrator (right-click the shortcut) when you want to apply settings.

## Update

```powershell
scoop update
scoop update mvolt
```

Exit mVolt+ from the tray icon first. Scoop cannot replace the exe while it is running.

New upstream releases are picked up automatically every 4 hours. Only stable releases are offered through Scoop. Drafts and prereleases are skipped.

## Older versions

Every stable release since v0.3 can be installed by version, from either package:

```powershell
scoop uninstall mvolt
scoop install mvolt/mvolt@0.47.3
```

A version installed this way stays on that version, and `scoop update` will not move it. To go back to the latest release, reinstall:

```powershell
scoop uninstall mvolt
scoop install mvolt/mvolt
```

To stay on your current version while still running `scoop update` for everything else, use `scoop hold mvolt`. Release it with `scoop unhold mvolt`.

## Release mirror

Every upstream release, including prereleases, is copied unmodified to [this repository's releases](https://github.com/AmirulAndalib/mvolt-scoop/releases). Each mirrored release has:

- `mVolt+.exe`, checked against GitHub's SHA256 for the upstream file before it is published, and again after upload.
- `mVolt-<tag>-source.zip`, the upstream repository at that tag (README, user guide and screenshots for that version).
- The upstream release notes and the SHA256 of both files.

The mirror only adds releases. If an upstream release is removed or replaced later, the mirrored copy stays as it was.

## Where mVolt+ keeps its data

Scoop only manages the exe. mVolt+ itself writes to these places, which Scoop never touches, including on update and uninstall:

| Data | Location |
| --- | --- |
| Profiles, preferences and logs | `%LOCALAPPDATA%\mVolt+` |
| Extend limits recovery data | `%PROGRAMDATA%\mVolt+\NativeLimits` (keep this while you use Extend limits) |
| Start with Windows copy | `%ProgramFiles%\mVolt+`, launched at logon |

Your profiles survive updates and reinstalls. Delete `%LOCALAPPDATA%\mVolt+` yourself if you want a clean slate.

## Start with Windows

When you turn on **Start with Windows**, mVolt+ installs its own copy of the exe under `%ProgramFiles%\mVolt+` and runs that copy at logon. Scoop does not manage that copy:

- After updating, open mVolt+ as administrator once. That refreshes the startup copy to the new version.
- Before `scoop uninstall mvolt`, turn **Start with Windows** off in mVolt+ so it stops launching at logon. If a folder is still left under `%ProgramFiles%\mVolt+` afterwards, you can delete it as administrator.

## Uninstall

```powershell
scoop uninstall mvolt
scoop bucket rm mvolt
```

## Problems

- Problems with mVolt+ itself (crashes, GPU support, features): [b00nz/mVolt issues](https://github.com/b00nz/mVolt/issues).
- Problems with the Scoop packages or the mirror (install fails, wrong hash, update not picked up): [open an issue here](https://github.com/AmirulAndalib/mvolt-scoop/issues).

## How this bucket works

- `bucket/mvolt.json` and `bucket/mvolt-mirror.json` are the manifests.
- The [Mirror](.github/workflows/mirror.yml) workflow runs [`scripts/mirror-releases.ps1`](scripts/mirror-releases.ps1) every 4 hours and copies any new upstream release here.
- The [Excavator](.github/workflows/excavator.yml) workflow runs Scoop's own `checkver` every 4 hours, ten minutes after the mirror. It reads `/releases/latest`, which never returns drafts or prereleases, takes the SHA256 that GitHub records for the release file and commits the update.
- The [CI](.github/workflows/ci.yml) workflow runs Scoop's manifest tests on Windows PowerShell and PowerShell 7. Once a day it also downloads both packages to confirm the URLs, the hashes and that the files are x64 executables.

GPU tuning can cause instability or hardware damage. Read the upstream [guide](https://github.com/b00nz/mVolt/blob/main/docs/guide.md) before changing voltages or limits.
