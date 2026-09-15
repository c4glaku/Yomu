import Foundation
import zlib

public enum ImportError: LocalizedError, Equatable {
    case unsupportedFormat, tooLarge, unreadable, noText, protectedBook, invalidEPUB, invalidArchive
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Choose a PDF, an EPUB, or a plain text file."
        case .tooLarge: "This book is too large. Choose a file under 75 MB with chapters smaller than 16 MB."
        case .unreadable: "This file could not be read. Try exporting a new copy."
        case .noText: "This book has no selectable text. Scanned pages and manga will be supported when OCR is added."
        case .protectedBook: "This book is encrypted or password protected. Import an unlocked, DRM-free copy."
        case .invalidEPUB: "This EPUB is missing readable chapters or has invalid book markup. Try exporting a new EPUB."
        case .invalidArchive: "This EPUB archive is damaged or uses an unsupported ZIP format."
        }
    }
}

/// Reads stored/deflated EPUB members in memory. No archive paths are written to disk.
struct ZIPArchive {
    struct Member { var path: String; var method: UInt16; var crc: UInt32; var compressed: Int; var size: Int; var offset: Int }
    let data: Data
    var members: [String: Member] = [:]

    init(data: Data) throws {
        self.data = data
        guard data.count >= 22 else { throw ImportError.invalidArchive }
        let lower = max(0, data.count - 65_557)
        var end: Int?
        for offset in stride(from: data.count - 22, through: lower, by: -1) {
            if data.u32(offset) == 0x06054b50,
               offset + 22 + Int(data.u16(offset + 20)) == data.count { end = offset; break }
        }
        guard let end, data.u16(end + 4) == 0, data.u16(end + 6) == 0 else { throw ImportError.invalidArchive }
        let count = Int(data.u16(end + 10))
        let directoryOffset = Int(data.u32(end + 16))
        let directorySize = Int(data.u32(end + 12))
        guard count < 5000, directoryOffset + directorySize <= end else { throw ImportError.tooLarge }
        var offset = directoryOffset
        var total = 0
        for _ in 0..<count {
            guard offset + 46 <= end, data.u32(offset) == 0x02014b50 else { throw ImportError.invalidArchive }
            let flags = data.u16(offset + 8)
            guard flags & 1 == 0 else { throw ImportError.protectedBook }
            let nameSize = Int(data.u16(offset + 28))
            let extraSize = Int(data.u16(offset + 30))
            let commentSize = Int(data.u16(offset + 32))
            let next = offset + 46 + nameSize + extraSize + commentSize
            guard next <= end, let path = String(data: data.subdata(in: offset + 46..<offset + 46 + nameSize), encoding: .utf8) else { throw ImportError.invalidArchive }
            let size = Int(data.u32(offset + 24))
            total += size
            guard size <= 16 * 1024 * 1024, total <= 200 * 1024 * 1024 else { throw ImportError.tooLarge }
            let normalized = try Self.resolve(path, relativeTo: "")
            guard members[normalized] == nil else { throw ImportError.invalidArchive }
            members[normalized] = Member(path: path, method: data.u16(offset + 10), crc: data.u32(offset + 16),
                                         compressed: Int(data.u32(offset + 20)), size: size, offset: Int(data.u32(offset + 42)))
            offset = next
        }
    }

    func read(_ path: String) throws -> Data {
        guard let member = members[path], member.offset + 30 <= data.count,
              data.u32(member.offset) == 0x04034b50 else { throw ImportError.invalidArchive }
        let start = member.offset + 30 + Int(data.u16(member.offset + 26)) + Int(data.u16(member.offset + 28))
        guard start <= data.count, member.compressed <= data.count - start else { throw ImportError.invalidArchive }
        let compressed = data.subdata(in: start..<start + member.compressed)
        let output: Data
        if member.method == 0 {
            guard compressed.count == member.size else { throw ImportError.invalidArchive }
            output = compressed
        } else if member.method == 8 {
            if member.size == 0 { return Data() }
            var inflated = Data(count: member.size)
            var stream = z_stream()
            guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw ImportError.invalidArchive }
            defer { inflateEnd(&stream) }
            let status = compressed.withUnsafeBytes { input in
                inflated.withUnsafeMutableBytes { destination in
                    stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
                    stream.avail_in = uInt(compressed.count)
                    stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(member.size)
                    return inflate(&stream, Z_FINISH)
                }
            }
            guard status == Z_STREAM_END, stream.total_out == member.size, stream.total_in == member.compressed else { throw ImportError.invalidArchive }
            output = inflated
        } else { throw ImportError.invalidArchive }
        let checksum = output.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(output.count)) }
        guard UInt32(checksum) == member.crc else { throw ImportError.invalidArchive }
        return output
    }

    static func resolve(_ path: String, relativeTo base: String) throws -> String {
        let path = path.components(separatedBy: "#")[0].removingPercentEncoding ?? path
        guard !path.hasPrefix("/"), !path.contains(":"), !path.contains("\\"), !path.contains("\0") else { throw ImportError.invalidArchive }
        var parts = base.split(separator: "/").dropLast().map(String.init)
        for component in path.split(separator: "/") {
            if component == "." { continue }
            if component == ".." {
                guard !parts.isEmpty else { throw ImportError.invalidArchive }
                parts.removeLast()
            } else { parts.append(String(component)) }
        }
        return parts.joined(separator: "/")
    }
}

private extension Data {
    func u16(_ offset: Int) -> UInt16 { UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8) }
    func u32(_ offset: Int) -> UInt32 { UInt32(u16(offset)) | (UInt32(u16(offset + 2)) << 16) }
}
