import SwiftUI

@main
struct YomuApp: App {
    @State private var store = AppStore()
    @AppStorage("appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.orange)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
        #if targetEnvironment(macCatalyst)
        .commands { MacCommands(store: store) }
        #endif
    }
}
