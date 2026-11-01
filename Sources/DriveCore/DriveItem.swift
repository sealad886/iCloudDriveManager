import Foundation

public enum SyncState: String, CaseIterable, Codable, Sendable {
    case current, cloudOnly, downloaded, downloading, uploading, queued, pendingUpload
    case conflict, error, unknown

    public var title: String {
        switch self {
        case .current: return "Up to date"
        case .cloudOnly: return "In iCloud"
        case .downloaded: return "Local copy outdated"
        case .downloading: return "Downloading"
        case .uploading: return "Uploading"
        case .queued: return "Download requested"
        case .pendingUpload: return "Waiting to upload"
        case .conflict: return "Conflict"
        case .error: return "Metadata warning"
        case .unknown: return "Unknown"
        }
    }

    public var isActive: Bool {
        [.downloading, .uploading, .queued, .pendingUpload].contains(self)
    }

    public var needsAttention: Bool { self == .conflict || self == .error }

    public var canRequestDownload: Bool { self == .cloudOnly || self == .downloaded }
}

public struct DriveItem: Identifiable, Hashable, Sendable {
    public var id: String { url.absoluteString }
    public let url: URL
    public let name: String
    public let relativePath: String
    public let byteCount: Int64?
    public let modifiedAt: Date?
    public let state: SyncState
    /// Fraction in 0...1. Nil means the provider has not reported progress.
    public let progress: Double?
    public let issue: String?
    public let isDirectory: Bool

    public init(
        url: URL, name: String, relativePath: String, byteCount: Int64? = nil,
        modifiedAt: Date? = nil, state: SyncState, progress: Double? = nil,
        issue: String? = nil, isDirectory: Bool = false
    ) {
        self.url = url.standardizedFileURL
        self.name = name
        self.relativePath = relativePath
        self.byteCount = byteCount.flatMap { $0 >= 0 ? $0 : nil }
        self.modifiedAt = modifiedAt
        self.state = state
        self.progress = progress.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil }
        self.issue = issue
        self.isDirectory = isDirectory
    }
}

public struct MetadataSnapshot: Sendable {
    public let items: [DriveItem]
    public let root: URL
    public let observedAt: Date
    public let isGathering: Bool
    public let warning: String?

    public init(
        items: [DriveItem], root: URL, observedAt: Date = Date(),
        isGathering: Bool = false, warning: String? = nil
    ) {
        self.items = items
        self.root = root
        self.observedAt = observedAt
        self.isGathering = isGathering
        self.warning = warning
    }
}
