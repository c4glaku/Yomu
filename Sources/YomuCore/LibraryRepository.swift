import Foundation

public struct LibraryRepository: Sendable {
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    public static func applicationRepository() throws -> Self {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        return try Self(root: support.appendingPathComponent("Yomu", isDirectory: true))
    }
    public func load() throws -> LibraryState {
        let url = root.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return LibraryState() }
        return try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: url))
    }
    public func save(_ state: LibraryState) throws {
        try JSONEncoder().encode(state).write(to: root.appendingPathComponent("library.json"), options: .atomic)
    }
    public func content(for id: UUID) throws -> BookContent {
        try JSONDecoder().decode(BookContent.self, from: Data(contentsOf: directory(for: id).appendingPathComponent("content.json")))
    }
    public func store(_ content: BookContent, original: URL? = nil, cover: Data? = nil) throws {
        let directory = directory(for: content.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(content).write(to: directory.appendingPathComponent("content.json"), options: .atomic)
        if let original {
            try FileManager.default.copyItem(at: original, to: directory.appendingPathComponent("original.\(original.pathExtension.lowercased())"))
        }
        if let cover { try cover.write(to: directory.appendingPathComponent("cover.jpg"), options: .atomic) }
    }
    public func directory(for id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func removeFiles(for id: UUID) throws {
        let url = directory(for: id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
