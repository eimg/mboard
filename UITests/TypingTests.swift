import XCTest

final class TypingTests: XCTestCase {
    func testEnglishDoubleShiftLocksUntilTheNextShiftTap() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        if app.buttons["Switch to English"].exists { app.buttons["Switch to English"].tap() }
        let shift = app.buttons["Shift"]
        shift.doubleTap()
        XCTAssertEqual(shift.value as? String, "Caps Lock")
        for key in ["key.H", "key.I", "Space", "key.M", "key.E"] { app.buttons[key].tap() }
        XCTAssertEqual(field.value as? String, "HI ME")
        shift.tap()
        app.buttons["key.a"].tap()
        shift.tap()
        app.buttons["key.B"].tap()
        app.buttons["key.c"].tap()
        XCTAssertEqual(field.value as? String, "HI MEaBc")
    }

    func testSentenceShortcutsAndSymbolPagesInBothLanguages() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        if app.buttons["Switch to Burmese"].exists { app.buttons["Switch to Burmese"].tap() }
        app.buttons["key.က"].tap()
        app.buttons["Space"].doubleTap()
        XCTAssertEqual(field.value as? String, "က။ ")
        app.buttons["Switch to English"].tap()
        let letter = app.buttons["key.Q"].exists ? "Q" : "q"
        app.buttons["key." + letter].tap()
        app.buttons["Space"].doubleTap()
        XCTAssertEqual(field.value as? String, "က။ " + letter + ". ")
        app.buttons["Show symbols"].tap()
        app.buttons["Space"].tap()
        app.buttons["key.1"].tap()
        app.buttons["key.2"].tap()
        app.buttons["Space"].tap()
        app.buttons["key.q"].tap()
        XCTAssertEqual(field.value as? String, "က။ " + letter + ".  12 q")
    }

    func testEmojiSearchClearsVisibleHostSuggestions() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        if app.buttons["Switch to English"].exists { app.buttons["Switch to English"].tap() }
        let lower = app.buttons["key.h"]
        (lower.exists ? lower : app.buttons["key.H"]).tap()
        app.buttons["key.e"].tap()
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "completion."))
        XCTAssertTrue(candidates.firstMatch.waitForExistence(timeout: 3))
        let original = field.value as? String
        app.buttons["Emoji"].tap()
        app.buttons["emoji.search.query"].tap()
        XCTAssertEqual(candidates.count, 0)
        app.buttons["key.c"].tap()
        XCTAssertEqual(app.buttons["emoji.search.query"].value as? String, "c")
        XCTAssertEqual(field.value as? String, original)
    }

    func testBackspaceDeletesASelectionAndPreservesItsNeighbors() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        if app.buttons["Switch to English"].exists { app.buttons["Switch to English"].tap() }
        for character in "hi red go" {
            if character == " " { app.buttons["Space"].tap(); continue }
            let lower = app.buttons["key." + String(character)]
            (lower.exists ? lower : app.buttons["key." + character.uppercased()]).tap()
        }
        field.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 54, dy: 24)).doubleTap()
        app.buttons["Delete"].firstMatch.tap()
        let remaining = (field.value as? String)?.lowercased().split(separator: " ")
        XCTAssertEqual(remaining, ["hi", "go"])

        app.buttons["Switch to Burmese"].tap()
        app.buttons["key.က"].tap()
        field.typeKey("a", modifierFlags: .command)
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue((field.value as? String ?? "").isEmpty)
    }

    func testBurmeseAndEnglishInTextView() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.label, "စာရိုက်စမ်းရန်")
        field.tap()

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
        tapKey("H")
        tapKey("e")
        let hello = app.buttons["completion.Hello"]
        XCTAssertTrue(hello.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(hello.frame.height, 44)
        hello.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        let mixedText = "ကျောင် Hello"
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

        app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(cKey.isHittable)
        XCTAssertEqual(field.value as? String, mixedText)
        XCTAssertTrue(app.cells["openSettings"].isHittable)

        field.tap()
        XCTAssertTrue(cKey.waitForExistence(timeout: 3))
        let start = field.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 12, dy: -10))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 130)))
        XCTAssertFalse(cKey.isHittable)
        XCTAssertEqual(field.value as? String, mixedText)
    }
}
