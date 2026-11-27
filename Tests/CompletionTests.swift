import Foundation
import XCTest
@testable import MBoardCore

final class CompletionTests: XCTestCase {
    func testEnglishCorrectionAndPhraseCandidates() throws {
        func titles(_ left: String, _ right: String, _ guesses: [String] = []) throws -> [String] {
            let token = try XCTUnwrap(EnglishToken(before: left, after: right))
            return Completions.englishSuggestions(token, apple: [], guesses: guesses, learned: [],
                                                  allCaps: false).map(\.title)
        }
        XCTAssertEqual(try titles("say he", "lo!"), ["hello"])
        XCTAssertEqual(try titles("", "Helo!").first, "Hello")
        XCTAssertTrue(try titles("say ", "hello").isEmpty)
        XCTAssertEqual(try titles("THANKYOU", "").first, "THANK YOU")
        XCTAssertEqual(try titles("see", "you").first, "see you")
        XCTAssertEqual(try titles("gotit", "", ["got it", "go tit"]), ["got it"])
        XCTAssertFalse(try titles("already", "").contains("al ready"))
        for (left, right) in [("me@thank", "you"), ("www.thankyou", ""), ("see_", "you"),
                              ("https://a/", "thankyou"), ("thankyou2", "")] {
            XCTAssertNil(EnglishToken(before: left, after: right))
        }
        XCTAssertEqual(Completions.selectedBurmese("ကျော", learned: []).first?.title, "ကျောင်း")
        XCTAssertTrue(Completions.selectedBurmese("သူ ကျော", learned: []).isEmpty)
    }

    func testCorrectionsWhileTypingKeepPrefixesAndOnlyEditOnTap() throws {
        func suggestions(_ prefix: String, apple: [String] = [], guesses: [String] = [],
                         learned: [String] = []) throws -> [Completion] {
            let token = try XCTUnwrap(EnglishToken(before: prefix, after: ""))
            return Completions.englishSuggestions(token, apple: apple, guesses: guesses, learned: learned, allCaps: false)
        }
        let correction = try XCTUnwrap(suggestions("Teh").first)
        XCTAssertEqual(correction.title, "The")
        XCTAssertEqual(correction.action, .replace(try XCTUnwrap(EnglishToken(before: "Teh", after: ""))))
        XCTAssertEqual(try suggestions("helo", guesses: ["he lo", "hello"]).first?.title, "hello")
        XCTAssertEqual(try suggestions("freind", guesses: ["fried", "friend"]).first?.title, "friend")
        let partial = try suggestions("hel", apple: ["hello", "help", "helmet"], guesses: ["hell", "he'll"])
        XCTAssertEqual(partial.map(\.title), ["hello", "help", "he'll"])
        XCTAssertEqual(try suggestions("wondr", guesses: ["wonder"]).first?.title, "wonder")
        XCTAssertEqual(try suggestions("squirre", guesses: ["squirrel"]).first?.action, .append)
        XCTAssertEqual(try suggestions("teh", learned: ["Teh"]).first?.title, "the")
        XCTAssertFalse(try suggestions("Teh", learned: ["Teh"]).contains { $0.title == "The" })
    }

    func testMissingApostrophesAndAmbiguousWordsWithoutSystemGuesses() throws {
        func results(_ text: String, apple: [String] = []) throws -> [Completion] {
            let token = try XCTUnwrap(EnglishToken(before: text, after: ""))
            return Completions.englishSuggestions(token, apple: apple, guesses: [], learned: [], allCaps: false)
        }
        for (literal, intended) in [("Im", "I'm"), ("im", "I'm"), ("Ive", "I've"), ("Youre", "You're"),
                                    ("dont", "don't"), ("theyre", "they're"), ("shouldve", "should've")] {
            XCTAssertEqual(try results(literal).first?.title, intended)
        }
        for (literal, intended) in [("well", "we'll"), ("were", "we're"), ("its", "it's"), ("ill", "I'll")] {
            let choices = try results(literal)
            XCTAssertTrue(choices.dropFirst().contains { $0.title == intended })
            XCTAssertNotEqual(choices.first?.title, intended)
        }
        let alternatives = try results("well", apple: ["wellness", "wellbeing", "wellies"])
        XCTAssertEqual(alternatives.map(\.title), ["wellness", "wellbeing", "we'll"])
        let keep = try XCTUnwrap(results("well").first)
        XCTAssertEqual(keep.action, .keep)
        let caret = HostContext(document: UUID(), before: "I'm well", after: "", selection: nil)
        XCTAssertTrue(keep.confirmed(from: caret, to: caret))
        let other = HostContext(document: UUID(), before: "I'm well", after: "", selection: nil)
        XCTAssertFalse(keep.confirmed(from: caret, to: other))
    }

