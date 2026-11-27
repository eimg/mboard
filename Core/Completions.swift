import Foundation

struct Completion: Equatable {
    let title: String
    let suffix: String
    var learned = false
    enum Action: Equatable { case append, replace(EnglishToken), selection }
    var action = Action.append

    func confirmed(from original: HostContext, to result: HostContext) -> Bool {
        guard result != original, let visible = result.before, !visible.isEmpty else { return false }
        let before = original.before ?? "", after = original.after ?? ""
        switch action {
        case .append:
            return result.matchesCaret(in: original, before: before + suffix, after: after)
        case .selection:
            return result.matchesCaret(in: original, before: before + title, after: after)
        case .replace(let token):
            return result.matchesCaret(in: original, before: before.dropLast(token.left.count) + title,
                                       after: String(after.dropFirst(token.right.count)))
        }
    }
}

private extension HostContext {
    // A host may expose a sliding window on either side of the caret.
    func matchesCaret(in original: HostContext, before expectedLeft: String, after expectedRight: String) -> Bool {
        guard original.document != nil, document == original.document, selection?.isEmpty != false else { return false }
        let left = (before ?? "").utf8, right = (after ?? "").utf8
        let leftCount = min(left.count, expectedLeft.utf8.count)
        let rightCount = min(right.count, expectedRight.utf8.count)
        return left.isEmpty == expectedLeft.isEmpty && right.isEmpty == expectedRight.isEmpty
            && left.suffix(leftCount).elementsEqual(expectedLeft.utf8.suffix(leftCount))
            && right.prefix(rightCount).elementsEqual(expectedRight.utf8.prefix(rightCount))
    }
}

/// Both segments contain only English letters and internal apostrophes. Keeping the
/// split at the original caret lets a tap edit just the word the user inspected.
struct EnglishToken: Equatable {
    let left: String
    let right: String
    var word: String { left + right }

    static func isLetter(_ c: Character) -> Bool {
        c.isLetter && c.unicodeScalars.first?.properties.name?.hasPrefix("LATIN ") == true
    }

    static func part(_ c: Character) -> Bool { isLetter(c) || c == "'" || c == "’" }

    init?(before: String, after: String) {
        let nearby = String(before.reversed().prefix { !$0.isWhitespace }.reversed()) + after.prefix { !$0.isWhitespace }
        guard !nearby.contains(where: { "@#/_".contains($0) || $0.isNumber }),
              !nearby.contains("://"),
              !zip(nearby, nearby.dropFirst()).contains(where: { $0 == "." && Self.isLetter($1) })
        else { return nil }
        var leading = String(before.reversed().prefix(while: Self.part).reversed())
        var trailing = String(after.prefix(while: Self.part))
        // Opening and closing quotes belong to the surrounding sentence.
        while let first = leading.first, !Self.isLetter(first) { leading.removeFirst() }
        while let last = trailing.last, !Self.isLetter(last) { trailing.removeLast() }
        guard let first = (leading + trailing).first, Self.isLetter(first),
              leading.count + trailing.count <= 48 else { return nil }
        left = leading
        right = trailing
    }

    /// Keep matching characters on both sides, including the suffix to the right
    /// of the caret. Move only through the validated word and never delete a neighbor.
    @MainActor
    func replace(with target: String, at original: HostContext, in host: BurmeseEditHost) -> Bool {
        guard original.document != nil, original.selection?.isEmpty != false,
              host.context == original,
              EnglishToken(before: original.before ?? "", after: original.after ?? "") == self
        else { return false }
        let shared = zip(word, target).prefix { $0 == $1 }.count
        let old = word.dropFirst(shared), new = target.dropFirst(shared)
        let tail = zip(old.reversed(), new.reversed()).prefix { $0 == $1 }.count
        let untouched = String(old.suffix(tail))
        let removed = String(old.dropLast(tail))
        let inserted = String(new.dropLast(tail))
        let prefix = String((original.before ?? "").dropLast(left.count)) + word.prefix(shared)
        let remaining = untouched + (original.after ?? "").dropFirst(right.count)
        let move = right.utf16.count - untouched.utf16.count
        if move != 0 { host.moveCaret(byUTF16: move) }
        let start = host.context
        guard start.matchesCaret(in: original, before: prefix + removed, after: remaining),
              (start.before ?? "").hasSuffix(removed) else { return false }

        // A filtering field can reject a suggestion. Insert first so a rejection
        // leaves the original text intact, even if the preceding letters repeat.
        if !inserted.isEmpty {
            host.insert(inserted)
            let staged = host.context
            if staged == start {
                if move != 0 { host.moveCaret(byUTF16: -move) }
                return false
            }
            guard staged.matchesCaret(in: original, before: prefix + removed + inserted, after: remaining)
            else { return false }
            if !removed.isEmpty { host.moveCaret(byUTF16: -inserted.utf16.count) }
        }

        var oldFragment = removed[...]
        while !oldFragment.isEmpty {
            let current = host.context
            guard current.matchesCaret(in: original, before: prefix + oldFragment, after: inserted + remaining),
                  current.before?.hasSuffix(oldFragment) == true else { return false }
            host.deleteBackward()
            oldFragment.removeLast()
        }
        let advance = untouched.utf16.count + (removed.isEmpty ? 0 : inserted.utf16.count)
        if advance != 0 { host.moveCaret(byUTF16: advance) }
        return host.context.matchesCaret(in: original, before: prefix + inserted + untouched,
                                         after: String((original.after ?? "").dropFirst(right.count)))
    }
}

