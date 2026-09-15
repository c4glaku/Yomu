import SwiftUI
import YomuCore

struct SessionSetupView: View {
    let book: LibraryBook
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("readingSpeed") private var speed = ReadingPace.defaultCharactersPerMinute
    @State private var content: BookContent?
    @State private var loadError: String?
    @State private var goal = ReadingGoal.pages
    @State private var count = 3
    @State private var start = 0
    @State private var started = false

    var body: some View {
        Group {
            if started, let content {
                ReaderView(book: book, content: content, start: start,
                           end: goal.endPage(start: start, count: count, pages: content.pages),
                           goal: goal, onClose: { dismiss() })
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            HStack(spacing: 25) {
                                BookCover(book: book, coverURL: book.coverFile.flatMap { store.repository?.directory(for: book.id).appendingPathComponent($0) }, compact: true).frame(width: 95)
                                VStack(alignment: .leading, spacing: 10) {
                                    Eyebrow(text: "MAKE YOURSELF A LITTLE TIME")
                                    Text(book.title).font(.system(size: 29, weight: .regular, design: .serif))
                                    Text(book.author).font(.caption).foregroundStyle(.secondary)
                                    Text("\(book.pageCount) pages · \(book.format.label)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 12)

                            if let content {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("A small goal. A little progress.").font(.title2.weight(.semibold))
                                    Text("Choose where to begin and when to pause for a quiz.").font(.subheadline).foregroundStyle(.secondary)
                                }

                                VStack(spacing: 14) {
                                    Stepper(value: $start, in: 0...max(0, content.pages.count - 1)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Start at page \(start + 1)").font(.subheadline.weight(.semibold))
                                            Text(content.pages[start].chapter).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                    Divider()
                                    Menu {
                                        ForEach(chapters(content), id: \.id) { page in
                                            Button("\(page.chapter) · p. \(page.id + 1)") { start = page.id }
                                        }
                                    } label: {
                                        HStack { Label("Jump to a chapter", systemImage: "list.bullet"); Spacer(); Image(systemName: "chevron.down") }.font(.subheadline)
                                    }
                                }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(ReadingGoal.allCases) { option in
                                        Button { goal = option } label: {
                                            VStack(alignment: .leading, spacing: 12) {
                                                HStack {
                                                    Image(systemName: symbol(option)).font(.title3)
                                                    Spacer()
                                                    Image(systemName: goal == option ? "checkmark.circle.fill" : "circle").foregroundStyle(goal == option ? Theme.orange : .secondary.opacity(0.3))
                                                }
                                                Text(option.title).font(.subheadline.weight(.medium))
                                            }.foregroundStyle(goal == option ? Theme.orange : .primary)
                                                .padding(17).frame(maxWidth: .infinity, alignment: .leading)
                                                .background(goal == option ? Theme.paleOrange : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(goal == option ? Theme.orange.opacity(0.6) : Theme.line, lineWidth: 1))
                                        }.buttonStyle(.plain).accessibilityAddTraits(goal == option ? .isSelected : [])
                                    }
                                }
                                if goal == .pages {
                                    Stepper("\(min(count, content.pages.count - start)) pages this session", value: $count, in: 1...max(1, content.pages.count - start))
                                        .font(.subheadline).padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Label("Reading pace", systemImage: "tortoise").font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text("\(Int(speed)) chars/min").font(.caption.monospacedDigit()).foregroundStyle(Theme.orange)
                                    }
                                    Slider(value: $speed, in: 30...600, step: 10).accessibilityLabel("Japanese characters per minute")
                                    Text("120 characters/min is a gentle starting point. Change it or pause anytime.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                                Label(goal == .free ? "Stop whenever you like to quiz what you’ve read." : "A short reading and meaning quiz follows your goal.", systemImage: "sparkles")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if let loadError {
                                ContentUnavailableView("Couldn’t open this book", systemImage: "exclamationmark.book.closed", description: Text(loadError))
                            } else { ProgressView("Opening your book…").frame(maxWidth: .infinity).padding(40) }
                        }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
                    }.background(Theme.background)
                        .navigationTitle("Your reading session").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
                        .safeAreaInset(edge: .bottom) {
                            if content != nil {
                                Button { started = true } label: { Label("Begin reading", systemImage: "arrow.right") }
                                    .buttonStyle(PrimaryButton()).padding(.horizontal, 24).padding(.vertical, 14)
                                    .frame(maxWidth: 640).frame(maxWidth: .infinity).background(Theme.background)
                            }
                        }
                }
            }
        }.onChange(of: start) { _, value in
            if let content { count = min(count, max(1, content.pages.count - value)) }
        }.task {
            do {
                let loaded = try await store.content(for: book)
                guard !loaded.pages.isEmpty else { throw ImportError.noText }
                content = loaded
                start = book.completed ? 0 : min(book.currentPage, loaded.pages.count - 1)
            } catch { loadError = error.localizedDescription }
        }
    }
    private func chapters(_ content: BookContent) -> [BookPage] {
        var seen = Set<Int>()
        return content.pages.filter { seen.insert($0.chapterIndex).inserted }
    }
    private func symbol(_ goal: ReadingGoal) -> String {
        switch goal { case .pages: "doc.text"; case .chapter: "bookmark"; case .book: "book.closed"; case .free: "infinity" }
    }
}
