import SwiftUI

struct EmphasisStylePicker: View {
    @Binding var selection: MarkdownEmphasisStyle
    let copy: AppText
    let accentColor: Color
    var compact = false

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: compact ? 72 : 92),
                spacing: compact ? 6 : 8
            )
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: compact ? 6 : 8) {
            ForEach(MarkdownEmphasisStyle.allControls, id: \.rawValue) { style in
                Button {
                    toggle(style)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: symbol(for: style))
                            .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
                            .frame(width: 13)

                        Text(copy.emphasisStyleName(style))
                            .font(.system(size: compact ? 11.2 : 12.3, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(selection.contains(style) ? Color.primary.opacity(0.90) : Color.secondary)
                    .padding(.horizontal, compact ? 7 : 9)
                    .padding(.vertical, compact ? 5 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection.contains(style) ? accentColor.opacity(0.16) : Color.white.opacity(0.08))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selection.contains(style) ? accentColor.opacity(0.34) : Color.white.opacity(0.20), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
                .help(copy.emphasisStyleName(style))
            }
        }
    }

    private func toggle(_ style: MarkdownEmphasisStyle) {
        var next = selection
        if next.contains(style) {
            next.remove(style)
        } else {
            next.insert(style)
        }
        selection = AppSettings.normalizedOneTapEmphasisStyles(next.rawValue)
    }

    private func symbol(for style: MarkdownEmphasisStyle) -> String {
        switch style {
        case .bold:
            "bold"
        case .italic:
            "italic"
        case .strikethrough:
            "strikethrough"
        case .highlight:
            "highlighter"
        case .smallHeading:
            "textformat.size"
        default:
            "textformat"
        }
    }
}
