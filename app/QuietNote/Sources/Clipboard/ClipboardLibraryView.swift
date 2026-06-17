import AppKit
import SwiftUI

struct ClipboardLibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    var settings: AppSettings
    var store: ClipboardStore
    @State private var query = ""
    @State private var paging = ClipboardListPagingState()
    @State private var selectedDetection: ClipboardDetection?

    private var palette: ClipboardPalette {
        ClipboardPalette(colorScheme: colorScheme, themeColor: settings.themeColor)
    }

    var body: some View {
        let copy = settings.localizedText
        let visibleSnapshot = store.visibleItems(matching: query, limit: paging.visibleItemLimit)
        let displayedItems = visibleSnapshot.items
        let lastDisplayedItemID = displayedItems.last?.id
        let palette = palette
        let themeColor = palette.themeColor
        let accentColor = palette.accentColor

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
        .foregroundStyle(palette.inkColor)
        .background {
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.02 : 0.04),
                    accentColor.opacity(0.012),
                    Color.black.opacity(colorScheme == .dark ? 0.035 : 0.012)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onChange(of: query) { _, _ in
            paging.resetForQueryChange()
            selectedDetection = nil
        }
        .onChange(of: store.items.count) { _, _ in
            paging.resetForItemCountChange()
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
                    .foregroundStyle(palette.inkColor)
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
                        .foregroundStyle(palette.inkColor)
                    Text("\(visibleSnapshot.totalCount)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.softInkColor)
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
                    .foregroundStyle(palette.softInkColor)

                TextField(copy.searchClipboard, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.inkColor)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(palette.searchBorderColor, lineWidth: 0.75)
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
                .foregroundStyle(palette.softInkColor)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.07), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))

            Text(copy.noClipboardItems)
                .font(.system(size: 13, weight: .semibold))

            Text(copy.noClipboardDescription)
                .font(.system(size: 11))
                .foregroundStyle(palette.softInkColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(22)
    }

    private func loadNextBatch(totalCount: Int) {
        guard let batch = paging.scheduleNextBatch(totalCount: totalCount) else { return }

        Task { @MainActor in
            await Task.yield()
            paging.finishScheduledBatch(batch)
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
                        .foregroundStyle(palette.inkColor)
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
                solidPopupCardBackground(cornerRadius: 14, accentColor: accentColor)
            }
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

    private func solidPopupCardBackground(cornerRadius: CGFloat, accentColor: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .fill(.regularMaterial)
            .opacity(0.10)
            .overlay {
                shape
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.92 : 0.95))
            }
            .overlay {
                shape
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.045 : 0.018))
                    .blendMode(.plusLighter)
            }
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20),
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.07),
                                Color.black.opacity(colorScheme == .dark ? 0.16 : 0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(colorScheme == .dark ? .normal : .plusLighter)
            }
    }
}
