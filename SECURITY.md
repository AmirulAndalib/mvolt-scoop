# Security Policy

## Scope

This repository holds two Scoop manifests, the workflows that keep them current, and an unmodified backup mirror of the mVolt+ releases. It does not contain mVolt+ source code and never changes the files it mirrors.

- `mvolt` downloads the official `mVolt+.exe` from the [upstream releases](https://github.com/b00nz/mVolt/releases).
- `mvolt-mirror` downloads the same file from [this repository's releases](https://github.com/AmirulAndalib/mvolt-scoop/releases).

Scoop checks every download against the SHA256 hash in the manifest. The mirror only publishes a file after its SHA256 matches the digest GitHub records for the upstream asset, and checks it again after upload.

## Reporting a Vulnerability

- **Problems in mVolt+ itself:** report them to the upstream project at [b00nz/mVolt](https://github.com/b00nz/mVolt/issues).
- **Problems in this repository** (a wrong hash, a URL that does not point at the official release or its exact mirror, a mirrored file that differs from upstream, a compromised workflow): open a [private security advisory](https://github.com/AmirulAndalib/mvolt-scoop/security/advisories/new) on this repository.

Please do not open public issues for security problems.
