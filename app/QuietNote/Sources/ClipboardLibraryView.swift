import AppKit
import SwiftUI

struct ClipboardLibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore
    @State private var query = ""
    @State private var visibleItemLimit = initialVisibleItemLimit
    @State private var isBatchLoadScheduled = false
    @State private var selectedDetection: ClipboardDetection?

    private static let initialVisibleItemLimit = 28
    private static let visibleItemBatchSize = 16

    private var inkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.86)
    }

    private var softInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.62 : 0.55)
    }

    private var searchBorderColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.24 : 0.18)
    }

    var body: some View {
        let copy = AppText(language: settings.language)
        let visibleSnapshot = store.visibleItems(matching: query, limit: visibleItemLimit)
        let displayedItems = visibleSnapshot.items
        let lastDisplayedItemID = displayedItems.last?.id
        let themeColor = settings.themeColor
        let accentColor = themeColor.color

        ZStack {
            clipboardContent(
                copy: copy,
                visibleSnapshot: visibleSnapshot,
                displayedItems: displayedItems,
                lastDisplayedItemID: lastDisplayedItemID,
                themeColor: themeColor,
                accentColor: accentColor
            )

            if let selectedDetection {
                detectionActionOverlay(
                    detection: selectedDetection,
                    copy: copy,
                    accentColor: accentColor
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                .zIndex(2)
            }
        }
        .foregroundStyle(inkColor)
        .background {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.28),
                    accentColor.opacity(0.06),
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
        .onChange(of: query) { _, _ in
            visibleItemLimit = Self.initialVisibleItemLimit
            selectedDetection = nil
        }
        .onChange(of: store.items.count) { _, _ in
            if visibleItemLimit < Self.initialVisibleItemLimit {
                visibleItemLimit = Self.initialVisibleItemLimit
            }
        }
    }

    private func clipboardContent(
        copy: AppText,
        visibleSnapshot: ClipboardListSnapshot,
        displayedItems: [ClipboardItem],
        lastDisplayedItemID: ClipboardItem.ID?,
        themeColor: AppThemeColor,
        accentColor: Color
    ) -> some View {
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
                    Text("\(visibleSnapshot.totalCount)")
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
                    .stroke(searchBorderColor, lineWidth: 0.75)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            if visibleSnapshot.totalCount == 0 {
                emptyState(copy: copy)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedItems) { item in
                            ClipboardRow(
                                item: item,
                                copy: copy,
                                themeColor: themeColor,
                                copyItem: { store.copy(item.text) },
                                deleteItem: { store.delete(item) },
                                showDetectionActions: { detection in
                                    withAnimation(.snappy(duration: 0.12)) {
                                        selectedDetection = detection
                                    }
                                }
                            )
                            .equatable()

                            if item.id != lastDisplayedItemID {
                                Divider()
                                    .overlay(.white.opacity(0.12))
                                    .padding(.leading, 3)
                                    .padding(.trailing, 2)
                            }
                        }

                        if displayedItems.count < visibleSnapshot.totalCount {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    loadNextBatch(totalCount: visibleSnapshot.totalCount)
                                }
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.bottom, 12)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
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

    private func loadNextBatch(totalCount: Int) {
        guard visibleItemLimit < totalCount, !isBatchLoadScheduled else { return }
        isBatchLoadScheduled = true
        Task { @MainActor in
            await Task.yield()
            visibleItemLimit = min(totalCount, visibleItemLimit + Self.visibleItemBatchSize)
            isBatchLoadScheduled = false
        }
    }

    private func detectionActionOverlay(
        detection: ClipboardDetection,
        copy: AppText,
        accentColor: Color
    ) -> some View {
        ZStack {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.12)) {
                        selectedDetection = nil
                    }
                }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: detection.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(accentColor.opacity(0.20), in: Circle())

                    Text(detection.value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(inkColor)
                        .lineLimit(3)
                        .textSelection(.enabled)

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(.snappy(duration: 0.12)) {
                            selectedDetection = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.12), in: Circle())
                    .help(copy.close)
                }

                Divider()
                    .overlay(.white.opacity(0.18))

                HStack(spacing: 8) {
                    Button {
                        selectedDetection = nil
                        store.copy(detection.value)
                    } label: {
                        Label(copy.copyExtracted, systemImage: "doc.on.doc")
                    }
                    .help(copy.copyExtracted)

                    if let openTitle = detection.openTitle {
                        Button {
                            selectedDetection = nil
                            store.open(detection)
                        } label: {
                            Label(openTitle, systemImage: detection.openSymbol)
                        }
                        .help(openTitle)
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .medium))
            }
            .padding(12)
            .frame(width: 260, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(0.86)
            }
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.30), accentColor.opacity(0.08), Color.white.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.62), accentColor.opacity(0.30), .black.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
}

