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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.detections) { detection in
                                DetectionChip(detection: detection, settings: settings, store: store)
                                    .fixedSize()
                            }
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
                Text(detection.kind.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(detection.value)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.white.opacity(0.32), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }
}
