import Foundation

struct LearnedWords: Codable {
    private struct Choice: Codable {
        let word: String
        let language: String
        let weight: Double
        let lastPicked: Date

        // Optional fields keep existing selection-only history readable.
        var typedCount: Int?
        var picked: Bool?
        var personalCase: String?
        var predecessors: [String: Double]?

        func score(at time: Date) -> Double {
            let days = max(0, time.timeIntervalSince(lastPicked)) / 86_400
            return weight * pow(0.5, days / 30)
        }
    }

    private var choices = [Choice]()

    struct Ranking {
        var words = [String]()
        var personalCase = [String: String]()
    }

    func ranking(for language: Language, previous: String? = nil, at time: Date = Date()) -> Ranking {
        let context = previous.map(Completions.key)
        var scored = [(choice: Choice, contextScore: Double, score: Double)]()
        for choice in choices where choice.language == language.rawValue {
            let weight = choice.score(at: time)
            guard weight >= 0.25 else { continue }
            let requiredUses = Completions.isEverydayEnglish(choice.word) ? 2 : 3
            guard choice.picked != false || (choice.typedCount ?? 0) >= requiredUses else { continue }
            let association = context.flatMap { choice.predecessors?[$0] } ?? 0
            let local = association * weight / choice.weight
            scored.append((choice, local >= 0.45 ? local : 0, weight))
        }
        scored.sort {
            ($0.contextScore, $0.score, $0.choice.lastPicked) > ($1.contextScore, $1.score, $1.choice.lastPicked)
        }
        var result = Ranking()
        for (choice, _, _) in scored {
            result.words.append(choice.word)
            if let spelling = choice.personalCase { result.personalCase[Completions.key(choice.word)] = spelling }
        }
        return result
    }

    func ranked(for language: Language, at time: Date = Date()) -> [String] {
        ranking(for: language, at: time).words
    }

    mutating func record(_ word: String, language: Language, previous: String? = nil,
                         typed: Bool = false, intentionalCase: Bool = false, at time: Date = Date()) {
        let key = Completions.key(word)
        // Repeated slips shouldn't train away their correction. An explicitly
        // capitalized name (such as Teh) or a suggestion tap can still qualify.
        if typed, language == .english, Completions.isCommonEnglishTypo(word),
           !(intentionalCase && word != word.lowercased()) { return }
        let index = choices.firstIndex { $0.language == language.rawValue && Completions.key($0.word) == key }
        let old = index.map { choices.remove(at: $0) }
        let priorScore = old?.score(at: time) ?? 0
        let increment = typed ? 0.3 : 1.0
        var contexts = old?.predecessors?.mapValues { $0 * priorScore / (old?.weight ?? 1) } ?? [:]
        if let previous, language == .english {
            let predecessor = Completions.key(previous)
            contexts[predecessor, default: 0] += increment
            if contexts.count > 6, let weakest = contexts.min(by: { $0.value < $1.value }) {
                contexts.removeValue(forKey: weakest.key)
            }
        }
        if choices.count >= 256,
           let weakest = choices.indices.min(by: { choices[$0].score(at: time) < choices[$1].score(at: time) }) {
            choices.remove(at: weakest)
        }
        let hasPick = !typed || (old.map { $0.picked ?? true } ?? false)
        choices.append(Choice(word: word, language: language.rawValue, weight: priorScore + increment, lastPicked: time,
                              typedCount: min(255, (old?.typedCount ?? 0) + (typed ? 1 : 0)), picked: hasPick,
                              personalCase: intentionalCase ? word : old?.personalCase,
                              predecessors: contexts.isEmpty ? nil : contexts))
    }

    mutating func forget(_ word: String, language: Language) {
        let key = Completions.key(word)
        choices.removeAll { $0.language == language.rawValue && Completions.key($0.word) == key }
        if language == .english {
            for index in choices.indices { choices[index].predecessors?.removeValue(forKey: key) }
        }
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
        await ranking(for: language).words
    }

    func ranking(for language: Language, previous: String? = nil) async -> LearnedWords.Ranking {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.history.ranking(for: language, previous: previous)) }
        }
    }

    func record(_ word: String, language: Language, previous: String? = nil,
                typed: Bool = false, intentionalCase: Bool = false) {
        update { $0.record(word, language: language, previous: previous, typed: typed, intentionalCase: intentionalCase) }
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
