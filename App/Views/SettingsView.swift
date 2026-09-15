import SwiftUI
import YomuCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("readingSpeed") private var speed = ReadingPace.defaultCharactersPerMinute
    @AppStorage("readerFontSize") private var fontSize = 22.0
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 17) {
                        BrandMark(size: 57)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("yomu").font(.system(size: 30, weight: .semibold, design: .rounded))
                            Text("A little reading. A little closer.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                }
                Section("Make it yours") {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }.accessibilityIdentifier("settings.appearance")
                    LabeledContent("Default reading pace", value: "\(Int(speed)) chars/min")
                    Slider(value: $speed, in: 30...600, step: 10).accessibilityLabel("Default reading speed")
                    LabeledContent("Reader text size", value: "\(Int(fontSize)) pt")
                    Slider(value: $fontSize, in: 17...34, step: 1).accessibilityLabel("Reader text size")
                }
                Section("About your library") {
                    Label("PDF, EPUB and plain text", systemImage: "doc.text")
                    Text("Import DRM-free books with selectable text. EPUB and text books use stable reading pages, so your place stays the same when you change text size. PDF pages keep their original numbering.").font(.caption).foregroundStyle(.secondary)
                    Label("Private by design", systemImage: "lock.shield")
                    Text("Books, highlights, vocabulary and progress are stored on this device. Reading and dictionary lookups work offline. Your device may include app data in its own backups.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Dictionary sources & licenses") {
                    Text("This app uses JMdict and KANJIDIC2, copyright © James William BREEN and the Electronic Dictionary Research and Development Group (EDRDG). The dictionaries and our SQLite adaptation are licensed under Creative Commons Attribution-ShareAlike 4.0.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("JMdict Japanese–English dictionary", destination: URL(string: "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project")!)
                    Link("KANJIDIC2 kanji dictionary", destination: URL(string: "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project")!)
                    Link("EDRDG license & documentation", destination: URL(string: "https://www.edrdg.org/edrdg/licence.html")!)
                    Link("Creative Commons BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    Text("The included starter story, 小さな一歩, was written for Yomu. Japanese pronunciation uses your device’s Japanese speech voice.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("Yomu · Version 1.0\nBuilt for the joy of understanding a little more.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
