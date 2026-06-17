import SwiftUI

struct ClipboardExtractionActionsPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    var settings: AppSettings

    let item: ClipboardItem
    let copy: AppText
    let maxHeight: CGFloat
    let copyDetection: (ClipboardDetection) -> Void
    let openDetection: (ClipboardDetection) -> Void

    private var controlInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.84)
    }

    private var controlStrongInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.94 : 0.86)
    }

    private var controlSoftInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.76 : 0.76)
    }

    var body: some View {
        let summary = copy.clipboardKindSummary(for: item.detections, prefix: copy.detectedClipboardPrefix)
        let panelBlue = Color(red: 0.36, green: 0.66, blue: 1.00)
        let listMaxHeight = max(88, maxHeight - 54)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(settings.accentColor)

                Text(summary)
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(controlStrongInkColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            ScrollView(.vertical, showsIndicators: item.detections.count > 2) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(item.detections.enumerated()), id: \.element.id) { index, detection in
                        detectionRow(
                            detection,
                            isLast: index == item.detections.count - 1
                        )
                    }
                }
            }
            .frame(maxHeight: listMaxHeight)
        }
        .padding(12)
        .background {
            ReadablePopupPanelBackground(
                accentColor: settings.accentColor,
                materialOpacity: 0.60,
                whiteOpacity: 0.10,
                accentOpacity: 0.028
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(panelBlue.opacity(0.34), lineWidth: 1.1)
        }
        .shadow(color: panelBlue.opacity(0.10), radius: 8, y: 1)
    }

    private func detectionRow(_ detection: ClipboardDetection, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: detection.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 14, height: 16)
                        .padding(.top, 1)

                    Text(ClipboardExtractionTextWrapping.wrappingValue(detection.value))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(controlInkColor)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(settings.accentColor.opacity(0.035))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    settings.accentColor.opacity(0.36),
                                    .white.opacity(0.20),
                                    settings.accentColor.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                }

                HStack(spacing: 8) {
                    Button {
                        copyDetection(detection)
                    } label: {
                        Label(copy.copy, systemImage: "doc.on.doc")
                    }
                    .help(copy.copyExtracted)

                    if let openTitle = detection.openTitle {
                        Button {
                            openDetection(detection)
                        } label: {
                            Label(openTitle, systemImage: detection.openSymbol)
                        }
                        .help(openTitle)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(controlSoftInkColor)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 8)

            if !isLast {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 1)
            }
        }
    }

}
