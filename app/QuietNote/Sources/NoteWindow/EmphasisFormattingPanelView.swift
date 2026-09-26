import SwiftUI

struct EmphasisFormattingPanelView: View {
    @Bindable var settings: AppSettings
    let copy: AppText
    let applyStyles: (MarkdownEmphasisStyle) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 78), spacing: 7)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(copy.emphasis, systemImage: "textformat")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    applyStyles(settings.oneTapEmphasisStyles)
                } label: {
                    Label(copy.oneTapEmphasis, systemImage: "wand.and.stars")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(copy.oneTapEmphasis)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                ForEach(MarkdownEmphasisStyle.allControls, id: \.rawValue) { style in
                    Button {
                        applyStyles(style)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: symbol(for: style))
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 13)

                            Text(copy.emphasisStyleName(style))
                                .font(.system(size: 11.5, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .foregroundStyle(Color.primary.opacity(0.86))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(copy.emphasisStyleName(style))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(copy.oneTapEmphasisStyle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                EmphasisStylePicker(
                    selection: $settings.oneTapEmphasisStyles,
                    copy: copy,
                    accentColor: settings.accentColor,
                    compact: true
                )
            }
        }
        .padding(13)
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
