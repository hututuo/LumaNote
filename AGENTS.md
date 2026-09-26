# LumaNote agent entry

LumaNote is a native macOS SwiftUI application. Before changing code:

1. Read `README.md`, `docs/architecture.md`, and `docs/development.md`.
2. Read `.project-context.json` to identify the source repository and public entry points.
3. Check the current branch, full `HEAD`, worktree status, and relevant tests.
4. If local Git configuration contains `project.devContextRepo`, `project.devContextKey`, and `project.devContextPath`, read the private `CONTEXT.md`, `PROJECT_INDEX.md`, `decisions.md`, and active plan there. If it is unavailable, say so explicitly and continue with public context only.

The private development context is authoritative for internal progress and handoffs. Do not copy credentials, private keys, authenticated responses, user data, machine-specific paths, or full session transcripts into this public repository. Keep checks, candidate builds, signing, and publishing as separate gates; this repository's cloud workflow runs checks and a candidate app build only.
