# Security Policy

## Scope

This repository only holds a Scoop manifest and the CI that keeps it current. It does not contain or redistribute mVolt+ itself. Scoop downloads the official `mVolt+.exe` from the [upstream releases](https://github.com/b00nz/mVolt/releases) and checks it against the SHA256 hash in `bucket/mvolt.json`.

## Reporting a Vulnerability

- **Problems in mVolt+ itself:** report them to the upstream project at [b00nz/mVolt](https://github.com/b00nz/mVolt/issues).
- **Problems in this bucket** (a wrong hash, a URL that does not point at the official release, a compromised workflow): open a [private security advisory](https://github.com/AmirulAndalib/mvolt-scoop/security/advisories/new) on this repository.

Please do not open public issues for security problems.
