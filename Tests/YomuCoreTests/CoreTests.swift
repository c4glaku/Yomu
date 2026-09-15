import Foundation
import PDFKit
import Testing
@testable import YomuCore
#if canImport(AppKit)
import AppKit
#endif

private func repository() throws -> LibraryRepository {
    try LibraryRepository(root: FileManager.default.temporaryDirectory.appendingPathComponent("yomu-test-\(UUID().uuidString)"))
}
private func fixture(_ name: String) -> URL {
    Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(name)")
}

@Test func paceUsesCharactersAndHasAMinimum() {
    #expect(ReadingPace.duration(text: String(repeating: "日", count: 120), charactersPerMinute: 120) == 60)
    #expect(ReadingPace.duration(text: " ", charactersPerMinute: 120) == 12)
    #expect(ReadingPace.duration(text: String(repeating: "日\n", count: 120), charactersPerMinute: 240) == 30)
    #expect(ReadingPace.duration(text: "日本", charactersPerMinute: 0).isFinite)
}

@Test func goalsRespectStartChapterAndBookBoundaries() {
    let (_, content) = SampleBook.make()
    #expect(ReadingGoal.pages.endPage(start: 4, count: 50, pages: content.pages) == 5)
    #expect(ReadingGoal.chapter.endPage(start: 0, count: 1, pages: content.pages) == 1)
    #expect(ReadingGoal.chapter.endPage(start: 1, count: 1, pages: content.pages) == 1)
    #expect(ReadingGoal.chapter.endPage(start: 2, count: 1, pages: content.pages) == 3)
    #expect(ReadingGoal.book.endPage(start: 3, count: 1, pages: content.pages) == 5)
    #expect(ReadingGoal.free.endPage(start: 5, count: 1, pages: content.pages) == 5)
    #expect(ReadingGoal.pages.endPage(start: 0, count: 0, pages: content.pages) == 0)
}

@Test func paginationPreservesJapaneseAndStableIDs() {
    let text = String(repeating: "春の空は青い。友達と本を読みます。", count: 100)
    let pages = TextPaginator.pages(text: text, chapter: "春", chapterIndex: 3, startingAt: 8)
    #expect(pages.count > 1)
    #expect(pages.map(\.text).joined() == text)
    #expect(pages.map(\.id) == Array(8..<8 + pages.count))
    #expect(pages.allSatisfy { $0.chapterIndex == 3 && $0.text.count <= 650 })
    #expect(TextPaginator.pages(text: " \n", chapter: "Empty").isEmpty)
}

@Test func dictionaryProvidesReadingsDefinitionsAndKanji() async throws {
    let dictionary = try JapaneseDictionary()
    let entries = await dictionary.lookup("日本語")
    #expect(entries.contains { $0.reading == "にほんご" && $0.definition.contains("Japanese") })
    let adult = await dictionary.lookup("大人")
    #expect(adult.contains { $0.reading == "おとな" })
    let kanji = await dictionary.kanji(in: "日日")
    #expect(kanji.count == 1)
    #expect(kanji.first?.onyomi.contains("ニチ") == true)
    #expect(kanji.first?.kunyomi.contains("ひ") == true)
    #expect(await dictionary.lookup("a word that does not exist in Japanese").isEmpty)
}

@Test func commonInflectionsFindDictionaryForms() async throws {
    let dictionary = try JapaneseDictionary()
    #expect(await dictionary.lookup("食べました").contains { $0.word == "食べる" })
    #expect(await dictionary.lookup("読みます").contains { $0.word == "読む" })
    #expect(await dictionary.lookup("歩いた").contains { $0.word == "歩く" })
}

@Test func sampleProducesRealJapaneseQuizQuestions() async throws {
    let dictionary = try JapaneseDictionary()
    let (_, content) = SampleBook.make()
    let candidates = await dictionary.candidates(in: content.pages[0])
    #expect(candidates.count >= 4)
    let questions = QuizEngine.questions(candidates: candidates, distractors: await dictionary.distractors())
    #expect(questions.count == 10)
    #expect(Set(questions.map(\.kind)) == [.reading, .meaning])
    for question in questions {
        #expect(question.pageIndex == 0)
        #expect(candidates.contains { $0.entry.id == question.entry.id })
        #expect(question.choices.filter { $0 == question.answer }.count == 1)
        #expect(Set(question.choices).count == question.choices.count)
        #expect(question.choices.count >= 3)
    }
}

