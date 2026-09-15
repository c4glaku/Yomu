import SwiftUI
import YomuCore

struct ActivityView: View {
    @Environment(AppStore.self) private var store
    private var pages: Int { store.state.records.reduce(0) { $0 + $1.pagesRead } }
    private var days: [Date] {
        (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: Date())) }
    }
    private func count(on day: Date) -> Int { store.state.records.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.pagesRead } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "SMALL STEPS, TAKEN OFTEN")
                    Text("Look how far\nyou’ve read.").font(.system(size: 38, design: .serif)).tracking(-1)
                    Text("Every page is time spent with the language.").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 24)
                HStack(spacing: 14) {
                    metric(String(pages), "PAGES READ")
                    metric(String(store.state.words.count), "WORDS SAVED")
                    metric(String(store.state.records.count), "SESSIONS")
                }
                VStack(alignment: .leading, spacing: 25) {
                    HStack { Text("A week of little steps").font(.headline); Spacer(); Text("7 days").font(.caption).foregroundStyle(.secondary) }
                    HStack(alignment: .bottom, spacing: 16) {
                        let maximum = max(1, days.map { count(on: $0) }.max() ?? 1)
                        ForEach(days, id: \.self) { day in
                            let value = count(on: day)
                            VStack(spacing: 10) {
                                Text(value > 0 ? String(value) : "").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                RoundedRectangle(cornerRadius: 6).fill(value > 0 ? Theme.orange : Theme.line)
                                    .frame(height: max(5, 90 * Double(value) / Double(maximum)))
                                Text(day, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)): \(value) pages")
                        }
                    }.frame(height: 140, alignment: .bottom)
                }.padding(22).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                Eyebrow(text: "YOUR READING JOURNAL")
                if store.state.records.isEmpty {
                    EmptyState(symbol: "leaf", title: "A fresh beginning.", message: "Finish a reading session and your progress will start to grow here.")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(store.state.records) { record in
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: record.pagesRead == 0 ? "character" : "book.closed")
                                    .font(.system(size: 17)).foregroundStyle(Theme.orange)
                                    .frame(width: 42, height: 46).background(Theme.paleOrange, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(record.bookTitle).font(.subheadline.weight(.semibold))
                                    Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption2).foregroundStyle(.secondary)
                                    Text(record.questionCount > 0 ? "\(record.pagesRead) pages · \(record.correctAnswers)/\(record.questionCount) quiz answers" : "\(record.pagesRead) pages · Reading session")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }.padding(.vertical, 16)
                            Divider()
                        }
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }
    }
    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(value).font(.system(size: 32, weight: .medium, design: .rounded)).foregroundStyle(Theme.orange)
            Text(label).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.5).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(15).background(Theme.surface, in: RoundedRectangle(cornerRadius: 17))
    }
}
