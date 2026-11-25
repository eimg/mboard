import XCTest

final class TypingTests: XCTestCase {
    func testBurmeseAndEnglishInTextView() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.label, "စာရိုက်စမ်းရန်")
        let done = app.navigationBars.buttons["doneTyping"]
        XCTAssertFalse(done.exists)
        field.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 3))

        // Enable MBoard in simulator Settings and select it from the globe before the run.
        let englishSwitch = app.buttons["Switch to English"]
        if app.buttons["Switch to Burmese"].exists { app.buttons["Switch to Burmese"].tap() }
        XCTAssertTrue(englishSwitch.waitForExistence(timeout: 5), "Select the enabled MBoard keyboard in this simulator.")
        func tapKey(_ value: String) { app.buttons["key." + value].tap() }
        for key in ["ေ","က","ျ","ာ","င","်","း"] { tapKey(key) }
        XCTAssertEqual(field.value as? String, "ကျောင်း")
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, "ကျောင်")
        app.buttons["Space"].tap()
        englishSwitch.tap()
        tapKey("h")
        tapKey("e")
        let hello = app.buttons["hello"]
        XCTAssertTrue(hello.waitForExistence(timeout: 3))
        hello.tap()
        let mixedText = "ကျောင် hello"
        XCTAssertEqual(field.value as? String, mixedText)

        let cKey = app.buttons["key.c"]
        let normalKeyHeight = cKey.frame.height
        app.buttons["Emoji"].tap()
        let search = app.buttons["emoji.search.query"]
        XCTAssertTrue(search.isHittable)
        XCTAssertFalse(cKey.isHittable)
        let grid = app.collectionViews["emoji.grid"]
        let firstEmoji = grid.descendants(matching: .any)["emoji.item.😀"].firstMatch
        XCTAssertTrue(firstEmoji.waitForExistence(timeout: 3))
        XCTAssertTrue(firstEmoji.isHittable)
        grid.swipeUp()
        XCTAssertFalse(firstEmoji.isHittable, "The initial picker should scroll through the full emoji catalog.")
        search.tap()
        XCTAssertTrue(cKey.isHittable)
        XCTAssertEqual(cKey.frame.height, normalKeyHeight, accuracy: 2)
        for letter in ["c", "a", "t"] {
            tapKey(letter)
        }
        XCTAssertEqual(field.value as? String, mixedText)
        let cat = app.descendants(matching: .any)["emoji.item.🐱"].firstMatch
        XCTAssertTrue(cat.waitForExistence(timeout: 3))
        XCTAssertTrue(cat.isHittable, "Emoji results should be visible above the search keys.")
        XCTAssertLessThan(cat.frame.maxY, search.frame.minY)
        cat.tap()
        XCTAssertEqual(field.value as? String, mixedText + "🐱")
        app.buttons["Back"].tap()
        XCTAssertTrue(search.isHittable)
        XCTAssertFalse(firstEmoji.isHittable, "Returning from search should restore the scroll position.")
        app.buttons["ABC"].tap()
        XCTAssertTrue(app.buttons["Switch to Burmese"].isHittable)
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, mixedText)

        done.tap()
        XCTAssertFalse(done.exists)
        XCTAssertFalse(cKey.isHittable)
        XCTAssertEqual(field.value as? String, mixedText)
        XCTAssertTrue(app.cells["openSettings"].isHittable)
    }
}