    func testPersonalNameRemainsAvailableAlongsideCommonTypo() throws {
        let token = try XCTUnwrap(EnglishToken(before: "say teh", after: "!"))
        let results = Completions.englishSuggestions(token, apple: [], guesses: [], learned: ["Teh"],
                                                     allCaps: false, personalCase: ["teh": "Teh"])
        XCTAssertEqual(results.prefix(2).map(\.title), ["the", "Teh"])
        XCTAssertTrue(results[1].learned)
    }

    func testTokenInspectionBoundsAndClosingQuotes() throws {
        XCTAssertNil(EnglishToken(before: String(repeating: "-", count: 97) + "Im", after: ""))
        XCTAssertNil(EnglishToken(before: String(repeating: "a.", count: 10_000) + "Im", after: ""))
        XCTAssertNil(EnglishToken(before: "Im", after: String(repeating: "b", count: 10_000)))
        XCTAssertNil(EnglishToken(before: "say ‘Im’", after: ""))
        XCTAssertNil(EnglishToken(before: "say 'Im'", after: ""))
        XCTAssertEqual(EnglishToken(before: "say ‘Im", after: "’")?.word, "Im")
        XCTAssertEqual(EnglishToken(before: "say don’", after: "")?.word, "don’")
    }

    func testPersonalRankingUsesConfirmedRepetitionAndPrecedingWord() throws {
        let time = Date()
        var history = LearnedWords()
        func type(_ word: String, _ previous: String) {
            history.record(word, language: .english, previous: previous, typed: true, intentionalCase: true, at: time)
        }
        type("Yangon", "visit")
        type("Yangon", "visit")
        XCTAssertFalse(history.ranked(for: .english, at: time).contains("Yangon"))
        type("Yangon", "visit")
        for _ in 0..<5 { type("yank", "please") }
        let token = try XCTUnwrap(EnglishToken(before: "visit yan", after: ""))
        XCTAssertEqual(token.previousWord(in: "they visit yan"), "visit")
        XCTAssertNil(token.previousWord(in: "visit. yan"))
        XCTAssertNil(token.previousWord(in: "visit\n yan"))
        func titles(_ previous: String?) -> [Completion] {
            let ranked = history.ranking(for: .english, previous: previous, at: time)
            return Completions.englishSuggestions(token, apple: [], guesses: [], learned: ranked.words,
                                                  allCaps: false, personalCase: ranked.personalCase)
        }
        XCTAssertEqual(titles(nil).first?.title, "yank")
        XCTAssertEqual(titles("VISIT").first, Completion(title: "Yangon", suffix: "", learned: true, action: .replace(token)))
        history.forget("visit", language: .english)
        XCTAssertEqual(titles("visit").first?.title, "yank")
        history.forget("Yangon", language: .english)
        XCTAssertFalse(titles(nil).contains { $0.title == "Yangon" })
        type("morning", "good")
        XCTAssertFalse(history.ranked(for: .english, at: time).contains("morning"))
        type("morning", "good")
        XCTAssertTrue(history.ranked(for: .english, at: time).contains("morning"))
        for _ in 0..<5 { type("teh", "saw") }
        XCTAssertFalse(history.ranked(for: .english, at: time).contains("teh"))
        for _ in 0..<3 { type("Teh", "hello") }
        XCTAssertTrue(history.ranked(for: .english, at: time).contains("Teh"))
        history.record("more", language: .english, at: time)
        XCTAssertLessThan(try XCTUnwrap(history.ranked(for: .english, at: time).firstIndex(of: "more")),
                          try XCTUnwrap(history.ranked(for: .english, at: time).firstIndex(of: "morning")))
    }

    func testLearningTracksOwnedKeysBoundariesAndUndo() {
        let doc = UUID()
        func context(_ text: String) -> HostContext { HostContext(document: doc, before: text, after: "", selection: nil) }
        var tracker = EnglishTypingHistory()
        var buffer = "pasted "
        var entries = [EnglishTypingHistory.Entry]()
        func type(_ keys: String) {
            for key in keys {
                let before = context(buffer)
                buffer.append(key)
                if let entry = tracker.inserted(String(key), from: before, to: context(buffer)) { entries.append(entry) }
            }
        }
        type("good mornx ")
        XCTAssertEqual(entries.map(\.word), ["good"])
        XCTAssertNil(entries.first?.previous)
        for _ in 0..<2 {
            let before = context(buffer)
            buffer.removeLast()
            tracker.deleted(from: before, to: context(buffer))
        }
        type("ing ")
        let morning = tracker.settled(at: context(buffer))
        XCTAssertEqual(morning?.word, "morning")
        XCTAssertEqual(morning?.previous, "good")
        XCTAssertNil(tracker.settled(at: context(buffer)))
        type("again. next ")
        XCTAssertEqual(entries.map(\.word), ["good", "again"])
        XCTAssertEqual(entries.last?.previous, "morning")
        XCTAssertNil(tracker.finish()?.previous)
        entries = []
        type("host.example user@example.com https://site.org/path ")
        XCTAssertTrue(entries.isEmpty)
        XCTAssertNil(tracker.finish())
        type("partial")
        buffer = "changed"
        type("x ")
        XCTAssertNil(tracker.finish())
        XCTAssertNil(tracker.inserted("t", from: context(buffer), to: context(buffer)))
    }

