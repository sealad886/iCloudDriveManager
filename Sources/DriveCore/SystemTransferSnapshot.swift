import Foundation

public enum PublishedTransferKind: String, Codable, Sendable {
    case downloading
    case uploading
    case unknown
}

/// Progress published by macOS. Direction is unknown unless its public operation
/// kind identifies it; localized descriptions are presented without classification.
public struct PublishedTransferSnapshot: Identifiable, Codable, Sendable {
    public let id: String
    public let observedAt: Date
    public let description: String
    public let additionalDescription: String?
    public let operationKind: PublishedTransferKind
    public let totalBytes: Int64?
    public let completedBytes: Int64?
    public let isCancellable: Bool
    public let isPausable: Bool

    public init(
        id: String, observedAt: Date = Date(), description: String, additionalDescription: String? = nil,
        operationKind: PublishedTransferKind, totalBytes: Int64? = nil, completedBytes: Int64? = nil,
        isCancellable: Bool, isPausable: Bool
    ) {
        self.id = id
        self.observedAt = observedAt
        self.description = description
        self.additionalDescription = additionalDescription
        self.operationKind = operationKind
        self.totalBytes = totalBytes
        self.completedBytes = completedBytes
        self.isCancellable = isCancellable
        self.isPausable = isPausable
    }
}

/// Provider diagnostic counters for outstanding materialization goals. Logical
/// sizes describe requested items, not remaining network traffic or transfer rate.
public struct SystemBacklogSnapshot: Codable, Sendable {
    public let observedAt: Date
    public let pendingItemCount: Int
    public let logicalBytes: Int64
    public let scopeDescription: String

    public init(
        observedAt: Date = Date(), pendingItemCount: Int, logicalBytes: Int64, scopeDescription: String
    ) {
        self.observedAt = observedAt
        self.pendingItemCount = pendingItemCount
        self.logicalBytes = logicalBytes
        self.scopeDescription = scopeDescription
    }
}
