# mvolt-scoop

[![CI](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/ci.yml/badge.svg)](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/ci.yml)
[![Excavator](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/excavator.yml/badge.svg)](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/excavator.yml)
[![Scoop Version](https://img.shields.io/scoop/v/mvolt?bucket=https%3A%2F%2Fgithub.com%2FAmirulAndalib%2Fmvolt-scoop)](https://github.com/AmirulAndalib/mvolt-scoop/blob/master/bucket/mvolt.json)
[![Upstream Release](https://img.shields.io/github/v/release/b00nz/mVolt)](https://github.com/b00nz/mVolt/releases/latest)

Unofficial [Scoop](https://scoop.sh) bucket for [mVolt+](https://github.com/b00nz/mVolt) by [b00nz](https://github.com/b00nz), a Windows tool for NVIDIA GPU tuning and monitoring (voltage, clocks, power, V/F and fan curves, telemetry and profiles).

This bucket is not affiliated with the mVolt+ author. It does not host or modify any files. Scoop downloads the official `mVolt+.exe` straight from the upstream GitHub release and checks it against the SHA256 hash in the manifest.

## Install

```powershell
scoop bucket add mvolt https://github.com/AmirulAndalib/mvolt-scoop
scoop install mvolt/mvolt
```

The package is called `mvolt` because Scoop app names cannot contain `+`. The installed file keeps its original name, `mVolt+.exe`.

What you get:

- A Start Menu shortcut named **mVolt+** under Scoop Apps.
- An `mvolt` command for the built-in CLI, for example `mvolt --version`, `mvolt --status` or `mvolt --list-gpus`.

Tuning needs administrator rights. Start mVolt+ as administrator (right-click the shortcut) when you want to apply settings.

## Update

```powershell
scoop update mvolt
```

Exit mVolt+ from the tray icon first. Scoop cannot replace the exe while it is running.

New upstream releases are picked up automatically every 4 hours. Only stable releases are tracked. Drafts and prereleases are skipped.

## Older versions

Every stable release since v0.3 is in this bucket's git history, so you can install a specific one:

```powershell
scoop install mvolt/mvolt@0.47.3
```

To go back to the latest version afterwards, run `scoop update mvolt`. Use `scoop hold mvolt` to stay on a version and `scoop unhold mvolt` to release it.

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

- After `scoop update mvolt`, open mVolt+ as administrator once. That refreshes the startup copy to the new version.
- Before `scoop uninstall mvolt`, turn **Start with Windows** off in mVolt+ so it stops launching at logon. If a folder is still left under `%ProgramFiles%\mVolt+` afterwards, you can delete it as administrator.

## Uninstall

```powershell
scoop uninstall mvolt
scoop bucket rm mvolt
```

## Problems

- Problems with mVolt+ itself (crashes, GPU support, features): [b00nz/mVolt issues](https://github.com/b00nz/mVolt/issues).
- Problems with the Scoop package (install fails, wrong hash, update not picked up): [open an issue here](https://github.com/AmirulAndalib/mvolt-scoop/issues).

## How this bucket works

- `bucket/mvolt.json` is the manifest.
- The [Excavator](.github/workflows/excavator.yml) workflow runs Scoop's own `checkver` every 4 hours. It reads `/releases/latest` from the upstream repo, which never returns drafts or prereleases, downloads the new exe, computes its hash and commits the update.
- The [CI](.github/workflows/ci.yml) workflow runs Scoop's manifest tests on Windows PowerShell and PowerShell 7, and once a day downloads the current release to confirm the URL, the hash and that the file is an x64 executable.

GPU tuning can cause instability or hardware damage. Read the upstream [guide](https://github.com/b00nz/mVolt/blob/main/docs/guide.md) before changing voltages or limits.