@Test func quizExtractionRejoinsConjugatedVerbs() async throws {
    let dictionary = try JapaneseDictionary()
    let page = BookPage(id: 2, text: "私は台所でお茶を入れた。駅まで歩いて、本を読みました。", chapter: "Test")
    let candidates = await dictionary.candidates(in: page)
    #expect(candidates.contains { $0.entry.word == "入れる" })
    #expect(!candidates.contains { $0.entry.word == "入れ" })
    #expect(candidates.contains { $0.entry.word == "読む" })
    #expect(candidates.allSatisfy { $0.pageIndex == 2 })
    let auxiliary = await dictionary.candidates(in: BookPage(id: 0, text: "鳥が歌っていた。", chapter: "Test"))
    #expect(auxiliary.contains { $0.entry.word == "歌う" })
    #expect(!auxiliary.contains { $0.entry.word == "板" })
}

@Test func quizPrioritizesSavedWordsAndAvoidsSynonymDistractors() {
    let a = DictionaryEntry(id: 1, word: "本", reading: "ほん", meanings: ["book"])
    let synonym = DictionaryEntry(id: 2, word: "書物", reading: "しょもつ", meanings: ["book"])
    let other = [
        DictionaryEntry(id: 3, word: "朝", reading: "あさ", meanings: ["morning"]),
        DictionaryEntry(id: 4, word: "夜", reading: "よる", meanings: ["night"]),
        DictionaryEntry(id: 5, word: "水", reading: "みず", meanings: ["water"])
    ]
    let candidates = [QuizCandidate(entry: other[0], context: "朝です", pageIndex: 8, priority: 1), QuizCandidate(entry: a, context: "本です", pageIndex: 3, priority: 120)]
    let questions = QuizEngine.questions(candidates: candidates, distractors: other + [synonym], limit: 4)
    #expect(questions.first?.entry.word == "本")
    #expect(questions.count == 4)
    #expect(questions.filter { $0.entry.word == "本" && $0.kind == .reading }.allSatisfy { !$0.choices.contains("しょもつ") })
    #expect(QuizEngine.questions(candidates: [], distractors: other).isEmpty)
}

@Test func libraryPersistsBooksHighlightsWordsAndHistory() throws {
    let repo = try repository()
    defer { try? FileManager.default.removeItem(at: repo.root) }
    let (book, content) = SampleBook.make()
    try repo.store(content)
    var state = LibraryState()
    var progressed = book
    progressed.currentPage = 3
    state.books = [progressed]
    state.highlights = [ReadingHighlight(bookID: book.id, pageIndex: 3, text: "言葉")]
    state.words = [SavedWord(entry: DictionaryEntry(id: 1, word: "言葉", reading: "ことば", meanings: ["word"]), bookID: book.id, bookTitle: book.title, pageIndex: 3, context: "新しい言葉", selectedText: "言葉")]
    state.records = [ReadingRecord(bookID: book.id, bookTitle: book.title, pagesRead: 4, correctAnswers: 7, questionCount: 10)]
    try repo.save(state)
    let loaded = try repo.load()
    #expect(loaded.books.first?.currentPage == 3)
    #expect(loaded.words.first?.context == "新しい言葉")
    #expect(loaded.highlights.first?.text == "言葉")
    #expect(loaded.records.first?.correctAnswers == 7)
    #expect(try repo.content(for: book.id).pages == content.pages)
}

@Test func corruptedLibraryIsNotTreatedAsAnEmptyLibrary() throws {
    let repo = try repository()
    defer { try? FileManager.default.removeItem(at: repo.root) }
    try Data("broken".utf8).write(to: repo.root.appendingPathComponent("library.json"))
    #expect(throws: (any Error).self) { try repo.load() }
    #expect(try String(contentsOf: repo.root.appendingPathComponent("library.json"), encoding: .utf8) == "broken")
}

