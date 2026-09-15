import SwiftUI
import YomuCore

struct WordsView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    @State private var selected: SavedWord?
    @State private var quiz: SessionQuiz?
    @State private var preparing = false
    private var words: [SavedWord] {
        store.state.words.filter { search.isEmpty || $0.entry.word.contains(search) || $0.entry.reading.contains(search) || $0.entry.definition.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "COLLECTED ALONG THE WAY")
                    Text("Words that stay.").font(.system(size: 38, design: .serif)).tracking(-1)
                    Text("Little discoveries from the stories you read.").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 24)
                if store.state.words.isEmpty {
                    EmptyState(symbol: "bookmark", title: "Your first word is waiting.", message: "Select a word while reading, look it up, and save it here with the sentence you found it in.")
                } else {
                    Button {
                        preparing = true
                        store.isPresentingSession = true
                        Task {
                            let candidates = store.state.words.map { QuizCandidate(entry: $0.entry, context: $0.context, pageIndex: $0.pageIndex, priority: 100) }.shuffled()
                            let distractors = await store.dictionary?.distractors() ?? []
                            quiz = SessionQuiz(bookTitle: "Your saved words", pagesRead: 0, questions: QuizEngine.questions(candidates: candidates, distractors: distractors))
                            preparing = false
                        }
                    } label: {
                        Label(preparing ? "Preparing…" : "Practice your saved words", systemImage: "sparkles")
                    }.buttonStyle(PrimaryButton()).disabled(preparing)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Find a word, reading or meaning", text: $search).font(.subheadline)
                    }.padding(15).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    Eyebrow(text: "\(words.count) SAVED WORD\(words.count == 1 ? "" : "S")")
                    if words.isEmpty { EmptyState(symbol: "magnifyingglass", title: "No matching words", message: "Try a different reading or meaning.") }
                    LazyVStack(spacing: 12) {
                        ForEach(words) { word in
                            Button {
                                store.isPresentingSession = true
                                selected = word
                            } label: {
                                HStack(alignment: .top, spacing: 18) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(word.entry.word).font(.system(size: 25, design: .serif))
                                        Text(word.entry.reading).font(.caption).foregroundStyle(Theme.orange)
                                    }.frame(minWidth: 74, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text(word.entry.meanings.prefix(2).joined(separator: "; ")).font(.subheadline).lineLimit(2)
                                        Text("\(word.bookTitle) · p. \(word.pageIndex + 1)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).padding(.top, 8)
                                }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 17))
                            }.buttonStyle(.plain).contextMenu {
                                Button("Remove saved word", systemImage: "trash", role: .destructive) { store.removeWord(word.id) }
                            }
                        }
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.sheet(item: $selected, onDismiss: { store.isPresentingSession = false }) { word in
            SavedWordView(word: word).environment(store)
        }
            .fullScreenCover(item: $quiz, onDismiss: { store.isPresentingSession = false }) { session in
                QuizView(session: session) { correct, total in
                    store.record(ReadingRecord(bookID: UUID(), bookTitle: "Saved vocabulary", pagesRead: 0, correctAnswers: correct, questionCount: total))
                    quiz = nil
                }
            }
    }
}

private struct SavedWordView: View {
    let word: SavedWord
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var speech = SpeechPlayer()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(word.entry.word).font(.system(size: 45, design: .serif))
                        Spacer()
                        CircleIconButton(symbol: "speaker.wave.2", label: "Hear pronunciation") { speech.speak(word.entry.reading) }
                    }
                    Text(word.entry.reading).font(.title2).foregroundStyle(Theme.orange)
                    Text(word.entry.definition).font(.body).lineSpacing(6)
                    Divider()
                    Eyebrow(text: "\(word.bookTitle) · PAGE \(word.pageIndex + 1)")
                    Text(word.context).font(.system(size: 20, design: .serif)).lineSpacing(9)
                    Button("Remove saved word", role: .destructive) { store.removeWord(word.id); dismiss() }.font(.subheadline).padding(.top, 12)
                }.padding(25)
            }.background(Theme.background).navigationTitle("Your saved word").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onDisappear { speech.stop() }
                .alert("Japanese pronunciation", isPresented: Binding(get: { speech.error != nil }, set: { if !$0 { speech.error = nil } })) {
                    Button("OK") { speech.error = nil }
                } message: { Text(speech.error ?? "") }
        }.presentationDetents([.medium, .large])
    }
}