private struct ClipboardRow: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme
    let item: ClipboardItem
    let copy: AppText
    let themeColor: AppThemeColor
    let copyItem: () -> Void
    let deleteItem: () -> Void
    let showDetectionActions: (ClipboardDetection) -> Void

    nonisolated static func == (lhs: ClipboardRow, rhs: ClipboardRow) -> Bool {
        lhs.item == rhs.item
            && lhs.copy.language == rhs.copy.language
            && lhs.themeColor == rhs.themeColor
    }

    private var accentColor: Color {
        themeColor.color
    }

    private var inkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.86)
    }

    private var softInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.62 : 0.55)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.preview)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(inkColor)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(softInkColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.07), in: Capsule())
            }

            if !item.detections.isEmpty {
                DetectionShelf(
                    detections: item.detections,
                    copy: copy,
                    themeColor: themeColor,
                    showDetectionActions: showDetectionActions
                )
                .equatable()
            }

            HStack(spacing: 7) {
                Spacer(minLength: 0)

                rowActionButton(symbol: "doc.on.doc", help: copy.copyClipboardItem) {
                    copyItem()
                }

                rowActionButton(symbol: "trash", help: copy.deleteClipboardItem, role: .destructive) {
                    deleteItem()
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

private struct DetectionShelf: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme
    let detections: [ClipboardDetection]
    let copy: AppText
    let themeColor: AppThemeColor
    let showDetectionActions: (ClipboardDetection) -> Void

    nonisolated static func == (lhs: DetectionShelf, rhs: DetectionShelf) -> Bool {
        lhs.detections == rhs.detections
            && lhs.copy.language == rhs.copy.language
            && lhs.themeColor == rhs.themeColor
    }

    private var accentColor: Color {
        themeColor.color
    }

    private var inkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.88 : 0.82)
    }

    var body: some View {
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
                    DetectionChip(
                        detection: detection,
                        copy: copy,
                        themeColor: themeColor,
                        showActions: showDetectionActions
                    )
                    .equatable()
                }
            }
        }
        .padding(8)
        .background(
            LinearGradient(
                colors: [accentColor.opacity(0.08), .white.opacity(0.05), accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.26), accentColor.opacity(0.14), .black.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

private struct DetectionChip: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme
    let detection: ClipboardDetection
    let copy: AppText
    let themeColor: AppThemeColor
    let showActions: (ClipboardDetection) -> Void

    nonisolated static func == (lhs: DetectionChip, rhs: DetectionChip) -> Bool {
        lhs.detection == rhs.detection
            && lhs.copy.language == rhs.copy.language
            && lhs.themeColor == rhs.themeColor
    }

    private var tint: Color {
        themeColor.color
    }

    private var inkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.90 : 0.86)
    }

    private var softInkColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.66 : 0.58)
    }

    var body: some View {
        Button {
            showActions(detection)
        } label: {
            bubbleLabel
        }
        .buttonStyle(.plain)
        .help(copy.showExtractedActions)
    }

    private var bubbleLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: detection.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.88 : 0.78))
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
    }
}

private struct WrappingChipLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    fileprivate struct Cache {
        var maxWidth: CGFloat = -1
        var rows: [Row] = []
        var size: CGSize = .zero
        var subviewCount: Int = -1
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        if cache.subviewCount != subviews.count {
            cache.subviewCount = -1
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let maxWidth = proposal.width ?? 260
        return layout(for: subviews, maxWidth: maxWidth, cache: &cache).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let rows = layout(for: subviews, maxWidth: bounds.width, cache: &cache).rows
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

    private func layout(for subviews: Subviews, maxWidth: CGFloat, cache: inout Cache) -> LayoutResult {
        let availableWidth = max(1, maxWidth)
        if abs(cache.maxWidth - availableWidth) < 0.5, cache.subviewCount == subviews.count {
            return LayoutResult(rows: cache.rows, size: cache.size)
        }

        let rows = rows(for: subviews, maxWidth: availableWidth)
        let height = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.height
        } + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        let size = CGSize(width: availableWidth, height: height)
        cache.maxWidth = availableWidth
        cache.rows = rows
        cache.size = size
        cache.subviewCount = subviews.count
        return LayoutResult(rows: rows, size: size)
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

    fileprivate struct LayoutResult {
        let rows: [Row]
        let size: CGSize
    }

    fileprivate struct Row {
        let items: [RowItem]
        let height: CGFloat
    }

    fileprivate struct RowItem {
        let index: Int
        let size: CGSize
    }
}
