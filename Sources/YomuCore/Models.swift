import Foundation

public enum BookFormat: String, Codable, CaseIterable, Sendable {
    case pdf, epub, txt, sample
    public var label: String { self == .sample ? "ORIGINAL STORY" : rawValue.uppercased() }
}

public struct BookPage: Codable, Identifiable, Hashable, Sendable {
    public var id: Int
    public var text: String
    public var chapter: String
    public var chapterIndex: Int
    public init(id: Int, text: String, chapter: String, chapterIndex: Int = 0) {
        self.id = id; self.text = text; self.chapter = chapter; self.chapterIndex = chapterIndex
    }
}

public struct BookContent: Codable, Sendable {
    public var id: UUID
    public var pages: [BookPage]
    public init(id: UUID, pages: [BookPage]) { self.id = id; self.pages = pages }
}

public struct LibraryBook: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var author: String
    public var format: BookFormat
    public var pageCount: Int
    public var currentPage: Int
    public var completed: Bool
    public var addedAt: Date
    public var lastReadAt: Date?
    public var coverStyle: Int
    public var coverFile: String?
    public var progress: Double { completed ? 1 : Double(currentPage) / Double(max(1, pageCount)) }

    public init(id: UUID = UUID(), title: String, author: String, format: BookFormat,
                pageCount: Int, coverStyle: Int = 0, coverFile: String? = nil) {
        self.id = id; self.title = title; self.author = author; self.format = format
        self.pageCount = pageCount; self.currentPage = 0; self.completed = false
        self.addedAt = Date(); self.coverStyle = coverStyle; self.coverFile = coverFile
    }
}

public struct DictionaryEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var word: String
    public var reading: String
    public var meanings: [String]
    public var partOfSpeech: String
    public var common: Bool
    public var definition: String { meanings.joined(separator: "; ") }
    public init(id: Int, word: String, reading: String, meanings: [String], partOfSpeech: String = "", common: Bool = false) {
        self.id = id; self.word = word; self.reading = reading; self.meanings = meanings
        self.partOfSpeech = partOfSpeech; self.common = common
    }
}

public struct KanjiEntry: Identifiable, Sendable {
    public var id: String { character }
    public var character: String
    public var onyomi: [String]
    public var kunyomi: [String]
    public var meanings: [String]
}

public struct SavedWord: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var entry: DictionaryEntry
    public var bookID: UUID
    public var bookTitle: String
    public var pageIndex: Int
    public var context: String
    public var selectedText: String
    public var savedAt: Date
    public init(entry: DictionaryEntry, bookID: UUID, bookTitle: String, pageIndex: Int,
                context: String, selectedText: String) {
        id = UUID(); self.entry = entry; self.bookID = bookID; self.bookTitle = bookTitle
        self.pageIndex = pageIndex; self.context = context; self.selectedText = selectedText; savedAt = Date()
    }
}

public struct QuizCandidate: Hashable, Sendable {
    public var entry: DictionaryEntry
    public var context: String
    public var pageIndex: Int
    public var priority: Int
    public init(entry: DictionaryEntry, context: String, pageIndex: Int, priority: Int = 0) {
        self.entry = entry; self.context = context; self.pageIndex = pageIndex; self.priority = priority
    }
}

public struct ReadingRecord: Codable, Identifiable, Sendable {
    public var id: UUID
    public var bookID: UUID
    public var bookTitle: String
    public var date: Date
    public var pagesRead: Int
    public var correctAnswers: Int
    public var questionCount: Int
    public init(bookID: UUID, bookTitle: String, pagesRead: Int, correctAnswers: Int, questionCount: Int) {
        id = UUID(); self.bookID = bookID; self.bookTitle = bookTitle; date = Date()
        self.pagesRead = pagesRead; self.correctAnswers = correctAnswers; self.questionCount = questionCount
    }
}

public struct LibraryState: Codable, Sendable {
    public var version = 1
    public var books: [LibraryBook] = []
    public var words: [SavedWord] = []
    public var highlights: [ReadingHighlight] = []
    public var records: [ReadingRecord] = []
    public init() {}
}

public struct ReadingHighlight: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var bookID: UUID
    public var pageIndex: Int
    public var text: String
    public init(bookID: UUID, pageIndex: Int, text: String) {
        self.bookID = bookID; self.pageIndex = pageIndex; self.text = text
    }
}

public enum ReadingGoal: String, CaseIterable, Identifiable, Sendable {
    case pages, chapter, book, free
    public var id: Self { self }
    public var title: String {
        switch self {
        case .pages: "Page goal"
        case .chapter: "This chapter"
        case .book: "Rest of the book"
        case .free: "Read freely"
        }
    }

    public func endPage(start: Int, count: Int, pages: [BookPage]) -> Int {
        guard !pages.isEmpty else { return 0 }
        let start = min(max(0, start), pages.count - 1)
        switch self {
        case .pages: return min(pages.count - 1, start + max(1, count) - 1)
        case .chapter:
            let chapter = pages[start].chapterIndex
            return pages.indices.dropFirst(start).first(where: { pages[$0].chapterIndex != chapter }).map { $0 - 1 } ?? pages.count - 1
        case .book, .free: return pages.count - 1
        }
    }
}

public enum ReadingPace {
    public static let defaultCharactersPerMinute: Double = 120
    public static func duration(text: String, charactersPerMinute: Double) -> TimeInterval {
        let characters = text.filter { !$0.isWhitespace }.count
        return max(12, Double(characters) / max(30, charactersPerMinute) * 60)
    }
}
