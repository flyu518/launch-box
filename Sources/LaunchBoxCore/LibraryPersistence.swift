import Foundation

public struct LibraryPersistence: Sendable {
    public let baseDirectory: URL
    public let fileName: String

    public var fileURL: URL {
        baseDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    public init(baseDirectory: URL, fileName: String = "LaunchLibrary.json") {
        self.baseDirectory = baseDirectory
        self.fileName = fileName
    }

    public func load() throws -> LaunchLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LaunchLibrary()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(LaunchLibrary.self, from: data)
        } catch {
            try backupCorruptFile()
            return LaunchLibrary()
        }
    }

    public func save(_ library: LaunchLibrary) throws {
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(library)
        try data.write(to: fileURL, options: .atomic)
    }

    public func export(_ library: LaunchLibrary, to destinationURL: URL) throws {
        let data = try encoder.encode(library)
        try data.write(to: destinationURL, options: .atomic)
    }

    public func importLibrary(from sourceURL: URL) throws -> LaunchLibrary {
        let data = try Data(contentsOf: sourceURL)
        return try decoder.decode(LaunchLibrary.self, from: data)
    }

    @discardableResult
    public func backupCurrentFile(label: String = "backup") throws -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )

        let stamp = timestamp()
        let backupURL = baseDirectory.appendingPathComponent("\(fileName).\(label)-\(stamp)")
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.copyItem(at: fileURL, to: backupURL)
        return backupURL
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func backupCorruptFile() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let stamp = timestamp()
        let backupURL = baseDirectory.appendingPathComponent("\(fileName).corrupt-\(stamp)")
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.moveItem(at: fileURL, to: backupURL)
    }

    private func timestamp() -> String {
        ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
    }
}
