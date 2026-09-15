import SwiftUI
import YomuCore

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedBook: LibraryBook?
    @State private var deleteBook: LibraryBook?
    @State private var search = ""
    @State private var sortByTitle = false

    private var books: [LibraryBook] {
        let books = store.state.books.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.author.localizedCaseInsensitiveContains(search) }
        return sortByTitle ? books.sorted { $0.title < $1.title } : books.sorted { $0.addedAt > $1.addedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.orange).frame(width: 5, height: 5)
                        Text("一日一歩   /   ONE PAGE AT A TIME").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(Theme.orange)
                    }
                    Text("Stories become\nsecond nature.")
                        .font(.system(size: 41, weight: .regular, design: .serif)).tracking(-1.6).lineSpacing(-3)
                    Text("Make a little room for Japanese.").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 24)

                if let recent = store.recentBook, search.isEmpty { continueCard(recent) }

                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Your library").font(.title3.weight(.semibold))
                        Text(String(store.state.books.count)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Theme.line, in: Capsule())
                        Spacer()
                        Menu {
                            Button("Recently added", systemImage: sortByTitle ? "clock" : "checkmark") { sortByTitle = false }
                            Button("Title", systemImage: sortByTitle ? "checkmark" : "textformat.abc") { sortByTitle = true }
                        } label: { Image(systemName: "arrow.up.arrow.down").foregroundStyle(.secondary).frame(width: 32, height: 40) }
                        Button { store.showImporter = true } label: { Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).frame(width: 40, height: 40).foregroundStyle(.white).background(Theme.orange, in: Circle()) }
                            .accessibilityLabel("Import a book").disabled(store.isImporting)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Find a book on your shelf", text: $search).font(.subheadline)
                        if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("Clear search") }
                    }.padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line, lineWidth: 1))

                    if store.isImporting {
                        HStack(spacing: 12) {
                            ProgressView().tint(Theme.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Preparing your book…").font(.subheadline.weight(.medium))
                                Text(store.importName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }.padding(18).background(Theme.paleOrange, in: RoundedRectangle(cornerRadius: 16))
                    }

                    if books.isEmpty && !search.isEmpty {
                        EmptyState(symbol: "magnifyingglass", title: "No matching books", message: "Try a different title or author.")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145, maximum: 215), spacing: 24)], alignment: .leading, spacing: 28) {
                            ForEach(books) { book in
                                Button { openBook(book) } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        BookCover(book: book, coverURL: coverURL(book))
                                        Text(book.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                        HStack(spacing: 5) {
                                            Text(book.format == .sample ? "STARTER STORY" : book.format.label)
                                            Text("·")
                                            Text("\(book.pageCount) pages")
                                        }.font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                                        ProgressView(value: book.progress).tint(Theme.orange).scaleEffect(y: 0.6)
                                    }
                                }.buttonStyle(.plain).contextMenu {
                                    Button("Read", systemImage: "book") { openBook(book) }
                                    Button("Remove book", systemImage: "trash", role: .destructive) { deleteBook = book }
                                }
                            }
                            if search.isEmpty { importTile }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield").font(.caption)
                    Text("Your books, your pace. Everything stays on this device.").font(.caption2)
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(.horizontal, 24).padding(.bottom, 22).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }
        .fullScreenCover(item: $selectedBook, onDismiss: { store.isPresentingSession = false }) { book in
            SessionSetupView(book: book).environment(store)
        }
        .confirmationDialog("Remove this book? Saved vocabulary and past sessions will stay in your activity.", isPresented: Binding(get: { deleteBook != nil }, set: { if !$0 { deleteBook = nil } }), titleVisibility: .visible) {
            Button("Remove book", role: .destructive) { if let book = deleteBook { store.delete(book) }; deleteBook = nil }
        }
    }

    private func coverURL(_ book: LibraryBook) -> URL? {
        book.coverFile.flatMap { store.repository?.directory(for: book.id).appendingPathComponent($0) }
    }

    private func openBook(_ book: LibraryBook) {
        store.isPresentingSession = true
        selectedBook = book
    }

    private func continueCard(_ book: LibraryBook) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Eyebrow(text: book.lastReadAt == nil ? "YOUR FIRST CHAPTER STARTS HERE" : "PICK UP WHERE YOU LEFT OFF")
                Spacer()
                Image(systemName: "sparkle").foregroundStyle(Theme.orange)
            }
            HStack(spacing: 22) {
                BookCover(book: book, coverURL: coverURL(book), compact: true).frame(width: 90)
                    .rotationEffect(.degrees(-5)).padding(.vertical, 5)
                VStack(alignment: .leading, spacing: 11) {
                    Text(book.title).font(.system(size: 24, weight: .medium, design: .serif)).lineLimit(2)
                    Text(book.lastReadAt == nil ? "A new world, one page at a time." : "Page \(book.currentPage + 1) of \(book.pageCount)")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { openBook(book) } label: {
                        HStack(spacing: 10) {
                            Text(book.lastReadAt == nil ? "Start reading" : "Continue reading")
                            Image(systemName: "arrow.right")
                        }.font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 12).background(Theme.orange, in: Capsule())
                    }.buttonStyle(.plain)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
    }

    private var importTile: some View {
        Button { store.showImporter = true } label: {
            Color.clear.aspectRatio(0.7, contentMode: .fit)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .light))
                            .frame(width: 48, height: 48).background(Theme.paleOrange, in: Circle())
                        Text("A story of your own").font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                        Text("Import PDF, EPUB or TXT").font(.system(size: 10)).foregroundStyle(.secondary)
                    }.foregroundStyle(Theme.orange).padding(12)
                }
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.orange.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                .padding(.bottom, 68)
        }.buttonStyle(.plain).disabled(store.isImporting).accessibilityLabel("Import PDF, EPUB or text book")
    }
}
