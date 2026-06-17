import SwiftUI

struct OnboardingView: View {
    var settings: AppSettings
    let updateActions: UpdateCheckingActions
    let onComplete: () -> Void

    @State private var page: OnboardingPage = .intro
    @State private var automaticallyChecks = true

    private let topDragOverlayHeight: CGFloat = 56

    var body: some View {
        let copy = settings.localizedText

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
                            .opacity(0.10)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.96))

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
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .center).combined(with: .opacity),
                    removal: .scale(scale: 0.985, anchor: .center).combined(with: .opacity)
                ))

                topWindowDragOverlay(windowWidth: proxy.size.width, cardWidth: cardWidth, copy: copy)
                    .frame(width: proxy.size.width, height: topDragOverlayHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
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
                WindowDragView()

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
                }
                .allowsHitTesting(false)
            }
            .frame(height: 36)

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

    private func topWindowDragOverlay(windowWidth: CGFloat, cardWidth: CGFloat, copy: AppText) -> some View {
        let cardLeft = max(0, (windowWidth - cardWidth) / 2)
        let protectedWidth: CGFloat = 62
        let protectedMinX = min(windowWidth, max(0, cardLeft + cardWidth - protectedWidth - 4))
        let leadingWidth = protectedMinX
        let trailingWidth = max(0, windowWidth - protectedMinX - protectedWidth)

        return HStack(spacing: 0) {
            WindowDragView()
                .frame(width: leadingWidth, height: topDragOverlayHeight)

            Color.clear
                .frame(width: protectedWidth, height: topDragOverlayHeight)
                .allowsHitTesting(false)

            WindowDragView()
                .frame(width: trailingWidth, height: topDragOverlayHeight)
        }
        .frame(width: windowWidth, height: topDragOverlayHeight)
        .help(copy.dragNote)
    }

    private func stepIndicator(copy: AppText) -> some View {
        HStack(spacing: 7) {
            ForEach(OnboardingPage.allCases) { onboardingPage in
                Capsule(style: .continuous)
                    .fill(onboardingPage == page ? settings.accentColor.opacity(0.74) : Color.black.opacity(0.14))
                    .frame(width: onboardingPage == page ? 26 : 8, height: 5)
                    .animation(.snappy(duration: 0.18), value: page)
                    .help(onboardingPage.stepLabel(copy: copy))
            }
        }
        .padding(.top, 1)
    }

    @ViewBuilder
    private func pageContent(copy: AppText) -> some View {
        switch page {
        case .intro:
            introPage(copy: copy)
        case .shortcuts:
            shortcutsPage(copy: copy)
        case .documents:
            documentsPage(copy: copy)
        case .ready:
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

            featureList(page.featureItems, spacing: 7)

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

    private func documentsPage(copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(copy.onboardingDocumentsTitle)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.90))

                Text(copy.onboardingDocumentsBody)
                    .font(.system(size: 12.6, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            featureList(page.featureItems, spacing: 8)
        }
    }

    private func readyPage(copy: AppText) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 7) {
                Text(copy.onboardingReadyTitle)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.90))

                Text(copy.onboardingReadyBody)
                    .font(.system(size: 12.6, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            featureList(page.featureItems, spacing: 8)

            if let bottomToolbarTitle = page.bottomToolbarTitle {
                Text(bottomToolbarTitle.resolved(language: settings.language))
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.70))
            }

            featureList(page.bottomToolbarItems, spacing: 8)
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
                recommendationToggleRow(
                    title: copy.automaticallyCheckForUpdates,
                    isOn: Binding(
                        get: { automaticallyChecks },
                        set: { enabled in
                            automaticallyChecks = enabled
                            updateActions.setAutomaticallyChecksForUpdates(enabled)
                            refreshUpdateState()
                        }
                    ),
                    help: copy.automaticallyCheckForUpdates
                )

                recommendationToggleRow(
                    title: copy.launchAtLogin,
                    isOn: settings.launchAtLoginBinding,
                    help: copy.launchAtLogin
                )

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

    private func recommendationToggleRow(title: String, isOn: Binding<Bool>, help: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 9) {
                onboardingCheckboxMark(isOn: isOn.wrappedValue)
                    .frame(width: 22, alignment: .leading)

                Text(title)
                    .font(.system(size: 12.3, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.78))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.black.opacity(isOn.wrappedValue ? 0.12 : 0.045), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func onboardingCheckboxMark(isOn: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isOn ? settings.accentColor.opacity(0.18) : Color.white.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.74), lineWidth: 1.25)
                )

            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.86))
            }
        }
        .frame(width: 17, height: 17)
    }

    private func featureList(_ items: [OnboardingFeatureItem], spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(items) { item in
                featureRow(item)
            }
        }
    }

    private func featureRow(_ item: OnboardingFeatureItem) -> some View {
        featureRow(
            icon: item.icon,
            title: item.title.resolved(language: settings.language),
            detail: item.detail.resolved(language: settings.language)
        )
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

            if let previousPage = page.previous {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        page = previousPage
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
                if let nextPage = page.next {
                    withAnimation(.snappy(duration: 0.18)) {
                        page = nextPage
                    }
                } else {
                    complete()
                }
            } label: {
                Text(page.next == nil ? copy.onboardingFinish : copy.onboardingNext)
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
            .help(page.next == nil ? copy.onboardingFinish : copy.onboardingNext)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private func enableRecommendedSettings() {
        automaticallyChecks = true
        updateActions.setAutomaticallyChecksForUpdates(true)
        if !settings.launchAtLogin {
            settings.setLaunchAtLogin(true)
        }
        refreshUpdateState()
    }

    private func refreshUpdateState() {
        automaticallyChecks = updateActions.automaticallyChecksForUpdates()
    }

    private func complete() {
        withAnimation(.snappy(duration: 0.18)) {
            settings.hasCompletedOnboarding = true
        }
        onComplete()
    }

    private func stepTitle(copy: AppText) -> String {
        page.stepLabel(copy: copy)
    }
}
