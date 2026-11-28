import XCTest

final class TypingTests: XCTestCase {
    func testLogoMenuLanguageTipsAndHideKeyboard() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("Burmese", in: app)

        func menuItem(_ title: String) -> XCUIElement {
            let item = app.buttons[title]
            // Flat menus scroll inside the extension on compact keyboard heights.
            for _ in 0..<4 {
                if item.exists && item.isHittable { return item }
                let menu = app.collectionViews.firstMatch
                guard menu.exists else { break }
                // Native menu AX bounds include content clipped by the keyboard.
                // Start well inside the visible area instead of the usual bottom edge.
                menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(
                    forDuration: 0.01, thenDragTo: menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
            }
            XCTAssertTrue(item.waitForExistence(timeout: 3), title)
            XCTAssertTrue(item.isHittable, title)
            return item
        }
        func openTips(_ language: String) {
            app.buttons["MBoard Menu"].tap()
            XCTAssertTrue(app.buttons["Auto-Capitalization"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["Word Suggestions"].exists)
            XCTAssertFalse(app.buttons["Keyboard Settings"].exists, "Settings should be inline, not a submenu.")
            XCTAssertFalse(app.staticTexts["Appearance"].exists)
            for title in ["Appearance", "System", "Light", "Dark"] {
                XCTAssertFalse(app.buttons[title].exists, title)
            }
            XCTAssertFalse(app.buttons["About & Privacy"].exists)
            if language == "Burmese" {
                snapshot("Flat menu before scrolling")
            }
            let tips = menuItem(language + " Typing")
            XCTAssertTrue(app.staticTexts["Typing Tips"].exists)
            if language == "Burmese" { snapshot("MBoard menu") }
            tips.tap()
            let back = app.buttons["Back to Keyboard"]
            let hide = app.buttons["Hide Keyboard"]
            XCTAssertTrue(back.waitForExistence(timeout: 3))
            XCTAssertTrue(hide.isHittable)
            let title = app.staticTexts[language == "Burmese" ? "မြန်မာ Typing Tips" : "English Typing Tips"]
            let firstTip = app.otherElements[language == "Burmese" ? "typingTips.burmese.hold" : "typingTips.english.cursor"]
            XCTAssertGreaterThanOrEqual(title.frame.minY, max(back.frame.maxY, hide.frame.maxY))
            XCTAssertEqual(title.frame.midX, firstTip.frame.midX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(firstTip.frame.minY - title.frame.maxY, 15)
        }
        func snapshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        app.buttons["key.က"].tap()
        snapshot("Keyboard toolbar")
        openTips("Burmese")
        XCTAssertTrue(app.otherElements["typingTips.burmese.hold"].isHittable)
        XCTAssertTrue(app.otherElements["typingTips.burmese.stacking"].isHittable)
        XCTAssertFalse(app.buttons["key.က"].isHittable)
        snapshot("Burmese typing tips")
        XCTAssertEqual(field.value as? String, "က")
        app.buttons["Back to Keyboard"].tap()
        XCTAssertTrue(app.buttons["key.က"].isHittable)

        // Follow the stacking tip using the actual Shift-layer key.
        app.buttons["Shift"].tap()
        app.buttons["key.္"].tap()
        app.buttons["key.က"].tap()
        XCTAssertEqual(field.value as? String, "က္က")
        app.buttons["Switch to English"].tap()
        openTips("English")
        XCTAssertTrue(app.otherElements["typingTips.english.cursor"].isHittable)
        XCTAssertTrue(app.otherElements["typingTips.english.period"].isHittable)
        XCTAssertFalse(app.otherElements["typingTips.burmese.hold"].exists)
        snapshot("English typing tips")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["Back to Keyboard"].isHittable)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.otherElements["typingTips.english.period"].isHittable)
        snapshot("Landscape typing tips")
        XCUIDevice.shared.orientation = .portrait

        // Hiding from help resets the help panel for the next typing session.
        app.buttons["Hide Keyboard"].tap()
        XCTAssertTrue(app.buttons["Back to Keyboard"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "က္က")
        field.tap()
        XCTAssertTrue(app.buttons["MBoard Menu"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Back to Keyboard"].exists)
        XCTAssertTrue(app.buttons["Switch to Burmese"].isHittable)
        app.buttons["Hide Keyboard"].tap()
        XCTAssertTrue(app.buttons["MBoard Menu"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "က္က")
    }

    private func selectKeyboard(_ language: String, in app: XCUIApplication) {
        // Remote keyboard buttons can appear after the practice field receives focus.
        let switches = app.buttons.matching(NSPredicate(format: "label IN %@", ["Switch to English", "Switch to Burmese"]))
        let globe = app.buttons["Next keyboard"].firstMatch
        if !switches.firstMatch.waitForExistence(timeout: 3), globe.exists {
            globe.press(forDuration: 0.8)
            let mboard = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'MBoard,'")).firstMatch
            if mboard.waitForExistence(timeout: 2) { mboard.tap() }
        }
        XCTAssertTrue(switches.firstMatch.waitForExistence(timeout: 3), "Enable MBoard in the simulator keyboard settings.")
        let toggle = app.buttons["Switch to " + language]
        if toggle.exists { toggle.tap() }
        let destination = language == "English" ? "Burmese" : "English"
        XCTAssertTrue(app.buttons["Switch to " + destination].waitForExistence(timeout: 3))
    }

    func testMixedScriptSpacingInThePracticeField() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        let h = app.buttons["key.H"]
        (h.exists ? h : app.buttons["key.h"]).tap()
        app.buttons["key.e"].tap()
        let hello = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "completion.hello")).firstMatch
        XCTAssertTrue(hello.waitForExistence(timeout: 4))
        hello.tap()
        func expect(_ value: String) {
            XCTAssertEqual((field.value as? String)?.lowercased(), value)
        }
        app.buttons["Switch to Burmese"].tap()
        expect("hello")
        app.buttons["key.ေ"].tap()
        app.buttons["key.က"].tap()
        expect("hello ကေ")
        app.buttons["Switch to English"].tap()
        expect("hello ကေ")
        app.buttons["key.A"].tap()
        app.buttons["key.b"].tap()
        expect("hello ကေ ab")
        app.buttons["Switch to Burmese"].tap()
        app.buttons["key.န"].tap()
        expect("hello ကေ ab န")
        app.buttons["Switch to English"].tap()
        app.buttons["Space"].tap()
        app.buttons["key.C"].tap()
        app.buttons["Switch to Burmese"].tap()
        app.buttons["key.။"].tap()
        expect("hello ကေ ab န c။")
    }

    func testBurmeseHoldAndSlideCompounds() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("Burmese", in: app)

        let ka = app.buttons["key.က"]
        ka.press(forDuration: 0.6)
        XCTAssertEqual(field.value as? String, "ဥ")
        app.buttons["Space"].tap()
        app.buttons["key.တ"].tap()
        let center = CGVector(dx: 0.5, dy: 0.5)
        let start = ka.coordinate(withNormalizedOffset: center)
        start.press(forDuration: 0.6, thenDragTo: start.withOffset(CGVector(dx: 54, dy: 0)))
        XCTAssertEqual(field.value as? String, "ဥ တက္က")

        // Slide across the lower row of the six-choice န menu.
        let na = app.buttons["key.န"].coordinate(withNormalizedOffset: center)
        na.press(forDuration: 0.6, thenDragTo: na.withOffset(CGVector(dx: 110, dy: 0)))
        XCTAssertEqual(field.value as? String, "ဥ တက္ကန္န")

        // The top-row ဂ menu already offered ASCII 8 one cell left of its default.
        let gaKey = app.buttons["key.ဂ"]
        let nearTop = gaKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        nearTop.press(forDuration: 0.6, thenDragTo: nearTop.withOffset(CGVector(dx: -54, dy: 0)))
        XCTAssertEqual(field.value as? String, "ဥ တက္ကန္န8")
        let ga = gaKey.coordinate(withNormalizedOffset: center)
        let upperRow = ga.withOffset(CGVector(dx: -54, dy: -gaKey.frame.height * 1.2))
        ga.press(forDuration: 0.6, thenDragTo: upperRow)
        XCTAssertEqual(field.value as? String, "ဥ တက္ကန္န8ဂ္ဃ")
    }

