import AppKit
import SwiftUI

struct ClipboardLibraryView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore
    @State private var query = ""

    private var filteredItems: [ClipboardItem] {
        return store.items.filter { item in
            query.isEmpty
                || item.text.localizedCaseInsensitiveContains(query)
                || item.detections.contains { $0.value.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(spacing: 0) {
            HStack {
                Label(copy.clipboard, systemImage: "list.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(copy.clear) {
                    store.clear()
                }
                .font(.system(size: 12))
                .disabled(store.items.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            TextField(copy.searchClipboard, text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            if filteredItems.isEmpty {
                ContentUnavailableView(
                    copy.noClipboardItems,
                    systemImage: "clipboard",
                    description: Text(copy.noClipboardDescription)
                )
                .padding(20)
            } else {
                List(filteredItems) { item in
                    ClipboardRow(item: item, settings: settings, store: store)
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                }
                .listStyle(.plain)
            }
        }
        .background(.regularMaterial)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: 7) {
            Text(item.preview)
                .font(.system(size: 12.5))
                .lineLimit(3)

            if !item.detections.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.extracted)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    WrappingChipLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(item.detections) { detection in
                            DetectionChip(detection: detection, settings: settings, store: store)
                        }
                    }
                }
            }

            HStack {
                Text(item.createdAt, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.copy(item.text)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy")
                Button {
                    store.paste(item.text)
                } label: {
                    Image(systemName: "arrow.turn.down.left")
                }
                .buttonStyle(.plain)
                .help("Paste")
                Button(role: .destructive) {
                    store.delete(item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
    }
}

private struct DetectionChip: View {
    let detection: ClipboardDetection
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ClipboardStore

    var body: some View {
        let copy = AppText(language: settings.language)

        Menu {
            Button {
                store.copy(detection.value)
            } label: {
                Label(copy.copyExtracted, systemImage: "doc.on.doc")
            }
            Button {
                store.paste(detection.value)
            } label: {
                Label(copy.pasteExtracted, systemImage: "arrow.turn.down.left")
            }
            if let openTitle = detection.openTitle {
                Button {
                    store.open(detection)
                } label: {
                    Label(openTitle, systemImage: detection.openSymbol)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: detection.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 12)
                Text(detection.value)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: 210, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .background(
                Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        }
        .menuStyle(.borderlessButton)
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
