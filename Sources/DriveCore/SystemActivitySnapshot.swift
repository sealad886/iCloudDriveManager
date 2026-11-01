import Foundation

/// Aggregate-only output from a completed, read-only system status observation.
/// Counts describe status records across the account, not selected-folder progress.
public struct SystemActivitySnapshot: Codable, Sendable {
    public let observedAt: Date
    public let pendingUploadCount: Int?
    public let downloadingCount: Int?
    public let itemCount: Int
    public let pendingUploadBytes: Int64?
    public let downloadingBytes: Int64?

    public init(
        observedAt: Date = Date(), pendingUploadCount: Int?, downloadingCount: Int?, itemCount: Int,
        pendingUploadBytes: Int64? = nil, downloadingBytes: Int64? = nil
    ) {
        self.observedAt = observedAt
        self.pendingUploadCount = pendingUploadCount
        self.downloadingCount = downloadingCount
        self.itemCount = itemCount
        self.pendingUploadBytes = pendingUploadBytes
        self.downloadingBytes = downloadingBytes
    }
}

/// XPC transports only encoded aggregate counts or a generic availability error.
@objc public protocol ICloudStatusReading {
    func readStatus(reply: @escaping (Data?, String?) -> Void)
}
