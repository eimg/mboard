import Foundation

/// Only the current segment belongs to the keyboard. The caller discards
/// ownership at syllable boundaries and on external edits.
struct BurmeseComposition {
    private(set) var text = ""
    private var vowelAwaitingBase = false

    var isEmpty: Bool { text.isEmpty }

    static func canCompose(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first else { return false }
        return (0x1000...0x103F).contains(first.value) || (0x1050...0x1059).contains(first.value)
    }

    func startsNewSegment(_ key: String) -> Bool {
        guard !text.isEmpty else { return false }
        if key == "ေ" { return true }
        return key.unicodeScalars.first.map(Self.isBase) == true && !vowelAwaitingBase && text.unicodeScalars.last?.value != 0x1039
    }

    private static func isBase(_ scalar: Unicode.Scalar) -> Bool {
        return (0x1000...0x102A).contains(scalar.value) || scalar.value == 0x103F
    }

    mutating func append(_ key: String) {
        if key == "ေ" {
            text += "\u{200C}ေ"
            vowelAwaitingBase = true
            return
        }
        for scalar in key.unicodeScalars {
            append(scalar)
        }
    }

    private mutating func append(_ scalar: Unicode.Scalar) {
        let isBase = Self.isBase(scalar)
        if vowelAwaitingBase && isBase && text == "\u{200C}ေ" {
            text = String(scalar) + "ေ"
            vowelAwaitingBase = false
            return
        }
        // The subscript consonant belongs before a pretyped E vowel.
        if isBase && text.unicodeScalars.suffix(2).elementsEqual("ေ္".unicodeScalars) {
            text.unicodeScalars.removeLast(2)
            text += "္" + String(scalar) + "ေ"
            return
        }

        var position = text.unicodeScalars.endIndex
        while position > text.unicodeScalars.startIndex {
            let previous = text.unicodeScalars.index(before: position)
            guard !vowelAwaitingBase, Self.movesBefore(scalar.value, text.unicodeScalars[previous].value) else { break }
            position = previous
        }
        text.unicodeScalars.insert(scalar, at: position)

        // These key sequences denote individual Myanmar letters in MyanSan.
        switch scalar.value {
        case 0x103B:
            if text.unicodeScalars.suffix(2).elementsEqual("စျ".unicodeScalars) {
                replaceSuffix(2, with: "ဈ")
            } else if text.unicodeScalars.suffix(3).elementsEqual("စျေ".unicodeScalars) {
                replaceSuffix(3, with: "ဈေ")
            }
        case 0x102E where text.unicodeScalars.suffix(2).elementsEqual("ဦ".unicodeScalars):
            replaceSuffix(2, with: "ဦ")
        case 0x103A where text.unicodeScalars.suffix(5).elementsEqual("သြော်".unicodeScalars):
            replaceSuffix(5, with: "ဪ")
        default: break
        }
    }

    private mutating func replaceSuffix(_ count: Int, with replacement: String) {
        text.unicodeScalars.removeLast(count)
        text += replacement
    }

    // Pairwise precedence keeps unrelated marks and repeated taps intact.
    private static func movesBefore(_ incoming: UInt32, _ previous: UInt32) -> Bool {
        switch previous {
        case 0x1031: return (0x103B...0x103E).contains(incoming)
        case 0x103D, 0x103E: return (0x103B..<previous).contains(incoming)
        case 0x102F, 0x1030: return (0x102D...0x102E).contains(incoming)
        case 0x1032: return (0x102D...0x1030).contains(incoming)
        case 0x1036: return (0x102D...0x1030).contains(incoming) || incoming == 0x1032
        case 0x1037: return (0x102B...0x1030).contains(incoming) || incoming == 0x1032 || incoming == 0x1036
        case 0x1038, 0x103A: return incoming == 0x1037
        default: return false
        }
    }

