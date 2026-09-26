# LumaNote development

## Local commands

Run commands from `app/QuietNote`:

```bash
swift test
./scripts/build-app.sh
open build/LumaNote.app
```

The app targets macOS 14 or later. `Package.resolved` pins the SwiftPM dependency graph. A normal development build uses the local Xcode toolchain and does not require Node.js, Python, a server, or a sidecar process.

## Cloud gates

Both jobs use the macOS 15 hosted image with Xcode 26.0.1 explicitly selected (Swift 6.2). The deployment target remains macOS 14; the runner OS is not the minimum supported app OS. Dependencies use the checked-in `Package.resolved`; CI rejects lockfile changes and performs uncached builds.

`.github/workflows/cloud-build.yml` has two jobs. `checks` runs the complete Swift test suite. `candidate` depends on `checks`, builds the release configuration for the hosted macOS arm64 runner, validates the app bundle and ad-hoc code signature, packages the complete app bundle as a zip, and uploads the zip plus a checksum manifest as a workflow artifact.

The workflow does not read a signing secret, overwrite the Sparkle feed, create a tag, create a release, or publish an update. A candidate is identified by its exact `GITHUB_SHA` and workflow run ID. The manifest records the app version/build, runner and toolchain, archive size, SHA256, signature state, and test command.

## Release boundary

Candidate artifacts are retained for 14 days. Download `lumanote-candidate-<run-number>` from the successful Actions run, or use `gh run download <run-id> --repo hututuo/LumaNote --name lumanote-candidate-<run-number>`. Compare the zip size and `shasum -a 256` with the included manifest before extracting. The zip contains the complete app and Sparkle framework; end users do not need Xcode or SwiftPM. It is an ad-hoc-signed, non-notarized test candidate, so Gatekeeper may require explicit approval. Clean-user installation, macOS 14 compatibility and interactive behavior remain separate acceptance checks. Do not overwrite an existing app without approval.

`prepare-release.sh` is a separate local release gate. It requires a clean tracked worktree, release notes, an exact version/tag identity, a fresh SwiftPM scratch path, a real Sparkle signature, a verified DMG, and matching checksums. Keep the Sparkle private key outside Git and outside workflow logs. Do not treat a passing cloud candidate as an installed, interactive, notarized, or backwards-compatibility acceptance.

## Private handoff context

Configure the local project clone with the private repository and path agreed by the maintainer:

```bash
git config --local project.devContextRepo https://github.com/hututuo/project-dev-context.git
git config --local project.devContextKey projects/hututuo--LumaNote
git config --local project.devContextPath /path/to/private/project-dev-context
```

Do not commit the absolute path or credentials. A new session should report when the private clone is missing or stale instead of claiming that internal progress has been loaded.
