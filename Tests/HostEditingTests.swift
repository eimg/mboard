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
