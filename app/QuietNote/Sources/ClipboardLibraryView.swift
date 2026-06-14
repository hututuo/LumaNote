import AppKit
import SwiftUI

struct ClipboardLibraryView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore
    @State private var query = ""

    private let inkColor = Color.black.opacity(0.86)
    private let softInkColor = Color.black.opacity(0.55)

    private var filteredItems: [ClipboardItem] {
        return store.items.filter { item in
            query.isEmpty
                || item.text.localizedCaseInsensitiveContains(query)
                || item.detections.contains { $0.value.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        let copy = AppText(language: settings.language)
        let visibleItems = filteredItems
        let visibleRows = Array(visibleItems.enumerated())

        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(inkColor)
                    .frame(width: 24, height: 24)
                    .background(
                        LinearGradient(
                            colors: [settings.accentColor.opacity(0.26), .white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.34), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(copy.clipboard)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(inkColor)
                    Text("\(visibleItems.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(softInkColor)
                }

                Spacer()

                Button {
                    store.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                .help(copy.clearClipboard)
                .disabled(store.items.isEmpty)
            }
            .padding(.horizontal, 13)
            .padding(.top, 13)
            .padding(.bottom, 9)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(softInkColor)

                TextField(copy.searchClipboard, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(inkColor)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 0.75)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            if visibleItems.isEmpty {
                emptyState(copy: copy)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleRows, id: \.element.id) { index, item in
                            ClipboardRow(item: item, settings: settings, store: store)

                            if index < visibleItems.count - 1 {
                                Divider()
                                    .overlay(.white.opacity(0.12))
                                    .padding(.leading, 3)
                                    .padding(.trailing, 2)
                            }
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.bottom, 12)
                }
            }
        }
        .foregroundStyle(inkColor)
        .background {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.28),
                    settings.accentColor.opacity(0.06),
                    Color.black.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
        }
        .background(Color.white.opacity(0.08))
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(0.60)
        }
    }

    private func emptyState(copy: AppText) -> some View {
        VStack(spacing: 9) {
            Image(systemName: "clipboard")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(softInkColor)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.07), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))

            Text(copy.noClipboardItems)
                .font(.system(size: 13, weight: .semibold))

            Text(copy.noClipboardDescription)
                .font(.system(size: 11))
                .foregroundStyle(softInkColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(22)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore
    private let inkColor = Color.black.opacity(0.86)
    private let softInkColor = Color.black.opacity(0.55)

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.preview)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(inkColor)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                Text(item.createdAt, style: .time)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(softInkColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.07), in: Capsule())
            }

            if !item.detections.isEmpty {
                DetectionShelf(detections: item.detections, settings: settings, store: store)
            }

            HStack(spacing: 7) {
                Spacer(minLength: 0)

                rowActionButton(symbol: "doc.on.doc", help: copy.copyClipboardItem) {
                    store.copy(item.text)
                }

                rowActionButton(symbol: "trash", help: copy.deleteClipboardItem, role: .destructive) {
                    store.delete(item)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 10)
    }

    private func rowActionButton(
        symbol: String,
        help: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .frame(width: 23, height: 22)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .help(help)
    }
}

private struct DetectionShelf: View {
    let detections: [ClipboardDetection]
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore
    private let inkColor = Color.black.opacity(0.82)

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .black))

                Text(copy.extracted)
                    .font(.system(size: 9.5, weight: .bold))
                    .textCase(.uppercase)

                Spacer(minLength: 0)
            }
            .foregroundStyle(inkColor)

            WrappingChipLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(detections) { detection in
                    DetectionChip(detection: detection, settings: settings, store: store)
                }
            }
        }
        .padding(8)
        .background(
            LinearGradient(
                colors: [settings.accentColor.opacity(0.08), .white.opacity(0.05), settings.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.26), settings.accentColor.opacity(0.14), .black.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: settings.accentColor.opacity(0.05), radius: 6, y: 1)
    }
}

private struct DetectionChip: View {
    let detection: ClipboardDetection
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore
    @State private var showActions = false

    private var tint: Color {
        settings.accentColor
    }

    private let inkColor = Color.black.opacity(0.86)
    private let softInkColor = Color.black.opacity(0.58)

    var body: some View {
        let copy = AppText(language: settings.language)

        Button {
            showActions.toggle()
        } label: {
            bubbleLabel
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showActions, arrowEdge: .top) {
            actionsPopover(copy: copy)
        }
        .help(copy.showExtractedActions)
    }

    private var bubbleLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: detection.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.78))
                .frame(width: 18, height: 18)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.76), .white.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 0.8))

            Text(detection.value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(inkColor)
                .lineLimit(1)
                .truncationMode(.middle)

            Image(systemName: "chevron.down")
                .font(.system(size: 7.5, weight: .black))
                .foregroundStyle(softInkColor)
        }
        .frame(maxWidth: 204, alignment: .leading)
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .padding(.vertical, 4.5)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.36), .white.opacity(0.2), tint.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .background(.white.opacity(0.18), in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.82), .white.opacity(0.6), .black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        )
        .shadow(color: tint.opacity(0.2), radius: 8, y: 2)
        .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
    }

    private func actionsPopover(copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detection.value)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 220, alignment: .leading)

            Divider()

            Button {
                showActions = false
                store.copy(detection.value)
            } label: {
                Label(copy.copyExtracted, systemImage: "doc.on.doc")
            }
            .help(copy.copyExtracted)

            if let openTitle = detection.openTitle {
                Button {
                    showActions = false
                    store.open(detection)
                } label: {
                    Label(openTitle, systemImage: detection.openSymbol)
                }
                .help(openTitle)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(inkColor)
        .buttonStyle(.borderless)
        .padding(12)
        .background(.regularMaterial)
    }
}

private struct WrappingChipLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 260
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.height
        } + verticalSpacing * CGFloat(max(rows.count - 1, 0))

        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }

            y += row.height + verticalSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        let availableWidth = max(1, maxWidth)
        var rows: [Row] = []
        var currentItems: [RowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let proposedChipWidth = min(availableWidth, 232)
            var size = subviews[index].sizeThatFits(ProposedViewSize(width: proposedChipWidth, height: nil))
            size.width = min(size.width, availableWidth)

            let nextWidth = currentItems.isEmpty
                ? size.width
                : currentWidth + horizontalSpacing + size.width

            if !currentItems.isEmpty, nextWidth > availableWidth {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = [RowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(RowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }

        return rows
    }

    private struct Row {
        let items: [RowItem]
        let height: CGFloat
    }

    private struct RowItem {
        let index: Int
        let size: CGSize
    }
}
