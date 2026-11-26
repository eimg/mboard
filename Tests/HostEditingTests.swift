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
    var hidesLeftAfterDeletion = false
    private(set) var deletions = 0

    init(_ left: String = "", right: String = "") {
        self.left = left
        self.right = right
    }

    var text: String { left + (selected ?? marked ?? "") + right }
    var hasText: Bool { !text.isEmpty }
    var context: HostContext {
        HostContext(document: document, before: hidesLeft ? nil : String((left + (marked ?? "")).suffix(limit)),
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
        left += text
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
        editor.backspace(in: host)
        XCTAssertEqual(host.text, "xz")
        XCTAssertEqual(host.deletions, 1)
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
