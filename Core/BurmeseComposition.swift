import Foundation

/// Only the current segment belongs to the keyboard. The caller discards
/// ownership at syllable boundaries and on external edits.
struct BurmeseComposition {
    private static let unboundE = "\u{200C}ေ"
    private(set) var text = ""

    var isEmpty: Bool { text.isEmpty }

    static func canCompose(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first else { return false }
        return (0x1000...0x103F).contains(first.value) || (0x1050...0x1059).contains(first.value)
    }

    func startsNewSegment(_ key: String) -> Bool {
        guard !text.isEmpty else { return false }
        if key == "ေ" { return true }
        guard key.unicodeScalars.first.map(Self.isBase) == true else { return false }
        return text != Self.unboundE && text.unicodeScalars.last != "္"
            && !text.unicodeScalars.suffix(4).elementsEqual("င်္ေ".unicodeScalars)
    }

    private static func isBase(_ scalar: Unicode.Scalar) -> Bool {
        return (0x1000...0x102A).contains(scalar.value) || scalar.value == 0x103F
    }

    mutating func append(_ key: String) {
        if key == "ေ" {
            text += Self.unboundE
            return
        }
        if key.unicodeScalars.count > 1, text == Self.unboundE, key.unicodeScalars.first.map(Self.isBase) == true {
            text = key + "ေ"
            return
        }
        // A multi-scalar shortcut at a pending stack is a literal key. Only
        // tapping one base completes the prebase stack transformation.
        if key.unicodeScalars.count > 1, pendingStackBase != nil {
            text += key
            return
        }
        for scalar in key.unicodeScalars {
            append(scalar)
        }
    }

    private mutating func append(_ scalar: Unicode.Scalar) {
        let isBase = Self.isBase(scalar)
        if isBase && text == Self.unboundE {
            text = (scalar == "ဥ" ? "ဉ" : String(scalar)) + "ေ"
            return
        }
        if isBase, text.unicodeScalars.suffix(4).elementsEqual("င်္ေ".unicodeScalars) {
            replaceSuffix(1, with: String(scalar) + "ေ")
            return
        }
        if scalar == "္", text.unicodeScalars.last == "ေ",
           let base = text.unicodeScalars.dropLast().last, Self.isBase(base) {
            replaceSuffix(2, with: "\u{200C}ေ" + String(base) + "္")
            return
        }
        if isBase, let base = pendingStackBase {
            replaceSuffix(4, with: String(base) + "္" + String(scalar) + "ေ")
            return
        }
        if text == "ဥ" {
            if scalar == "ိ" || scalar == "ီ" { text = "ဦ"; return }
            if "ျြွှဲါာ္်".unicodeScalars.contains(scalar) { text = "ဉ" }
        }
        // An unbound sequence has no syllable to reorder.
        guard text.unicodeScalars.first.map(Self.isBase) == true else {
            text.unicodeScalars.append(scalar)
            return
        }
        let medial = (0x103B...0x103E).contains(scalar.value)
        let closed = text.unicodeScalars.contains("ါ") || text.unicodeScalars.contains("ာ")
            || text.range(of: "့်", options: .literal) != nil || text.range(of: "့့", options: .literal) != nil
        let endsSpelling = ["့်", "့့"].contains { text.unicodeScalars.suffix(2).elementsEqual($0.unicodeScalars) }
        if (closed && !medial) || endsSpelling {
            text.unicodeScalars.append(scalar)
        } else {
            if let conflicts = Self.replacedMarks(for: scalar) {
                var index = text.unicodeScalars.endIndex
                while index > text.unicodeScalars.startIndex {
                    let previous = text.unicodeScalars.index(before: index)
                    let mark = text.unicodeScalars[previous]
                    guard Self.editableMarks.contains(mark) else { break }
                    if conflicts.contains(mark) { text.unicodeScalars.remove(at: previous) }
                    index = previous
                }
            }
            var position = text.unicodeScalars.endIndex
            while position > text.unicodeScalars.startIndex {
                let previous = text.unicodeScalars.index(before: position)
                guard Self.movesBefore(scalar, text.unicodeScalars[previous]) else { break }
                position = previous
            }
            text.unicodeScalars.insert(scalar, at: position)
        }

        // These key sequences denote individual Myanmar letters in MyanSan.
        switch scalar.value {
        case 0x103B, 0x103C:
            let base: Unicode.Scalar = scalar == "ျ" ? "စ" : "သ"
            if let index = text.unicodeScalars.lastIndex(of: scalar), index > text.unicodeScalars.startIndex {
                let previous = text.unicodeScalars.index(before: index)
                if text.unicodeScalars[previous] == base {
                    let letter: Unicode.Scalar = scalar == "ျ" ? "ဈ" : "ဩ"
                    text.unicodeScalars.replaceSubrange(previous...index, with: [letter])
                }
            }
        case 0x103A where text.unicodeScalars.suffix(4).elementsEqual("ဩော်".unicodeScalars):
            replaceSuffix(4, with: "ဪ")
        default: break
        }
    }

