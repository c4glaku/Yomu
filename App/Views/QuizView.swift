import SwiftUI
import YomuCore

struct SessionQuiz: Identifiable {
    var id = UUID()
    var bookTitle: String
    var pagesRead: Int
    var questions: [QuizQuestion]
}

struct QuizView: View {
    let session: SessionQuiz
    let onComplete: (Int, Int) -> Void
    @State private var index = 0
    @State private var answers: [UUID: String] = [:]
    @State private var showSummary = false
    @State private var confirmExit = false
    @State private var speech = SpeechPlayer()
    private var question: QuizQuestion? { session.questions.indices.contains(index) ? session.questions[index] : nil }
    private var score: Int { session.questions.filter { answers[$0.id] == $0.answer }.count }
    private var mistakes: [QuizQuestion] { session.questions.filter { answers[$0.id] != nil && answers[$0.id] != $0.answer } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if session.questions.isEmpty { emptyQuiz }
                    else if showSummary { summary }
                    else if let question {
                        HStack {
                            Eyebrow(text: "A MOMENT TO REMEMBER")
                            Spacer()
                            Text("\(index + 1) / \(session.questions.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(index), total: Double(session.questions.count)).tint(Theme.orange)
                        VStack(alignment: .leading, spacing: 10) {
                            Label(question.kind == .reading ? "READING" : "MEANING", systemImage: question.kind == .reading ? "character" : "text.book.closed")
                                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(Theme.orange)
                            Text(question.kind == .reading ? "How do you read this word?" : "What does this word mean?")
                                .font(.system(size: 29, weight: .regular, design: .serif))
                        }.padding(.top, 10)
                        VStack(spacing: 16) {
                            Text(question.entry.word).font(.system(size: 52, weight: .regular, design: .serif))
                            if question.kind == .meaning { Text(question.entry.reading).font(.title3).foregroundStyle(Theme.orange) }
                            Rectangle().fill(Theme.line).frame(height: 1)
                            Text(question.context).font(.system(size: 15, design: .serif)).lineSpacing(6).foregroundStyle(.secondary)
                            Text("FROM PAGE \(question.pageIndex + 1)").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4).foregroundStyle(.secondary)
                        }.padding(25).frame(maxWidth: .infinity).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))

                        VStack(spacing: 11) {
                            ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                                choiceButton(choice, number: choiceIndex + 1, question: question)
                            }
                        }
                        if let answer = answers[question.id] {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(answer == question.answer ? "That’s right." : "A new connection to remember.", systemImage: answer == question.answer ? "checkmark.circle.fill" : "lightbulb")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(answer == question.answer ? .green : Theme.orange)
                                HStack {
                                    Text("\(question.entry.word) · \(question.entry.reading)").font(.headline)
                                    Spacer()
                                    Button { speech.speak(question.entry.reading) } label: { Image(systemName: "speaker.wave.2") }.accessibilityLabel("Hear the answer")
                                }
                                Text(question.entry.meanings.prefix(3).joined(separator: "; ")).font(.subheadline).foregroundStyle(.secondary)
                            }.padding(18).background(Theme.paleOrange, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }.padding(24).padding(.top, 12).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.id(showSummary ? "summary" : "question-\(index)").background(Theme.background)
                .navigationTitle("Reading reflection").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !showSummary && !session.questions.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) { Button("Close") { confirmExit = true } }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Group {
                        if showSummary || session.questions.isEmpty {
                            Button { onComplete(score, answers.count) } label: { Label("Back to your library", systemImage: "books.vertical") }.buttonStyle(PrimaryButton())
                        } else if let question, answers[question.id] != nil {
                            Button {
                                speech.stop()
                                if index + 1 >= session.questions.count { showSummary = true } else { index += 1 }
                            } label: { Label(index + 1 >= session.questions.count ? "See your reflection" : "Next question", systemImage: "arrow.right") }.buttonStyle(PrimaryButton()).accessibilityIdentifier("quiz.next")
                        }
                    }.padding(.horizontal, 24).padding(.vertical, 14).frame(maxWidth: 640).frame(maxWidth: .infinity).background(Theme.background)
                }
                .confirmationDialog("Finish this quiz now? Your answered questions will be saved.", isPresented: $confirmExit, titleVisibility: .visible) {
                    Button("Finish quiz") { onComplete(score, answers.count) }
                }
                .onDisappear { speech.stop() }
                .alert("Japanese pronunciation", isPresented: Binding(get: { speech.error != nil }, set: { if !$0 { speech.error = nil } })) {
                    Button("OK") { speech.error = nil }
                } message: { Text(speech.error ?? "") }
        }.interactiveDismissDisabled()
    }

    private func choiceButton(_ choice: String, number: Int, question: QuizQuestion) -> some View {
        let answered = answers[question.id]
        let correct = answered != nil && choice == question.answer
        let wrong = answered == choice && choice != question.answer
        return Button { answers[question.id] = choice } label: {
            HStack(spacing: 14) {
                Text(String(number)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: 28, height: 28).background(Theme.line, in: RoundedRectangle(cornerRadius: 8))
                Text(choice).font(question.kind == .reading ? .title3 : .subheadline).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if wrong { Image(systemName: "xmark.circle").foregroundStyle(Theme.orange) }
            }.foregroundStyle(.primary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(correct ? Color.green.opacity(0.07) : wrong ? Theme.paleOrange : Theme.surface, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(correct ? Color.green.opacity(0.6) : wrong ? Theme.orange : Theme.line, lineWidth: 1))
        }.buttonStyle(.plain).disabled(answered != nil).accessibilityIdentifier("quiz.choice.\(number)")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(spacing: 18) {
                Text("一歩前へ").font(.system(size: 33, design: .serif)).foregroundStyle(Theme.orange)
                    .frame(width: 150, height: 150).background(Theme.paleOrange, in: Circle())
                Text("A little further than before.").font(.system(size: 31, design: .serif)).multilineTextAlignment(.center)
                Text("You made time for Japanese. That adds up.").font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
            HStack(spacing: 15) {
                metric("\(session.pagesRead)", label: "PAGES READ")
                metric("\(score)/\(answers.count)", label: "REMEMBERED")
            }
            if !mistakes.isEmpty {
                Eyebrow(text: "WORTH ANOTHER LOOK")
                ForEach(mistakes) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(question.entry.word)  ·  \(question.entry.reading)").font(.headline)
                        Text(question.entry.meanings.prefix(3).joined(separator: "; ")).font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    private var emptyQuiz: some View {
        VStack(spacing: 24) {
            EmptyState(symbol: "book.closed", title: "Reading is progress, too.", message: "There weren’t enough matching Japanese words for a useful quiz. Try looking up and saving a few words during your next session.")
            metric("\(session.pagesRead)", label: "PAGES READ")
        }
    }
    private func metric(_ value: String, label: String) -> some View {
        VStack(spacing: 9) {
            Text(value).font(.system(size: 34, weight: .medium, design: .rounded)).foregroundStyle(Theme.orange)
            Eyebrow(text: label)
        }.frame(maxWidth: .infinity).padding(24).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}