    /// Keep only the suffix that a subsequent combining key can still change.
    var stablePrefixLength: Int {
        let scalars = text.unicodeScalars
        if scalars.first?.value == 0x200C { return 0 }
        // Prefixes of the three MyanSan letter substitutions and of a stack
        // with a pretyped E need to remain available across key presses.
        let unfinished = ["စ", "စေ", "ဥ", "သ", "သေ", "သြ", "သြေ", "သြော"]
        if scalars.last?.value == 0x1031 || scalars.suffix(2).elementsEqual("ေ္".unicodeScalars) {
            return 0
        }
        var stable = scalars.count
        for pattern in unfinished {
            let suffix = pattern.unicodeScalars
            if scalars.suffix(suffix.count).elementsEqual(suffix) {
                stable = min(stable, scalars.count - suffix.count)
            }
        }

        // Find the earliest insertion point among the supported combining
        // keys. The next syllable can never reach into this one.
        let upperPresent = scalars.contains { (0x102D...0x102E).contains($0.value) }
        for incoming: UInt32 in [0x102B, 0x102D, 0x102F, 0x1032, 0x1036, 0x1037, 0x103B, 0x103C, 0x103D, 0x103E] {
            if incoming == 0x102D && upperPresent { continue }
            var count = scalars.count
            for previous in scalars.reversed() {
                guard Self.movesBefore(incoming, previous.value) else { break }
                count -= 1
            }
            stable = min(stable, count)
        }
        return stable
    }

    mutating func backspace() {
        guard !text.isEmpty else { return }
        text.unicodeScalars.removeLast()
        vowelAwaitingBase = text == "\u{200C}ေ"
    }
}

enum BurmeseDeletion {
    static func removedSuffix(before: String, after: String) -> String? {
        guard let last = before.last else { return nil }
        let old = before.unicodeScalars, new = after.unicodeScalars
        guard !old.elementsEqual(new) else { return nil }
        let count = old.count - new.count
        if count > 0, count <= last.unicodeScalars.count, old.dropLast(count).elementsEqual(new) {
            return String(old.suffix(count))
        }
        // A bounded proxy window can reveal more preceding text after deletion.
        // Accept only an unambiguous scalar or grapheme deletion at that boundary.
        let candidates = Set([1, last.unicodeScalars.count]).filter { length in
            let prefix = old.dropLast(length)
            return !prefix.isEmpty && new.count > prefix.count && new.suffix(prefix.count).elementsEqual(prefix)
        }
        guard candidates.count == 1, let length = candidates.first else { return nil }
        return String(old.suffix(length))
    }
    static func retainedScalars(before: String, afterHostDelete: String?) -> String? {
        guard let afterHostDelete, let removed = removedSuffix(before: before, after: afterHostDelete),
              removed.unicodeScalars.count > 1,
              removed.unicodeScalars.allSatisfy({ (0x1000...0x109F).contains($0.value) || $0.value == 0x200C })
        else { return nil }
        return String(removed.unicodeScalars.dropLast())
    }
}

struct HostContext: Equatable {
    let document: UUID?
    let before: String?
    let after: String?
    let selection: String?
}

@MainActor
protocol BurmeseEditHost {
    var context: HostContext { get }
    var hasText: Bool { get }
    func insert(_ text: String)
    func mark(_ text: String)
    func unmark()
    func deleteBackward()
}

/// Commit the stable prefix as ordinary text. Only keys still subject to
/// reordering belong to UIKit's marked range, even with a truncated context.
@MainActor
struct BurmeseHostEditor {
    private var pending = BurmeseComposition()
    private var committed = ""
    private var owner: HostContext?
    private var plainAnchor: String?
    private var markBoundary: String?
    private var marked: String { String(pending.text.unicodeScalars.dropFirst(committed.unicodeScalars.count)) }

    mutating func finish(in host: BurmeseEditHost) {
        let context = host.context
        let tail = marked
        if !tail.isEmpty, owner?.document == context.document {
            if owner == context { host.insert(tail) }
            else { host.unmark() }
        }
        self = BurmeseHostEditor()
    }

    mutating func check(_ context: HostContext, in host: BurmeseEditHost) {
        if let owner, owner != context { finish(in: host) }
    }

    /// UIKit omits the marked suffix from documentContextBeforeInput. Some
    /// hosts already include it, so compare against the captured boundary.
    func contextForSuggestions(_ raw: HostContext) -> HostContext {
        let tail = marked
        guard owner == raw, !tail.isEmpty, raw.before == markBoundary else { return raw }
        return HostContext(document: raw.document, before: (raw.before ?? "") + tail,
                           after: raw.after, selection: raw.selection)
    }

