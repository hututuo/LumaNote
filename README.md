<div align="center">

<img src="assets/lumanote-icon.png" alt="LumaNote icon" width="128">

# LumaNote

[English](README.md) | [中文](README.zh-CN.md)

**A translucent glass Markdown sticky note for macOS.**

**One command install · Live Markdown styling · Local clipboard library**

</div>

> The English and Chinese READMEs are maintained as content-equivalent versions. If one document changes, update the other in the same commit.

## Community

<p align="center">
  <img src="assets/wechat-group-qr.jpeg" alt="WeChat group QR code for HTT repositories" width="220">
</p>

<p align="center">
  Scan to join the WeChat group for discussion, product releases, and update notes.
</p>

## Why This Exists

LumaNote is built for the tiny notes that should stay close: a thought, a checklist, a link, an address, a verification code, or a Markdown draft you keep at the edge of the screen.

Most note apps become libraries, databases, or dashboards. LumaNote stays intentionally small: one elegant glass note, live Markdown styling, quick file switching, adjustable transparency, and a local clipboard library that can surface useful extracted values without taking over the screen.

## Quick Install

macOS 14+ with Swift / Xcode Command Line Tools:

```bash
curl -fsSL https://raw.githubusercontent.com/hututuo/LumaNote/main/install.sh | bash
```

The installer clones or updates the repository under `~/.lumanote/source`, builds and ad-hoc signs the app locally, installs it to `~/Applications/LumaNote.app`, and opens it.

If you publish this repository under a different URL, override the clone source:

```bash
LUMANOTE_REPO=https://github.com/your-name/LumaNote.git \
  curl -fsSL https://raw.githubusercontent.com/your-name/LumaNote/main/install.sh | bash
```

## Manual Build

```bash
git clone https://github.com/hututuo/LumaNote.git
cd LumaNote/app/QuietNote
./scripts/build-app.sh
open build/LumaNote.app
```

## Key Features

| Feature | What it does |
|---|---|
| Glass sticky note | A compact frosted-glass note designed to live at the edge of the screen. |
| Adjustable transparency | Bottom slider controls note shell visibility while keeping text and controls readable. |
| Live Markdown styling | Edit plain Markdown directly; headings, links, lists, task checkboxes, code, highlights, and common inline styles are styled in place. |
| Task checkboxes | `- [ ]` and `- [x]` render as clickable checkboxes with task-list Return behavior. |
| Recent file switcher | Bottom switch button opens a compact recent-file panel, with Open New File as the first row. |
| Save As | Save the current note as a Markdown/text file and continue live-saving to that file. |
| Clipboard library | Local clipboard history with search, retention settings, copy, paste, and delete. |
| Clipboard extraction | Detects URLs, email addresses, phone numbers, address-like text, and labeled codes from each clipboard item. |
| Top island suggestions | Extracted clipboard values can appear in a compact top island for quick copy, paste, open URL, email, call, or map actions. |
| Global shortcuts | Configurable shortcuts for showing the note, hiding the note, and opening the clipboard library. |
| Launch at login | Optional macOS Login Items integration so LumaNote can open automatically after sign-in. |
| Chinese / English UI | Built-in app chrome language switch. Markdown content is not translated or changed. |

## Markdown Compatibility

LumaNote saves note content as plain Markdown. The editor is a lightweight live styler, not a full CommonMark or GitHub-Flavored Markdown renderer.

See the full table:

- [Markdown Compatibility](docs/markdown-compatibility.md)

## Local Data

LumaNote stores app data locally under:

```text
~/Library/Application Support/QuietNote/
```

Clipboard monitoring is local and can be disabled from the in-note menu or Settings.

## Repository Layout

```text
LumaNote/
  app/QuietNote/                 # SwiftUI macOS app source
    Sources/                     # App code
    scripts/build-app.sh         # Builds build/LumaNote.app
    support/Info.plist           # Bundle metadata
    support/AppIcon.icns         # macOS app icon
  assets/                        # README icon and WeChat QR image
  docs/markdown-compatibility.md # Markdown support table
  install.sh                     # One-command installer
  README.md
  README.zh-CN.md
```

## Development

```bash
cd app/QuietNote
swift build
./scripts/build-app.sh
open build/LumaNote.app
```

Build outputs, `.build/`, `build/`, and local run artifacts are intentionally ignored.

## Notes

LumaNote is currently a local macOS build, not a signed/notarized App Store release. If macOS Gatekeeper warns on first launch, build from source or approve the app through System Settings.
The local bundle is ad-hoc signed during `./scripts/build-app.sh`, which is useful for local installation and update workflows but is not the same as Developer ID signing or notarization.
