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

Before the Swift suite, CI tests and runs scripts/check-public-history.py over all objects introduced since the merge base with origin/main. This catches matching content even when a later commit deletes the file. Reports contain object IDs, paths and rule names, never matched values. This incremental gate does not erase or certify inherited history and is not a comprehensive secret scanner.

Both jobs use the macOS 15 hosted image with Xcode 26.0.1 explicitly selected (Swift 6.2). The deployment target remains macOS 14; the runner OS is not the minimum supported app OS. Dependencies use the checked-in `Package.resolved`; CI rejects lockfile changes and performs uncached builds.

`.github/workflows/cloud-build.yml` has two jobs. `checks` runs the complete Swift test suite. `candidate` depends on `checks`, builds the release configuration for the hosted macOS arm64 runner, validates the app bundle and ad-hoc code signature, packages the complete app bundle as a zip, and uploads the zip plus a checksum manifest as a workflow artifact.

The workflow does not read a signing secret, overwrite the Sparkle feed, create a tag, create a release, or publish an update. A candidate is identified by its exact `GITHUB_SHA` and workflow run ID. The manifest records the app version/build, runner and toolchain, archive size, SHA256, signature state, and test command.

## Packaged startup checks

After packaging, independent disposable macOS runners download the actual archive and verify its source SHA, size and checksum. The startup matrix tests a fresh profile and a synthetic legacy note.md profile. The harness refuses local/self-hosted environments, existing LumaNote processes and existing profile data. It copies the app into a temporary Applications directory without rebuilding or installing developer dependencies.

Each test waits for AppKit launch readiness, observes the process for 15 seconds, requests normal quit, then checks default-note creation or legacy-note byte preservation. Child PATH contains only system tools; update checks are disabled for this run. JSON evidence is uploaded separately. Hosted runners still contain developer tools: this does not prove a machine without them, Gatekeeper download acceptance, rendered layout, physical gestures or a real user's old-data upgrade. The local application is never launched by this harness.

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
