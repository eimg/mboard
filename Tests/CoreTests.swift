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
    func testCommittedDeletionOnlyRestoresVerifiedCluster() {
        XCTAssertEqual(BurmeseDeletion.retainedScalars(before: "Aကျိ", afterHostDelete: "A"), "ကျ")
        XCTAssertEqual(BurmeseDeletion.retainedScalars(before: "ကေ", afterHostDelete: ""), "က")
        XCTAssertNil(BurmeseDeletion.retainedScalars(before: "Aကျိ", afterHostDelete: "Aကျ"))
        XCTAssertNil(BurmeseDeletion.retainedScalars(before: "ကျိ", afterHostDelete: "unrelated"))
        XCTAssertNil(BurmeseDeletion.retainedScalars(before: "x👩🏽‍💻", afterHostDelete: "x"))
    }

    func testInlineCompositionReplacesOnlyTheChangedScalars() {
        let prebase = BurmeseComposition.edit(from: "\u{200C}ေ", to: "ကေ")
        XCTAssertEqual(prebase.remove, "\u{200C}ေ")
        XCTAssertEqual(prebase.insert, "ကေ")
        let medial = BurmeseComposition.edit(from: "ကေ", to: "ကျေ")
        XCTAssertEqual(medial.remove, "ေ")
        XCTAssertEqual(medial.insert, "ျေ")
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