    private var pendingStackBase: Unicode.Scalar? {
        let tail = text.unicodeScalars.suffix(4)
        guard tail.count == 4, tail.starts(with: "\u{200C}ေ".unicodeScalars),
              tail.last == "္", let base = tail.dropLast().last, Self.isBase(base) else { return nil }
        return base
    }

    private mutating func replaceSuffix(_ count: Int, with replacement: String) {
        text.unicodeScalars.removeLast(count)
        text += replacement
    }

    // Only the marks in the current editable run can replace one another.
    private static let editableMarks = "ျြွှိီုူဲံ့ေ်".unicodeScalars

    private static func replacedMarks(for incoming: Unicode.Scalar) -> String.UnicodeScalarView? {
        switch incoming {
        case "ျ", "ြ", "ွ", "ှ": return String(incoming).unicodeScalars
        case "ိ", "ီ": return "ိီဲ်".unicodeScalars
        case "ု", "ူ": return "ုူ".unicodeScalars
        case "ဲ", "်": return "ိီဲံ်".unicodeScalars
        case "ံ": return "ဲံ်".unicodeScalars
        default: return nil
        }
    }

    private static func movesBefore(_ incoming: Unicode.Scalar, _ previous: Unicode.Scalar) -> Bool {
        switch incoming {
        case "ျ": return "ြွှေိီုူဲံ့ါာ".unicodeScalars.contains(previous)
        case "ြ": return "ွှေိီုူဲံ့ါာ".unicodeScalars.contains(previous)
        case "ွ": return "ှေိီုူဲံ့ါာ".unicodeScalars.contains(previous)
        case "ှ": return "ေိီုူဲံ့ါာ်".unicodeScalars.contains(previous)
        case "ိ", "ီ": return "ုူံ့".unicodeScalars.contains(previous)
        case "ု", "ူ": return "ဲံ့".unicodeScalars.contains(previous)
        case "ဲ", "ံ": return previous == "့"
        case "့": return previous == "်"
        case "်": return "ျြွေုူ".unicodeScalars.contains(previous)
        default: return false
        }
    }

