# Markdown Compatibility

QuietNote saves note content as plain Markdown text. The table below describes the current live styling and editing behavior inside the note editor, not a full CommonMark/GitHub-Flavored Markdown renderer.

When Markdown syntax is visually hidden, it is not removed from the file. Moving the cursor into or close to a styled element temporarily reveals that element's source syntax, so links, emphasis markers, inline code backticks, headings, and code block fences can still be edited in place.

| Markdown syntax | Example | Current support | Notes |
|---|---|---:|---|
| Headings | `# Title` through `###### Title` | Supported | Requires a space after `#`. Heading markers are visually hidden until the cursor enters the heading. H1-H3 use larger text and a faint separator line; H4-H6 use bold body-sized text. |
| Bold | `**bold**`, `__bold__` | Supported | Simple single-line bold styling. Markdown marker characters are visually hidden while the saved text remains plain Markdown. Deeply nested emphasis is not fully parsed. |
| Italic | `*italic*`, `_italic_` | Supported | Simple single-line italic styling. Markdown marker characters are visually hidden. |
| Bold italic | `***text***`, `___text___` | Supported | Styled as bold text with italic slant. Markdown marker characters are visually hidden. |
| Strikethrough | `~~done~~` | Supported | Styled with a single strikethrough. Markdown marker characters are visually hidden. |
| Inline code | `` `code` `` | Supported | Single-line inline code spans are styled and backticks are visually hidden. Multiple-backtick edge cases are not fully parsed. |
| Links | `[Apple](https://apple.com)`, `[Apple](https://apple.com "title")`, `[Spec](https://example.com/a_(b))` | Supported | The link label is styled while surrounding Markdown syntax and destination text are visually hidden. The editor does not currently open links on click. URLs containing unmatched `)` may still be imperfect. |
| Reference links | `[text][id]`, `[id]: https://example.com` | Partial | References and definitions are styled, but references are not resolved or opened. |
| Raw URLs | `https://example.com` | Supported | `http://` and `https://` URLs are styled. |
| Autolinks | `<https://example.com>`, `<name@example.com>` | Supported | Angle-bracket URL and email autolinks are styled. |
| Email addresses | `name@example.com` | Supported | Plain email addresses are styled as link-like text. |
| Blockquotes | `> quote`, `>> nested` | Supported | Nested quote levels receive deeper indentation, but no full quote-bar rendering yet. |
| GitHub alerts | `> [!NOTE]` | Partial | Alert header lines are colored for NOTE/TIP/IMPORTANT/WARNING/CAUTION. Continuation lines remain regular quote styling. |
| Unordered lists | `- item`, `* item`, `+ item` | Partial | List markers are styled and indentation is preserved for nested lists. Plain list auto-continuation is not currently implemented. |
| Ordered lists | `1. item` | Partial | Number markers are styled and indentation is preserved for nested lists. Auto-numbering is not currently implemented. |
| Task lists | `- [ ] task`, `- [x] done` | Supported | `-` and `*` task markers are styled as clickable checkboxes. Pressing Return on a non-empty task continues with a new checkbox; pressing Return on an empty task exits the task list. |
| Fenced code blocks | <code>```swift</code>, `~~~` | Partial | Backtick and tilde fences are invisible but keep their layout space until the cursor enters the code block, so collapsed and active blocks keep matching spacing. The block is drawn as a rounded code panel with a language title and Copy button. Inline Markdown inside a fenced code block is kept as code text instead of being restyled as links or emphasis. Language-specific syntax highlighting is not implemented. |
| Horizontal rules | `---`, `***` | Supported | Only exact `---` and `***` lines are styled as rules. |
| Tables | `A \| B \| C` | Partial | Lines containing at least two `\|` characters are styled in a monospaced table-like style. Columns, alignment, and table structure are not fully parsed. |
| Images | `![alt](image.png)` | Partial | Image syntax is styled as an image reference. Inline image preview is not currently implemented. |
| Wiki links | `[[Page]]` | Partial | Wiki-style links are styled, but they do not resolve to files/pages. |
| Highlight | `==highlight==` | Supported | Styled with a subtle yellow background. |
| Emoji shortcode | `:smile:` | Partial | Styled as a shortcode token, but not converted to an emoji. |
| HTML | `<span>text</span>` | Not styled | Inline HTML is preserved as text but not rendered. |
| Footnotes | `[^1]` | Not styled | Footnote references and definitions are preserved as text only. |
| Math | `$x^2$`, `$$...$$` | Not styled | LaTeX math rendering is not currently implemented. |
| Front matter | `---` YAML block | Not styled as metadata | `---` is treated as a horizontal rule, not YAML front matter. |
| Mermaid / diagrams | <code>```mermaid</code> | Not rendered | Mermaid blocks remain text/code-style content. Diagram rendering is not currently implemented. |

## Practical Summary

QuietNote currently works best for everyday notes: headings, emphasis, links, quotes, lists, task checkboxes, simple code blocks, lightweight table-like text, image references, highlights, and wiki/reference-link style notes. More advanced publishing features, such as inline image preview, footnotes, math, HTML rendering, resolved reference links, and diagrams, are preserved as Markdown text but are not fully rendered inside the editor yet.
