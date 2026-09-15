#if targetEnvironment(macCatalyst)
import SwiftUI

struct MacWindowConfiguration: UIViewRepresentable {
    func makeUIView(context: Context) -> WindowObserver { WindowObserver() }
    func updateUIView(_ uiView: WindowObserver, context: Context) {}

    final class WindowObserver: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene else { return }
            scene.sizeRestrictions?.minimumSize = CGSize(width: 960, height: 720)
            scene.title = "Yomu"
        }
    }
}

struct MacCommands: Commands {
    let store: AppStore
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Import Books…") { store.showImporter = true }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(store.isImporting || store.isPresentingSession || store.showSettings)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { store.showSettings = true }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(store.isPresentingSession || store.showImporter)
        }
        CommandMenu("Go") {
            Button("Library") { store.selectedTab = 0 }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(store.isPresentingSession)
            Button("Words") { store.selectedTab = 1 }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(store.isPresentingSession)
            Button("Activity") { store.selectedTab = 2 }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(store.isPresentingSession)
        }
    }
}
#endif
