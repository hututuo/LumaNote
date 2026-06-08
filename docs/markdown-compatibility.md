# Markdown Compatibility

QuietNote saves note content as plain Markdown text. The table below describes the current live styling and editing behavior inside the note editor, not a full CommonMark/GitHub-Flavored Markdown renderer.

| Markdown syntax | Example | Current support | Notes |
|---|---|---:|---|
| Headings | `# Title` through `###### Title` | Supported | Requires a space after `#`. H1-H3 use larger text; H4-H6 use bold body-sized text. |
| Bold | `**bold**`, `__bold__` | Supported | Simple single-line bold styling. Nested emphasis is not fully parsed. |
| Italic | `*italic*` | Partial | Single-asterisk italic is styled. Underscore italic, such as `_italic_`, is not currently styled. |
| Strikethrough | `~~done~~` | Supported | Styled with a single strikethrough. |
| Inline code | `` `code` `` | Supported | Single-line inline code spans are styled. Multiple-backtick edge cases are not fully parsed. |
| Links | `[Apple](https://apple.com)` | Supported | Styled as link-colored underlined text. The editor does not currently open links on click. |
| Raw URLs | `https://example.com` | Supported | `http://` and `https://` URLs are styled. Angle-bracket autolinks are not specially parsed. |
| Blockquotes | `> quote` | Supported | Single-line quote styling with indentation. Nested quote levels are not visually differentiated. |
| Unordered lists | `- item`, `* item`, `+ item` | Partial | List markers are styled and body text is indented. Plain list auto-continuation is not currently implemented. |
| Ordered lists | `1. item` | Partial | Number markers are styled and body text is indented. Auto-numbering is not currently implemented. |
| Task lists | `- [ ] task`, `- [x] done` | Supported | `-` and `*` task markers are styled as clickable checkboxes. Pressing Return on a non-empty task continues with a new checkbox; pressing Return on an empty task exits the task list. |
| Fenced code blocks | <code>```swift</code> | Partial | Triple-backtick fences and their contents are styled in monospace. Language-specific syntax highlighting is not implemented. Tilde fences are not styled. |
| Horizontal rules | `---`, `***` | Supported | Only exact `---` and `***` lines are styled as rules. |
| Tables | `A \| B` | Partial | Lines containing `\|` are styled in a monospaced table-like style. Columns, alignment, and table structure are not fully parsed. |
| Images | `![alt](image.png)` | Not styled | Image syntax stays as plain text. Inline image preview is not currently implemented. |
| Reference links | `[text][id]` | Not styled | Reference-style link definitions and references are not currently parsed. |
| HTML | `<span>text</span>` | Not styled | Inline HTML is preserved as text but not rendered. |
| Footnotes | `[^1]` | Not styled | Footnote references and definitions are preserved as text only. |
| Math | `$x^2$`, `$$...$$` | Not styled | LaTeX math rendering is not currently implemented. |
| Front matter | `---` YAML block | Not styled as metadata | `---` is treated as a horizontal rule, not YAML front matter. |
| Mermaid / diagrams | <code>```mermaid</code> | Not rendered | Mermaid blocks remain text/code-style content. Diagram rendering is not currently implemented. |

## Practical Summary

QuietNote currently works best for everyday notes: headings, emphasis, links, quotes, lists, task checkboxes, simple code blocks, and lightweight table-like text. More advanced publishing features, such as images, footnotes, math, HTML rendering, reference links, and diagrams, are preserved as Markdown text but are not visually rendered inside the editor yet.
