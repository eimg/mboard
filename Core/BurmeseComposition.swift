import Foundation

/// Only the current segment belongs to the keyboard. The caller discards
/// ownership at syllable boundaries and on external edits.
struct BurmeseComposition {
    private(set) var text = ""
    private var vowelAwaitingBase = false

    var isEmpty: Bool { text.isEmpty }

    static func edit(from previous: String, to next: String) -> (remove: String, insert: String) {
        let common = zip(previous.unicodeScalars, next.unicodeScalars).prefix(while: { $0 == $1 }).count
        return (String(previous.unicodeScalars.dropFirst(common)), String(next.unicodeScalars.dropFirst(common)))
    }

    static func canCompose(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first else { return false }
        return (0x1000...0x103F).contains(first.value) || (0x1050...0x1059).contains(first.value)
    }

    func startsNewSegment(_ key: String) -> Bool {
        guard !text.isEmpty else { return false }
        if key == "ေ" { return true }
        return Self.startsWithBase(key) && !vowelAwaitingBase && text.unicodeScalars.last?.value != 0x1039
    }

    private static func startsWithBase(_ key: String) -> Bool {
        guard let scalar = key.unicodeScalars.first else { return false }
        return (0x1000...0x102A).contains(scalar.value) || scalar.value == 0x103F
    }

    mutating func append(_ key: String) {
        if key == "ေ" {
            text += "\u{200C}ေ"
            vowelAwaitingBase = true
        } else if vowelAwaitingBase && Self.startsWithBase(key) && text == "\u{200C}ေ" {
            text = key + "ေ"
            vowelAwaitingBase = false
        } else if key.unicodeScalars.count == 1, let scalar = key.unicodeScalars.first,
                  (0x103B...0x103E).contains(scalar.value), text.unicodeScalars.last?.value == 0x1031,
                  !vowelAwaitingBase {
            text.unicodeScalars.removeLast()
            text += key + "ေ"
        } else {
            text += key
        }
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
    /// Some hosts erase the full grapheme. Restore its leading scalars only
    /// when both context snapshots demonstrate that exact deletion.
    static func retainedScalars(before: String, afterHostDelete: String) -> String? {
        guard let cluster = before.last, cluster.unicodeScalars.count > 1,
              cluster.unicodeScalars.allSatisfy({ (0x1000...0x109F).contains($0.value) || $0.value == 0x200C }),
              before.dropLast().unicodeScalars.elementsEqual(afterHostDelete.unicodeScalars) else { return nil }
        return String(cluster.unicodeScalars.dropLast())
    }
}
