import XCTest

final class LawSenseUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    @MainActor func launchAndAccept() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let start = app.buttons["start-learning"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        if !start.isHittable { app.swipeUp() }
        XCTAssertFalse(start.isEnabled)
        let toggle = app.switches["acknowledge-toggle"]
        if !toggle.isHittable { app.swipeUp() }
        // SwiftUI exposes both the labelled row and its native switch.
        let control = toggle.switches.firstMatch
        if control.exists { control.tap() } else { toggle.tap() }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed, "Acknowledgement must enable the start button")
        start.tap()
        XCTAssertTrue(app.buttons["daily-question"].waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "home"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        return app
    }

    @MainActor func testOnboardingAndDailyAnswer() {
        let app = launchAndAccept()
        app.buttons["daily-question"].tap()
        let submit = app.buttons["submit-answer"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)
        app.buttons["option-b"].tap()
        submit.tap()
        XCTAssertTrue(app.staticTexts["没关系，看看依据"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["option-a"].isEnabled)
        let finish = app.buttons["finish-learning"]
        for _ in 0..<5 where !finish.isHittable { app.swipeUp() }
        finish.tap()
        XCTAssertEqual(finish.label, "已完成学习")
    }

    @MainActor func testCardBookmarkAppearsInProfile() {
        let app = launchAndAccept()
        app.tabBars.buttons["学法堂"].tap()
        let card = app.buttons["card-link-demo-card-1"]
        for _ in 0..<5 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let bookmark = app.buttons["bookmark-button"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "取消收藏")
        capture(app, name: "knowledge-card")
        app.tabBars.buttons["我的"].tap()
        app.buttons["我的收藏"].tap()
        let savedCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "看见一条结论，先问出处")).firstMatch
        XCTAssertTrue(savedCard.waitForExistence(timeout: 5))
        capture(app, name: "bookmarks")
    }

    @MainActor func testSearchAndOriginalArticle() {
        let app = launchAndAccept()
        app.tabBars.buttons["查法条"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("1")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "看见一条结论，先问出处")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.staticTexts["article-original"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["开发样例 v1 · 非施行版本"].exists)
        capture(app, name: "article")
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