    func testReadsLegacyHistoryAndPersistsTypedPairCounts() async throws {
        let suite = "com.eimg.mboard.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = ["choices": [["word": "older", "language": Language.english.rawValue,
                                    "weight": 1, "lastPicked": Date().timeIntervalSinceReferenceDate]]]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "learnedCompletions.v1")
        let store = LearnedWordStore(defaults: defaults)
        for _ in 0..<3 { store.record("Yonder", language: .english, previous: "over", typed: true, intentionalCase: true) }
        let general = await store.ranked(for: .english)
        XCTAssertEqual(general, ["older", "Yonder"])
        let reopened = LearnedWordStore(defaults: defaults)
        let contextual = await reopened.ranking(for: .english, previous: "over")
        XCTAssertEqual(contextual.words, ["Yonder", "older"])
        XCTAssertEqual(contextual.personalCase["yonder"], "Yonder")
        reopened.clear()
        let cleared = await reopened.ranking(for: .english, previous: "over")
        XCTAssertTrue(cleared.words.isEmpty)
        XCTAssertNil(defaults.data(forKey: "learnedCompletions.v1"))
    }

    func testAcceptanceAndDeferredSpaceTrainEachWordOnce() {
        let document = UUID()
        func at(_ left: String) -> HostContext { HostContext(document: document, before: left, after: "", selection: nil) }
        var history = EnglishTypingHistory()
        XCTAssertNil(history.inserted("g", from: at(""), to: at("g")))
        XCTAssertNil(history.accepted("good", from: at("g"), to: at("good")))
        XCTAssertNil(history.inserted(" m", from: at("good"), to: at("good m")))
        XCTAssertEqual(history.accepted("morning", from: at("good m"), to: at("good morning")), "good")
        XCTAssertNil(history.inserted(" ", from: at("good morning"), to: at("good morning ")))
        XCTAssertNil(history.finish())
    }

    func testJoinedPhraseAppearsWhileTypingTheSecondWord() throws {
        func candidates(_ left: String, _ right: String = "", allCaps: Bool = false) throws -> [String] {
            let token = try XCTUnwrap(EnglishToken(before: left, after: right))
            let ranked = Completions.englishSuggestions(token, apple: ["thankyou"], guesses: ["thank you"],
                                                        learned: ["thankyou"], allCaps: allCaps)
            if let immediate = Completions.joinedPhrase(for: token, allCaps: allCaps) {
                XCTAssertEqual(ranked.first, immediate)
                XCTAssertEqual(ranked.filter { $0.title == immediate.title }.count, 1)
            }
            return ranked.map(\.title)
        }
        for prefix in ["thanky", "thankyo", "thankyou"] {
            XCTAssertEqual(try candidates("say " + prefix).first, "thank you")
        }
        XCTAssertEqual(try candidates("Thankyo").first, "Thank you")
        XCTAssertEqual(try candidates("THANKY").first, "THANK YOU")
        XCTAssertEqual(try candidates("thankyo", allCaps: true).first, "THANK YOU")
        XCTAssertEqual(try candidates("seey").first, "see you")
        XCTAssertEqual(try candidates("seeya").first, "see ya")
        for (left, right) in [("thank", ""), ("thanks", ""), ("thankyo", "x"), ("thank", "yo")] {
            XCTAssertFalse(try candidates(left, right).contains("thank you"))
        }
    }

    func testDeferredSpaceBelongsToTheAcceptedCaret() {
        let doc = UUID()
        func at(_ left: String, _ right: String = "") -> HostContext {
            HostContext(document: doc, before: left, after: right, selection: nil)
        }
        var pending = DeferredEnglishSpace()
        let end = at("say hello")
        for key in ["w", ",", " ", "’", "က", "🥰", "\n"] {
            pending.remember(end, accepted: "hello")
            XCTAssertEqual(pending.consume(before: key, at: end), key == "w")
            XCTAssertFalse(pending.consume(before: "x", at: end))
        }
        pending.remember(end, accepted: "hello")
        pending.observe(at("say hel", "lo"))
        XCTAssertFalse(pending.consume(before: "w", at: end))
        pending.remember(at("hello", ","), accepted: "hello")
        XCTAssertFalse(pending.applies(at: at("hello", ",")))
    }

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
        for right in ["llo", "'t", "’ll", "é"] { XCTAssertEqual(EnglishToken(before: "he", after: right)?.right, right) }
        for right in ["", " ", ".", "ကျောင်း"] { XCTAssertEqual(EnglishToken(before: "he", after: right)?.right, "") }
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
