import AppKit
import SwiftUI

struct UpdateCheckButtonView: View {
    @ObservedObject var settings: AppSettings
    var compact = false

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Button {
                NSApp.sendAction(#selector(AppDelegate.checkForUpdatesFromMenu), to: nil, from: nil)
            } label: {
                Label(copy.checkForUpdates, systemImage: "arrow.down.circle")
                    .font(.system(size: compact ? 12.5 : 13, weight: .semibold))
            }
            .buttonStyle(.plain)

            Text(copy.checkForUpdatesHint)
                .font(.system(size: compact ? 10.8 : 11.5, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
