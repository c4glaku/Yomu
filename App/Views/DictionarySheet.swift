import SwiftUI
import YomuCore

struct DictionarySheet: View {
    let text: String
    let book: LibraryBook
    let page: BookPage
    var onConsult: (DictionaryEntry) -> Void
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [DictionaryEntry] = []
    @State private var kanji: [KanjiEntry] = []
    @State private var index = 0
    @State private var loading = true
    @State private var speech = SpeechPlayer()

    private var entry: DictionaryEntry? { entries.indices.contains(index) ? entries[index] : nil }
    private var saved: Bool { entry.map { entry in store.state.words.contains { $0.entry.id == entry.id && $0.bookID == book.id } } ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "A WORD TO TAKE WITH YOU")
                            Text(entry?.word ?? String(text.prefix(30))).font(.system(size: 43, weight: .regular, design: .serif))
                            if let entry {
                                Text(entry.reading).font(.title3).foregroundStyle(Theme.orange)
                                if entry.word != text { Text("Dictionary form of “\(String(text.prefix(30)))”").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        Spacer()
                        CircleIconButton(symbol: "speaker.wave.2", label: "Hear Japanese pronunciation") { speech.speak(entry?.reading ?? String(text.prefix(80))) }
                    }
                    if loading { ProgressView("Looking up Japanese…").padding(.vertical, 30) }
                    else if let entry {
                        if entries.count > 1 {
                            Menu {
                                ForEach(Array(entries.enumerated()), id: \.offset) { offset, item in
                                    Button("\(item.word)【\(item.reading)】 \(item.meanings.first ?? "")") { index = offset; onConsult(item) }
                                }
                            } label: {
                                HStack {
                                    Text("Match \(index + 1) of \(entries.count)")
                                    Spacer()
                                    Text("Other readings & senses")
                                    Image(systemName: "chevron.down")
                                }.font(.caption)
                            }
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Eyebrow(text: "MEANING")
                                Spacer()
                                if entry.common { Text("COMMON WORD").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(Theme.orange).padding(6).background(Theme.paleOrange, in: Capsule()) }
                            }
                            if !entry.partOfSpeech.isEmpty { Text(entry.partOfSpeech).font(.caption).foregroundStyle(.secondary) }
                            ForEach(Array(entry.meanings.enumerated()), id: \.offset) { offset, meaning in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(String(offset + 1)).font(.caption.monospacedDigit()).foregroundStyle(Theme.orange).frame(width: 14, alignment: .leading)
                                    Text(meaning).font(.body)
                                }
                            }
                        }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        Button { store.saveWord(entry, book: book, page: page, selectedText: text) } label: {
                            Label(saved ? "Saved to your words" : "Save word & highlight", systemImage: saved ? "checkmark" : "bookmark")
                        }.buttonStyle(PrimaryButton()).disabled(saved).opacity(saved ? 0.65 : 1)
                    } else if !loading {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(text.count > 80 ? "Try selecting a single word" : "No word match found").font(.headline)
                            Text("Select a shorter word or its dictionary form. Names, slang, and some conjugations may not match.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button { store.highlight(bookID: book.id, page: page.id, text: text) } label: { Label("Keep this highlight", systemImage: "highlighter") }.font(.subheadline)
                        }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }

                    if !kanji.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: "INSIDE THE KANJI")
                            Text("Word pronunciation depends on context. These are the individual characters’ readings.").font(.caption).foregroundStyle(.secondary)
                            ForEach(kanji) { character in
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                                        Text(character.character).font(.system(size: 35, design: .serif))
                                        Text(character.meanings.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    readingRow("ON’YOMI", values: character.onyomi)
                                    readingRow("KUN’YOMI", values: character.kunyomi)
                                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "FROM YOUR READING · PAGE \(page.id + 1)")
                        Text(JapaneseText.context(for: text, in: page.text)).font(.system(size: 16, design: .serif)).lineSpacing(7).foregroundStyle(.secondary)
                    }
                    Text("Dictionary: JMdict & KANJIDIC2 · EDRDG · CC BY-SA 4.0").font(.system(size: 9)).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.background(Theme.background)
                .navigationTitle("Japanese dictionary").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .task {
                    if let dictionary = store.dictionary {
                        entries = await dictionary.lookup(text)
                        kanji = await dictionary.kanji(in: String(text.prefix(24)))
                        if let entry { onConsult(entry) }
                    }
                    loading = false
                }
                .onDisappear { speech.stop() }
                .alert("Japanese pronunciation", isPresented: Binding(get: { speech.error != nil }, set: { if !$0 { speech.error = nil } })) {
                    Button("OK") { speech.error = nil }
                } message: { Text(speech.error ?? "") }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }
    private func readingRow(_ label: String, values: [String]) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(.secondary).frame(width: 68, alignment: .leading).padding(.top, 4)
            Text(values.isEmpty ? "—" : values.joined(separator: "、")).font(.subheadline).foregroundStyle(Theme.orange)
        }
    }
}
