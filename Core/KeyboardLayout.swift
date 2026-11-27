import Foundation

enum Language: String {
    case burmese = "my", english = "en"
    var title: String { self == .burmese ? "မြန်မာ" : "English" }

    static func isBurmeseWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        (0x104C...0x104F).contains(scalar.value) || ((0x1000...0x109F).contains(scalar.value) &&
            (CharacterSet.letters.contains(scalar) || CharacterSet.nonBaseCharacters.contains(scalar)))
    }

    func needsWordSpace(before key: String, at context: HostContext) -> Bool {
        guard context.document != nil, context.selection?.isEmpty != false,
              let left = context.before, let last = left.last, let first = key.first,
              let lastScalar = left.unicodeScalars.last, let firstScalar = key.unicodeScalars.first else { return false }
        switch self {
        case .english:
            return Self.isBurmeseWordScalar(lastScalar) && EnglishToken.isLetter(first)
        case .burmese:
            return Self.isBurmeseWordScalar(firstScalar) && EnglishToken.isLetter(last)
        }
    }
}

/// A drag advances by visible characters. UIKit's text proxy measures offsets in UTF-16.
struct SpacebarCursorDrag {
    let document: UUID
    private var anchorX: CGFloat
    private static let pointsPerCharacter: CGFloat = 10

    init(document: UUID, x: CGFloat) {
        self.document = document
        anchorX = x
    }

    mutating func offset(to x: CGFloat, in context: HostContext) -> Int {
        guard context.document == document else { return 0 }
        let steps = Int((x - anchorX) / Self.pointsPerCharacter)
        guard steps != 0 else { return 0 }
        anchorX += CGFloat(steps) * Self.pointsPerCharacter
        if steps < 0 {
            return -((context.before ?? "").suffix(-steps).utf16.count)
        }
        return (context.after ?? "").prefix(steps).utf16.count
    }
}

/// Only a pair of Space key taps at the same insertion point can end a sentence.
struct DoubleSpaceShortcut {
    private var first: (time: Date, language: Language, context: HostContext)?

    private func followsFirstSpace(_ context: HostContext) -> Bool {
        guard let first, let prefix = first.context.before, let left = context.before,
              context.document == first.context.document, context.after == first.context.after,
              context.selection?.isEmpty != false, left.last == " " else { return false }
        // iOS may slide its surrounding-text window after inserting a space.
        let expected = (prefix + " ").unicodeScalars.suffix(64)
        let visible = left.unicodeScalars.suffix(64)
        let length = min(expected.count, visible.count)
        return length >= 2 && expected.suffix(length).elementsEqual(visible.suffix(length))
    }

    mutating func selectionChanged(to context: HostContext) {
        if !followsFirstSpace(context) { first = nil }
    }

    mutating func separator(for language: Language, at context: HostContext,
                            now: Date = Date()) -> String? {
        let completesPair = first.map {
            $0.language == language && (0...0.45).contains(now.timeIntervalSince($0.time))
        } == true && followsFirstSpace(context)
        first = nil
        if completesPair { return language == .english ? ". " : "။ " }
        guard context.document != nil, context.selection?.isEmpty != false,
              let last = context.before?.last else { return nil }
        if last.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) })
            || ")]}’”\"'".contains(last) {
            first = (now, language, context)
        }
        return nil
    }
}

enum EnglishCapitalization {
    case none, words, sentences, allCharacters

    private static func containsBurmeseInSentence<S: Sequence>(_ scalars: S) -> Bool
        where S.Element == Unicode.Scalar {
        for scalar in scalars {
            if CharacterSet.newlines.contains(scalar) || ".!?။…".unicodeScalars.contains(scalar) { break }
            if Language.isBurmeseWordScalar(scalar) { return true }
        }
        return false
    }

    func shouldShift(before text: String, after: String = "") -> Bool {
        switch self {
        case .none: return false
        case .allCharacters: return true
        case .words, .sentences:
            var context = text[...]
            let quotes = "\"'“‘([{"
            while let last = context.last, quotes.contains(last) { context.removeLast() }
            guard let last = context.last else { return true }
            if let scalar = last.unicodeScalars.last, Language.isBurmeseWordScalar(scalar) { return true }
            if last == "၊" || last == "။" { return true }
            guard last.isWhitespace else { return false }
            if self == .words { return true }
            while let space = context.last, space.isWhitespace {
                if space.isNewline { return true }
                context.removeLast()
            }
            while let closing = context.last, "\"'”’)]}".contains(closing) { context.removeLast() }
            guard let preceding = context.last else { return true }
            if ".!?။…".contains(preceding) { return true }
            // At a word boundary, English words in a Burmese sentence start with a capital.
            return Self.containsBurmeseInSentence(context.unicodeScalars.reversed()) ||
                Self.containsBurmeseInSentence(after.unicodeScalars)
        }
    }
}

struct LetterKey {
    let text: String
    let alternatives: [String]
    var defaultIndex = 0
    var hint: String?
    // An expanded Gboard menu keeps its original choices in the row nearest the key.
    var originalHoldRowWidth: Int?

    init(_ text: String, alternatives: [String] = [], defaultIndex: Int = 0, hint: String? = nil) {
        self.text = text
        self.alternatives = alternatives
        self.defaultIndex = defaultIndex
        self.hint = hint
    }

