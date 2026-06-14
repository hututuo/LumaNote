import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    let onComplete: () -> Void

    @State private var page = 0
    @State private var automaticallyChecks = true

    private let pageCount = 3

    var body: some View {
        let copy = AppText(language: settings.language)

        GeometryReader { proxy in
            let cardWidth = min(430, max(246, proxy.size.width - 18))
            let cardHeight = min(560, max(222, proxy.size.height - 22))

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .contentShape(Rectangle())

                VStack(spacing: 10) {
                    header(copy: copy)
                    stepIndicator(copy: copy)

                    ScrollView(.vertical, showsIndicators: false) {
                        pageContent(copy: copy)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 12)
                    }

                    footer(copy: copy)
                }
                .frame(width: cardWidth, height: cardHeight)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.regularMaterial)
                            .opacity(0.18)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.91))

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(settings.accentColor.opacity(0.018))
                            .blendMode(.plusLighter)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.72),
                                    settings.accentColor.opacity(0.22),
                                    .black.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.24), radius: 24, y: 10)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .center).combined(with: .opacity),
                    removal: .scale(scale: 0.985, anchor: .center).combined(with: .opacity)
                ))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
            refreshUpdateState()
        }
    }

    private func header(copy: AppText) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(settings.accentColor.opacity(0.18))
                Circle()
                    .strokeBorder(.white.opacity(0.56), lineWidth: 1)
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(copy.onboardingTitle)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.88))
                Text(stepTitle(copy: copy))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.50))
            }

            Spacer(minLength: 0)

            Button {
                complete()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.70))
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.24))
                            .overlay(Circle().stroke(Color.white.opacity(0.42), lineWidth: 1))
                    }
            }
            .buttonStyle(.plain)
            .help(copy.onboardingSkip)
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
    }

    private func stepIndicator(copy: AppText) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == page ? settings.accentColor.opacity(0.74) : Color.black.opacity(0.14))
                    .frame(width: index == page ? 26 : 8, height: 5)
                    .animation(.snappy(duration: 0.18), value: page)
                    .help(stepLabel(index: index, copy: copy))
            }
        }
        .padding(.top, 1)
    }

    @ViewBuilder
    private func pageContent(copy: AppText) -> some View {
        switch page {
        case 0:
            introPage(copy: copy)
        case 1:
            shortcutsPage(copy: copy)
        default:
            readyPage(copy: copy)
        }
    }

    private func introPage(copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(copy.onboardingIntroTitle)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.90))

                Text(copy.onboardingSubtitle)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                Text(copy.onboardingIntroBody)
                    .font(.system(size: 12.6, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 7) {
                featureRow(icon: "text.badge.checkmark", title: text("实时 Markdown", "Live Markdown"), detail: text("边写边渲染，内容仍保存为普通 Markdown。", "Styled while editing, saved as plain Markdown."))
                featureRow(icon: "square.on.square", title: text("本地剪切板库", "Local clipboard library"), detail: text("复制内容后在本机保存并提取可用信息。", "Saves copied text locally and extracts useful snippets."))
                featureRow(icon: "keyboard", title: text("快捷呼出", "Quick summon"), detail: text("用全局快捷键呼出或隐藏这张便签。", "Use global shortcuts to show or hide the note."))
            }

            recommendedBox(copy: copy)
        }
    }

    private func shortcutsPage(copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(copy.onboardingShortcutTitle)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.90))

                Text(copy.onboardingShortcutBody)
                    .font(.system(size: 12.6, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ShortcutSettingsPanel(settings: settings, presentation: .sheet)
        }
    }

    private func readyPage(copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 7) {
                Text(copy.onboardingReadyTitle)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.90))

                Text(copy.onboardingReadyBody)
                    .font(.system(size: 12.6, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                statusRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: copy.automaticallyCheckForUpdates,
                    isEnabled: automaticallyChecks,
                    copy: copy
                )
                statusRow(
                    icon: "power",
                    title: copy.launchAtLogin,
                    isEnabled: settings.launchAtLogin,
                    copy: copy
                )
                statusRow(
                    icon: "keyboard.fill",
                    title: copy.globalShortcuts,
                    isEnabled: true,
                    copy: copy
                )
            }
        }
    }

    private func recommendedBox(copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(settings.accentColor)
                Text(copy.onboardingRecommendedTitle)
                    .font(.system(size: 13.2, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.84))
            }

            Text(copy.onboardingRecommendedBody)
                .font(.system(size: 11.6, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                Toggle(copy.automaticallyCheckForUpdates, isOn: Binding(
                    get: { automaticallyChecks },
                    set: { enabled in
                        automaticallyChecks = enabled
                        appDelegate?.setAutomaticallyChecksForUpdates(enabled)
                        refreshUpdateState()
                    }
                ))
                .font(.system(size: 12.3, weight: .semibold))
                .help(copy.automaticallyCheckForUpdates)

                Toggle(copy.launchAtLogin, isOn: $settings.launchAtLogin)
                    .font(.system(size: 12.3, weight: .semibold))
                    .help(copy.launchAtLogin)

                if let error = settings.launchAtLoginError {
                    Text(copy.launchAtLoginFailed + error)
                        .font(.system(size: 10.8, weight: .medium))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                enableRecommendedSettings()
            } label: {
                Label(copy.onboardingEnableRecommended, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12.4, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        Capsule(style: .continuous)
                            .fill(settings.accentColor.opacity(0.16))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(settings.accentColor.opacity(0.34), lineWidth: 1)
                            )
                    }
            }
            .buttonStyle(.plain)
            .help(copy.onboardingEnableRecommended)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(settings.accentColor.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    settings.accentColor.opacity(0.30),
                                    .white.opacity(0.26),
                                    .black.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.76))
                .frame(width: 25, height: 25)
                .background {
                    Circle()
                        .fill(settings.accentColor.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.6, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text(detail)
                    .font(.system(size: 11.4, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.035))
        }
    }

    private func statusRow(icon: String, title: String, isEnabled: Bool, copy: AppText) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.76))
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill((isEnabled ? settings.accentColor : Color.black).opacity(isEnabled ? 0.14 : 0.08))
                }

            Text(title)
                .font(.system(size: 12.7, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))

            Spacer(minLength: 6)

            Text(isEnabled ? copy.onboardingConfigured : copy.onboardingNotConfigured)
                .font(.system(size: 11.2, weight: .heavy, design: .rounded))
                .foregroundStyle(isEnabled ? settings.accentColor : Color.black.opacity(0.46))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule(style: .continuous)
                        .fill((isEnabled ? settings.accentColor : Color.black).opacity(isEnabled ? 0.10 : 0.06))
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.055), lineWidth: 1)
                )
        }
    }

    private func footer(copy: AppText) -> some View {
        HStack(spacing: 9) {
            Button {
                complete()
            } label: {
                Text(copy.onboardingSkip)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.54))
            }
            .buttonStyle(.plain)
            .help(copy.onboardingSkip)

            Spacer(minLength: 0)

            if page > 0 {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        page -= 1
                    }
                } label: {
                    Text(copy.onboardingBack)
                        .font(.system(size: 12.2, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.70))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.16))
                                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                        }
                }
                .buttonStyle(.plain)
                .help(copy.onboardingBack)
            }

            Button {
                if page == pageCount - 1 {
                    complete()
                } else {
                    withAnimation(.snappy(duration: 0.18)) {
                        page += 1
                    }
                }
            } label: {
                Text(page == pageCount - 1 ? copy.onboardingFinish : copy.onboardingNext)
                    .font(.system(size: 12.4, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background {
                        Capsule(style: .continuous)
                            .fill(settings.accentColor.opacity(0.20))
                            .overlay(Capsule().stroke(settings.accentColor.opacity(0.38), lineWidth: 1))
                    }
            }
            .buttonStyle(.plain)
            .help(page == pageCount - 1 ? copy.onboardingFinish : copy.onboardingNext)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private func enableRecommendedSettings() {
        automaticallyChecks = true
        appDelegate?.setAutomaticallyChecksForUpdates(true)
        if !settings.launchAtLogin {
            settings.launchAtLogin = true
        }
        refreshUpdateState()
    }

    private func refreshUpdateState() {
        guard let appDelegate else { return }
        automaticallyChecks = appDelegate.automaticallyChecksForUpdates
    }

    private func complete() {
        withAnimation(.snappy(duration: 0.18)) {
            settings.hasCompletedOnboarding = true
        }
        onComplete()
    }

    private func stepTitle(copy: AppText) -> String {
        stepLabel(index: page, copy: copy)
    }

    private func stepLabel(index: Int, copy: AppText) -> String {
        switch index {
        case 0: copy.onboardingIntroStep
        case 1: copy.onboardingShortcutStep
        default: copy.onboardingReadyStep
        }
    }

    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    private func text(_ chinese: String, _ english: String) -> String {
        settings.language == .chinese ? chinese : english
    }
}