    func testEnglishCorrectionsAndPersonalContextStayCentered() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        func type(_ keys: String) {
            for key in keys {
                if key == " " { app.buttons["Space"].tap(); continue }
                let lower = app.buttons["key." + String(key)]
                (lower.exists ? lower : app.buttons["key." + key.uppercased()]).tap()
            }
        }
        func centered(_ word: String) -> XCUIElement {
            let candidate = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "completion." + word)).firstMatch
            XCTAssertTrue(candidate.waitForExistence(timeout: 4), word)
            XCTAssertEqual(candidate.frame.midX, field.frame.midX, accuracy: 3)
            XCTAssertGreaterThanOrEqual(candidate.frame.height, 44)
            return candidate
        }
        type("teh")
        centered("the").tap()
        XCTAssertEqual((field.value as? String)?.lowercased(), "the")
        type(" helo")
        _ = centered("hello")
        type(" ")
        XCTAssertTrue((field.value as? String)?.hasSuffix("helo ") == true)

        // Use a fresh shared prefix so prior simulator history cannot satisfy the assertions.
        let suffix = String((0..<3).map { _ in "bcdfghjklmnpqrstvwxyz".randomElement()! })
        let stem = "z" + suffix
        let first = stem + "a", second = stem + "o"
        for _ in 0..<3 { type("good " + first + " ") }
        for _ in 0..<4 { type("nice " + second + " ") }
        type("good " + stem)
        centered(first).tap()
        XCTAssertTrue((field.value as? String)?.hasSuffix("good " + first) == true)
        type(" nice " + stem)
        centered(second).tap()
        XCTAssertTrue((field.value as? String)?.hasSuffix("nice " + second) == true)
    }

    func testEnglishDoubleShiftLocksUntilTheNextShiftTap() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
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

    func testSpacingAfterAcceptingThankYou() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        func type(_ letters: String) {
            for letter in letters {
                app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "key." + String(letter))).firstMatch.tap()
            }
        }
        func pickThankYou() {
            type("thankyo")
            let phrase = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "completion.thank you")).firstMatch
            XCTAssertTrue(phrase.waitForExistence(timeout: 3))
            phrase.tap()
        }
        pickThankYou()
        XCTAssertEqual((field.value as? String)?.lowercased(), "thank you")
        type("for")
        XCTAssertEqual((field.value as? String)?.lowercased(), "thank you for")
        app.buttons["Space"].tap()
        pickThankYou()
        app.buttons["key.,"].tap()
        XCTAssertEqual((field.value as? String)?.lowercased(), "thank you for thank you,")
    }

    func testCaseOverridesBelongToOneOccurrence() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        let delete = app.buttons["Delete"].firstMatch
        let space = app.buttons["Space"]
        func key(_ text: String) { app.buttons["key." + text].tap() }
        key("S")
        delete.tap()
        key("i")
        space.tap()
        XCTAssertEqual(field.value as? String, "i ")

        key("i")
        space.tap()
        XCTAssertEqual(field.value as? String, "i I ")
        delete.tap()
        XCTAssertEqual(field.value as? String, "i i")
        space.tap()
        XCTAssertEqual(field.value as? String, "i i ")

        key("i")
        let keep = app.buttons["Keep i"]
        XCTAssertTrue(keep.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(keep.frame.midX, field.frame.midX)
        keep.tap()
        key(".")
        delete.tap()
        key(".")
        space.tap()
        app.buttons["Shift"].tap()
        key("i")
        space.tap()
        XCTAssertEqual(field.value as? String, "i i i. i ")
        for letter in "thankyo" { key(String(letter)) }
        let keepTypo = app.buttons["Keep thankyo"]
        XCTAssertTrue(keepTypo.waitForExistence(timeout: 3))
        keepTypo.tap()
        key("x")
        XCTAssertEqual(field.value as? String, "i i i. i thankyo x")
    }

    func testCapitalizesStandalonePronounOnSpaceAndPunctuation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        for key in "say i think it is i," {
            if key == " " { app.buttons["Space"].tap() }
            else { app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "key." + String(key))).firstMatch.tap() }
        }
        XCTAssertEqual(field.value as? String, "Say I think it is I,")
    }

    func testMissingApostrophesInThePracticeField() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        for (keys, title) in [("im", "I'm"), ("dont", "don't")] {
            for key in keys {
                let button = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "key." + String(key))).firstMatch
                button.tap()
            }
            let correction = app.buttons["completion." + title]
            XCTAssertTrue(correction.waitForExistence(timeout: 4))
            XCTAssertEqual(correction.frame.midX, field.frame.midX, accuracy: 3)
            correction.tap()
        }
        XCTAssertEqual(field.value as? String, "I'm don't")
        for key in "well" { app.buttons["key." + String(key)].tap() }
        XCTAssertTrue(app.buttons["completion.we'll"].waitForExistence(timeout: 4))
        app.buttons["Space"].tap()
        XCTAssertEqual(field.value as? String, "I'm don't well ")
    }

    func testSentenceShortcutsAndSymbolPagesInBothLanguages() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("Burmese", in: app)
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

    func testEmojiReturnKeyFollowsLanguageChangedDuringSearch() {
        let app = XCUIApplication()
        app.launch()
        app.textViews["practice"].tap()
        selectKeyboard("Burmese", in: app)
        app.buttons["Emoji"].tap()
        XCTAssertTrue(app.buttons["Return to Burmese keyboard"].isHittable)
        app.buttons["emoji.search.query"].tap()
        app.buttons["Switch to English"].tap()
        app.buttons["Back"].tap()
        app.buttons["Return to English keyboard"].tap()
        XCTAssertTrue(app.buttons["Switch to Burmese"].isHittable)
    }

    func testEmojiSearchClearsVisibleHostSuggestions() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
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

    func testMovingHostCaretExitsEmojiSearch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        for letter in "hello" {
            let key = app.buttons["key." + String(letter)]
            (key.exists ? key : app.buttons["key." + letter.uppercased()]).tap()
        }
        app.buttons["Emoji"].tap()
        app.buttons["emoji.search.query"].tap()
        app.buttons["key.c"].tap()
        XCTAssertEqual(app.buttons["emoji.search.query"].value as? String, "c")

        // Move from the end to the start without dismissing the keyboard.
        field.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 6, dy: 24)).tap()
        XCTAssertTrue(app.buttons["Emoji"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["emoji.search.query"].exists)
        let x = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "key.x")).firstMatch
        x.tap()
        XCTAssertEqual((field.value as? String)?.lowercased(), "xhello")
    }

    func testReturningToSameHostCaretExitsEmojiSearch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        for text in ["", "hi"] {
            for character in text {
                let key = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "key." + String(character))).firstMatch
                key.tap()
            }
            app.buttons["Emoji"].tap()
            app.buttons["emoji.search.query"].tap()
            app.buttons["key.c"].tap()
            // Tap blank space on the first text line: the insertion point stays at its end.
            field.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 160, dy: 24)).tap()
            XCTAssertTrue(app.buttons["Emoji"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["emoji.search.query"].exists)
            XCTAssertEqual((field.value as? String)?.lowercased(), text)
        }
    }

    func testSelectingHostTextExitsEmojiSearch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        for character in "hi red go" {
            if character == " " { app.buttons["Space"].tap(); continue }
            let key = app.buttons["key." + String(character)]
            (key.exists ? key : app.buttons["key." + character.uppercased()]).tap()
        }
        app.buttons["Emoji"].tap()
        app.buttons["emoji.search.query"].tap()
        field.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 54, dy: 24)).doubleTap()
        XCTAssertTrue(app.buttons["Emoji"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["emoji.search.query"].exists)
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertEqual((field.value as? String)?.lowercased().split(separator: " "), ["hi", "go"])
    }

    func testDoneExitsEmptyAndPopulatedEmojiSearch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        for query in ["", "cat"] {
            app.buttons["Emoji"].tap()
            app.buttons["emoji.search.query"].tap()
            for letter in query { app.buttons["key." + String(letter)].tap() }
            app.buttons["emoji.search.done"].tap()
            XCTAssertTrue(app.buttons["Emoji"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["emoji.search.query"].exists)
            XCTAssertEqual(field.value as? String, "")
        }
        let h = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "key.h")).firstMatch
        h.tap()
        XCTAssertEqual((field.value as? String)?.lowercased(), "h")
    }

    func testEmojiCommonSearchAndPersistentRecents() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
        app.buttons["Emoji"].tap()
        let search = app.buttons["emoji.search.query"]
        search.tap()
        for query in ["happy", "thanks", "love", "lol", "pink heart"] {
            for character in query {
                if character == " " { app.buttons["Space"].tap() }
                else { app.buttons["key." + String(character)].tap() }
            }
            let expected = ["happy": "😊", "thanks": "🙏", "love": "❤️", "lol": "😂", "pink heart": "🩷"][query]!
            let emoji = app.collectionViews["emoji.grid"].cells["emoji.item." + expected]
            XCTAssertTrue(emoji.waitForExistence(timeout: 3))
            XCTAssertTrue(emoji.isHittable)
            if query == "lol" { XCTAssertFalse(app.collectionViews["emoji.grid"].cells["emoji.item.🍭"].exists) }
            if query == "pink heart" {
                emoji.tap()
                XCTAssertEqual(field.value as? String, "🩷")
                XCTAssertTrue(search.exists, "Inserting a result keeps search available.")
                XCTAssertEqual(search.value as? String, query)
            }
            app.buttons["Clear emoji search"].tap()
        }
        app.buttons["emoji.search.done"].tap()
        app.terminate()
        app.launch()
        field.tap()
        selectKeyboard("English", in: app)
        app.buttons["Emoji"].tap()
        let grid = app.collectionViews["emoji.grid"]
        XCTAssertTrue(grid.cells["emoji.item.🩷"].waitForExistence(timeout: 3))
        XCTAssertEqual(grid.cells.element(boundBy: 0).identifier, "emoji.item.🩷")
        XCTAssertTrue(grid.cells["emoji.item.😂"].isHittable, "Common emoji remain near the front of the full list.")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Common emoji in the full scrollable list"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBackspaceDeletesASelectionAndPreservesItsNeighbors() {
        let app = XCUIApplication()
        app.launch()
        let field = app.textViews["practice"]
        field.tap()
        selectKeyboard("English", in: app)
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
        // Triple-tap the single paragraph to select it through the touch UI.
        field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
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
        selectKeyboard("Burmese", in: app)
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

        let cKey = app.buttons.matching(NSPredicate(format: "identifier =[c] %@", "key.c")).firstMatch
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
        app.buttons["Return to English keyboard"].tap()
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
