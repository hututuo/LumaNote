# Glass Markdown Note Context

## Current Direction

Build a native macOS SwiftUI sticky note app focused on one compact frosted-glass note that can stay at the edge of the screen.

The selected visual direction is a fusion of the generated `Bottom Rail Note` and `Slim Strip Note` concepts:

- One resizable frosted-glass note, not a dashboard.
- Content area takes priority.
- A slim bottom rail holds the main controls.
- The opacity slider runs from 0% to 100%.
- The bottom rail includes a compact file switcher for recent Markdown/text files plus Save As for the current note.
- Extra controls stay behind compact icon buttons or popovers.
- Clipboard suggestions appear as a compact top-bar island/popover, not a large permanent panel.

## Required Product Behavior

- Markdown note editing with live save.
- Markdown should render live inside the editable note body, not through separate edit/preview modes.
- Adjustable note opacity. New default note opacity is 60%.
- Customizable global shortcuts for showing the note, hiding the note, and opening the clipboard library.
- App-level Chinese/English UI language switch in Settings. This changes app chrome text, not the user's Markdown content.
- Clipboard history saved locally after explicit app setting enables monitoring.
- Clipboard detection suggestions for URL, email, phone, address-like text, and labeled codes such as verification codes or order/tracking numbers.
- Polished SwiftUI/macOS visual style with frosted glass and subtle slide/fade behavior.

## Current Build Entry

- App source: `app/QuietNote/`
- Visual reference: `design/quiet-rail-note_reference_20260607-100100.png`
- Debug app bundle: `app/QuietNote/build/QuietNote.app`
- Current visual verification: `app/QuietNote/runs/20260607-101650_opacity-readability/screen.png`
- Current live-render verification: `app/QuietNote/runs/20260607-102025_live-render-editor/screen.png`
- Current drag-handle/display verification: `app/QuietNote/runs/20260607-102630_visible-drag-bars-display/screen.png`
- Current reopen verification: `app/QuietNote/runs/20260607-103101_reopen-visible-check/screen.png`
- Current reopen-hook verification: `app/QuietNote/runs/20260607-103255_reopen-hook-build-check/screen.png`
- Current Dock/deactivate verification: `app/QuietNote/runs/20260607-103556_finder-deactivate-sticky-check/screen.png`
- Current zero-opacity/task verification: `app/QuietNote/runs/20260607-104119_zero-opacity-task-checkbox-check/screen.png`
- Current transparent-controls verification: `app/QuietNote/runs/20260607-104552_transparent-body-visible-controls-check/screen.png`
- Current minimum-opacity verification: `app/QuietNote/runs/20260607-104918_minimum-one-percent-glass-check/screen.png`
- Current small drag-handle verification: `app/QuietNote/runs/20260607-105817_small-drag-handle-first-mouse-check/screen.png`
- Current wide hidden drag-hit-area verification: `app/QuietNote/runs/20260607-110524_wide-hidden-drag-hit-area-check/screen.png`
- Current clipboard/settings v2 verification: `app/QuietNote/runs/20260607-111511_clipboard-settings-v2-build-check/screen.png`
- Current clipboard auto-monitor verification: `app/QuietNote/runs/20260607-112331_clipboard-auto-monitor-fix-check/screen.png`
- Current per-item extraction verification: `app/QuietNote/runs/20260607-113323_per-item-extraction-ui-check/screen.png`
- Current bottom extraction chip verification: `app/QuietNote/runs/20260607-120216_bottom-chip-open-actions-final-check/screen.png`
- Current lower liquid extraction chip verification: `app/QuietNote/runs/20260607-130144_lower-stronger-liquid-chip-check/screen.png`
- Current real glass circle verification: `app/QuietNote/runs/20260607-143756_real-glass-circle-popover-check/screen.png`
- Current top extraction island verification: `app/QuietNote/runs/20260607-152000_top-island-bar-check/screen.png`
- Current collapsed island verification: `app/QuietNote/runs/20260607-152000_top-island-bar-check/screen_plain.png`
- Current neutral glass top island verification: `app/QuietNote/runs/20260607-150800_neutral-glass-top-island-check/expanded.png`
- Current neutral glass collapsed verification: `app/QuietNote/runs/20260607-150800_neutral-glass-top-island-check/collapsed.png`
- Current top island click/drag verification: `app/QuietNote/runs/20260607-151900_click-drag-top-island-check/expanded.png`
- Current title island verification: `app/QuietNote/runs/20260607-153600_title-island-auto-reset-check/title.png`
- Current detected island verification: `app/QuietNote/runs/20260607-153600_title-island-auto-reset-check/detected.png`
- Current 60-second reset verification: `app/QuietNote/runs/20260607-153600_title-island-auto-reset-check/after_60s.png`
- Current centered title / clipboard icon verification: `app/QuietNote/runs/20260607-151300_center-title-clipboard-icon-check/title.png`
- Current detected island / clipboard icon verification: `app/QuietNote/runs/20260607-151300_center-title-clipboard-icon-check/detected.png`
- Current island opacity sync verification: `app/QuietNote/runs/20260607-152700_island-opacity-sync-check/current.png`
- Current island minimum opacity verification: `app/QuietNote/runs/20260607-152700_island-opacity-sync-check/minimum.png`
- Current island hit-zone / shortened width verification: `app/QuietNote/runs/20260607-153900_island-hit-zones-width-check/detected.png`
- Current island shell-only opacity verification: `app/QuietNote/runs/20260607-160500_island-shell-only-opacity-check/current.png`
- Current island shell-only minimum verification: `app/QuietNote/runs/20260607-160500_island-shell-only-opacity-check/minimum.png`
- Current grip drag hit-area verification: `app/QuietNote/runs/20260607-161900_grip-drag-hit-area-restored-check/screen.png`
- Current language/shortcut settings verification: `app/QuietNote/runs/20260607-162800_language-and-shortcuts-settings-check/settings.png`

