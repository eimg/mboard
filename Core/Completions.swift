import Foundation

struct Completion: Equatable {
    let title: String
    let suffix: String
}

enum Completions {
    // Small, hand-entered prototype vocabulary. No external dictionary assets.
    private static let english = """
    hello help helpful here home hope how good goodbye morning night nice next
    please thank thanks tomorrow today tonight time together there their then
    meeting message minutes much welcome weekend work working would what when
    where which will with without yes yesterday you your keyboard language
    """
    private static let burmese = """
    မင်္ဂလာပါ မင်္ဂလာ မြန်မာ မြန်မာစာ မြန်မာနိုင်ငံ ကျောင်း ကျောင်းသား
    ကျောင်းသူ ကျေးဇူး ကျေးဇူးတင်ပါတယ် နေကောင်းလား နေကောင်းပါတယ်
    ကောင်းပါတယ် ကောင်းတယ် ဟုတ်ကဲ့ ဟုတ်ပါတယ် အဆင်ပြေပါတယ်
    မနက်ဖြန် မနက်ခင်း ဒီနေ့ ဒီည နောက်မှ ပြန်တွေ့မယ် စာအုပ်
    ရန်ကုန် မန္တလေး အိမ် အလုပ် စကားပြော ကွန်ပျူတာ
    """
    private static let words = [Language.english: english.split(whereSeparator: \.isWhitespace).map(String.init),
                                .burmese: burmese.split(whereSeparator: \.isWhitespace).map(String.init)]

    static func matches(before: String, language: Language) -> [Completion] {
        let vocabulary = words[language] ?? []
        let scalars = Array(before.unicodeScalars.suffix(48))
        var prefixes = [String]()
        if language == .english {
            let token = String(String.UnicodeScalarView(scalars.reversed().prefix {
                (65...90).contains($0.value) || (97...122).contains($0.value)
            }.reversed()))
            if !token.isEmpty { prefixes.append(token) }
        } else {
            // Consider a word following another word without a separating space.
            let run = Array(scalars.reversed().prefix { (0x1000...0x103F).contains($0.value) }.reversed())
            for i in run.indices where (0x1000...0x102A).contains(run[i].value) {
                if i > 0 && run[i-1].value == 0x1039 { continue }
                prefixes.append(String(String.UnicodeScalarView(run[i...])))
            }
        }
        for prefix in prefixes {
            let p = prefix.lowercased().unicodeScalars
            let found: [Completion] = vocabulary.compactMap { word in
                guard word.unicodeScalars.starts(with: p), word.unicodeScalars.count > p.count else { return nil }
                let suffix = String(word.unicodeScalars.dropFirst(p.count))
                return Completion(title: prefix + suffix, suffix: suffix)
            }
            if !found.isEmpty { return Array(found.prefix(3)) }
        }
        return []
    }
}
