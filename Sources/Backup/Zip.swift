import Compression
import Foundation

/// Hand-rolled ZIP container reader (local/central-directory parsing) over
/// Apple's `Compression` framework's raw-DEFLATE codec (`COMPRESSION_ZLIB`
/// is RFC 1951 raw deflate — exactly ZIP's compression method 8, no
/// zlib/gzip wrapper). This is a lighter path than linking `libz` directly:
/// `Compression` is already a proper Swift-importable system framework, so
/// no custom C module map is needed. Only reading is implemented — this
/// app's own backups are raw SQLite file copies, not zips (see
/// docs/DESIGN.md); a zip is only ever something we *receive* (a YNAB
/// export).
enum ZipError: Error {
    case invalidArchive
    case unsupportedCompressionMethod
    case decompressionFailed
}

struct ZipEntry {
    let name: String
    let compressionMethod: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
}

struct ZipArchive {
    let entries: [ZipEntry]
    private let data: Data

    init(data: Data) throws {
        self.data = data
        entries = try Self.parseCentralDirectory(data: data)
    }

    func entry(matching predicate: (String) -> Bool) -> ZipEntry? {
        entries.first { predicate($0.name.lowercased()) }
    }

    func contents(of entry: ZipEntry) throws -> Data {
        let offset = entry.localHeaderOffset
        guard data.readUInt32(at: offset) == 0x0404_4b50 else { throw ZipError.invalidArchive }
        let filenameLength = Int(data.readUInt16(at: offset + 26))
        let extraLength = Int(data.readUInt16(at: offset + 28))
        let dataStart = offset + 30 + filenameLength + extraLength
        let compressed = data.subdata(in: dataStart ..< (dataStart + entry.compressedSize))
        switch entry.compressionMethod {
        case 0:
            return compressed
        case 8:
            return try Self.inflateRaw(compressed, uncompressedSize: entry.uncompressedSize)
        default:
            throw ZipError.unsupportedCompressionMethod
        }
    }

    private static func inflateRaw(_ data: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        var output = [UInt8](repeating: 0, count: uncompressedSize)
        let decodedCount = data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            output.withUnsafeMutableBufferPointer { dst in
                compression_decode_buffer(
                    dst.baseAddress!, uncompressedSize,
                    src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard decodedCount == uncompressedSize else { throw ZipError.decompressionFailed }
        return Data(output)
    }

    private static func parseCentralDirectory(data: Data) throws -> [ZipEntry] {
        guard let eocdOffset = findEOCD(in: data) else { throw ZipError.invalidArchive }
        let cdOffset = Int(data.readUInt32(at: eocdOffset + 16))
        let cdEntryCount = Int(data.readUInt16(at: eocdOffset + 10))

        var entries: [ZipEntry] = []
        var offset = cdOffset
        for _ in 0 ..< cdEntryCount {
            guard data.readUInt32(at: offset) == 0x0201_4b50 else { break }
            let method = data.readUInt16(at: offset + 10)
            let compressedSize = Int(data.readUInt32(at: offset + 20))
            let uncompressedSize = Int(data.readUInt32(at: offset + 24))
            let filenameLength = Int(data.readUInt16(at: offset + 28))
            let extraLength = Int(data.readUInt16(at: offset + 30))
            let commentLength = Int(data.readUInt16(at: offset + 32))
            let localHeaderOffset = Int(data.readUInt32(at: offset + 42))
            let nameStart = offset + 46
            let nameData = data.subdata(in: nameStart ..< (nameStart + filenameLength))
            let name = String(data: nameData, encoding: .utf8) ?? ""
            entries.append(ZipEntry(name: name, compressionMethod: method, compressedSize: compressedSize, uncompressedSize: uncompressedSize, localHeaderOffset: localHeaderOffset))
            offset = nameStart + filenameLength + extraLength + commentLength
        }
        return entries
    }

    private static func findEOCD(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let searchStart = max(0, data.count - 65557)
        var i = data.count - 22
        while i >= searchStart {
            if data[data.startIndex + i] == 0x50, data[data.startIndex + i + 1] == 0x4B,
               data[data.startIndex + i + 2] == 0x05, data[data.startIndex + i + 3] == 0x06 {
                return i
            }
            i -= 1
        }
        return nil
    }
}

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        let i = startIndex + offset
        return UInt16(self[i]) | (UInt16(self[i + 1]) << 8)
    }

    func readUInt32(at offset: Int) -> UInt32 {
        let i = startIndex + offset
        var value: UInt32 = 0
        for j in 0 ..< 4 {
            value |= UInt32(self[i + j]) << (8 * j)
        }
        return value
    }
}
