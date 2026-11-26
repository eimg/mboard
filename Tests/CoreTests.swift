import XCTest
@testable import MBoardCore

final class CoreTests: XCTestCase {
    // Keep committed units separate from the current marked segment, as in the extension.
    private func run(_ keys: [String]) -> [UInt32] {
        var committed = ""
        var core = BurmeseComposition()
        for key in keys {
            if core.startsNewSegment(key) { committed += core.text; core = BurmeseComposition() }
            core.append(key)
        }
        return (committed + core.text).unicodeScalars.map(\.value)
    }

    func testDoubleSpaceUsesTheActiveLanguageAndOnlyAnOwnedSpace() {
        let document = UUID(), other = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 100)
        func context(_ left: String?, _ right: String? = nil, selection: String? = nil, id: UUID? = nil) -> HostContext {
            HostContext(document: id ?? document, before: left, after: right, selection: selection)
        }
        func pair(_ first: HostContext, _ second: HostContext, _ language: Language = .english,
                  delay: TimeInterval = 0.2) -> String? {
            var shortcut = DoubleSpaceShortcut()
            XCTAssertNil(shortcut.separator(for: language, at: first, now: now))
            return shortcut.separator(for: language, at: second, now: now.addingTimeInterval(delay))
        }

        XCTAssertEqual(pair(context("hello"), context("hello ")), ". ")
        XCTAssertEqual(pair(context("ကျောင်း"), context("ကျောင်း "), .burmese), "။ ")
        XCTAssertEqual(pair(context("123"), context("123 ")), ". ")
        XCTAssertEqual(pair(context("long paragraph"), context("paragraph ")), ". ")
        XCTAssertNil(pair(context("hello"), context("hello "), delay: 1))
        XCTAssertNil(pair(context("hello"), context("hello ", id: other)))
        XCTAssertNil(pair(context("hello"), context("hello ", selection: "selected")))
        XCTAssertNil(pair(context("hello", "there"), context("hello ", "elsewhere")))
        XCTAssertNil(pair(context("hello"), context("other ")))
        XCTAssertNil(pair(context(nil), context(" ")))
        var shortcut = DoubleSpaceShortcut()
        XCTAssertNil(shortcut.separator(for: .english, at: context("hello"), now: now))
        shortcut.selectionChanged(to: context("hello "))
        shortcut.selectionChanged(to: context("he", "llo "))
        XCTAssertNil(shortcut.separator(for: .english, at: context("hello "), now: now.addingTimeInterval(0.2)))
        for prior in ["", " ", "hello.", "ပြီး။", "hello!"] {
            XCTAssertNil(pair(context(prior), context(prior + " ")))
        }
    }

    func testReferenceSequences() {
        XCTAssertEqual(run(["ေ","က","ျ","ာ","င","်","း"]), [0x1000,0x103B,0x1031,0x102C,0x1004,0x103A,0x1038])
        XCTAssertEqual(run(["င","်","္","က"]), [0x1004,0x103A,0x1039,0x1000])
        XCTAssertEqual(run(["င်္","က"]), [0x1004,0x103A,0x1039,0x1000])
        XCTAssertEqual(run(["က","ေ","်"]), [0x1000,0x200C,0x1031,0x103A])
        XCTAssertEqual(run(["က","္","က"]), [0x1000,0x1039,0x1000])
    }
    func testMarkedDeletion() {
        var core = BurmeseComposition()
        core.append("ေ")
        XCTAssertEqual(core.text.unicodeScalars.map(\.value), [0x200C,0x1031])
        core.append("က")
        core.backspace()
        XCTAssertEqual(core.text, "က")
        core.backspace()
        XCTAssertTrue(core.isEmpty)
    }

    func testMyanSanCombiningOrdersProduceIdenticalScalars() {
        for marks in [["ိ","ု","့"], ["ိ","့","ု"], ["ု","ိ","့"],
                      ["ု","့","ိ"], ["့","ိ","ု"], ["့","ု","ိ"]] {
            XCTAssertEqual(run(["က"] + marks), [0x1000,0x102D,0x102F,0x1037])
        }
        for (keys, word) in [
            (["က","ိ","ု"], "ကို"), (["က","ု","ိ"], "ကို"),
            (["ခ","ြ","ံ","ု"], "ခြုံ"), (["ခ","ြ","ုံ"], "ခြုံ"),
            (["ေ","က","ွ","ြ","း"], "ကြွေး"), (["ေ","က","ြ","ွ","း"], "ကြွေး"),
            (["ပ","ု","ေ","ဏ","္","ဏ","း","မ"], "ပုဏ္ဏေးမ"),
            (["က","ှ","ွ","ျ"], "ကျွှ"), (["က","်","့"], "က့်"),
            (["က","ု","မ","ိ"], "ကုမိ"), (["က","ု","ု","ိ"], "ကို")
        ] {
            XCTAssertEqual(run(keys), word.unicodeScalars.map(\.value), keys.description)
        }
    }

    func testMyanSanLetterSequencesAndDirectKeys() {
        for (keys, expected) in [
            (["စ","ျ"], [0x1008]), (["ေ","စ","ျ"], [0x1008,0x1031]),
            (["ဥ","ီ"], [0x1026]), (["ေ","သ","ြ","ာ","်"], [0x102A]),
            (["ဈ"], [0x1008]), (["ဦ"], [0x1026]), (["ဪ"], [0x102A])
        ] {
            XCTAssertEqual(run(keys), expected.map(UInt32.init), keys.description)
        }
    }
    func testCommittedDeletionOnlyRestoresVerifiedCluster() {
        XCTAssertEqual(BurmeseDeletion.retainedScalars(before: "Aကျိ", afterHostDelete: "A"), "ကျ")
        XCTAssertEqual(BurmeseDeletion.retainedScalars(before: "ကေ", afterHostDelete: ""), "က")
        XCTAssertNil(BurmeseDeletion.retainedScalars(before: "Aကျိ", afterHostDelete: "Aကျ"))
        XCTAssertNil(BurmeseDeletion.retainedScalars(before: "ကျိ", afterHostDelete: "unrelated"))
        XCTAssertNil(BurmeseDeletion.retainedScalars(before: "x👩🏽‍💻", afterHostDelete: "x"))
    }

    func testBoundedHostDeletion() {
        XCTAssertEqual(BurmeseDeletion.removedSuffix(before: "xကေ", after: "xက"), "ေ")
        XCTAssertEqual(BurmeseDeletion.removedSuffix(before: "xကေ", after: "x"), "ကေ")
        XCTAssertEqual(BurmeseDeletion.removedSuffix(before: "xကေ", after: "wx"), "ကေ")
        XCTAssertNil(BurmeseDeletion.removedSuffix(before: "xကေ", after: "xကေ"))
        XCTAssertNil(BurmeseDeletion.removedSuffix(before: "xကေ", after: "other"))
    }
    func testCompletionOnlyAppendsMissingScalars() {
        XCTAssertTrue(Completions.matches(before: "Hi He", language: .english).contains(Completion(title:"Hello",suffix:"llo")))
        XCTAssertTrue(Completions.matches(before: "သူကျော", language: .burmese).contains(Completion(title:"ကျောင်း",suffix:"င်း")))
        XCTAssertTrue(Completions.matches(before: "unknownword", language: .english).isEmpty)
        XCTAssertTrue(Completions.matches(before: " ", language: .burmese).isEmpty)
    }
    func testEnglishReferenceHolds() {
        let rows = KeyboardLayout.letters(.english, shift: false)
        XCTAssertEqual(rows.map(\.count), [10, 9, 7])
        for (key, expected) in [(rows[0][2], "3"), (rows[1][0], "à"), (KeyboardLayout.period, ",")] {
            XCTAssertEqual(key.alternatives[key.defaultIndex], expected)
        }
        XCTAssertTrue(rows[0][2].alternatives.contains("é"))
    }

    func testEnglishCapitalizationUsesTheInsertionPointAndFieldMode() {
        for before in ["", "  ", "Hello. ", "Really?  ", "Done!” ", "ဟုတ်ပါတယ်။ ", "Hello\n", "Hi. “"] {
            XCTAssertTrue(EnglishCapitalization.sentences.shouldShift(before: before), before)
        }
        for before in ["a", "Hello ", "hello.", "3.14 ", "Say “", "example.com"] {
            XCTAssertFalse(EnglishCapitalization.sentences.shouldShift(before: before), before)
        }
        XCTAssertTrue(EnglishCapitalization.words.shouldShift(before: "First "))
        XCTAssertFalse(EnglishCapitalization.words.shouldShift(before: "Fir"))
        XCTAssertTrue(EnglishCapitalization.allCharacters.shouldShift(before: "ab"))
        XCTAssertFalse(EnglishCapitalization.none.shouldShift(before: ""))
    }

    func testEnglishWordsInBurmeseSentences() {
        let mode = EnglishCapitalization.sentences
        for prefix in ["ကျောင်း", "ကျောင်း ", "က၊", "ကို “", "ဒီမှာ App ", "ဒီမှာ App Store သုံး"] {
            XCTAssertTrue(mode.shouldShift(before: prefix), prefix)
        }
        XCTAssertTrue(mode.shouldShift(before: "Try ", after: " သုံးပါ"))
        for prefix in ["ကAp", "ဒီမှာ Don’", "ဒီမှာ Don'", "က။ This ", "က\nThis ", "က! This "] {
            XCTAssertFalse(mode.shouldShift(before: prefix), prefix)
        }
        XCTAssertFalse(mode.shouldShift(before: "Try ", after: "this. က"))
        XCTAssertTrue(EnglishCapitalization.words.shouldShift(before: "က"))
        XCTAssertFalse(EnglishCapitalization.none.shouldShift(before: "က "))
    }

    func testReferenceLayout() {
        let rows = KeyboardLayout.letters(.burmese, shift: false)
        XCTAssertEqual(rows.map(\.count), [10,10,10,8])
        XCTAssertEqual(rows[0][3].alternatives[rows[0][3].defaultIndex], "င်္")
        XCTAssertEqual(KeyboardLayout.shifted[2][3], "္")
        for row in rows.indices {
            for col in rows[row].indices {
                let key = rows[row][col]
                XCTAssertTrue(key.alternatives.indices.contains(key.defaultIndex))
                if row > 0 { XCTAssertEqual(key.alternatives.first, KeyboardLayout.shifted[row][col]) }
            }
        }
    }
}