    /// Ordinary text allows host selections, suggestions and native deletion.
    /// Use this path only while the proxy exposes the complete anchored input.
    private mutating func writePlain(_ next: BurmeseComposition, anchor: String, in host: BurmeseEditHost) {
        let old = committed.unicodeScalars, new = next.text.unicodeScalars
        let shared = zip(old, new).prefix(while: { $0 == $1 }).count
        var kept = old[...]
        while kept.count > shared {
            let context = host.context
            guard let left = context.before, let last = left.last,
                  last.unicodeScalars.count <= kept.count,
                  left.unicodeScalars.elementsEqual((anchor + String(kept)).unicodeScalars) else { break }
            host.deleteBackward()
            let after = host.context
            guard after.document == context.document, after.after == context.after,
                  after.selection?.isEmpty != false else {
                self = BurmeseHostEditor()
                return
            }
            let actual = after.before ?? (host.hasText ? nil : "")
            guard let actual,
                  let deleted = BurmeseDeletion.removedSuffix(before: left, after: actual),
                  kept.suffix(deleted.unicodeScalars.count).elementsEqual(deleted.unicodeScalars) else {
                self = BurmeseHostEditor()
                return
            }
            kept = kept.dropLast(deleted.unicodeScalars.count)
        }
        guard kept.count <= shared else {
            // The active text touches a host-owned grapheme. Keep it intact.
            self = BurmeseHostEditor()
            return
        }
        host.insert(String(new.dropFirst(kept.count)))
        committed = next.text
        pending = next
        owner = host.context
        if owner?.before?.unicodeScalars.elementsEqual((anchor + committed).unicodeScalars) != true {
            plainAnchor = nil
        }
    }

    mutating func type(_ key: String, in host: BurmeseEditHost) {
        check(host.context, in: host)
        if pending.startsNewSegment(key) { finish(in: host) }
        let context = host.context
        guard context.document != nil else { host.insert(key); return }

        var next = pending
        next.append(key)
        if let anchor = plainAnchor, context.selection?.isEmpty != false,
           context.before?.unicodeScalars.elementsEqual((anchor + committed).unicodeScalars) == true {
            writePlain(next, anchor: anchor, in: host)
            return
        }
        if !next.text.unicodeScalars.starts(with: committed.unicodeScalars) {
            // An extra or conflicting mark begins a new group. Never edit
            // text already committed to the document.
            finish(in: host)
            next = BurmeseComposition()
            next.append(key)
        }
        let startingMark = marked.isEmpty
        pending = next
        let scalars = next.text.unicodeScalars
        let stable = next.stablePrefixLength
        let written = committed.unicodeScalars.count
        if stable > written {
            host.insert(String(scalars.dropFirst(written).prefix(stable - written)))
            committed = String(scalars.prefix(stable))
        }
        let tail = marked
        if !tail.isEmpty {
            if startingMark || stable > written { markBoundary = host.context.before }
            host.mark(tail)
        }
        let updated = host.context
        if updated.document == context.document {
            if owner == nil, written == 0, tail.isEmpty, context.selection?.isEmpty != false,
               context.before != nil || context.after == nil,
               updated.before?.unicodeScalars.elementsEqual(((context.before ?? "") + committed).unicodeScalars) == true {
                plainAnchor = context.before ?? ""
            }
            owner = updated
        } else {
            self = BurmeseHostEditor()
        }
    }

    mutating func backspace(in host: BurmeseEditHost) {
        // Let UIKit handle a real selection even when the proxy previously
        // hid it behind a marked range. Never regenerate a mark on Backspace.
        if !marked.isEmpty, owner?.document == host.context.document { host.unmark() }
        self = BurmeseHostEditor()
        let before = host.context
        host.deleteBackward()
        let after = host.context
        guard before.document != nil, before.document == after.document, before.after == after.after,
              before.selection?.isEmpty != false, after.selection?.isEmpty != false,
              let previous = before.before else { return }
        let left = after.before ?? (host.hasText ? nil : "")
        if let restore = BurmeseDeletion.retainedScalars(before: previous, afterHostDelete: left) {
            host.insert(restore)
        }
    }
}
