import Foundation
import XCTest
@testable import MBoardCore

@MainActor
private final class EditingHost: BurmeseEditHost {
    var document = UUID()
    var left: String
    var right: String
    var marked: String?
    var selected: String?
    var limit = 100
    var deletesScalar = false
    var hidesLeft = false
    var excludesMark = false
    var rejectedInput: String?
    var hidesLeftAfterDeletion = false
    private(set) var deletions = 0

    init(_ left: String = "", right: String = "") {
        self.left = left
        self.right = right
    }

    var text: String { left + (selected ?? marked ?? "") + right }
    var hasText: Bool { !text.isEmpty }
    var context: HostContext {
        HostContext(document: document, before: hidesLeft ? nil : String((left + (excludesMark ? "" : (marked ?? ""))).suffix(limit)),
                    after: String(right.prefix(limit)), selection: marked == nil ? selected : nil)
    }

    func mark(_ text: String) {
        selected = nil
        marked = text
    }
    func unmark() {
        if selected == nil { left += marked ?? "" }
        marked = nil
    }
    func insert(_ text: String) {
        marked = nil
        selected = nil
        if text != rejectedInput { left += text }
    }
    func moveCaret(byUTF16 offset: Int) {
        let text = (left + right) as NSString
        let position = min(max(0, left.utf16.count + offset), text.length)
        left = text.substring(to: position)
        right = text.substring(from: position)
    }
    func deleteBackward() {
        deletions += 1
        if selected != nil { selected = nil }
        else if !left.isEmpty {
            if deletesScalar { left.unicodeScalars.removeLast() }
            else { left.removeLast() }
        }
        hidesLeft = hidesLeftAfterDeletion
    }
}

final class HostEditingTests: XCTestCase {
    @MainActor func testEnglishReplacementPreservesNeighborsAndEndsAtWordBoundary() async throws {
        for (left, right, result) in [("he", "lo", "hello"), ("", "helo", "hello"),
                                     ("thankyo", "", "thank you"), ("thanky", "", "thank you"),
                                     ("thankyou", "", "thank you"), ("se", "eyou", "see you"),
                                     ("ta", "ht", "that"), ("spel", "lingg", "spelling")] {
            let host = EditingHost("မင်္ဂလာ🥰 " + left, right: right + ", too.")
            let context = host.context
            let token = try XCTUnwrap(EnglishToken(before: host.left, after: host.right))
            XCTAssertTrue(token.replace(with: result, at: context, in: host))
            XCTAssertEqual(host.left, "မင်္ဂလာ🥰 " + result)
            XCTAssertEqual(host.right, ", too.")
            XCTAssertFalse(token.replace(with: result, at: context, in: host))
        }
    }

    @MainActor func testEnglishCorrectionRestoresTextWhenHostRejectsInsertion() async throws {
        for (left, right, target, rejected) in [("go ba", "d!", "bed", "e"),
                                                ("go aab", "!", "aaa", "a")] {
            let host = EditingHost(left, right: right)
            host.rejectedInput = rejected
            let token = try XCTUnwrap(EnglishToken(before: host.left, after: host.right))
            XCTAssertFalse(token.replace(with: target, at: host.context, in: host))
            XCTAssertEqual(host.left, left)
            XCTAssertEqual(host.right, right)
            XCTAssertEqual(host.deletions, 0)
        }
    }

    @MainActor func testReplacementCanBeLongerThanTheVisibleHostContext() async throws {
        let host = EditingHost("go bad", right: "!")
        host.limit = 3
        let token = try XCTUnwrap(EnglishToken(before: host.context.before ?? "", after: "!"))
        XCTAssertTrue(token.replace(with: "better", at: host.context, in: host))
        XCTAssertEqual(host.left, "go better")
        XCTAssertEqual(host.right, "!")
    }