@Test(arguments: ["stored.epub", "deflated.epub"])
func epubUsesSpineOrderAndExcludesRubyAnnotations(_ filename: String) async throws {
    let repo = try repository()
    defer { try? FileManager.default.removeItem(at: repo.root) }
    let book = try await BookImporter().importBook(at: fixture(filename), into: repo)
    let content = try repo.content(for: book.id)
    #expect(book.title == "日本語の旅")
    #expect(book.author == "Yomu Tests")
    #expect(content.pages.count == 2)
    #expect(content.pages[0].chapter == "最初の章")
    #expect(content.pages[0].text.contains("日本語の本を読みます。"))
    #expect(!content.pages[0].text.contains("にほんご"))
    #expect(!content.pages.map(\.text).joined().contains("DO NOT INCLUDE"))
    #expect(FileManager.default.fileExists(atPath: repo.directory(for: book.id).appendingPathComponent("original.epub").path))
}

@Test(arguments: ["japanese.txt", "shift-jis.txt"])
func textImportSupportsJapaneseEncodings(_ filename: String) async throws {
    let repo = try repository()
    defer { try? FileManager.default.removeItem(at: repo.root) }
    let book = try await BookImporter().importBook(at: fixture(filename), into: repo)
    #expect(try repo.content(for: book.id).pages.first?.text.contains("日本語の本") == true)
}

@Test func encryptedEPUBIsRejected() async throws {
    let repo = try repository()
    defer { try? FileManager.default.removeItem(at: repo.root) }
    await #expect(throws: ImportError.protectedBook) { try await BookImporter().importBook(at: fixture("protected.epub"), into: repo) }
}

@Test func traversalAndCorruptArchivesAreRejected() throws {
    #expect(throws: ImportError.invalidArchive) { try ZIPArchive(data: Data(contentsOf: fixture("traversal.epub"))) }
    #expect(throws: ImportError.invalidArchive) { try ZIPArchive(data: Data("not a zip".utf8)) }
    #expect(throws: ImportError.invalidArchive) { try ZIPArchive.resolve("../../../private.txt", relativeTo: "OPS/Text/chapter.xhtml") }
    #expect(try ZIPArchive.resolve("../Text/first.xhtml#section", relativeTo: "OPS/Text/package.opf") == "OPS/Text/first.xhtml")
    var corrupt = try Data(contentsOf: fixture("stored.epub"))
    // Flip a byte in the stored mimetype payload; central-directory CRC stays intact.
    corrupt[40] ^= 1
    let archive = try ZIPArchive(data: corrupt)
    #expect(throws: ImportError.invalidArchive) { try archive.read("mimetype") }
}

#if canImport(AppKit)
@Test @MainActor func textPDFImportsAndScannedPDFReportsNoText() async throws {
    let repo = try repository()
    defer { try? FileManager.default.removeItem(at: repo.root) }
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 700))
    view.string = "日本語の本を読みます。"
    view.font = NSFont.systemFont(ofSize: 22)
    let pdf = view.dataWithPDF(inside: view.bounds)
    let url = repo.root.appendingPathComponent("test.pdf")
    try pdf.write(to: url)
    let book = try await BookImporter().importBook(at: url, into: repo)
    #expect(book.pageCount == 1)
    #expect(try repo.content(for: book.id).pages[0].text.contains("日本語"))

    let image = NSImage(size: NSSize(width: 100, height: 100))
    image.lockFocus(); NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 100, height: 100).fill(); image.unlockFocus()
    let scanned = PDFDocument()
    scanned.insert(PDFPage(image: image)!, at: 0)
    let scanURL = repo.root.appendingPathComponent("scan.pdf")
    try scanned.dataRepresentation()!.write(to: scanURL)
    await #expect(throws: ImportError.noText) { try await BookImporter().importBook(at: scanURL, into: repo) }
}
#endif
