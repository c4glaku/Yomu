import Foundation
import NaturalLanguage
import SQLite3

private final class SQLiteConnection: @unchecked Sendable {
    let handle: OpaquePointer
    init(url: URL) throws {
        var pointer: OpaquePointer?
        let code = sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard code == SQLITE_OK, let pointer else {
            if let pointer { sqlite3_close(pointer) }
            throw DictionaryError.unavailable
        }
        handle = pointer
    }
    deinit { sqlite3_close(handle) }
}

public enum DictionaryError: LocalizedError {
    case unavailable
    public var errorDescription: String? { "The Japanese dictionary could not be opened. Please reinstall the app." }
}

public actor JapaneseDictionary {
    private let connection: SQLiteConnection
    public init(url: URL? = nil) throws {
        guard let url = url ?? Bundle.module.url(forResource: "Dictionary", withExtension: "sqlite") else {
            throw DictionaryError.unavailable
        }
        connection = try SQLiteConnection(url: url)
    }

    public func lookup(_ text: String) -> [DictionaryEntry] {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !text.isEmpty, text.count <= 80 else { return [] }
        let direct = entries(for: text)
        if !direct.isEmpty { return direct }
        for form in JapaneseText.dictionaryForms(text) where form != text {
            let matches = entries(for: form)
            if !matches.isEmpty { return matches }
        }
        return []
    }

    private func entries(for form: String) -> [DictionaryEntry] {
        let sql = "SELECT e.id,e.word,e.reading,e.meanings,e.pos,e.common FROM forms f JOIN entries e ON e.id=f.entry_id WHERE f.form=? ORDER BY e.common DESC,e.id LIMIT 16"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(form, to: statement, index: 1)
        var results: [DictionaryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW { results.append(entry(from: statement)) }
        return results
    }

    public func kanji(in text: String) -> [KanjiEntry] {
        var seen = Set<String>()
        return text.compactMap { character in
            let value = String(character)
            guard JapaneseText.containsKanji(value), seen.insert(value).inserted else { return nil }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(connection.handle, "SELECT character,onyomi,kunyomi,meanings FROM kanji WHERE character=?", -1, &statement, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(statement) }
            bind(value, to: statement, index: 1)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return KanjiEntry(character: column(statement, 0), onyomi: array(statement, 1),
                              kunyomi: array(statement, 2), meanings: array(statement, 3))
        }
    }

    public func candidates(in page: BookPage, maximum: Int = 16) -> [QuizCandidate] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = page.text
        tokenizer.setLanguage(.japanese)
        var ranges: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: page.text.startIndex..<page.text.endIndex) { range, _ in ranges.append(range); return true }
        var seen = Set<String>()
        var candidates: [QuizCandidate] = []
        var index = 0
        while index < ranges.count {
            var consumed = 1
            // Japanese tokenization separates conjugation endings. Try contiguous
            // windows first: 入れ + た must resolve to 入れる, not the noun 入れ.
            for length in stride(from: min(4, ranges.count - index), through: 1, by: -1) {
                let surface = String(page.text[ranges[index].lowerBound..<ranges[index + length - 1].upperBound])
                guard (2...30).contains(surface.count), surface.allSatisfy({ JapaneseText.containsJapanese(String($0)) || $0.isNumber }),
                      let entry = lookup(surface).first else { continue }
                // Kana-only auxiliary endings can be homophones of unrelated
                // kanji words (いた -> 板). Only quiz a kana spelling when it is
                // itself a dictionary headword, rather than inferring kanji.
                guard JapaneseText.containsKanji(surface) ||
                        (surface.count >= 3 && entry.word == surface && !entry.partOfSpeech.contains("auxiliary") && !entry.partOfSpeech.contains("suffix")) else { continue }
                consumed = length
                if seen.insert(entry.word).inserted {
                    let score = (JapaneseText.containsKanji(entry.word) ? 4 : 0) + (entry.common ? 1 : 3)
                    candidates.append(QuizCandidate(entry: entry, context: JapaneseText.context(for: surface, in: page.text),
                                                    pageIndex: page.id, priority: score))
                }
                break
            }
            index += consumed
        }
        return Array(candidates.sorted { $0.priority > $1.priority }.prefix(maximum))
    }

    public func distractors() -> [DictionaryEntry] {
        ["学校", "時間", "友達", "勉強", "図書館", "静か", "旅行", "天気", "電車", "物語", "言葉", "朝", "夜", "本", "水", "食べる", "読む", "歩く", "大切", "新しい"]
            .compactMap { entries(for: $0).first }
    }

    private func bind(_ text: String, to statement: OpaquePointer?, index: Int32) {
        _ = text.withCString { sqlite3_bind_text(statement, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    private func column(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }
    private func array(_ statement: OpaquePointer?, _ index: Int32) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(column(statement, index).utf8))) ?? []
    }
    private func entry(from statement: OpaquePointer?) -> DictionaryEntry {
        DictionaryEntry(id: Int(sqlite3_column_int64(statement, 0)), word: column(statement, 1),
                        reading: column(statement, 2), meanings: array(statement, 3),
                        partOfSpeech: column(statement, 4), common: sqlite3_column_int(statement, 5) != 0)
    }
}

public enum JapaneseText {
    public static func containsKanji(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) || (0x20000...0x3134F).contains($0.value) }
    }
    public static func containsJapanese(_ text: String) -> Bool {
        containsKanji(text) || text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
    }
    public static func tokens(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.japanese)
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range])); return true
        }
        return tokens
    }
    public static func dictionaryForms(_ text: String) -> [String] {
        var result = [text]
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        tagger.setLanguage(.japanese, range: text.startIndex..<text.endIndex)
        if !text.isEmpty, let lemma = tagger.tag(at: text.startIndex, unit: .word, scheme: .lemma).0?.rawValue {
            result.append(lemma)
        }
        // A bounded fallback for common polite, negative, past and te forms.
        let rules: [(String, [String])] = [
            ("ました", ["る", "う", "く", "ぐ", "す", "つ", "ぬ", "ぶ", "む"]),
            ("ます", ["る", "う", "く", "ぐ", "す", "つ", "ぬ", "ぶ", "む"]),
            ("ません", ["る"]), ("なかった", ["る"]), ("ない", ["る"]),
            ("かった", ["い"]), ("くない", ["い"]), ("くて", ["い"]),
            ("って", ["う", "つ", "る"]), ("った", ["う", "つ", "る"]),
            ("んで", ["む", "ぶ", "ぬ"]), ("んだ", ["む", "ぶ", "ぬ"]),
            ("いて", ["く"]), ("いた", ["く"]), ("いで", ["ぐ"]), ("いだ", ["ぐ"]),
            ("して", ["す", "する"]), ("した", ["す", "する"]), ("て", ["る"]), ("た", ["る"])
        ]
        for (suffix, endings) in rules where text.hasSuffix(suffix) && text.count > suffix.count {
            let stem = String(text.dropLast(suffix.count))
            result += endings.map { stem + $0 }
            if ["ました", "ます", "ません"].contains(suffix), let last = stem.last {
                let dictionaryEnding: [Character: String] = ["い": "う", "き": "く", "ぎ": "ぐ", "し": "す", "ち": "つ", "に": "ぬ", "び": "ぶ", "み": "む", "り": "る"]
                if let ending = dictionaryEnding[last] { result.append(String(stem.dropLast()) + ending) }
            }
        }
        return result
    }
    public static func context(for word: String, in text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
        let sentence = sentences.first { $0.contains(word) } ?? text
        return String(sentence.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180))
    }
    public static func hiragana(_ text: String) -> String {
        text.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text
    }
}