struct DeferredEnglishSpace {
    private var anchor: HostContext?

    mutating func remember(_ context: HostContext, accepted word: String) {
        anchor = nil
        guard context.document != nil, context.selection?.isEmpty != false,
              (context.after ?? "").isEmpty, context.before?.hasSuffix(word) == true else { return }
        anchor = context
    }

    func applies(at context: HostContext) -> Bool { anchor == context }

    mutating func observe(_ context: HostContext) {
        if anchor != context { anchor = nil }
    }

    mutating func consume(before key: String, at context: HostContext) -> Bool {
        defer { anchor = nil }
        return applies(at: context) && key.count == 1 && key.first.map(EnglishToken.isLetter) == true
    }
}

enum Completions {
    // A short allowlist also works without an installed English spelling dictionary.
    private static let joinedPhrases = [
        "thank you", "see you", "good morning", "how are", "are you",
        "can you", "let me", "call me", "miss you", "love you", "on my", "of course",
        "a lot", "for you", "see ya", "right now", "talk soon", "take care"
    ]
    // Index prefixes only after the user has started the second word. For
    // shared prefixes (e.g. seey), the phrase list supplies the tie-breaker.
    private static let joinedPrefixes: [String: String] = {
        var index = [String: String]()
        for phrase in joinedPhrases {
            let words = phrase.split(separator: " ")
            var prefix = String(words[0])
            for letter in words[1] {
                prefix.append(letter)
                if index[prefix] == nil || prefix.count == phrase.count - 1 {
                    index[prefix] = phrase
                }
            }
        }
        return index
    }()

    static func joinedPhrase(for token: EnglishToken, allCaps: Bool) -> Completion? {
        let source = token.word
        guard let phrase = joinedPrefixes[key(source)],
              let space = phrase.firstIndex(of: " ") else { return nil }
        let joined = phrase.replacingOccurrences(of: " ", with: "")
        guard token.right.isEmpty || source.count == joined.count else { return nil }
        let boundary = phrase.distance(from: phrase.startIndex, to: space)
        var title = String(source.prefix(boundary)) + " " + source.dropFirst(boundary)
        title += joined.dropFirst(source.count)
        if allCaps || source == source.uppercased() { title = title.uppercased() }
        return Completion(title: title, suffix: "", action: .replace(token))
    }