## Implementation Notes

- The note opacity slider controls the glass/readability layers, not the whole NSWindow alpha. Text and controls intentionally stay readable.
- The compact settings copy distinguishes the bottom opacity slider from the glass feel slider: opacity controls how visible the note shell is, while frosted glass controls blur, haze, and glass texture. New default frosted glass strength is 10%.
- Markdown editing uses `MarkdownRenderingEditor.swift`, an editable `NSTextView` that live-styles the Markdown source. It saves plain Markdown.
- The Markdown editor's enclosing `NSScrollView` uses macOS overlay scrollers with a custom 5pt mini vertical scroller, so the scrollbar stays very thin at the right edge and autohides instead of occupying a thick permanent gutter. The editor view keeps more left padding than right padding so the scroller sits close to the note's right edge.
- `- [ ]` and `- [x]` are rendered as clickable checkboxes while keeping the underlying Markdown text.
- Task markers should not use a tiny hidden font because that makes the insertion caret short near a task marker. The current implementation parses each task line into indentation width plus a fixed checkbox slot, then dynamically computes the hidden marker kern so `- [ ]`, `- [ ] `, `- [ ]  `, `- [x] `, and newly typed tasks occupy the same visual slot.
- Checkbox drawing should use `lineFragmentRect.minX + textContainer.lineFragmentPadding + parsed indentation width`, not marker trailing position or ad hoc constants. The `lineFragmentPadding` term matters because ordinary text starts after AppKit's text-container padding; omitting it makes checkbox left edges fail to align with non-task paragraph text.
- `MarkdownTaskTextView.insertNewline(_:)` handles task continuation. Pressing Return on a non-empty `- [ ]` or `- [x]` line inserts a new `- [ ]`; pressing Return on an empty task line exits the task list by deleting only the current line's task marker/content range, not by inserting or replacing with another newline.
- The Markdown editor disables `NSTextView` automatic text completion, text checking, link/data detection, spelling correction, smart insert/delete, quote substitution, dash substitution, and text replacement. Keep these off so macOS does not auto-continue a plain hyphen list after the app has exited an empty task item.
- The opacity slider now bottoms out at 1%, not 0%. The lowest state keeps a faint glass silhouette, border, and visible control rail so the note does not degrade into frameless floating text.
- The top empty drag area shows three narrower, thinner semi-transparent horizontal bars so users know they can drag there.
- The visible bars stay small, but the invisible `WindowDragView` now fills the full top drag strip and the bars ignore hit testing, so dragging directly on the visible bars should always hit the AppKit drag layer.
- `WindowDragView.swift` overrides `acceptsFirstMouse` so the drag strip can receive the first mouse/trackpad event even while QuietNote is inactive. This is intended to make three-finger dragging work without first focusing the app.
- The top island must not be implemented as a normal SwiftUI `Button`; it blocks three-finger dragging. Use `WindowClickDragView` for the island hit target so short clicks open clipboard/actions and drag gestures call `window.performDrag`.
- The app stores data locally under `~/Library/Application Support/QuietNote/`.
- `NoteStore` tracks a current Markdown file URL and up to 8 recent file URLs. Opening a file loads it into the note, pushes it to the recent list, and switches live save to that file; Save As writes the current content to the chosen file, pushes it to the recent list, and then switches live save to the new path. The current path and recent paths are remembered locally for the next launch.
- The bottom-left file button is a switcher, not a direct open button. It uses a left-right arrows icon and opens an in-window glass panel anchored to the button; the first row is "Open new file", followed by a separated recent-file list for quick switching. The file switcher panel is less transparent than the note shell so the recent list remains readable over Markdown content.
- Clipboard monitoring is on by default for new users, can be disabled from the compact more menu or Settings, and immediately captures the current clipboard when enabled.
- Clipboard monitoring timer starts/stops with the setting and runs in the common run loop so UI interaction is less likely to pause polling.
- Clipboard library v2 supports local search, per-item delete, copy/paste actions, and Copy/Paste menus on detected values.
- Extracted clipboard values are shown under the source clipboard record as contextual chips. Do not reintroduce a top-level type grouping unless the user explicitly asks.
- Do not extract arbitrary numeric values. `Number` is now reserved for labeled codes/identifiers, such as 验证码, 取件码, 订单号, 快递单号, invoice, tracking, ticket, or similar labels. Plain years, dates, counts, prices, decimals, or standalone numbers should not create chips or top-island suggestions.
- Phone extraction is restricted to 10-15 digits and excludes simple date-like formats such as `2026-06-07`.
- The top island normally shows the current note title. `NoteStore.displayTitle` uses the first Markdown heading when present, otherwise the actual saved filename.
- In title mode, the title text is centered inside the island. The right-side clipboard icon is the only title-mode hit target that opens the clipboard library; clicking the rest of the capsule should not open the library.
- The clipboard library should not use SwiftUI/macOS `.popover`; it now uses `clipboardInlineOverlay`, an in-window glass panel centered under the top island. This avoids system popover misplacement and uses a faster 0.16s snappy transition.
- The compact settings/more menu should also avoid SwiftUI/macOS `.popover`. It uses an in-window glass overlay anchored to the bottom-right settings button, then clamps its panel position to the note bounds so it stays usable near screen edges.
- The island's glass shell, border, highlights, icon button background, and shadows follow `settings.noteOpacity` through `islandOpacity = max(0.05, settings.noteOpacity)`. Do not apply global opacity to the island content: the title text and icons must remain readable and should not fade with note transparency.
- When the latest clipboard entry has extracted values, the top island temporarily switches from title mode to detection mode. Its popover supports Copy/Paste, plus Open URL, Send Email, Call, or Open in Maps where appropriate.
- Detection-mode hit zones are separated: the left grip area should only drag and must not open popovers, the middle detection content area opens extraction actions, and the right clipboard icon opens the clipboard library. Keep the detection island narrower than the note's rounded top edge; do not let it span into the window corner radius.
- The left grip area must use `islandDragGrip`, which overlays a transparent `WindowDragView` on the three-line visual grip. Do not leave the three bars as a visual-only view, or three-finger dragging on the bars will stop working.
- Detection mode automatically returns to title mode after 60 seconds using `hiddenSuggestionID` and a cancellable `Task`. Avoid leaving the island permanently stuck on a stale clipboard item.
- The drag affordance is integrated into the island itself. Avoid returning to separate external bars plus a separate ball.
- URL extraction excludes Chinese punctuation so values like `https://example.com，地址` are captured as `https://example.com`.
- Clipboard paste copies the selected text, hides QuietNote, then sends Cmd+V to the system. This may depend on macOS input-event permissions in stricter environments.
- The compact more menu now includes clipboard monitoring, stored item count, retention limit, and clear-library action.
- Settings now includes a Chinese/English segmented language control. `AppSettings.language` defaults to Chinese, and `AppText` provides app chrome strings for Settings, More, Clipboard Library, and extraction action menus.
- Global shortcuts are split: `showQuietNote` shows the note, `hideQuietNote` hides it, and `toggleClipboardLibrary` opens/toggles the clipboard library. `toggleQuietNote` remains only as an old-name migration source for the show shortcut and should not be shown as the primary setting.
- If the app process is running but the window is not visible, `osascript -e 'tell application "QuietNote" to activate'` can bring the panel back.
- `QuietNoteApp.swift` now handles macOS reopen events so opening an already-running `QuietNote.app` calls `panelController.show()`.
- The app now runs as a regular macOS app (`LSUIElement=false`, activation policy `.regular`) so it appears in the Dock/任务栏.
- `NotePanelController.swift` sets `panel.hidesOnDeactivate = false`; verified by switching to Finder while the note remained visible above other windows.

## Notes For Next Agent

Keep the app small and quiet. Do not turn it into a note-management dashboard unless the user asks.
