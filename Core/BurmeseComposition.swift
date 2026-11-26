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
              let last = removed.unicodeScalars.last,
              (0x1000...0x109F).contains(last.value) || last.value == 0x200C
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
    func moveCaret(byUTF16 offset: Int)
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

    private func owns(_ context: HostContext) -> Bool {
        guard let owner else { return false }
        if owner == context { return true }
        guard !isMarked, owner.document == context.document, owner.after == context.after,
              context.selection?.isEmpty != false, let expected = owner.before,
              let left = context.before, endsWith(left, pending.text) else { return false }
        // Inserting into a bounded context shifts its leading edge.
        return endsWith(expected, left) || endsWith(left, expected)
    }

    mutating func check(_ context: HostContext, in host: BurmeseEditHost) {
        if owner != nil, !owns(context) { finish(in: host) }
    }

    /// UIKit omits the marked suffix from documentContextBeforeInput. Some
    /// hosts already include it, so compare against the captured boundary.
    func contextForSuggestions(_ raw: HostContext) -> HostContext {
        guard owner == raw, isMarked, raw.before == markBoundary else { return raw }
        return HostContext(document: raw.document, before: (raw.before ?? "") + pending.text,
                           after: raw.after, selection: raw.selection)
    }

    private func endsWith(_ left: String?, _ suffix: String) -> Bool {
        left?.unicodeScalars.suffix(suffix.unicodeScalars.count).elementsEqual(suffix.unicodeScalars) == true
    }

    /// Edit only the differing scalars. A vowel inserted before another mark
    /// moves the caret temporarily and never deletes the existing syllable.
    private mutating func writePlain(_ next: BurmeseComposition, key: String, in host: BurmeseEditHost) {
        let original = host.context
        let old = pending.text.unicodeScalars, new = next.text.unicodeScalars
        let shared = zip(old, new).prefix { $0 == $1 }.count
        let oldTail = old.dropFirst(shared), newTail = new.dropFirst(shared)
        let trailing = zip(oldTail.reversed(), newTail.reversed()).prefix { $0 == $1 }.count
        let removed = oldTail.dropLast(trailing)
        let inserted = String(newTail.dropLast(trailing))
        let suffix = String(oldTail.suffix(trailing))
        let distance = String(oldTail).utf16.count
        if distance > 0 {
            host.moveCaret(byUTF16: -distance)
        }
        if removed.isEmpty {
            if !inserted.isEmpty { host.insert(inserted) }
        } else {
            // Some editors delete a whole grapheme and can stop exposing the
            // left context after that call. Stage the replacement first. A
            // zero-width space is a grapheme break on both sides, so each
            // superseded scalar and finally the separator delete individually.
            let separator = "\u{200B}"
            host.insert(separator)
            guard endsWith(host.context.before, separator) else {
                // A constrained field may reject the separator. Leave its
                // existing text intact and submit the key as ordinary input.
                host.moveCaret(byUTF16: distance)
                host.insert(key)
                self = BurmeseHostEditor()
                return
            }
            if !inserted.isEmpty {
                host.moveCaret(byUTF16: -1)
                host.insert(inserted)
                let accepted = endsWith(host.context.before, inserted)
                host.moveCaret(byUTF16: 1)
                if !accepted {
                    host.deleteBackward() // Remove only the confirmed separator.
                    host.moveCaret(byUTF16: distance)
                    self = BurmeseHostEditor()
                    return
                }
            }
            for scalar in removed {
                host.moveCaret(byUTF16: String(scalar).utf16.count)
                host.deleteBackward()
            }
            host.deleteBackward()
        }
        if !suffix.isEmpty { host.moveCaret(byUTF16: suffix.utf16.count) }
        pending = next
        // Cursor moves are delivered to UIKit in order, but an immediate
        // proxy read can still describe an intermediate caret position.
        let prefix = String((original.before ?? "").unicodeScalars.dropLast(old.count))
        owner = HostContext(document: original.document, before: prefix + next.text,
                            after: original.after, selection: original.selection)
    }

    mutating func type(_ key: String, in host: BurmeseEditHost) {
        check(host.context, in: host)
        if pending.startsNewSegment(key) { finish(in: host) }
        let context = host.context
        guard context.document != nil else { host.insert(key); return }

        var next = pending
        next.append(key)
        if plainAnchor != nil, context.selection?.isEmpty != false, endsWith(context.before, pending.text) {
            writePlain(next, key: key, in: host)
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
            plainAnchor = boundary
            isMarked = false
            // The proxy can report its old window until the next key event.
            // Verify the predicted caret against the next live context.
            owner = HostContext(document: context.document, before: full, after: context.after, selection: nil)
            return
        }
        owner = host.context
    }

    mutating func backspace(in host: BurmeseEditHost) {
        // Let UIKit handle a real selection even when the proxy previously
        // hid it behind a marked range. Never regenerate a mark on Backspace.
        let owned = owns(host.context)
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
        let ownsSuffix = owned && !active.isEmpty && expectedAnchor != nil && endsWith(previous, active.text)
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
              endsWith(finalLeft, survivor.text) else { return }
        pending = survivor
        plainAnchor = anchor
        owner = host.context
    }
}
