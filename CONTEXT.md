# Glass Markdown Note Context

## Current Direction

Build LumaNote, a native macOS SwiftUI sticky note app focused on one compact frosted-glass note that can stay at the edge of the screen.

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
- Clipboard detection suggestions for URL, email, phone, address-like text, labeled codes such as verification codes or order/tracking numbers, and labeled free text after a colon.
- Polished SwiftUI/macOS visual style with frosted glass and subtle slide/fade behavior.

## Current Build Entry

- 2026-06-11 local packaging review: DMG background copy now says `系统设置 → 隐私与安全 → 滑到最底下找到 LumaNote`, and `prepare-release.sh` keeps the GitHub Release download prefix ending in `/` so Sparkle appcast URLs stay correct. `LUMANOTE_ALLOW_DIRTY=1 app/QuietNote/scripts/prepare-release.sh` completed successfully and produced a reviewable v0.1.1 DMG/zip/checksum set under `app/QuietNote/build/releases/v0.1.1/`; mounted DMG verification found both `.DS_Store` and `.background/dmg-background.png`. No GitHub push/release was performed in this step.
- App source: `app/QuietNote/`
- Visual reference: `design/quiet-rail-note_reference_20260607-100100.png`
- Debug app bundle: `app/QuietNote/build/LumaNote.app`
- Build script: `app/QuietNote/scripts/build-app.sh` compiles, packages, ad-hoc signs with the explicit designated requirement `identifier "com.hututuo.lumanote"`, and verifies `build/LumaNote.app`.
- DMG script: `app/QuietNote/scripts/build-dmg.sh` packages the signed app with an `/Applications` symlink and custom glass installer background into `build/LumaNote-<version>-macos-arm64.dmg`.
- Release script: `app/QuietNote/scripts/prepare-release.sh` builds the app, verifies the stable signing requirement, creates the DMG, Sparkle update zip, compatibility zip, and `SHA256SUMS-v<version>.txt` under `app/QuietNote/build/releases/v<version>/`.
- Current release notes: `docs/releases/v0.1.1.md`.
- Current release audit: `docs/releases/v0.1.1-audit.md`.
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
- Markdown compatibility notes for GitHub are documented in `docs/markdown-compatibility.md`. The app saves original Markdown text, but the live editor is a lightweight visual styler rather than a full CommonMark/GFM renderer.
- Recent Markdown styling additions include underscore italic, bold italic, tilde fenced code blocks, nested quote/list indentation, GitHub Alert headers, email/autolink styling, reference/wiki link styling, image-reference styling, highlight syntax, and emoji shortcode token styling.
- The Markdown editor's enclosing `NSScrollView` uses macOS overlay scrollers with a custom 4pt mini vertical scroller, so the scrollbar stays very thin at the right edge without occupying a thick permanent gutter. Do not use AppKit's own scroller autohide here; the custom scroller must remain visible as a faint idle thumb. It draws only the floating thumb, not a separate track. It briefly becomes clearer and wider while scrolling or while the pointer is over it, then animates back to a visible thin low-opacity idle state after about 1 second or when the note loses focus. The editor view keeps more left padding than right padding so the scroller sits close to the note's right edge.
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
- The public product name is LumaNote. The Swift package/target still uses the legacy `QuietNote` name internally, while the built macOS bundle is `LumaNote.app` with the selected glass bubble icon.
- `build-app.sh` signs the local bundle with ad-hoc identity (`codesign --sign -`) and verifies it with `codesign --verify --deep --strict`. This is for local builds/install/update hygiene and is not Developer ID signing or notarization.
- The `test/ad-hoc-permission-update` branch signs with `--requirements '=designated => identifier "com.hututuo.lumanote"'`; the temporary Accessibility permission request UI was removed after update permission persistence was confirmed.
- The `test/ad-hoc-permission-update` branch embeds Sparkle 2.9.3 through SwiftPM and points `SUFeedURL` at `https://raw.githubusercontent.com/hututuo/LumaNote/test/ad-hoc-permission-update/appcast-test/appcast.xml`. Sparkle's EdDSA private key is stored in the local login Keychain under account `com.hututuo.lumanote`; only the public key is committed in `Info.plist`.
- When embedding Sparkle from SwiftPM in the manually assembled app bundle, `build-app.sh` must add `@executable_path/../Frameworks` to the app executable rpath before signing; otherwise the app crashes at launch with dyld "Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle".
- Sparkle permission-retention test update uses `CFBundleShortVersionString=0.1.1` and `CFBundleVersion=2` as the first downloadable build after the locally installed `0.1.0` / build `1` baseline.
- Sparkle permission-retention testing confirmed that Accessibility permission remains authorized after an ad-hoc signed Sparkle update when the bundle ID and designated requirement stay stable.
- The temporary `0.1.2` / build `3` test update package was reverted after testing. Keep Sparkle integration, automatic update checking, and the visible update button; do not keep one-off test update artifacts unless a new test feed is needed.
- Sparkle automatic checks are enabled by default with `SUEnableAutomaticChecks=true` and `SUScheduledCheckInterval=86400`; the in-app update section reads/writes Sparkle's own `automaticallyChecksForUpdates` property rather than duplicating the setting in `AppSettings`.
- Test appcast files live in `appcast-test/` on the `test/ad-hoc-permission-update` branch. The current update archive is a Sparkle-signed zip, not the public-facing DMG, because Sparkle can update from zip reliably while the DMG script is only for manual drag-install distribution.
- For v0.1.1, `appcast-test/appcast.xml` points its enclosure to the GitHub Release asset `https://github.com/hututuo/LumaNote/releases/download/v0.1.1/LumaNote-0.1.1-macos-arm64.zip`. Because Keychain access was unavailable in the release audit run, the release flow must upload the exact existing signed zip from `appcast-test/LumaNote-0.1.1-macos-arm64.zip` or regenerate the appcast with the Sparkle private key.
- `prepare-release.sh` supports both Sparkle Keychain mode (`--account com.hututuo.lumanote`) and non-interactive file mode through `SPARKLE_PRIVATE_KEY_FILE`. Private keys must stay outside the repo, preferably under a user-private path such as `~/.config/lumanote/sparkle-ed25519-private.key` with `0600` permissions.
- GitHub test downloads should use the DMG artifact, not the old zip. The DMG is a drag-to-Applications image and may still trigger macOS "unidentified developer" Gatekeeper flow because it is ad-hoc signed but not notarized.
- The DMG background is source-controlled at `app/QuietNote/support/dmg-background.png` and can be regenerated with `app/QuietNote/scripts/generate-dmg-background.swift`. Do not commit generated DMGs from `app/QuietNote/build/` unless the user explicitly asks for a release artifact.
- `NoteStore` tracks a current Markdown file URL and up to 8 recent file URLs. Opening a file loads it into the note, pushes it to the recent list, and switches live save to that file; Save As writes the current content to the chosen file, pushes it to the recent list, and then switches live save to the new path. The current path and recent paths are remembered locally for the next launch.
- The bottom-left file button is a switcher, not a direct open button. It uses a left-right arrows icon and opens an in-window glass panel anchored to the button; the first row is "Open new file", followed by a separated recent-file list for quick switching. The file switcher panel is taller than the compact settings menu, sized for up to 7 recent files when space allows, and is less transparent than the note shell so the recent list remains readable over Markdown content.
- Clipboard monitoring is on by default for new users, can be disabled from the compact more menu or Settings, and immediately captures the current clipboard when enabled.
- Clipboard monitoring timer starts/stops with the setting and runs in the common run loop so UI interaction is less likely to pause polling.
- Clipboard library v2 supports local search, per-item delete, copy/paste actions, and Copy/Paste popovers on detected values. Its list is custom `ScrollView + LazyVStack`, not a default macOS `List`; individual clipboard messages should not be boxed as cards. Keep the list lightweight with thin separators between messages and hidden/non-dominant scroll indicators.
- Extracted clipboard values are shown under the source clipboard record as contextual chips. Do not reintroduce a top-level type grouping unless the user explicitly asks.
- Clipboard detail extraction chips should wrap into multiple rows instead of using horizontal scrolling, because sideways trackpad scrolling is awkward in the small sticky-note panel. Extracted values live inside a subtle glass shelf, and each value is a stronger capsule bubble with icon + extracted value + subtle action chevron. Avoid wrapping the whole clipboard message itself in another bubble/card.
- Label/colon values such as `地址：...`, `电话：...`, `邮箱：...`, or `备注：...` are processed before generic detection. Known labels are typed when the value validates; unknown or invalid labeled values fall back to copyable Text chips instead of being dropped.
- Do not extract arbitrary numeric values. `Number` is now reserved for labeled codes/identifiers, such as 验证码, 取件码, 订单号, 快递单号, invoice, tracking, ticket, or similar labels. Plain years, dates, counts, prices, decimals, or standalone numbers should not create chips or top-island suggestions.
- Phone extraction is restricted to 10-15 digits and excludes simple date-like formats such as `2026-06-07`.
- Address extraction must not hand the whole clipboard body to Maps when only a labeled address segment exists. Prefer the value after the address label/colon, and use generic address matching only for standalone address-like snippets.
- The top island normally shows the current note title. `NoteStore.displayTitle` uses the first Markdown heading when present, otherwise the actual saved filename.
- In title mode, the title text is centered inside the island. The right-side clipboard icon is the only title-mode hit target that opens the clipboard library; clicking the rest of the capsule should not open the library.
- The clipboard library should not use SwiftUI/macOS `.popover`; it now uses `clipboardInlineOverlay`, an in-window glass panel centered under the top island. This avoids system popover misplacement and uses a faster 0.16s snappy transition. Keep a little breathing room below the top capsule; the panel currently starts at about 40 px from the note top.
- When the clipboard library is open, its transparent dismiss backdrop must leave the top drag strip hit-test transparent. The user should still be able to drag the note from the top capsule/grip while the clipboard list is visible.
- When focus leaves LumaNote/the note window while the clipboard library is open, close only the clipboard library overlay. The note window itself should remain visible because `hidesOnDeactivate=false` is intentional.
- The compact settings/more menu should also avoid SwiftUI/macOS `.popover`. It uses an in-window glass overlay anchored to the bottom-right settings button, then clamps its panel position to the note bounds so it stays usable near screen edges.
- The island's glass shell, border, highlights, icon button background, and shadows follow `settings.noteOpacity` through `islandOpacity = max(0.05, settings.noteOpacity)`. Do not apply global opacity to the island content: the title text and icons must remain readable and should not fade with note transparency.
- The island's title/detected value text and adjacent symbols should be stronger than the glass shell, not faded. Treat "20%/35% stronger" as increased visual weight from a full-strength baseline, not as 20%/35% opacity. Current island content uses a slightly whiter fixed foreground with a subtle shadow so it stays readable over glass.
- When the latest clipboard entry has extracted values, the top island temporarily switches from title mode to detection mode. Its popover supports Copy/Paste, plus Open URL, Send Email, Call, or Open in Maps where appropriate.
- Detection-mode hit zones are separated: the left grip area should only drag and must not open popovers, the middle detection content area opens extraction actions, and the right clipboard icon opens the clipboard library. Keep the detection island narrower than the note's rounded top edge; do not let it span into the window corner radius.
- The left grip area must use `islandDragGrip`, which overlays a transparent `WindowDragView` on the three-line visual grip. Do not leave the three bars as a visual-only view, or three-finger dragging on the bars will stop working.
- Detection mode automatically returns to title mode after 60 seconds using `hiddenSuggestionID` and a cancellable `Task`. Avoid leaving the island permanently stuck on a stale clipboard item.
- The drag affordance is integrated into the island itself. Avoid returning to separate external bars plus a separate ball.
- The top island is intentionally lowered by about 5 px inside the top bar so it has breathing room from the note's rounded top edge.
- URL extraction excludes Chinese punctuation so values like `https://example.com，地址` are captured as `https://example.com`.
- Clipboard paste copies the selected text, hides QuietNote, then sends Cmd+V to the system. This may depend on macOS input-event permissions in stricter environments.
- Clipboard paste UI should be labeled as pasting to the current app, because the action targets whichever app/input had focus before LumaNote.
- The compact more menu now includes clipboard monitoring, stored item count, retention limit, and clear-library action.
- Settings now includes a Chinese/English segmented language control. `AppSettings.language` defaults to Chinese, and `AppText` provides app chrome strings for Settings, More, Clipboard Library, and extraction action menus.
- Settings and the compact More menu include a Launch at Login toggle. It uses macOS `SMAppService.mainApp` rather than a custom LaunchAgent. If registration fails, the toggle reverts and shows the localized error message.
- Global shortcuts are split: `showQuietNote` shows the note, `hideQuietNote` hides it, and `toggleClipboardLibrary` opens/toggles the clipboard library. `toggleQuietNote` remains only as an old-name migration source for the show shortcut and should not be shown as the primary setting.
- If the app process is running but the window is not visible, `osascript -e 'tell application "QuietNote" to activate'` can bring the panel back.
- `QuietNoteApp.swift` now handles macOS reopen events so opening an already-running `QuietNote.app` calls `panelController.show()`.
- The app now runs as a regular macOS app (`LSUIElement=false`, activation policy `.regular`) so it appears in the Dock/任务栏.
- `NotePanelController.swift` sets `panel.hidesOnDeactivate = false`; verified by switching to Finder while the note remained visible above other windows.
- `NotePanelController.swift` lets the root `NSHostingView` autoresize with the panel content area. Keep this, otherwise narrowing the window can crop the old-width SwiftUI rounded shell and make the visible edges look square.
- The panel and SwiftUI rounded shell share `NoteWindowLayout.minimumSize` at 270 x 270. This keeps both width and height compact, with width at 75% of the 360 px normal width. The bottom rail compacts between 360 px and 270 px by shrinking spacing, horizontal padding, the opacity slider, and rail buttons; the clipboard, settings, and file-switcher overlays also reduce their minimum heights so a short note does not clip the rounded glass shell.
- The bottom rail is an overlay above the Markdown editor rather than a separate layout row. Its material follows the same glass-shell recipe as the top island: regular material, subtle white highlight, gradient border, and shadow. The editor reserves bottom space for this rail, so the text view and vertical scroller stop above the toolbar instead of extending underneath it. The rail also has its own transparent hit surface so pointer hover/clicks do not fall through to the Markdown text editor. The rail uses its own visibility curve: at the lowest note opacity it is about 50% stronger than the island's 5% minimum so the controls remain findable, while at 100% note opacity it is capped at half strength so the toolbar still feels transparent.

## Release Status

- `v0.1.1 published`: local build, ad-hoc signing, DMG packaging, checksum verification, mounted DMG inspection, temporary install/launch smoke, branch push, and GitHub Release upload passed on 2026-06-11. Release URL: `https://github.com/hututuo/LumaNote/releases/tag/v0.1.1`.
- Final local release artifacts are under `app/QuietNote/build/releases/v0.1.1/` and remain ignored build outputs. The same assets have been uploaded to GitHub Releases: `LumaNote-0.1.1-macos-arm64.dmg`, `LumaNote-0.1.1-macos-arm64.zip`, `LumaNote.app.zip`, and `SHA256SUMS-v0.1.1.txt`.

## Notes For Next Agent

Keep the app small and quiet. Do not turn it into a note-management dashboard unless the user asks.
