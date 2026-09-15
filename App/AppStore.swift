import Foundation
import Observation
import YomuCore

@MainActor @Observable
final class AppStore {
    var state = LibraryState()
    var error: String?
    var isImporting = false
    var importName = ""
    var selectedTab = 0
    var showImporter = false
    var showSettings = false
    var isPresentingSession = false
    let dictionary: JapaneseDictionary?
    let repository: LibraryRepository?
    private let importer = BookImporter()
    private var storageReady = false

    init() {
        dictionary = try? JapaneseDictionary()
        do {
            let repository: LibraryRepository
            #if DEBUG
            if let testStore = ProcessInfo.processInfo.environment["YOMU_TEST_STORE"], UUID(uuidString: testStore) != nil {
                repository = try LibraryRepository(root: FileManager.default.temporaryDirectory.appendingPathComponent("Yomu-UITests/\(testStore)"))
            } else { repository = try LibraryRepository.applicationRepository() }
            #else
            repository = try LibraryRepository.applicationRepository()
            #endif
            self.repository = repository
            do {
                let firstLaunch = !FileManager.default.fileExists(atPath: repository.root.appendingPathComponent("library.json").path)
                state = try repository.load()
                if firstLaunch {
                    let (book, content) = SampleBook.make()
                    try repository.store(content)
                    state.books = [book]
                    try repository.save(state)
                }
                storageReady = true
            } catch { self.error = "Your library couldn’t be loaded. Your files have been preserved. \(error.localizedDescription)" }
        } catch {
            repository = nil
            self.error = error.localizedDescription
        }
        if dictionary == nil { error = DictionaryError.unavailable.localizedDescription }
    }

    var recentBook: LibraryBook? {
        state.books.filter { !$0.completed }.sorted { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) }.first
    }

    func content(for book: LibraryBook) async throws -> BookContent {
        guard let repository else { throw ImportError.unreadable }
        return try await Task.detached(priority: .userInitiated) { try repository.content(for: book.id) }.value
    }

    func importFiles(_ urls: [URL]) async {
        guard storageReady, let repository, !isImporting else { return }
        isImporting = true
        defer { isImporting = false; importName = "" }
        var failures: [String] = []
        for url in urls {
            importName = url.lastPathComponent
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let book = try await importer.importBook(at: url, into: repository)
                var updated = state
                updated.books.insert(book, at: 0)
                do { try repository.save(updated); state = updated }
                catch { try? repository.removeFiles(for: book.id); throw error }
            } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        if !failures.isEmpty { error = failures.joined(separator: "\n\n") }
    }

    func saveProgress(bookID: UUID, page: Int, completed: Bool = false) {
        guard let index = state.books.firstIndex(where: { $0.id == bookID }) else { return }
        state.books[index].currentPage = min(max(0, page), state.books[index].pageCount - 1)
        state.books[index].lastReadAt = Date()
        state.books[index].completed = completed
        persist()
    }

    func saveWord(_ entry: DictionaryEntry, book: LibraryBook, page: BookPage, selectedText: String) {
        guard !state.words.contains(where: { $0.entry.id == entry.id && $0.bookID == book.id }) else { return }
        state.words.insert(SavedWord(entry: entry, bookID: book.id, bookTitle: book.title, pageIndex: page.id,
                                     context: JapaneseText.context(for: selectedText, in: page.text), selectedText: selectedText), at: 0)
        highlight(bookID: book.id, page: page.id, text: selectedText)
    }

    func highlight(bookID: UUID, page: Int, text: String) {
        guard !text.isEmpty, !state.highlights.contains(where: { $0.bookID == bookID && $0.pageIndex == page && $0.text == text }) else { persist(); return }
        state.highlights.append(ReadingHighlight(bookID: bookID, pageIndex: page, text: text))
        persist()
    }
    func removeHighlight(_ id: UUID) { state.highlights.removeAll { $0.id == id }; persist() }
    func removeWord(_ id: UUID) { state.words.removeAll { $0.id == id }; persist() }
    func record(_ record: ReadingRecord) { state.records.insert(record, at: 0); persist() }

    func delete(_ book: LibraryBook) {
        guard storageReady, let repository else { return }
        var updated = state
        updated.books.removeAll { $0.id == book.id }
        updated.highlights.removeAll { $0.bookID == book.id }
        do {
            try repository.save(updated)
            state = updated
            try repository.removeFiles(for: book.id)
        } catch { self.error = error.localizedDescription }
    }

    private func persist() {
        guard storageReady, let repository else { return }
        do { try repository.save(state) }
        catch { self.error = "Your latest changes couldn’t be saved. \(error.localizedDescription)" }
    }
}