    func testSuggestionConfirmationRequiresTheExpectedHostEdit() throws {
        let document = UUID()
        func context(_ left: String?, _ right: String?, _ selected: String? = nil) -> HostContext {
            HostContext(document: document, before: left, after: right, selection: selected)
        }
        let hello = Completion(title: "hello", suffix: "lo")
        let prefix = context("say hel", "!")
        XCTAssertTrue(hello.confirmed(from: prefix, to: context("ello", "!")))
        XCTAssertFalse(hello.confirmed(from: prefix, to: prefix))
        XCTAssertFalse(hello.confirmed(from: prefix, to: context("odd hello", "!")))
        XCTAssertFalse(hello.confirmed(from: prefix, to: context("say hello", "?")))
        XCTAssertFalse(hello.confirmed(from: prefix, to: context(nil, "!")))
        XCTAssertFalse(hello.confirmed(from: prefix, to: context("say hello", "!", "x")))
        XCTAssertFalse(hello.confirmed(from: prefix, to: HostContext(document: UUID(), before: "say hello", after: "!", selection: nil)))

        let token = try XCTUnwrap(EnglishToken(before: "say he", after: "lo!"))
        let correction = Completion(title: "hello", suffix: "", action: .replace(token))
        XCTAssertTrue(correction.confirmed(from: context("say he", "lo!"), to: context("say hello", "!")))
        let selection = Completion(title: "ကျောင်း", suffix: "", action: .selection)
        XCTAssertTrue(selection.confirmed(from: context("သူ", "မှာ", "ကျော"), to: context("သူကျောင်း", "မှာ")))
    }

    @MainActor func testDeferredSpaceAfterCorrectionsInBoundedHost() throws {
        for (input, title) in [("thankyo", "thank you"), ("im", "I'm")] {
            let host = EditingHost("say " + input)
            host.limit = input.count
            let original = host.context
            let token = try XCTUnwrap(EnglishToken(before: original.before ?? "", after: ""))
            let candidate = Completion(title: title, suffix: "", action: .replace(token))
            XCTAssertTrue(token.replace(with: title, at: original, in: host))
            XCTAssertTrue(candidate.confirmed(from: original, to: host.context))
            XCTAssertEqual(host.text, "say " + title)
            var spacing = DeferredEnglishSpace()
            spacing.remember(host.context, accepted: title)
            host.limit = 100
            spacing.observe(host.context)
            XCTAssertTrue(spacing.consume(before: "f", at: host.context))
            XCTAssertFalse(spacing.consume(before: "f", at: host.context))
        }
    }

    @MainActor func testVowelOrdersWithSlidingAndDisappearingContext() async {
        let prefix = String(repeating: "paragraph ", count: 44)
        for excludesMark in [false, true] {
            for limit in [2, 64, 1000] {
                for scalarDeletion in [false, true] {
                    for taps in [["က", "ု", "ိ"], ["က", "ိ", "ု"]] {
                        let host = EditingHost(prefix, right: " end")
                        host.limit = limit
                        host.excludesMark = excludesMark
                        host.deletesScalar = scalarDeletion
                        host.hidesLeftAfterDeletion = true
                        var editor = BurmeseHostEditor()
                        for tap in taps { editor.type(tap, in: host) }
                        editor.finish(in: host)
                        XCTAssertEqual(host.left.unicodeScalars.map(\.value), (prefix + "ကို").unicodeScalars.map(\.value))
                        XCTAssertEqual(host.right, " end")
                        XCTAssertEqual(host.deletions, 0)
                    }
                }
            }
        }
    }

    @MainActor func testRepeatedContextUpdatesAtTheSameCaret() async {
        let prefix = String(repeating: "paragraph ", count: 44)
        let host = EditingHost(prefix)
        host.excludesMark = true
        var editor = BurmeseHostEditor()
        editor.type("က", in: host)
        editor.type("ု", in: host)
        for width in [64, 64, 96, 32] {
            host.limit = width
            editor.check(host.context, in: host)
        }
        editor.type("ိ", in: host)
        XCTAssertEqual(host.left, prefix + "ကို")
    }

