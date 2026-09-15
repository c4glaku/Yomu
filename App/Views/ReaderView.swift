import SwiftUI
import YomuCore

struct LookupRequest: Identifiable {
    let id = UUID()
    let text: String
}

struct ReaderView: View {
    let book: LibraryBook
    let content: BookContent
    let start: Int
    let end: Int
    let goal: ReadingGoal
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("readingSpeed") private var speed = ReadingPace.defaultCharactersPerMinute
    @AppStorage("readerFontSize") private var fontSize = 22.0
    @State private var pageIndex: Int
    @State private var elapsed = 0.0
    @State private var playing = true
    @State private var selected = ""
    @State private var lookup: LookupRequest?
    @State private var showControls = false
    @State private var showHighlights = false
    @State private var visited: Set<Int> = []
    @State private var lookedUp: [QuizCandidate] = []
    @State private var quiz: SessionQuiz?
    @State private var preparingQuiz = false
    @State private var hasRecorded = false

    init(book: LibraryBook, content: BookContent, start: Int, end: Int, goal: ReadingGoal, onClose: @escaping () -> Void) {
        self.book = book; self.content = content; self.start = start; self.end = end; self.goal = goal; self.onClose = onClose
        _pageIndex = State(initialValue: start)
    }
    private var page: BookPage { content.pages[pageIndex] }
    private var duration: Double { ReadingPace.duration(text: page.text, charactersPerMinute: speed) }
    private var fraction: Double { min(1, elapsed / duration) }
    private var pageHighlights: [ReadingHighlight] { store.state.highlights.filter { $0.bookID == book.id && $0.pageIndex == pageIndex } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(page.chapter).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1).lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(pageIndex + 1) / \(content.pages.count)").font(.caption.monospacedDigit())
                }.foregroundStyle(.secondary).padding(.horizontal, 26).padding(.top, 15).padding(.bottom, 12)
                Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 26)

                if page.text.isEmpty {
                    EmptyState(symbol: "doc.viewfinder", title: "An image-only page", message: "There’s no selectable text here. Skip this page to keep reading. OCR is planned for a future version.")
                        .frame(maxHeight: .infinity)
                } else {
                    SelectablePage(text: page.text, pageID: pageIndex, fontSize: fontSize,
                                   highlights: pageHighlights.map(\.text), fraction: fraction, isPlaying: playing,
                                   onSelection: { selected = $0; if !$0.isEmpty { playing = false } },
                                   onLookup: openLookup, onHighlight: highlight,
                                   onManualScroll: { playing = false })
                        .padding(.horizontal, 28)
                }

                if !selected.isEmpty {
                    HStack(spacing: 18) {
                        Text(String(selected.prefix(12))).font(.caption).lineLimit(1)
                        Spacer(minLength: 0)
                        Button { openLookup(selected) } label: { Label("Look up", systemImage: "character.book.closed") }
                        Button { highlight(selected) } label: { Image(systemName: "highlighter") }.accessibilityLabel("Highlight selection")
                    }.font(.caption.weight(.semibold)).padding(14).background(Theme.paleOrange, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 22).padding(.bottom, 8)
                }
                readerControls
            }.frame(maxWidth: 820).frame(maxWidth: .infinity).background(Theme.background)
                .navigationTitle(book.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Finish & quiz", systemImage: "sparkles") { finish() }
                            Button("Save & close", systemImage: "bookmark") { closeWithoutQuiz() }
                        } label: { Image(systemName: "chevron.down").foregroundStyle(.primary).frame(width: 36, height: 40) }
                            .accessibilityLabel("Reading session options")
                            .simultaneousGesture(TapGesture().onEnded { playing = false })
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 10) {
                            Button { playing = false; showHighlights = true } label: { Image(systemName: "bookmark") }.accessibilityLabel("Page highlights")
                            Button { playing = false; showControls = true } label: { Image(systemName: "textformat.size") }.accessibilityLabel("Reading settings")
                        }.foregroundStyle(.primary)
                    }
                }
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .sheet(item: $lookup) { request in
                    DictionarySheet(text: request.text, book: book, page: page) { entry in
                        lookedUp.append(QuizCandidate(entry: entry, context: JapaneseText.context(for: request.text, in: page.text), pageIndex: pageIndex, priority: 100))
                    }.environment(store)
                }
                .sheet(isPresented: $showControls) { controlsSheet }
                .sheet(isPresented: $showHighlights) { highlightsSheet }
                .fullScreenCover(item: $quiz) { session in
                    QuizView(session: session) { correct, total in
                        if !hasRecorded {
                            store.record(ReadingRecord(bookID: book.id, bookTitle: book.title, pagesRead: visited.count, correctAnswers: correct, questionCount: total))
                            hasRecorded = true
                        }
                        onClose()
                    }
                }
                .overlay {
                    if preparingQuiz {
                        ZStack {
                            Theme.background.opacity(0.94).ignoresSafeArea()
                            VStack(spacing: 18) {
                                ProgressView().tint(Theme.orange)
                                Text("Gathering the words you met…").font(.subheadline)
                                Text("A little reflection makes it stick.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .task {
                    visited.insert(pageIndex)
                    store.saveProgress(bookID: book.id, page: pageIndex)
                    var last = Date()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                        let now = Date()
                        let delta = min(1, now.timeIntervalSince(last))
                        last = now
                        if playing && scenePhase == .active && lookup == nil && !showControls && !showHighlights && !preparingQuiz && quiz == nil {
                            elapsed += delta
                            if elapsed >= duration { advance() }
                        }
                    }
                }
                .onChange(of: scenePhase) { _, value in if value != .active { playing = false } }
                .onChange(of: speed) { old, new in
                    let previous = ReadingPace.duration(text: page.text, charactersPerMinute: old)
                    elapsed = min(1, elapsed / previous) * ReadingPace.duration(text: page.text, charactersPerMinute: new)
                }
        }.interactiveDismissDisabled()
    }

    private var readerControls: some View {
        VStack(spacing: 13) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(playing ? Theme.orange : .secondary).frame(width: 5, height: 5)
                    Text(playing ? "READING WITH YOU" : "TAKE YOUR TIME").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.4)
                }
                Spacer()
                Text(goal == .free ? "Free reading" : "Goal: page \(end + 1)").font(.caption2)
            }.foregroundStyle(.secondary)
            ProgressView(value: fraction).tint(Theme.orange).accessibilityLabel("Time through this page")
            HStack {
                Button { playing = false; showControls = true } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(Int(speed))").font(.system(size: 17, weight: .medium, design: .rounded)).monospacedDigit()
                        Text("CHARS / MIN").font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(1)
                    }.foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                }.accessibilityLabel("Adjust reading speed, \(Int(speed)) characters per minute")
                Spacer()
                Button { move(to: pageIndex - 1) } label: { Image(systemName: "backward.end.fill").font(.system(size: 16)).frame(width: 44, height: 48) }
                    .disabled(pageIndex <= start).accessibilityLabel("Previous page")
                Button { selected = ""; playing.toggle() } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white).frame(width: 60, height: 60).background(Theme.orange, in: Circle())
                }.accessibilityLabel(playing ? "Pause reading" : "Resume automatic reading")
                Button { advance() } label: { Image(systemName: "forward.end.fill").font(.system(size: 16)).frame(width: 44, height: 48) }
                    .accessibilityLabel(pageIndex >= end ? "Finish and quiz" : "Next page")
                Spacer()
                Button { finish() } label: { Text("Finish").font(.caption.weight(.semibold)).frame(width: 65, height: 44, alignment: .trailing) }
                    .foregroundStyle(Theme.orange).accessibilityLabel("Finish session and start quiz")
            }.buttonStyle(.plain)
            Text("Select a word to look it up, or highlight a passage.").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 10)
            .background(Theme.surface).overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
    }

    private var controlsSheet: some View {
        NavigationStack {
            Form {
                Section("Reading pace") {
                    LabeledContent("Characters per minute", value: "\(Int(speed))")
                    Slider(value: $speed, in: 30...600, step: 10).accessibilityLabel("Characters per minute")
                    Text("Pages advance automatically while playing. Scrolling, selecting text, or leaving the app pauses reading.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Text size") {
                    Slider(value: $fontSize, in: 17...34, step: 1).accessibilityLabel("Reader text size")
                    Text("言葉の旅を、少しずつ。").font(.system(size: fontSize, design: .serif))
                }
            }.navigationTitle("Make it comfortable").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showControls = false } } }
        }.presentationDetents([.medium, .large])
    }
    private var highlightsSheet: some View {
        NavigationStack {
            List {
                if pageHighlights.isEmpty { Text("Select text and choose Highlight to keep a passage on this page.").foregroundStyle(.secondary) }
                ForEach(pageHighlights) { highlight in
                    Text(highlight.text).font(.body).padding(.vertical, 8)
                        .swipeActions { Button("Remove", role: .destructive) { store.removeHighlight(highlight.id) } }
                }
            }.navigationTitle("Page \(pageIndex + 1) highlights").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHighlights = false } } }
        }.presentationDetents([.medium, .large])
    }

    private func openLookup(_ text: String) { playing = false; lookup = LookupRequest(text: text) }
    private func highlight(_ text: String) { playing = false; store.highlight(bookID: book.id, page: pageIndex, text: text); selected = "" }
    private func move(to index: Int) {
        guard (start...end).contains(index) else { return }
        pageIndex = index; elapsed = 0; selected = ""; visited.insert(index)
        store.saveProgress(bookID: book.id, page: index)
    }
    private func advance() {
        if pageIndex >= end { finish(afterCompletingPage: true) } else { move(to: pageIndex + 1) }
    }
    private func closeWithoutQuiz() {
        playing = false
        store.saveProgress(bookID: book.id, page: pageIndex)
        if !hasRecorded {
            store.record(ReadingRecord(bookID: book.id, bookTitle: book.title, pagesRead: visited.count, correctAnswers: 0, questionCount: 0))
            hasRecorded = true
        }
        onClose()
    }
    private func finish(afterCompletingPage: Bool = false) {
        guard !preparingQuiz, quiz == nil else { return }
        playing = false; preparingQuiz = true
        let bookmark = afterCompletingPage ? min(pageIndex + 1, content.pages.count - 1) : pageIndex
        store.saveProgress(bookID: book.id, page: bookmark, completed: afterCompletingPage && pageIndex == content.pages.count - 1)
        Task {
            var candidates = lookedUp
            let saved = store.state.words.filter { $0.bookID == book.id && visited.contains($0.pageIndex) }
            candidates += saved.map { QuizCandidate(entry: $0.entry, context: $0.context, pageIndex: $0.pageIndex, priority: 120) }
            if let dictionary = store.dictionary {
                for index in visited.sorted() {
                    var extracted = await dictionary.candidates(in: content.pages[index])
                    let passages = store.state.highlights.filter { $0.bookID == book.id && $0.pageIndex == index }
                    for offset in extracted.indices where passages.contains(where: { $0.text.contains(extracted[offset].entry.word) }) { extracted[offset].priority += 50 }
                    candidates += extracted
                }
                let questions = QuizEngine.questions(candidates: candidates, distractors: await dictionary.distractors())
                quiz = SessionQuiz(bookTitle: book.title, pagesRead: visited.count, questions: questions)
            } else { quiz = SessionQuiz(bookTitle: book.title, pagesRead: visited.count, questions: []) }
            preparingQuiz = false
        }
    }
}
