# LumaNote architecture

LumaNote is a local-first macOS 14+ SwiftUI application with AppKit bridges where the native text system and window behavior are required. It stores ordinary Markdown files and keeps clipboard history in the user's local Application Support directory.

## Runtime composition

- `Sources/App` owns application startup, settings, language and appearance preferences, global shortcuts, login-item integration, and Sparkle update configuration.
- `Sources/Markdown` contains the editable `NSTextView` bridge, Markdown block and inline styling, hidden-syntax handling, document positions, task checkboxes, scrolling, and static swipe-preview rendering.
- `Sources/Notes` owns Markdown file IO, recent files, workspaces, per-file document positions, debounced saves, external-modification checks, and preview data.
- `Sources/Clipboard` owns opt-in pasteboard monitoring, detection, local history persistence, search indexing, retention limits, and action metadata.
- `Sources/NoteWindow` and `Sources/Window` compose the glass note window, bottom rail, overlays, resize metrics, drag behavior, and horizontal document switching.
- `Sources/Onboarding` and `Sources/Settings` expose the first-run and settings flows without changing the user's Markdown format.
- `support/` contains the app bundle metadata, icon, and DMG artwork. `scripts/` builds the app, packages a DMG, and prepares release artifacts.

## Main data flows

Markdown text is loaded by `NoteStore`, bound to `MarkdownRenderingEditor`, styled in TextKit, and saved back as plain UTF-8 Markdown. The editor stores a per-file `MarkdownDocumentPosition` so a later open can restore the user's last visible position without allowing a stale selection to pull the new document to an unrelated location.

Horizontal switching is coordinated by `NoteDocumentSwipeCoordinator`. It loads adjacent Markdown text, renders a bounded static bitmap for the swipe surface, tracks the target file's position, and only commits the editable document after the target preview is ready. The preview and editable editor share the same Markdown styling rules and restored selection state when a position is active.

Clipboard monitoring is disabled for fresh settings until the user enables it. Once enabled, `ClipboardStore` bounds each record and the total history, detects values off the main UI path, and writes a versioned local envelope through a serialized writer. Corrupt history is preserved until the user explicitly clears it.

## Packaging boundary

SwiftPM resolves `KeyboardShortcuts` and `Sparkle` through `Package.resolved`. `build-app.sh` produces a self-contained `LumaNote.app` containing the Sparkle framework. The cloud candidate workflow packages that app as a zip and records checksums; release signing and public publication are separate operator-controlled gates.
