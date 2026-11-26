import Foundation

struct LearnedWords: Codable {
    private struct Choice: Codable {
        let word: String
        let language: String
        let weight: Double
        let lastPicked: Date

        func score(at time: Date) -> Double {
            let days = max(0, time.timeIntervalSince(lastPicked)) / 86_400
            return weight * pow(0.5, days / 30)
        }
    }

    private var choices = [Choice]()

    func ranked(for language: Language, at time: Date = Date()) -> [String] {
        choices.filter { $0.language == language.rawValue && $0.score(at: time) >= 0.25 }
            .sorted { $0.score(at: time) > $1.score(at: time) }.map(\.word)
    }

    mutating func record(_ word: String, language: Language, at time: Date = Date()) {
        let key = Completions.key(word)
        let index = choices.firstIndex { $0.language == language.rawValue && Completions.key($0.word) == key }
        let previous = index.map { choices.remove(at: $0).score(at: time) } ?? 0
        if choices.count >= 256,
           let weakest = choices.indices.min(by: { choices[$0].score(at: time) < choices[$1].score(at: time) }) {
            choices.remove(at: weakest)
        }
        choices.append(Choice(word: word, language: language.rawValue, weight: previous + 1, lastPicked: time))
    }

    mutating func forget(_ word: String, language: Language) {
        let key = Completions.key(word)
        choices.removeAll { $0.language == language.rawValue && Completions.key($0.word) == key }
    }
}

// Submitting mutations synchronously orders a tap, a later forget/clear, and
// the next lookup. Persistence and ranking stay off the input thread.
final class LearnedWordStore: @unchecked Sendable {
    static let shared = LearnedWordStore()
    private let queue = DispatchQueue(label: "com.eimg.mboard.learned-words")
    private let defaults: UserDefaults
    private let key = "learnedCompletions.v1"
    private lazy var history: LearnedWords = {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(LearnedWords.self, from: data) else { return LearnedWords() }
        return saved
    }()

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func ranked(for language: Language) async -> [String] {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.history.ranked(for: language)) }
        }
    }

    func record(_ word: String, language: Language) {
        update { $0.record(word, language: language) }
    }

    func forget(_ word: String, language: Language) {
        update { $0.forget(word, language: language) }
    }

    private func update(_ change: @escaping (inout LearnedWords) -> Void) {
        queue.async {
            change(&self.history)
            if let data = try? JSONEncoder().encode(self.history) { self.defaults.set(data, forKey: self.key) }
        }
    }

    func clear() {
        queue.async {
            self.history = LearnedWords()
            self.defaults.removeObject(forKey: self.key)
        }
    }
}