    static func label(for value: String) -> String {
        guard let first = value.unicodeScalars.first,
              CharacterSet.nonBaseCharacters.contains(first) else { return value }
        return "◌" + value
    }
}

enum KeyboardLayout {
    // Parallel rows follow the observed Android layout, including multi-scalar keys.
    static let base = [
        ["ဈ", "ဝ", "ဋ", "ုံ", "ော", "ဪ", "ရ", "ဂ", "ဟ", "၏"],
        ["ဆ", "တ", "န", "မ", "အ", "ပ", "က", "င", "သ", "စ"],
        ["ေ", "ျ", "ိ", "်", "ါ", "့", "ြ", "ု", "ူ", "း"],
        ["ဖ", "ထ", "ခ", "လ", "ဘ", "ည", "ာ", "ယ"]
    ]
    static let shifted = [
        ["၁", "၂", "၃", "၄", "၅", "၆", "၇", "၈", "၉", "၀"],
        ["ဍ", "ဏ္ဍ", "ဣ", "၎င်း", "ဤ", "၌", "ဥ", "၍", "ဿ", "ဏ"],
        ["ဗ", "ှ", "ီ", "္", "ွ", "ံ", "ဲ", "ဒ", "ဓ", "ဏ္ဌ"],
        ["ဇ", "ဌ", "ဃ", "ဠ", "ဎ", "ဉ", "ဦ", "ဧ"]
    ]
    static let topHolds = [
        ["ဍ္ဎ","1","၁"], ["ကျပ်","2","၂"], ["၃","ဋ္ဌ","3"], ["၄","င်္","4"],
        ["၅","ေါ","5"], ["၆","ဩ","6"], ["7","ၒ","၇"], ["၈","8","ၔ"],
        ["၉","9","ၐ"], ["၀","0"]
    ]
    static let defaults = [0,0,1,1,1,1,1,2,2,1]

    // iOS Burmese stack shortcuts, grouped on the corresponding Gboard key.
    // Append only choices that the existing menu doesn't already offer.
    private static let additionalBurmeseHolds: [String: [String]] = [
        "ဈ": ["ဍ္ဍ"], "ဋ": ["ဋ္ဋ"], "ဂ": ["ဂ္ဂ", "ဂ္ဃ"],
        "ဆ": ["ဍ္ဍ", "ဍ္ဎ"], "တ": ["တ္တ", "တ္ထ"],
        "န": ["န္တ", "န္ထ", "န္ဒ", "န္ဓ", "န္န"],
        "မ": ["မ္ပ", "မ္ဗ", "မ္ဘ", "မ္မ"], "ပ": ["ပ္ပ", "ပ္ဖ"],
        "က": ["က္က", "က္ခ"], "င": ["င်္"],
        "စ": ["စ္စ", "စ္ဆ", "ဏ္ဋ", "ဏ္ဍ", "ဏ္ဌ", "ဏ္ဎ", "ဏ္ဏ"],
        "ေ": ["ဗ္ဗ", "ဗ္ဘ"], "ု": ["ဒ္ဒ", "ဒ္ဓ"],
        "ဖ": ["ဇ္ဇ", "ဇ္ဈ"], "လ": ["လ္လ"], "ည": ["ဉ္စ", "ဉ္ဆ", "ဉ္ဇ", "ဉ္ဈ"]
    ]

    static let period = LetterKey(".", alternatives: ["&", "%", "+", "\"", "-", ":", "'", "@", ";", "/", "(", ")", "#", "!", ",", "?"], defaultIndex: 14)
    static func letters(_ language: Language, shift: Bool) -> [[LetterKey]] {
        if language == .english {
            return ["qwertyuiop","asdfghjkl","zxcvbnm"].enumerated().map { row, letters in
                letters.enumerated().map { col, char in
                    let digit = String((col + 1) % 10)
                    let accents: [String]
                    let index: Int
                    switch char {
                    case "e": accents = ["ē","ê","ë","è","3","é"]; index = 4
                    case "a": accents = ["æ","ã","å","ā","à","á","â","ä"]; index = 4
                    default: accents = row == 0 ? [digit] : []; index = 0
                    }
                    return LetterKey(shift ? char.uppercased() : String(char),
                                     alternatives: shift ? accents.map { $0.uppercased() } : accents, defaultIndex: index, hint: row == 0 ? digit : nil)
                }
            }
        }
        return base.enumerated().map { row, letters in
            letters.enumerated().map { col, letter in
                if shift { return LetterKey(shifted[row][col]) }
                let existing = row == 0 ? topHolds[col] : [shifted[row][col]]
                let additions = additionalBurmeseHolds[letter] ?? []
                var key = LetterKey(letter, alternatives: existing + additions,
                                    defaultIndex: row == 0 ? defaults[col] : 0,
                                    hint: row == 0 ? String((col + 1) % 10) : nil)
                if row == 0 && !additions.isEmpty { key.originalHoldRowWidth = existing.count }
                return key
            }
        }
    }

    static func symbols(_ language: Language, second: Bool) -> [[LetterKey]] {
        let rows = second ? ["~`|•√π÷×§∆", "£¢€¥^°={}\\", "%©®™✓[]"]
                          : [language == .burmese ? "၁၂၃၄၅၆၇၈၉၀" : "1234567890", "@#$_&-+()/", "*\"':;!?"]
        return rows.map { $0.map { LetterKey(String($0)) } }
    }
}
