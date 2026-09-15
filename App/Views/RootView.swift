import SwiftUI
import UniformTypeIdentifiers
import YomuCore

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        platformLayout
            .sheet(isPresented: $store.showSettings) { SettingsView() }
            .fileImporter(isPresented: $store.showImporter,
                          allowedContentTypes: [.pdf, UTType(filenameExtension: "epub") ?? .data, .plainText],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    store.selectedTab = 0
                    Task { await store.importFiles(urls) }
                case .failure(let error): store.error = error.localizedDescription
                }
            }
            .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch store.selectedTab {
        case 1: WordsView()
        case 2: ActivityView()
        default: LibraryView()
        }
    }

    @ViewBuilder private var platformLayout: some View {
        #if targetEnvironment(macCatalyst)
        HStack(spacing: 0) {
            desktopSidebar
            Rectangle().fill(Theme.line).frame(width: 1)
            NavigationStack {
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background).toolbar(.hidden, for: .navigationBar)
            }
        }.background(Theme.background)
            .background(MacWindowConfiguration())
        #else
        NavigationStack {
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack(spacing: 10) {
                        BrandMark(size: 37)
                        Text("yomu").font(.system(size: 28, weight: .semibold, design: .rounded)).tracking(-1)
                        Spacer()
                        CircleIconButton(symbol: "slider.horizontal.3", label: "Settings") { store.showSettings = true }
                    }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 6)
                        .frame(maxWidth: 1000).frame(maxWidth: .infinity).background(Theme.background)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 0) {
                        tabButton("Library", symbol: "books.vertical", selected: "books.vertical.fill", index: 0)
                        tabButton("Words", symbol: "bookmark", selected: "bookmark.fill", index: 1)
                        tabButton("Activity", symbol: "chart.bar.xaxis", selected: "chart.bar.xaxis", index: 2)
                    }.padding(.top, 12).padding(.bottom, 6).background(Theme.surface)
                        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private var desktopSidebar: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 11) {
                BrandMark(size: 36)
                Text("yomu").font(.system(size: 29, weight: .semibold, design: .rounded)).tracking(-1)
            }.padding(.vertical, 14)
            Eyebrow(text: "YOUR READING SPACE")
            VStack(spacing: 8) {
                sidebarButton("Library", symbol: "books.vertical", index: 0)
                sidebarButton("Words", symbol: "bookmark", index: 1)
                sidebarButton("Activity", symbol: "chart.bar.xaxis", index: 2)
            }
            Button { store.showImporter = true } label: {
                Label("Import books", systemImage: "plus").frame(maxWidth: .infinity)
            }.buttonStyle(PrimaryButton()).disabled(store.isImporting)
            Text("PDF, EPUB & TXT\n⌘O to add a book").font(.caption).foregroundStyle(.secondary).lineSpacing(5)
            Spacer()
            Text("一日一歩").font(.system(size: 23, design: .serif)).foregroundStyle(Theme.orange)
            Text("One page at a time.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Button { store.showSettings = true } label: {
                Label("Settings", systemImage: "slider.horizontal.3").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 9)
            }.buttonStyle(.plain).accessibilityLabel("Settings")
        }.padding(22).frame(width: 220).background(Theme.surface)
    }

    private func sidebarButton(_ title: String, symbol: String, index: Int) -> some View {
        Button { store.selectedTab = index } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol).frame(width: 21)
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text("⌘\(index + 1)").font(.caption2).foregroundStyle(.secondary)
            }.foregroundStyle(store.selectedTab == index ? Theme.orange : .primary)
                .padding(13).background(store.selectedTab == index ? Theme.paleOrange : .clear, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(store.selectedTab == index ? .isSelected : [])
    }
    #endif

    private func tabButton(_ title: String, symbol: String, selected: String, index: Int) -> some View {
        Button { store.selectedTab = index } label: {
            VStack(spacing: 5) {
                Image(systemName: store.selectedTab == index ? selected : symbol).font(.system(size: 20, weight: .medium))
                Text(title).font(.system(size: 10, weight: .semibold))
            }.foregroundStyle(store.selectedTab == index ? Theme.orange : .secondary)
                .frame(maxWidth: .infinity).frame(minHeight: 44)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(store.selectedTab == index ? .isSelected : [])
    }
}
