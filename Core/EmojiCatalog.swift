import Foundation

struct EmojiItem: Equatable, Sendable {
    let glyph: String
    let name: String
    let keywords: String
    let version: Double

    var base: String {
        let untoned = String(String.UnicodeScalarView(glyph.unicodeScalars.filter {
            !(0x1F3FB...0x1F3FF).contains($0.value) && $0.value != 0xFE0F
        }))
        return Self.variantBases[untoned] ?? untoned
    }

    var hasSkinTone: Bool { glyph.unicodeScalars.contains { (0x1F3FB...0x1F3FF).contains($0.value) } }

    // Multi-person tone sequences use a different encoding from their default emoji.
    private static let variantBases = [
        "🫱‍🫲": "🤝", "👩‍🤝‍👩": "👭", "👩‍🤝‍👨": "👫", "👨‍🤝‍👨": "👬",
        "🧑‍❤‍💋‍🧑": "💏", "🧑‍❤‍🧑": "💑"
    ]
}

struct EmojiCatalog: Sendable {
    let items: [EmojiItem]
    let browseItems: [EmojiItem]
    private let groups: [String: [EmojiItem]]
    private let byGlyph: [String: EmojiItem]
    private let searchEntries: [SearchEntry]
    private struct SearchEntry: Sendable {
        let item: EmojiItem
        let name: String
        let terms: Set<String>
        let words: Set<String>
    }

    // A curated starting order, followed by the complete Unicode list. Emoji
    // unsupported by the current iOS version are filtered before this is applied.
    static let everydayGlyphs = """
    😀 😊 😂 🤣 🥰 😍 😘 😭 🥹 🥲 😅 🙏 👍 ❤️ 🩷 💕
    😁 😄 😆 🙂 🙃 😉 😌 😋 😜 🤪 😎 🤩 🥳 😏 😒 😔
    😞 😢 😩 😫 🥺 😤 😡 🤬 😱 😨 😰 😥 😓 🤗 🤔 🫢
    🤭 🤫 🫣 🫠 🫡 🤐 🤨 😐 😑 🙄 😬 😮 😯 😲 😳 🤯
    🥱 😴 🤤 😪 🤒 🤕 🤢 🤮 🤧 🥵 🥶 🫨 😵‍💫 🫩 🫶 🥴
    👋 🤚 ✋ 👌 ✌️ 🤞 🤟 🤘 🤙 👎 👏 🙌 🤝 💪 🫰 👀
    💔 💖 💗 💓 💞 💘 💝 💜 💙 🩵 💚 💛 🧡 🤍 🩶 🖤
    🔥 ✨ ⭐ 🌟 💯 ✅ ❌ ❗ ❓ 🎉 🎊 🎂 🎁 🎈 🌹 💐
    🌸 🌻 ☀️ 🌙 🌈 ☔ 🐱 🐶 🐻 🦋 🍀 🍕 🍔 ☕ 🍺 🥂
    """.split(whereSeparator: \.isWhitespace).map(String.init)

    init(tsv: String, maximumVersion: Double) {
        let parsed: [EmojiItem] = tsv.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 5, let version = Double(fields[4]), version <= maximumVersion else { return nil }
            return EmojiItem(glyph: String(fields[1]), name: String(fields[2]), keywords: String(fields[3]), version: version)
        }
        items = parsed
        let index = Dictionary(parsed.map { ($0.glyph, $0) }, uniquingKeysWith: { first, _ in first })
        byGlyph = index
        groups = Dictionary(grouping: parsed, by: \.base).filter { $0.value.count > 1 }
        let common = Self.everydayGlyphs.compactMap { index[$0] }
        let commonGlyphs = Set(common.map(\.glyph))
        let browse = common + parsed.filter { !$0.hasSkinTone && !commonGlyphs.contains($0.glyph) }
        browseItems = browse
        searchEntries = browse.map { item in
            let name = Self.normalized(item.name)
            let terms = Set((item.keywords + " | " + item.name).components(separatedBy: " | ").map(Self.normalized))
            return SearchEntry(item: item, name: name, terms: terms,
                               words: Set(terms.flatMap { Self.words(in: $0) }))
        }
    }

    func browse(recent: [EmojiItem]) -> [EmojiItem] {
        let recentGlyphs = Set(recent.map(\.glyph))
        return recent + browseItems.filter { !recentGlyphs.contains($0.glyph) }
    }

    func recent(glyphs: [String]) -> [EmojiItem] {
        var seen = Set<String>()
        return Array(glyphs.compactMap { glyph in
            guard seen.insert(glyph).inserted else { return nil }
            return byGlyph[glyph]
        }.prefix(32))
    }

    func variants(for item: EmojiItem) -> [EmojiItem] { groups[item.base] ?? [] }

    func matches(_ query: String) -> [EmojiItem] {
        let query = Self.normalized(query)
        guard !query.isEmpty else { return [] }
        if let emoji = byGlyph[query] { return [emoji] }
        let tokens = Self.words(in: query)
        guard !tokens.isEmpty else { return [] }
        var ranked = [(rank: Int, order: Int, item: EmojiItem)]()
        for (order, entry) in searchEntries.enumerated() {
            if Task.isCancelled { return [] }
            let exact = entry.terms.contains(query)
            let matches = tokens.allSatisfy { token in
                if token.unicodeScalars.contains(where: { (0x1000...0x109F).contains($0.value) }) {
                    return entry.terms.contains { $0.contains(token) }
                }
                if ["lol", "lmao", "rofl", "ok"].contains(token) { return entry.words.contains(token) }
                // Match word prefixes so "love" cannot match "Slovenia".
                return entry.words.contains { $0.hasPrefix(token) }
            }
            guard exact || matches else { continue }
            let rank: Int
            if entry.name == query { rank = 0 }
            else if exact { rank = 1 }
            else if tokens.allSatisfy({ entry.words.contains($0) }) { rank = 2 }
            else { rank = 3 }
            ranked.append((rank, order, entry.item))
        }
        return ranked.sorted { ($0.rank, $0.order) < ($1.rank, $1.order) }.map(\.item)
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "\u{200C}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func words(in value: String) -> [String] {
        value.split { character in
            let isMark = character.unicodeScalars.contains {
                $0.properties.generalCategory == .nonspacingMark || $0.properties.generalCategory == .spacingMark
            }
            return !character.isLetter && !character.isNumber && !isMark
        }.map(String.init)
    }
}
