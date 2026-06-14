import AppKit
import SwiftUI

struct UpdateCheckButtonView: View {
    @ObservedObject var settings: AppSettings
    var compact = false

    @State private var automaticallyChecks = true
    @State private var canCheck = true

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Toggle(copy.automaticallyCheckForUpdates, isOn: Binding(
                get: { automaticallyChecks },
                set: { newValue in
                    automaticallyChecks = newValue
                    appDelegate?.setAutomaticallyChecksForUpdates(newValue)
                    refresh()
                }
            ))
            .font(.system(size: compact ? 12 : 13, weight: .medium))

            Button {
                NSApp.sendAction(#selector(AppDelegate.checkForUpdatesFromMenu), to: nil, from: nil)
                refresh()
            } label: {
                Label(copy.checkForUpdates, systemImage: "arrow.down.circle")
                    .font(.system(size: compact ? 12.5 : 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canCheck)
            .help(copy.checkForUpdates)

            Text(copy.checkForUpdatesHint)
                .font(.system(size: compact ? 10.8 : 11.5, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            refresh()
        }
    }

    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    private func refresh() {
        guard let appDelegate else { return }
        automaticallyChecks = appDelegate.automaticallyChecksForUpdates
        canCheck = appDelegate.canCheckForUpdates
    }
}
