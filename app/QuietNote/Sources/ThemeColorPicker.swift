import SwiftUI

struct ThemeColorPicker: View {
    @Binding var selection: AppThemeColor
    let language: AppLanguage
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            ForEach(AppThemeColor.allCases) { theme in
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        selection = theme
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.color.opacity(0.94),
                                        theme.color.opacity(0.44),
                                        .white.opacity(0.26)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(selection == theme ? 0.78 : 0.32), lineWidth: selection == theme ? 1.4 : 1)
                            )
                            .shadow(color: theme.color.opacity(selection == theme ? 0.32 : 0.12), radius: selection == theme ? 7 : 3, y: 2)

                        if selection == theme {
                            Image(systemName: "checkmark")
                                .font(.system(size: compact ? 8 : 9.5, weight: .black))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.24), radius: 1, y: 0.5)
                        }
                    }
                    .frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(theme.displayName(language: language))
                .accessibilityLabel(theme.displayName(language: language))
            }
        }
    }
}
