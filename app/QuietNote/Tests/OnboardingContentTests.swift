import XCTest
@testable import QuietNote

final class OnboardingContentTests: XCTestCase {
    func testOnboardingPageOrderAndNavigation() {
        XCTAssertEqual(OnboardingPage.allCases, [.intro, .shortcuts, .documents, .ready])
        XCTAssertNil(OnboardingPage.intro.previous)
        XCTAssertEqual(OnboardingPage.intro.next, .shortcuts)
        XCTAssertEqual(OnboardingPage.shortcuts.previous, .intro)
        XCTAssertEqual(OnboardingPage.documents.next, .ready)
        XCTAssertNil(OnboardingPage.ready.next)
    }

    func testOnboardingFeatureGroupsMatchPages() {
        XCTAssertEqual(OnboardingPage.intro.featureItems.count, 3)
        XCTAssertTrue(OnboardingPage.shortcuts.featureItems.isEmpty)
        XCTAssertEqual(OnboardingPage.documents.featureItems.count, 3)
        XCTAssertEqual(OnboardingPage.ready.featureItems.count, 2)
        XCTAssertNil(OnboardingPage.documents.bottomToolbarTitle)
        XCTAssertEqual(OnboardingPage.ready.bottomToolbarItems.count, 2)
    }

    func testLocalizedFeatureTextResolvesByLanguage() {
        let item = OnboardingPage.intro.featureItems[0]

        XCTAssertEqual(item.title.resolved(language: .chinese), "实时 Markdown")
        XCTAssertEqual(item.title.resolved(language: .english), "Live Markdown")
    }

    func testStepLabelsUseAppTextLanguage() {
        let chinese = AppText(language: .chinese)
        let english = AppText(language: .english)

        XCTAssertEqual(OnboardingPage.intro.stepLabel(copy: chinese), "介绍")
        XCTAssertEqual(OnboardingPage.intro.stepLabel(copy: english), "Intro")
        XCTAssertEqual(OnboardingPage.ready.stepLabel(copy: chinese), "完成")
        XCTAssertEqual(OnboardingPage.ready.stepLabel(copy: english), "Ready")
    }
}
