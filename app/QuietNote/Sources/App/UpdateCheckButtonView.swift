import AppKit
import SwiftUI

struct UpdateCheckingActions {
    let checkForUpdates: @MainActor () -> Void
    let canCheckForUpdates: @MainActor () -> Bool
    let automaticallyChecksForUpdates: @MainActor () -> Bool
    let setAutomaticallyChecksForUpdates: @MainActor (Bool) -> Void
}

struct UpdateCheckButtonView: View {
    var settings: AppSettings
    let updateActions: UpdateCheckingActions
    var compact = false

    @State private var automaticallyChecks = true
    @State private var canCheck = true

    var body: some View {
        let copy = settings.localizedText

        VStack(alignment: .leading, spacing: compact ? 7 : 9) {
            Toggle(copy.automaticallyCheckForUpdates, isOn: Binding(
                get: { automaticallyChecks },
                set: { newValue in
                    automaticallyChecks = newValue
                    updateActions.setAutomaticallyChecksForUpdates(newValue)
                    refresh()
                }
            ))
            .font(.system(size: compact ? 12 : 13, weight: .medium))

            Button {
                updateActions.checkForUpdates()
                refresh()
            } label: {
                HStack(spacing: compact ? 7 : 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: compact ? 14 : 15, weight: .semibold))

                    Text(copy.checkForUpdates)
                        .font(.system(size: compact ? 12.5 : 13, weight: .semibold))

                    Spacer(minLength: compact ? 6 : 10)

                    Image(systemName: "chevron.right")
                        .font(.system(size: compact ? 9.5 : 10.5, weight: .bold))
                        .opacity(0.62)
                }
                .foregroundStyle(canCheck ? Color.primary.opacity(0.86) : Color.secondary.opacity(0.62))
                .padding(.horizontal, compact ? 10 : 12)
                .padding(.vertical, compact ? 7 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: compact ? 10 : 11, style: .continuous)
                        .fill(settings.accentColor.opacity(canCheck ? 0.14 : 0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: compact ? 10 : 11, style: .continuous)
                                .stroke(settings.accentColor.opacity(canCheck ? 0.34 : 0.14), lineWidth: 1)
                        }
                }
                .contentShape(RoundedRectangle(cornerRadius: compact ? 10 : 11, style: .continuous))
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

    @MainActor
    private func refresh() {
        automaticallyChecks = updateActions.automaticallyChecksForUpdates()
        canCheck = updateActions.canCheckForUpdates()
    }
}
