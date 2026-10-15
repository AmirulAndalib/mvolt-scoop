# mvolt-scoop

[![CI](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/ci.yml/badge.svg)](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/ci.yml)
[![Update](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/update.yml/badge.svg)](https://github.com/AmirulAndalib/mvolt-scoop/actions/workflows/update.yml)
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

Both install the same exe with the same hash and the same `mvolt` command, so install only one of them. The Start Menu shortcut is **mVolt+** for `mvolt` and **mVolt+ (mirror)** for `mvolt-mirror`. To switch, uninstall one and install the other. Your settings are not affected.

The package is called `mvolt` because Scoop app names cannot contain `+`. The installed file keeps its original name, `mVolt+.exe`.

What you get:

- A Start Menu shortcut under Scoop Apps (**mVolt+**, or **mVolt+ (mirror)** for `mvolt-mirror`).
- An `mvolt` command for the built-in CLI. mVolt+ is a GUI program, so in PowerShell pipe its output like upstream does, for example `mvolt --status | Out-Host` or `mvolt --list-gpus | Out-Host`. In cmd and Git Bash a plain `mvolt --status` works.

Tuning needs administrator rights. Start mVolt+ as administrator (right-click the shortcut) when you want to apply settings.

## Update

```powershell
scoop update
scoop update mvolt
```

If you opened mVolt+ from the Scoop shortcut, exit it from the tray icon first. Scoop cannot replace the exe while it is running. An mVolt+ started by Start with Windows is handled for you, see [Start with Windows](#start-with-windows).

New upstream releases are picked up automatically, usually within an hour. Both packages move to a new version in the same run. Only stable releases are offered through Scoop. Drafts and prereleases are skipped.

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

The mirror never replaces a file it already has. If an upstream release is removed or its file replaced later, the mirrored copy stays as it was. The prerelease flag and the latest release follow upstream, so a prerelease that upstream later promotes to a full release is promoted here too. If the upstream repository disappears, the mirror keeps everything and keeps working.

## Where mVolt+ keeps its data

mVolt+ itself writes to these places:

| Data | Location | What the Scoop package does with it |
| --- | --- | --- |
| Profiles, preferences and logs | `%LOCALAPPDATA%\mVolt+` | Never touched, including on uninstall |
| Extend limits recovery data | `%PROGRAMDATA%\mVolt+\NativeLimits` | Never touched. Keep this while you use Extend limits |
| Start with Windows copy | `%ProgramFiles%\mVolt+`, launched at logon | Replaces an older exe with the new one, see [Start with Windows](#start-with-windows). Never deleted |

Your profiles survive updates and reinstalls. Delete `%LOCALAPPDATA%\mVolt+` yourself if you want a clean slate.

## Start with Windows

When you turn on **Start with Windows**, mVolt+ copies its exe to `%ProgramFiles%\mVolt+\<your user>\<GPU>\mVolt+.exe` and a logon task runs that copy. Opening mVolt+ as administrator refreshes the copy. That refresh is a plain file copy; the logon task is not changed.

The packages keep that copy in step for you. When you install or update and your startup copy is older than the new version:

1. Scoop asks for administrator rights once (a UAC prompt). From an administrator terminal there is no prompt.
2. If mVolt+ is running from the startup copy, it is stopped.
3. The startup copy is replaced with the new exe and its SHA256 is checked.
4. If it was running, mVolt+ is started again through its own logon task, exactly as at sign-in. That re-applies your startup profile.

If you decline the prompt, or nobody answers it within 3 minutes, nothing is changed and Scoop tells you to open mVolt+ as administrator once instead. Installing an older version never downgrades the startup copy. Nothing happens if you never turned on Start with Windows.

While mVolt+ is stopped for the swap (a few seconds), a software fan curve is not running and the fan stays at its last speed. The restart brings the curve back. Applied clocks and voltages are not affected.

If you opened mVolt+ from the Scoop shortcut, exit it from the tray before updating. Scoop cannot see an mVolt+ that runs as administrator, so the package checks for it and stops the update or uninstall with a clear message before anything is removed.

The startup copy is a separate file, so it keeps running at logon after `scoop uninstall mvolt`. Scoop warns about this on uninstall. Turn **Start with Windows** off in mVolt+ first if you no longer want it.

## Uninstall

```powershell
scoop uninstall mvolt
scoop bucket rm mvolt
```

## Problems

- Problems with mVolt+ itself (crashes, GPU support, features): [b00nz/mVolt issues](https://github.com/b00nz/mVolt/issues).
- Problems with the Scoop packages or the mirror (install fails, wrong hash, update not picked up): [open an issue here](https://github.com/AmirulAndalib/mvolt-scoop/issues).

## How this bucket works

- `bucket/mvolt.json` and `bucket/mvolt-mirror.json` are the manifests. Their install and uninstall scripts are generated by [`scripts/Update-Manifests.ps1`](scripts/Update-Manifests.ps1), which embeds [`scripts/refresh-helper.ps1`](scripts/refresh-helper.ps1) (the Start with Windows refresh). CI fails if the manifests and the generator disagree.
- The [Update](.github/workflows/update.yml) workflow runs every hour in two steps. First [`scripts/mirror-releases.ps1`](scripts/mirror-releases.ps1) copies any new upstream release here. Only after that succeeds, Scoop's own Excavator runs `checkver` for both packages: it reads `/releases/latest`, which never returns drafts or prereleases, takes the SHA256 that GitHub records for the release file and commits the update. Because the mirror always runs first, `mvolt` and `mvolt-mirror` update in the same run.
- The [CI](.github/workflows/ci.yml) workflow runs Scoop's manifest tests and [`tests/Manifest-Hooks.Tests.ps1`](tests/Manifest-Hooks.Tests.ps1) (the Start with Windows handling, against a temporary folder) on Windows PowerShell and PowerShell 7. Every 6 hours it also downloads both packages to confirm the URLs, the hashes and that the files are x64 executables, and fails if either package has not followed upstream's latest stable release within 6 hours.

## License

The manifests, scripts and workflows in this repository are under the [MIT License](LICENSE). mVolt+ itself is not covered by it. mVolt+ belongs to [b00nz](https://github.com/b00nz) and is published without a license file.

GPU tuning can cause instability or hardware damage. Read the upstream [guide](https://github.com/b00nz/mVolt/blob/main/docs/guide.md) before changing voltages or limits.
