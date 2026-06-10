import SwiftUI

struct PermissionRequestView: View {
    @ObservedObject var settings: AppSettings
    var compact = false

    @State private var accessibilityTrusted = AccessibilityPermissionController.isTrusted

    var body: some View {
        let copy = AppText(language: settings.language)

        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                Label(copy.accessibilityPermission, systemImage: "accessibility")
                    .font(.system(size: compact ? 12.5 : 13, weight: .semibold))
                Spacer()
                Label(
                    accessibilityTrusted ? copy.permissionAuthorized : copy.permissionNotAuthorized,
                    systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .foregroundStyle(accessibilityTrusted ? .green : .secondary)
            }

            Button {
                accessibilityTrusted = AccessibilityPermissionController.requestAccess()
                refreshPermissionStatusSoon()
            } label: {
                Label(copy.requestAccessibilityPermission, systemImage: "hand.raised")
            }
            .buttonStyle(.plain)

            Text(copy.accessibilityPermissionHint)
                .font(.system(size: compact ? 10.8 : 11.5, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            accessibilityTrusted = AccessibilityPermissionController.isTrusted
        }
    }

    private func refreshPermissionStatusSoon() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            accessibilityTrusted = AccessibilityPermissionController.isTrusted
        }
    }
}
