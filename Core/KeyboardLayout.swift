import Foundation

enum Language: String {
    case burmese = "my", english = "en"
    var title: String { self == .burmese ? "မြန်မာ" : "English" }
}

enum EnglishCapitalization {
    case none, words, sentences, allCharacters

    func shouldShift(before text: String) -> Bool {
        switch self {
        case .none: return false
        case .allCharacters: return true
        case .words: return text.last?.isWhitespace ?? true
        case .sentences:
            var context = text[...]
            let quotes = "\"'“‘([{"
            while let last = context.last, quotes.contains(last) { context.removeLast() }
            guard let last = context.last else { return true }
            guard last.isWhitespace else { return false }
            while let space = context.last, space.isWhitespace {
                if space.isNewline { return true }
                context.removeLast()
            }
            while let closing = context.last, "\"'”’)]}".contains(closing) { context.removeLast() }
            return context.last.map { ".!?။…".contains($0) } ?? true
        }
    }
}

struct LetterKey {
    let text: String
    let alternatives: [String]
    var defaultIndex = 0
    var hint: String?

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
                if row == 0 {
                    return LetterKey(letter, alternatives: topHolds[col], defaultIndex: defaults[col],
                                     hint: String((col + 1) % 10))
                }
                return LetterKey(letter, alternatives: [shifted[row][col]])
            }
        }
    }

    static func symbols(_ language: Language, second: Bool) -> [[LetterKey]] {
        let rows = second ? ["~`|•√π÷×§∆", "£¢€¥^°={}\\", "%©®™✓[]"]
                          : [language == .burmese ? "၁၂၃၄၅၆၇၈၉၀" : "1234567890", "@#$_&-+()/", "*\"':;!?"]
        return rows.map { $0.map { LetterKey(String($0)) } }
    }
}