    @MainActor func testReplacementInAFieldThatFiltersZeroWidthSpace() async {
        let host = EditingHost("A ", right: " end")
        host.rejectedInput = "\u{200B}"
        var editor = BurmeseHostEditor()
        for tap in ["က", "ိ", "ု", "ီ"] { editor.type(tap, in: host) }
        XCTAssertEqual(host.text, "A ကိုီ end")
        XCTAssertEqual(host.deletions, 0)
    }

    @MainActor func testDeclinedReplacementKeepsExistingText() async {
        let host = EditingHost("A ", right: " end")
        var editor = BurmeseHostEditor()
        editor.type("စ", in: host)
        host.rejectedInput = "ဈ"
        editor.type("ျ", in: host)
        XCTAssertEqual(host.left, "A စ")
        XCTAssertEqual(host.right, " end")
    }

    @MainActor func testReplacingAnOwnedVowelWhenDeletionHidesLeftContext() async {
        for scalarDeletion in [false, true] {
            let host = EditingHost("A 👩🏽‍💻 ", right: " end")
            host.deletesScalar = scalarDeletion
            host.hidesLeftAfterDeletion = true
            var editor = BurmeseHostEditor()
            for tap in ["က", "ိ", "ု", "ီ"] { editor.type(tap, in: host) }
            editor.finish(in: host)
            XCTAssertEqual(host.text, "A 👩🏽‍💻 ကီု end")
            XCTAssertEqual(host.right, " end")
        }
    }

    @MainActor func testDeleteCommittedPlaceholderPreservesNeighbor() async {
        for prefix in ["A", "A ", "👩🏽‍💻"] {
            for scalarDeletion in [false, true] {
                let host = EditingHost(prefix + "\u{200C}ေ", right: " end")
                host.deletesScalar = scalarDeletion
                var editor = BurmeseHostEditor()
                editor.backspace(in: host)
                XCTAssertEqual(host.text, prefix + "\u{200C} end")
                editor.backspace(in: host)
                XCTAssertEqual(host.text, prefix + " end")
            }
        }
    }

