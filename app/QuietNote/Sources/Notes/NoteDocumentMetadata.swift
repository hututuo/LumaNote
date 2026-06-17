import Foundation

enum NoteDocumentMetadata {
    static func displayTitle(for markdown: String, currentFileURL: URL) -> String {
        var lineStart = markdown.startIndex
        let end = markdown.endIndex

        while lineStart < end {
            let lineEnd = markdown[lineStart...].firstIndex(of: "\n") ?? end
            var cursor = lineStart

            while cursor < lineEnd, markdown[cursor] == " " || markdown[cursor] == "\t" {
                cursor = markdown.index(after: cursor)
            }

            if cursor < lineEnd, markdown[cursor] == "#" {
                while cursor < lineEnd, markdown[cursor] == "#" || markdown[cursor] == " " || markdown[cursor] == "\t" {
                    cursor = markdown.index(after: cursor)
                }

                var titleEnd = lineEnd
                while cursor < titleEnd {
                    let previous = markdown.index(before: titleEnd)
                    guard markdown[previous] == " " || markdown[previous] == "\t" || markdown[previous] == "#" else { break }
                    titleEnd = previous
                }

                if cursor < titleEnd {
                    return String(markdown[cursor..<titleEnd])
                }
            }

            guard lineEnd < end else { break }
            lineStart = markdown.index(after: lineEnd)
        }

        return currentFileURL.lastPathComponent
    }

    static let exampleMarkdown = """
    # LumaNote 示例便签

    这是你的第一张 Markdown 便签。直接编辑即可，内容会自动保存。

    ## 常用语法

    - **加粗**、*斜体*、`行内代码`
    - [链接](https://github.com/hututuo/LumaNote)
    - `- [ ]` 会变成可以点击的待办框

    > 引用适合记录灵感或摘录。

    ## 今日待办

    - [ ] 试着输入一条新待办
    - [ ] 用底部切换按钮新建或打开 Markdown 文件
    - [x] Markdown 会实时渲染

    ```swift
    let note = "代码块也可以放在便签里"
    ```
    """
}