    static func englishSuggestions(_ token: EnglishToken, apple: [String], guesses: [String],
                                   learned: [String], allCaps: Bool) -> [Completion] {
        let source = token.word
        var choices: [Completion] = []
        var seen = Set([key(source)])
        func offer(_ spelling: String) {
            guard choices.count < 3, seen.insert(key(spelling)).inserted else { return }
            let title: String
            if allCaps || source == source.uppercased() { title = spelling.uppercased() }
            else if source.first?.isUppercase == true { title = spelling.prefix(1).uppercased() + spelling.dropFirst() }
            else { title = spelling }
            choices.append(Completion(title: title, suffix: "", action: .replace(token)))
        }
        func offerSplit(_ phrase: String) {
            guard let space = phrase.firstIndex(of: " ") else { return }
            let boundary = phrase.distance(from: phrase.startIndex, to: space)
            offer(String(source.prefix(boundary)) + " " + source.dropFirst(boundary))
        }
        if !token.right.isEmpty && key(source) == "helo" { offer("hello") }
        if let phrase = joinedPhrase(for: token, allCaps: allCaps) {
            choices.append(phrase)
            seen.insert(key(phrase.title))
        }
        // A spelling dictionary may itself propose a missed space. Accept only
        // splits which preserve every typed letter and introduce one space.
        for guess in guesses where choices.isEmpty {
            let parts = guess.components(separatedBy: " ")
            if parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isLetter) }),
               key(parts.joined()) == key(source) { offerSplit(guess) }
        }
        if !token.right.isEmpty {
            for guess in guesses where guess.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "’" }) {
                offer(guess)
            }
        } else {
            let completions = matches(before: source, language: .english, apple: apple, learned: learned, allCaps: allCaps)
            choices += completions.filter { seen.insert(key($0.title)).inserted }.prefix(3 - choices.count)
        }
        return choices
    }

    static func selectedBurmese(_ selected: String, learned: [String]) -> [Completion] {
        guard !selected.isEmpty, selected.unicodeScalars.count <= 48,
              selected.unicodeScalars.allSatisfy({ (0x1000...0x103F).contains($0.value) }) else { return [] }
        return matches(before: selected, language: .burmese, learned: learned).compactMap {
            guard $0.title.utf8.starts(with: selected.utf8) else { return nil }
            var candidate = $0
            candidate.action = .selection
            return candidate
        }
    }

    private static let english = """
    hello help helpful here home hope how good goodbye morning night nice next
    please thank thanks tomorrow today tonight time together there their then
    meeting message minutes much welcome weekend work working would what when
    where which will with without yes yesterday you your keyboard language
    I'll I'm I've I'd don't didn't doesn't can't couldn't won't wouldn't
    you're we're they're that's there's let's isn't aren't wasn't
    """.split(whereSeparator: \.isWhitespace).map(String.init)

    // Everyday phrases take precedence over the alphabetical word-break dictionary.
    private static let conversational = """
    မင်္ဂလာပါ မင်္ဂလာ မြန်မာ မြန်မာစာ မြန်မာနိုင်ငံ ကျောင်း ကျောင်းသား
    ကျောင်းသူ ကျေးဇူး ကျေးဇူးတင်ပါတယ် ကျေးဇူးပါ နေကောင်းလား နေကောင်းပါတယ်
    ကောင်းပါတယ် ကောင်းတယ် ဟုတ်ကဲ့ ဟုတ်ပါတယ် အဆင်ပြေလား အဆင်ပြေပါတယ် အဆင်ပြေတယ်
    မနက်ဖြန် မနက်ခင်း ဒီနေ့ ဒီည နောက်မှ ပြန်တွေ့မယ် စာအုပ်
    ရန်ကုန် မန္တလေး အိမ် အလုပ် စကားပြော ကွန်ပျူတာ
    ဘယ်မှာလဲ ဘယ်တော့လဲ ဘယ်အချိန်လဲ ဘယ်လောက်လဲ ဘယ်လိုလဲ ဘာလုပ်နေလဲ
    စားပြီးပြီလား စားပြီးပြီ မစားရသေးဘူး ရောက်ပြီလား ရောက်ပြီ ရောက်တော့မယ်
    လာနေပြီ လာတော့မယ် ခဏစောင့်ပါ ခဏလေး စောင့်နေတယ် စောင့်ပေးပါ
    ရပါတယ် ရတယ် မရသေးဘူး မသိသေးဘူး သိပါပြီ နားလည်ပါတယ်
    အခု အခုပဲ အိမ်ပြန်ရောက်ပြီ ပြန်လာပြီ ပြန်ခေါ်မယ် ပြီးရင်ပြောမယ်
    ပို့ပေးပါ ဖုန်းဆက်မယ် သတိရတယ် ဂရုစိုက်ပါ တောင်းပန်ပါတယ်
    နောက်မှပြောမယ် တွေ့ရတာဝမ်းသာပါတယ် ကိစ္စမရှိပါဘူး အရမ်းကောင်းတယ်
    """.split(whereSeparator: \.isWhitespace).map(String.init)

    private static let conversationalWords = Set(conversational)

    static func englishPrefix(in text: String) -> String {
        let tail = text.reversed().prefix(while: EnglishToken.part).reversed()
        return String(tail.drop(while: { !EnglishToken.isLetter($0) }))
    }

    static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    private static func burmesePrefixes(in text: String) -> [String] {
        let run = Array(text.unicodeScalars.suffix(48).reversed().prefix {
            (0x1000...0x103F).contains($0.value)
        }.reversed())
        return run.indices.compactMap { i in
            guard (0x1000...0x102A).contains(run[i].value), i == 0 || run[i-1].value != 0x1039 else { return nil }
            return String(String.UnicodeScalarView(run[i...]))
        }
    }

    private static func insideBurmeseWord(_ prefixes: [String], after right: String?, learned: [String]) -> Bool {
        guard let right, let first = right.unicodeScalars.first else { return false }
        if (0x102B...0x103E).contains(first.value) { return true }
        guard (0x1000...0x102A).contains(first.value) || first.value == 0x103F else { return false }
        let continuation = right.unicodeScalars.prefix(48).prefix { (0x1000...0x103F).contains($0.value) }
        let endings = String(continuation)
        let savedWords = Set(learned)
        for prefix in prefixes {
            var word = prefix
            for character in endings {
                word.append(character)
                if conversationalWords.contains(word) || savedWords.contains(word) || BurmeseWordList.shared.contains(word) {
                    return true
                }
            }
        }
        return false
    }

    private static func overlapsBurmeseContinuation(_ suffix: String, after right: String?) -> Bool {
        guard let right, !right.isEmpty else { return false }
        if suffix.first == right.first { return true }
        // A longer candidate can also end with the next word in unspaced text.
        return suffix.indices.contains { right.unicodeScalars.starts(with: suffix[$0...].unicodeScalars) }
    }

    static func matches(before: String, after: String? = nil, language: Language, apple: [String] = [],
                        learned: [String] = [], allCaps: Bool = false) -> [Completion] {
        let prefixes = language == .english ? [englishPrefix(in: before)] : burmesePrefixes(in: before)
        if language == .burmese, insideBurmeseWord(prefixes, after: after, learned: learned) { return [] }
        for prefix in prefixes where !prefix.isEmpty {
            let needle = key(prefix)
            var result = [Completion]()
            var seen = Set<String>()
            func add(_ word: String, learned: Bool = false) {
                guard result.count < 3 else { return }
                let normalized = key(word)
                guard normalized.utf8.starts(with: needle.utf8), normalized != needle,
                      seen.insert(normalized).inserted else { return }
                let rest = word.unicodeScalars.dropFirst(prefix.unicodeScalars.count)
                let caps = language == .english && (allCaps || (prefix.filter(\.isLetter).count > 1 && prefix == prefix.uppercased()))
                let suffix: String
                if caps { suffix = String(rest).uppercased() }
                else if learned && language == .english {
                    // A previous tap may have been in an all-caps field. Use
                    // dictionary spelling for names such as iPhone when available.
                    let spelling = apple.first { key($0) == normalized && $0 != $0.uppercased() }
                    suffix = spelling.map { String($0.unicodeScalars.dropFirst(prefix.unicodeScalars.count)) }
                        ?? String(rest).lowercased()
                }
                else { suffix = String(rest) }
                if language == .burmese, overlapsBurmeseContinuation(suffix, after: after) { return }
                result.append(Completion(title: prefix + suffix, suffix: suffix, learned: learned))
            }

            for word in learned where result.count < 3 { add(word, learned: true) }
            if language == .english {
                // Keep one familiar everyday completion alongside Apple's leading choices.
                for word in apple {
                    if result.count >= 2 { break }
                    add(word)
                }
                for word in english where result.count < 3 { add(word) }
                for word in apple where result.count < 3 { add(word) }
            } else {
                for word in conversational where result.count < 3 { add(word) }
                if result.count < 3 {
                    for word in BurmeseWordList.shared.matches(prefix) { add(word) }
                }
            }
            if !result.isEmpty { return result }
        }
        return []
    }
}

private struct BurmeseWordList {
    static let shared = BurmeseWordList()
    private let words: [ArraySlice<UInt8>]

    private init() {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "BurmeseWords", withExtension: "txt"),
              let data = try? Data(contentsOf: url) else { words = []; return }
        words = Array(data).split(separator: 10)
    }

    private func lowerBound(_ needle: String.UTF8View) -> Int {
        // The bundled lines are sorted by UTF-8. Search by bytes so a partial
        // Myanmar grapheme can match its continuation without scanning the list.
        var low = 0, high = words.count
        while low < high {
            let mid = low + (high - low) / 2
            if words[mid].lexicographicallyPrecedes(needle) { low = mid + 1 }
            else { high = mid }
        }
        return low
    }

    func contains(_ word: String) -> Bool {
        let bytes = word.utf8
        let index = lowerBound(bytes)
        return index < words.count && words[index].elementsEqual(bytes)
    }

    func matches(_ prefix: String) -> [String] {
        let needle = prefix.utf8
        return words[lowerBound(needle)...].prefix(4).prefix(while: { $0.starts(with: needle) })
            .map { String(decoding: $0, as: UTF8.self) }
    }
}