    mutating func backspace() {
        guard !text.isEmpty else { return }
        text.unicodeScalars.removeLast()
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

/// Keep one active syllable. A native marked range protects input when the
/// host hides or truncates the text needed to verify an ordinary replacement.
@MainActor
struct BurmeseHostEditor {
    private var pending = BurmeseComposition()
    private var isMarked = false
    private var owner: HostContext?
    private var plainAnchor: String?
    private var emptyBoundary = false
    private var markBoundary: String?
    private var boundary: String? { markBoundary ?? (emptyBoundary ? "" : nil) }

    mutating func finish(in host: BurmeseEditHost) {
        let context = host.context
        if isMarked, owner?.document == context.document {
            if owner == context { host.insert(pending.text) }
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
        guard owner == raw, isMarked, raw.before == markBoundary else { return raw }
        return HostContext(document: raw.document, before: (raw.before ?? "") + pending.text,
                           after: raw.after, selection: raw.selection)
    }

    /// Ordinary text allows host selections, suggestions and native deletion.
    /// Use this path only while the proxy exposes the complete anchored input.
    private mutating func writePlain(_ next: BurmeseComposition, anchor: String, in host: BurmeseEditHost) {
        let old = (anchor + pending.text).unicodeScalars, new = (anchor + next.text).unicodeScalars
        let shared = zip(old, new).prefix(while: { $0 == $1 }).count
        var kept = old[...]
        while kept.count > shared {
            let context = host.context
            guard let left = context.before, let last = left.last, left.unicodeScalars.elementsEqual(kept) else {
                self = BurmeseHostEditor()
                return
            }
            host.deleteBackward()
            let after = host.context
            guard after.document == context.document, after.after == context.after,
                  after.selection?.isEmpty != false else {
                self = BurmeseHostEditor()
                return
            }
            let atStart = kept.count == last.unicodeScalars.count && after.after?.isEmpty == false
            let actual = after.before ?? (!host.hasText || atStart ? "" : nil)
            guard let actual, let removed = BurmeseDeletion.removedSuffix(before: left, after: actual),
                  kept.suffix(removed.unicodeScalars.count).elementsEqual(removed.unicodeScalars) else {
                self = BurmeseHostEditor()
                return
            }
            kept = kept.dropLast(removed.unicodeScalars.count)
        }
        // UIKit can delete a whole grapheme, including a character before
        // our joiner. Restore its verified prefix along with the new syllable.
        let insertion = String(new.dropFirst(kept.count))
        if !insertion.isEmpty { host.insert(insertion) }
        isMarked = false
        pending = next
        owner = host.context
        if owner?.before?.unicodeScalars.elementsEqual((anchor + pending.text).unicodeScalars) != true {
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
           context.before?.unicodeScalars.elementsEqual((anchor + pending.text).unicodeScalars) == true {
            writePlain(next, anchor: anchor, in: host)
            return
        }
        if !isMarked && !pending.isEmpty {
            // The proxy lost its anchor. This tap can only own a new range.
            finish(in: host)
            next = BurmeseComposition()
            next.append(key)
        }
        if pending.isEmpty {
            markBoundary = context.before
            emptyBoundary = context.before == nil && (!host.hasText || context.selection?.isEmpty == false)
        }
        pending = next
        isMarked = true
        host.mark(next.text)
        let updated = host.context
        guard updated.document == context.document else { self = BurmeseHostEditor(); return }
        // Finish a readable native mark within this key event. A later host
        // selection or Backspace must operate on ordinary selectable text.
        if let boundary {
            let full = boundary + next.text
            let exposesRange = updated.before?.unicodeScalars.elementsEqual(full.unicodeScalars) == true
            // A window exposing just one grapheme can contain both a leading
            // joiner and the previous character. Keep that ambiguous mark native.
            let separateBoundary = boundary.isEmpty || full.count > 1
            guard updated.before == markBoundary || (exposesRange && separateBoundary) else {
                owner = updated
                return
            }
            host.unmark()
            // Some hosts exclude the marked text before unmarking.
            if host.context.before?.unicodeScalars.elementsEqual((boundary + next.text).unicodeScalars) == true {
                plainAnchor = boundary
            }
            isMarked = false
        }
        owner = host.context
    }

    mutating func backspace(in host: BurmeseEditHost) {
        // Let UIKit handle a real selection even when the proxy previously
        // hid it behind a marked range. Never regenerate a mark on Backspace.
        let owned = owner != nil && owner == host.context
        if isMarked, owner?.document == host.context.document { host.unmark() }
        let active = pending
        let expectedAnchor = plainAnchor ?? boundary
        let before = host.context
        self = BurmeseHostEditor()
        host.deleteBackward()
        let after = host.context
        guard before.document != nil, before.document == after.document, before.after == after.after,
              before.selection?.isEmpty != false, after.selection?.isEmpty != false,
              let previous = before.before else { return }
        let ownsSuffix = owned && !active.isEmpty && expectedAnchor.map {
            previous.unicodeScalars.elementsEqual(($0 + active.text).unicodeScalars)
        } == true
        let deletedAtStart = ownsSuffix && expectedAnchor == "" && after.after?.isEmpty == false
        let left = after.before ?? (!host.hasText || deletedAtStart ? "" : nil)
        if ownsSuffix, let left, let removed = BurmeseDeletion.removedSuffix(before: previous, after: left) {
            // A joiner can make the preceding space or Latin letter part of
            // the same grapheme. Preserve that neighbor on a verified delete.
            let retained = removed.unicodeScalars.dropLast()
            if !retained.isEmpty { host.insert(String(retained)) }
        } else if let restore = BurmeseDeletion.retainedScalars(before: previous, afterHostDelete: left) {
            host.insert(restore)
        }
        // Continue composing only the surviving part of our own segment.
        // Pasted text, selections and moved carets are never adopted.
        guard ownsSuffix, let anchor = expectedAnchor else { return }
        var survivor = active
        survivor.backspace()
        guard !survivor.isEmpty, let finalLeft = host.context.before,
              finalLeft.unicodeScalars.elementsEqual((anchor + survivor.text).unicodeScalars) else { return }
        pending = survivor
        plainAnchor = anchor
        owner = host.context
    }
}
