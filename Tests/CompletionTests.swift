import Foundation
import XCTest
@testable import MBoardCore

final class CompletionTests: XCTestCase {
    func testBurmeseSuggestionsRespectTextOnBothSidesOfCaret() {
        func titles(after right: String) -> [String] {
            Completions.matches(before: "သူကျော", after: right, language: .burmese).map(\.title)
        }
        XCTAssertTrue(titles(after: "င်း").isEmpty)
        XCTAssertTrue(titles(after: "င်းတက်").isEmpty)
        XCTAssertFalse(titles(after: "သား").contains("ကျောင်းသား"))
        XCTAssertTrue(titles(after: "်း").isEmpty)
        for right in ["", " ", "တက်", "ငယ်", "သား"] {
            XCTAssertTrue(titles(after: right).contains("ကျောင်း"), right)
        }
    }

    func testEnglishSourcesPreservePrefixAndMergeWithoutDuplicates() {
        let results = Completions.matches(before: "say he", language: .english,
                                         apple: ["he", "hey", "HEY", "he's", "her"])
        XCTAssertEqual(results.map(\.title), ["hey", "he's", "hello"])
        for (typed, expected) in [("don’", "don’t"), ("don'", "don't"), ("I’", "I’ll"), ("DON’", "DON’T")] {
            let matches = Completions.matches(before: "say " + typed, language: .english, apple: ["don't", "I'll"])
            XCTAssertEqual(matches.first?.title, expected)
            XCTAssertEqual(typed + (matches.first?.suffix ?? ""), expected)
        }
        XCTAssertTrue(Completions.matches(before: "‘", language: .english).isEmpty)
    }

    func testEnglishCaretBoundariesAndLearnedCase() {
        for right in ["llo", "'t", "’ll", "é"] { XCTAssertTrue(Completions.continuesEnglishWord(right)) }
        for right in ["", " ", ".", "ကျောင်း"] { XCTAssertFalse(Completions.continuesEnglishWord(right)) }
        for (prefix, expected) in [("he", "hello"), ("He", "Hello"), ("HE", "HELLO")] {
            XCTAssertEqual(Completions.matches(before: prefix, language: .english, learned: ["HELLO"]).first?.title, expected)
        }
        XCTAssertEqual(Completions.matches(before: "iP", language: .english, apple: ["iPhone"],
                                           learned: ["IPHONE"]).first?.title, "iPhone")
        XCTAssertEqual(Completions.matches(before: "H", language: .english, learned: ["hello"], allCaps: true).first?.title, "HELLO")
    }

    func testBundledICUAndConversationalBurmese() {
        XCTAssertTrue(Completions.matches(before: "ကီလိုဂရ", language: .burmese).contains(Completion(title: "ကီလိုဂရမ်", suffix: "မ်")))
        let phrases = Completions.matches(before: "အဆင်ပြေ", language: .burmese)
        XCTAssertTrue(phrases.contains(Completion(title: "အဆင်ပြေလား", suffix: "လား")))
        XCTAssertTrue(phrases.contains(Completion(title: "အဆင်ပြေပါတယ်", suffix: "ပါတယ်")))
        let learned = Completions.matches(before: "သူကျော", language: .burmese, learned: ["ကျောင်းသား"])
        XCTAssertEqual(learned.first, Completion(title: "ကျောင်းသား", suffix: "င်းသား", learned: true))
        XCTAssertEqual("သူကျော" + (learned.first?.suffix ?? ""), "သူကျောင်းသား")
        XCTAssertEqual(Set(learned.map(\.title)).count, learned.count)
        XCTAssertLessThanOrEqual(learned.count, 3)
    }

    func testRepeatedAndRecentPicksOutrankOlderPicks() {
        var history = LearnedWords()
        let t = Date(timeIntervalSince1970: 0)
        history.record("help", language: .english, at: t)
        history.record("Help", language: .english, at: t)
        history.record("hey", language: .english, at: t.addingTimeInterval(60))
        XCTAssertEqual(history.ranked(for: .english, at: t.addingTimeInterval(61)), ["Help", "hey"])
        let later = t.addingTimeInterval(100 * 86_400)
        history.record("hey", language: .english, at: later)
        XCTAssertEqual(history.ranked(for: .english, at: later), ["hey"])
        XCTAssertTrue(history.ranked(for: .burmese, at: later).isEmpty)
    }

    func testStorePersistsOnlyPicksAndForgetsInOrder() async throws {
        let suite = "com.eimg.mboard.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LearnedWordStore(defaults: defaults)
        store.record("he’ll", language: .english)
        store.record("ကျောင်းသား", language: .burmese)
        let ranked = await store.ranked(for: .english)
        XCTAssertEqual(ranked, ["he’ll"])
        let reopened = LearnedWordStore(defaults: defaults)
        let persisted = await reopened.ranked(for: .burmese)
        XCTAssertEqual(persisted, ["ကျောင်းသား"])
        reopened.forget("HE'LL", language: .english)
        let forgotten = await reopened.ranked(for: .english)
        XCTAssertTrue(forgotten.isEmpty)
        let retained = await reopened.ranked(for: .burmese)
        XCTAssertEqual(retained, ["ကျောင်းသား"])
        reopened.clear()
        let cleared = await reopened.ranked(for: .burmese)
        XCTAssertTrue(cleared.isEmpty)
        let fresh = await LearnedWordStore(defaults: defaults).ranked(for: .english)
        XCTAssertTrue(fresh.isEmpty)
    }
}
