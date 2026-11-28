import XCTest
@testable import MBoardCore

final class EmojiCatalogTests: XCTestCase {
    private func catalog(version: Double = 17) throws -> EmojiCatalog {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let tsv = try String(contentsOf: root.appendingPathComponent("Keyboard/Resources/Emoji.tsv"), encoding: .utf8)
        return EmojiCatalog(tsv: tsv, maximumVersion: version)
    }

    func testCommonQueriesFindIntendedEmojiWithoutSubstringNoise() throws {
        let catalog = try catalog()
        func matches(_ query: String) -> [String] { catalog.matches(query).map(\.glyph) }
        XCTAssertTrue(matches("happy").contains("😊"))
        XCTAssertTrue(matches("thanks").contains("🙏"))
        XCTAssertTrue(matches("THANK YOU").contains("🙏"))
        XCTAssertTrue(matches("love").contains("❤️"))
        XCTAssertFalse(matches("love").contains("🇸🇮"))
        XCTAssertTrue(matches("lol").contains("😂"))
        XCTAssertFalse(matches("lol").contains("🍭"))
        XCTAssertTrue(matches("ကြောင်").contains("🐱"))
        XCTAssertTrue(matches("ကျေးဇူး").contains("🙏"))
        XCTAssertEqual(matches("🩷"), ["🩷"])
        XCTAssertEqual(matches("  "), [])
        XCTAssertTrue(catalog.matches("hand").allSatisfy { !$0.hasSkinTone })
    }

    func testCommonFirstOrderingStillContainsTheFullList() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog.items.count, 3944)
        XCTAssertEqual(EmojiCatalog.everydayGlyphs.count, 144)
        XCTAssertEqual(catalog.browseItems.prefix(144).map(\.glyph), EmojiCatalog.everydayGlyphs)
        XCTAssertEqual(Set(catalog.browseItems.map(\.glyph)), Set(catalog.items.filter { !$0.hasSkinTone }.map(\.glyph)))
        XCTAssertEqual(Set(catalog.browseItems.map(\.glyph)).count, catalog.browseItems.count)
        XCTAssertTrue(catalog.browseItems.contains { $0.glyph == "🇲🇲" })
    }

    func testVersionFilteringAppliesToSearchRecentsAndToneVariants() throws {
        let old = try catalog(version: 14)
        let modern = try catalog()
        XCTAssertFalse(old.items.contains { $0.glyph == "🩷" })
        XCTAssertTrue(modern.items.contains { $0.glyph == "🩷" })
        XCTAssertTrue(old.matches("pink heart").isEmpty)
        XCTAssertTrue(old.recent(glyphs: ["🩷"]).isEmpty)
        let handshake = try XCTUnwrap(old.items.first { $0.glyph == "🤝" })
        XCTAssertGreaterThan(old.variants(for: handshake).count, 5)
        XCTAssertTrue(old.variants(for: handshake).allSatisfy { $0.version <= 14 })
    }

    func testSavedRecentsKeepToneAndOrderWithoutDuplicatesOrUnknownEntries() throws {
        let catalog = try catalog()
        let saved = catalog.recent(glyphs: ["invalid", "👍🏽", "❤️", "👍🏽", "😂"])
        XCTAssertEqual(saved.map(\.glyph), ["👍🏽", "❤️", "😂"])
        let browse = catalog.browse(recent: saved)
        XCTAssertEqual(browse.prefix(3).map(\.glyph), saved.map(\.glyph))
        XCTAssertEqual(browse.filter { $0.glyph == "❤️" }.count, 1)
        XCTAssertEqual(catalog.recent(glyphs: catalog.items.prefix(50).map(\.glyph)).count, 32)
    }
}
