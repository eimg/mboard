import Foundation

struct Completion: Equatable {
    let title: String
    let suffix: String
    var learned = false
}

enum Completions {
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

    static func englishPrefix(in text: String) -> String {
        let tail = text.unicodeScalars.reversed().prefix {
            (65...90).contains($0.value) || (97...122).contains($0.value) || $0 == "'" || $0 == "’"
        }
        return String(String.UnicodeScalarView(tail.reversed().drop(while: { $0 == "'" || $0 == "’" })))
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

    static func matches(before: String, language: Language, apple: [String] = [],
                        learned: [String] = []) -> [Completion] {
        let prefixes = language == .english ? [englishPrefix(in: before)] : burmesePrefixes(in: before)
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
                let caps = language == .english && prefix.filter(\.isLetter).count > 1 && prefix == prefix.uppercased()
                let suffix = caps ? String(rest).uppercased() : String(rest)
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

    func matches(_ prefix: String) -> [String] {
        // The bundled lines are sorted by UTF-8. Search by bytes so a partial
        // Myanmar grapheme can match its continuation without scanning the list.
        let needle = prefix.utf8
        var low = 0, high = words.count
        while low < high {
            let mid = low + (high - low) / 2
            if words[mid].lexicographicallyPrecedes(needle) { low = mid + 1 }
            else { high = mid }
        }
        return words[low...].prefix(4).prefix(while: { $0.starts(with: needle) })
            .map { String(decoding: $0, as: UTF8.self) }
    }
}
