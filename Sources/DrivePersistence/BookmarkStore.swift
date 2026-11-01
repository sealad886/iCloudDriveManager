import Foundation

/// The only durable app data is a user-granted folder bookmark. File metadata and queues stay in memory.
public struct BookmarkRecord: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let bookmarkData: Data

    public init(bookmarkData: Data) {
        self.schemaVersion = 1
        self.bookmarkData = bookmarkData
    }
}

public enum BookmarkStoreError: LocalizedError, Equatable {
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return
                "Saved folder access uses an unsupported format (version \(version)). The saved record was preserved."
        }
    }
}

public struct BookmarkStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func applicationStore() throws -> BookmarkStore {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return BookmarkStore(fileURL: support.appendingPathComponent("iCloudDriveManager/connection.json"))
    }

    public func load() throws -> BookmarkRecord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let record = try JSONDecoder().decode(BookmarkRecord.self, from: data)
        guard record.schemaVersion == 1 else { throw BookmarkStoreError.unsupportedSchema(record.schemaVersion) }
        return record
    }

    public func save(bookmarkData: Data) throws {
        // Validate any existing format before replacing it. Unknown formats are never silently downgraded.
        _ = try load()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try JSONEncoder().encode(BookmarkRecord(bookmarkData: bookmarkData))
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        // Validate first: disconnect must preserve a newer app's record too.
        _ = try load()
        try FileManager.default.removeItem(at: fileURL)
    }
}
