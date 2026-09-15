import Foundation
import PDFKit
#if canImport(FoundationXML)
import FoundationXML
#endif

public actor BookImporter {
    public init() {}

    public func importBook(at url: URL, into repository: LibraryRepository) throws -> LibraryBook {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 75 * 1024 * 1024 else { throw ImportError.tooLarge }
        let data = try Data(contentsOf: url)
        guard data.count <= 75 * 1024 * 1024 else { throw ImportError.tooLarge }
        let title = url.deletingPathExtension().lastPathComponent
        let imported: ImportedText
        let format: BookFormat
        switch url.pathExtension.lowercased() {
        case "pdf": imported = try readPDF(data, fallbackTitle: title); format = .pdf
        case "epub": imported = try readEPUB(data, fallbackTitle: title); format = .epub
        case "txt", "text":
            let hasUTF16BOM = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
            let decoded = hasUTF16BOM ? String(data: data, encoding: .utf16) : (String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS))
            guard let text = decoded else { throw ImportError.unreadable }
            imported = ImportedText(title: title, author: "Imported text", pages: TextPaginator.pages(text: text, chapter: "Text"))
            format = .txt
        default: throw ImportError.unsupportedFormat
        }
        guard !imported.pages.isEmpty, imported.pages.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw ImportError.noText }
        let book = LibraryBook(title: imported.title, author: imported.author, format: format,
                               pageCount: imported.pages.count, coverStyle: Int.random(in: 0..<4),
                               coverFile: imported.cover == nil ? nil : "cover.jpg")
        do {
            try repository.store(BookContent(id: book.id, pages: imported.pages), original: url, cover: imported.cover)
        } catch {
            try? repository.removeFiles(for: book.id)
            throw error
        }
        return book
    }

    private func readPDF(_ data: Data, fallbackTitle: String) throws -> ImportedText {
        guard let document = PDFDocument(data: data) else { throw ImportError.unreadable }
        guard !document.isLocked else { throw ImportError.protectedBook }
        guard document.pageCount <= 5000 else { throw ImportError.tooLarge }
        let attributes = document.documentAttributes ?? [:]
        let title = (attributes[PDFDocumentAttribute.titleAttribute] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle
        let author = attributes[PDFDocumentAttribute.authorAttribute] as? String ?? "Imported PDF"
        var outlines: [(Int, String)] = []
        func visit(_ outline: PDFOutline) {
            if let destination = outline.destination, let page = destination.page, let label = outline.label {
                let index = document.index(for: page)
                if index != NSNotFound { outlines.append((index, label)) }
            }
            for index in 0..<outline.numberOfChildren { if let child = outline.child(at: index) { visit(child) } }
        }
        if let root = document.outlineRoot { visit(root) }
        outlines.sort { $0.0 < $1.0 }
        let pages = (0..<document.pageCount).map { index in
            let section = outlines.lastIndex(where: { $0.0 <= index })
            return BookPage(id: index, text: document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                            chapter: section.map { outlines[$0].1 } ?? "\(title)", chapterIndex: section.map { $0 + 1 } ?? 0)
        }
        return ImportedText(title: title, author: author, pages: pages)
    }

    private func readEPUB(_ data: Data, fallbackTitle: String) throws -> ImportedText {
        let archive = try ZIPArchive(data: data)
        if let mime = try? archive.read("mimetype"), String(data: mime, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) != "application/epub+zip" { throw ImportError.invalidEPUB }
        let container = try BookXML.parse(archive.read("META-INF/container.xml"))
        guard let rawPath = container.rootfile else { throw ImportError.invalidEPUB }
        let packagePath = try ZIPArchive.resolve(rawPath, relativeTo: "")
        let package = try BookXML.parse(archive.read(packagePath))
        if archive.members["META-INF/encryption.xml"] != nil {
            let encrypted = try BookXML.parse(archive.read("META-INF/encryption.xml"))
            let chapterPaths = try Set(package.items.values.filter { $0.type.contains("html") }.map { try ZIPArchive.resolve($0.href, relativeTo: packagePath) })
            for reference in encrypted.encryptedPaths {
                if chapterPaths.contains(try ZIPArchive.resolve(reference, relativeTo: "")) { throw ImportError.protectedBook }
            }
        }
        var pages: [BookPage] = []
        for (chapterIndex, identifier) in package.spine.enumerated() {
            guard let item = package.items[identifier], item.type.contains("html") else { continue }
            let path = try ZIPArchive.resolve(item.href, relativeTo: packagePath)
            let chapter = try BookXML.parse(archive.read(path))
            let text = chapter.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            let title = chapter.heading.isEmpty ? (chapter.title.isEmpty ? "Chapter \(chapterIndex + 1)" : chapter.title) : chapter.heading
            pages += TextPaginator.pages(text: text, chapter: title, chapterIndex: chapterIndex, startingAt: pages.count)
        }
        var cover: Data?
        if let item = package.items.values.first(where: { $0.properties.split(separator: " ").contains("cover-image") }) ?? package.coverID.flatMap({ package.items[$0] }) {
            cover = try? archive.read(ZIPArchive.resolve(item.href, relativeTo: packagePath))
        }
        return ImportedText(title: package.title.isEmpty ? fallbackTitle : package.title,
                            author: package.author.isEmpty ? "Unknown author" : package.author, pages: pages, cover: cover)
    }
}

