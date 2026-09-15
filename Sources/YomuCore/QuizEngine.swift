import Foundation

public enum QuizKind: String, Sendable { case reading, meaning }

public struct QuizQuestion: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var kind: QuizKind
    public var entry: DictionaryEntry
    public var context: String
    public var pageIndex: Int
    public var choices: [String]
    public var answer: String
}

public enum QuizEngine {
    public static func questions(candidates: [QuizCandidate], distractors: [DictionaryEntry], limit: Int = 10) -> [QuizQuestion] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        let selected = candidates.sorted { $0.priority > $1.priority }.filter { seen.insert($0.entry.word).inserted }
        let pool = selected.map(\.entry) + distractors
        var result: [QuizQuestion] = []
        // Interleave reading and meaning questions, with at most two per word.
        for kind in [QuizKind.reading, .meaning] {
            for candidate in selected {
                let entry = candidate.entry
                if kind == .reading && !JapaneseText.containsKanji(entry.word) { continue }
                let answer = kind == .reading ? JapaneseText.hiragana(entry.reading) : (entry.meanings.first ?? "")
                guard !answer.isEmpty else { continue }
                let validReadings = Set(pool.filter { $0.word == entry.word }.map { JapaneseText.hiragana($0.reading) })
                var unique = Set([answer])
                let wrongAnswers = pool.shuffled().filter { other in
                    other.word != entry.word && Set(other.meanings).isDisjoint(with: entry.meanings)
                }.compactMap { other -> String? in
                    let value = kind == .reading ? JapaneseText.hiragana(other.reading) : (other.meanings.first ?? "")
                    guard !value.isEmpty, kind != .reading || !validReadings.contains(value), unique.insert(value).inserted else { return nil }
                    return value
                }
                guard wrongAnswers.count >= 2 else { continue }
                result.append(QuizQuestion(kind: kind, entry: entry, context: candidate.context,
                                           pageIndex: candidate.pageIndex,
                                           choices: ([answer] + wrongAnswers.prefix(3)).shuffled(), answer: answer))
            }
        }
        // Round-robin the two kinds so short quizzes still exercise both skills.
        var readings = result.filter { $0.kind == .reading }
        var meanings = result.filter { $0.kind == .meaning }
        var ordered: [QuizQuestion] = []
        while ordered.count < limit && (!readings.isEmpty || !meanings.isEmpty) {
            if !readings.isEmpty { ordered.append(readings.removeFirst()) }
            if ordered.count < limit && !meanings.isEmpty { ordered.append(meanings.removeFirst()) }
        }
        return ordered
    }
}