    @MainActor func testRecordedGboardTapsThroughHostEditor() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "GboardBurmese", withExtension: "tsv"))
        let cases = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").filter { !$0.hasPrefix("#") }
        XCTAssertEqual(cases.count, 458)
        for line in cases {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 2 else { return XCTFail("Malformed Gboard fixture: \(line)") }
            let taps = fields[0].unicodeScalars.split(separator: " ").map(String.init)
            let expected = fields[1] == "{empty}" ? "" : fields[1].replacingOccurrences(of: "{ZWNJ}", with: "\u{200C}")
            for scalarDeletion in [false, true] {
                let host = EditingHost("A ", right: " Z")
                host.deletesScalar = scalarDeletion
                var editor = BurmeseHostEditor()
                for tap in taps {
                    if tap == "⌫" { editor.backspace(in: host) }
                    else { editor.type(tap, in: host) }
                }
                editor.finish(in: host)
                XCTAssertEqual(host.text.unicodeScalars.map(\.value),
                               ("A " + expected + " Z").unicodeScalars.map(\.value), String(fields[0]))
            }
        }
    }

    @MainActor func testBackspaceInsideUnfinishedStackAfterSpace() async {
        let host = EditingHost("မ ", right: " end")
        var editor = BurmeseHostEditor()
        for key in ["ေ", "က", "္"] { editor.type(key, in: host) }
        // UIKit can delete its entire native marked range on the next Backspace.
        XCTAssertNil(host.marked)
        editor.backspace(in: host)
        XCTAssertEqual(host.text.unicodeScalars.map(\.value), "မ \u{200C}ေက end".unicodeScalars.map(\.value))
    }

    @MainActor func testReorderInBoundedAndUnavailableContext() async {
        for hidden in [true, false] {
            let host = EditingHost("wx", right: "z")
            host.limit = 1
            host.hidesLeft = hidden
            var editor = BurmeseHostEditor()
            for key in ["ေ", "က", "ျ", "ာ"] { editor.type(key, in: host) }
            XCTAssertEqual(host.text, "wxကျောz")
            editor.finish(in: host)
            XCTAssertNil(host.marked)
            XCTAssertEqual(host.deletions, 0)
        }
    }

    @MainActor func testMyanSanReordersOnlyTheActiveSegment() async {
        let host = EditingHost("old ကု ", right: " tail")
        host.limit = 1
        var editor = BurmeseHostEditor()
        for key in ["က", "ု", "ိ", "ပ", "ု", "ေ", "ဏ", "္", "ဏ", "း", "မ"] {
            editor.type(key, in: host)
        }
        XCTAssertEqual(host.text.unicodeScalars.map(\.value),
                       "old ကု ကိုပုဏ္ဏေးမ tail".unicodeScalars.map(\.value))
        XCTAssertEqual(host.deletions, 0)
        editor.backspace(in: host)
        XCTAssertEqual(host.text, "old ကု ကိုပုဏ္ဏေး tail")
    }

    @MainActor func testMyanSanOrdersInDifferentHostEditors() async {
        for hidden in [true, false] {
            for scalarDeletion in [true, false] {
                let host = EditingHost("A ", right: " Z")
                host.hidesLeft = hidden
                host.deletesScalar = scalarDeletion
                var editor = BurmeseHostEditor()
                for key in ["က","ု","ိ","မ","ြ","့","ု","ိ","စ","ျ","ဥ","ီ"] {
                    editor.type(key, in: host)
                }
                editor.finish(in: host)
                XCTAssertEqual(host.text.unicodeScalars.map(\.value), "A ကိုမြို့ဈဦ Z".unicodeScalars.map(\.value))
            }
        }
    }

    @MainActor func testCommittedDeletionAtBoundedCaretAndSelection() async {
        for scalar in [true, false] {
            let host = EditingHost("wxကျိ", right: "z")
            host.limit = 2
            host.deletesScalar = scalar
            var editor = BurmeseHostEditor()
            editor.backspace(in: host)
            XCTAssertEqual(host.text, "wxကျz")
            host.selected = "abc"
            editor.backspace(in: host)
            XCTAssertEqual(host.text, "wxကျz")
            XCTAssertEqual(host.deletions, 2)
        }
        let host = EditingHost("ကျိ", right: "z")
        host.hidesLeftAfterDeletion = true
        var editor = BurmeseHostEditor()
        editor.backspace(in: host)
        XCTAssertEqual(host.text, "z") // No evidence to reconstruct a host deletion.
    }

    @MainActor func testBackspaceLetsHostDeleteSelectedPendingVowel() async {
        let host = EditingHost("x", right: "z")
        var editor = BurmeseHostEditor()
        editor.type("ေ", in: host)
        editor.type("က", in: host)
        if host.marked == nil { host.left = "x" } // Move the selected range out of the left context.
        host.selected = "ကေ"
        let priorDeletions = host.deletions
        editor.backspace(in: host)
        XCTAssertEqual(host.text, "xz")
        XCTAssertEqual(host.deletions - priorDeletions, 1)
    }

    @MainActor func testExternalEditAndDocumentSwitchDiscardOwnership() async {
        let host = EditingHost()
        var editor = BurmeseHostEditor()
        editor.type("ေ", in: host)
        host.unmark()
        host.left = "new"
        editor.type("က", in: host)
        XCTAssertEqual(host.text, "newက")
        editor.type("ေ", in: host)
        host.document = UUID()
        host.left = "other"
        host.marked = nil
        editor.type("ျ", in: host)
        XCTAssertEqual(host.text, "otherျ")
    }
}