private struct ImportedText {
    var title: String
    var author: String
    var pages: [BookPage]
    var cover: Data? = nil
}

public enum TextPaginator {
    /// Stable logical pages, independent of font size or device dimensions.
    public static func pages(text: String, chapter: String, chapterIndex: Int = 0, startingAt: Int = 0, target: Int = 650) -> [BookPage] {
        let text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        let target = max(80, target)
        var chunks: [String] = []
        var remaining = text[...]
        while remaining.count > target {
            let limit = remaining.index(remaining.startIndex, offsetBy: target)
            let lower = remaining.index(remaining.startIndex, offsetBy: target / 2)
            let split = remaining[lower..<limit].lastIndex(where: { "。！？\n".contains($0) }).map { remaining.index(after: $0) } ?? limit
            chunks.append(String(remaining[..<split]))
            remaining = remaining[split...]
        }
        if !remaining.isEmpty { chunks.append(String(remaining)) }
        return chunks.enumerated().map { index, chunk in
            BookPage(id: startingAt + index, text: chunk.trimmingCharacters(in: .whitespacesAndNewlines), chapter: chapter, chapterIndex: chapterIndex)
        }
    }
}

private final class BookXML: NSObject, XMLParserDelegate {
    struct Item { var href: String; var type: String; var properties: String }
    var rootfile: String?
    var items: [String: Item] = [:]
    var spine: [String] = []
    var title = ""
    var author = ""
    var body = ""
    var heading = ""
    var coverID: String?
    var encryptedPaths: [String] = []
    private var elements: [String] = []
    private var ignoredDepth = 0
    private var inBody = false
    private var capturingHeading = false
    private let blocks: Set<String> = ["p", "div", "section", "h1", "h2", "h3", "h4", "li", "blockquote", "br", "tr"]

    static func parse(_ data: Data) throws -> BookXML {
        var bytes = data
        if var text = String(data: data, encoding: .utf8) {
            guard !text.contains("<!ENTITY") else { throw ImportError.invalidEPUB }
            // Common XHTML named entities; XML's five built-ins remain untouched.
            let entities = ["nbsp": " ", "mdash": "—", "ndash": "–", "hellip": "…", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "copy": "©"]
            for (entity, value) in entities { text = text.replacingOccurrences(of: "&\(entity);", with: value) }
            bytes = Data(text.utf8)
        }
        let delegate = BookXML()
        let parser = XMLParser(data: bytes)
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = delegate
        guard parser.parse() else { throw ImportError.invalidEPUB }
        delegate.title = delegate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        delegate.author = delegate.author.trimmingCharacters(in: .whitespacesAndNewlines)
        delegate.heading = delegate.heading.trimmingCharacters(in: .whitespacesAndNewlines)
        return delegate
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        elements.append(name)
        if ignoredDepth > 0 { ignoredDepth += 1; return }
        if ["script", "style", "rt", "rp"].contains(name) { ignoredDepth = 1; return }
        if name == "rootfile", rootfile == nil { rootfile = attributes["full-path"] }
        if name == "item", let id = attributes["id"], let href = attributes["href"] {
            items[id] = Item(href: href, type: attributes["media-type"] ?? "", properties: attributes["properties"] ?? "")
        }
        if name == "itemref", attributes["linear"] != "no", let id = attributes["idref"] { spine.append(id) }
        if name == "meta", attributes["name"] == "cover" { coverID = attributes["content"] }
        if name == "CipherReference", let path = attributes["URI"] { encryptedPaths.append(path) }
        if name == "body" { inBody = true }
        if inBody && blocks.contains(name) { body += "\n\n" }
        if inBody && ["h1", "h2"].contains(name) && heading.isEmpty { capturingHeading = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard ignoredDepth == 0 else { return }
        if elements.last == "title" { title += string }
        if elements.last == "creator" { author += string }
        if capturingHeading { heading += string }
        if inBody { body += string }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elements.popLast() ?? elementName
        if ignoredDepth > 0 { ignoredDepth -= 1; return }
        if ["h1", "h2"].contains(name) { capturingHeading = false }
        if inBody && blocks.contains(name) { body += "\n\n" }
        if name == "body" { inBody = false }
    }
}
