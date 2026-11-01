import Foundation

/// Primitive values copied from provider resource values or the optional iCloud
/// query. Fresh provider values take priority; omitted fields can be supplemented.
struct MetadataFields: Sendable {
    static let resourceKeys: Set<URLResourceKey> = [
        .isUbiquitousItemKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
        .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsUploadedKey,
        .ubiquitousItemIsUploadingKey, .ubiquitousItemIsDownloadingKey,
        .ubiquitousItemDownloadRequestedKey, .ubiquitousItemHasUnresolvedConflictsKey,
        .ubiquitousItemDownloadingErrorKey, .ubiquitousItemUploadingErrorKey,
    ]
    var isUbiquitous: Bool?
    var isDirectory: Bool?
    var byteCount: Int64?
    var modifiedAt: Date?
    var downloadingStatus: String?
    var isUploaded: Bool?
    var isUploading: Bool?
    var isDownloading: Bool?
    var downloadRequested: Bool?
    var hasConflicts: Bool?
    var downloadingError: String?
    var uploadingError: String?
    var percentDownloaded: Double?
    var percentUploaded: Double?

    func fallingBack(to other: MetadataFields) -> MetadataFields {
        MetadataFields(
            isUbiquitous: isUbiquitous ?? other.isUbiquitous,
            isDirectory: isDirectory ?? other.isDirectory,
            byteCount: byteCount ?? other.byteCount,
            modifiedAt: modifiedAt ?? other.modifiedAt,
            downloadingStatus: downloadingStatus ?? other.downloadingStatus,
            isUploaded: isUploaded ?? other.isUploaded,
            isUploading: isUploading ?? other.isUploading,
            isDownloading: isDownloading ?? other.isDownloading,
            downloadRequested: downloadRequested ?? other.downloadRequested,
            hasConflicts: hasConflicts ?? other.hasConflicts,
            downloadingError: downloadingError ?? other.downloadingError,
            uploadingError: uploadingError ?? other.uploadingError,
            percentDownloaded: percentDownloaded ?? other.percentDownloaded,
            percentUploaded: percentUploaded ?? other.percentUploaded
        )
    }

    var syncFacts: SyncFacts {
        SyncFacts(
            downloadingStatus: downloadingStatus, isUploaded: isUploaded,
            isUploading: isUploading == true, isDownloading: isDownloading == true,
            downloadRequested: downloadRequested == true, hasConflicts: hasConflicts == true,
            downloadingError: downloadingError, uploadingError: uploadingError,
            percentDownloaded: percentDownloaded, percentUploaded: percentUploaded
        )
    }

    /// Reads metadata only, without a coordinated read or file-content access.
    static func readResources(at url: URL) throws -> MetadataFields {
        var freshURL = URL(fileURLWithPath: url.path, isDirectory: url.hasDirectoryPath)
        freshURL.removeAllCachedResourceValues()
        let values = try freshURL.resourceValues(forKeys: resourceKeys)
        let status: String?
        switch values.ubiquitousItemDownloadingStatus {
        case .current: status = NSMetadataUbiquitousItemDownloadingStatusCurrent
        case .downloaded: status = NSMetadataUbiquitousItemDownloadingStatusDownloaded
        case .notDownloaded: status = NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
        default: status = nil
        }
        return MetadataFields(
            isUbiquitous: values.isUbiquitousItem, isDirectory: values.isDirectory,
            byteCount: values.fileSize.map(Int64.init), modifiedAt: values.contentModificationDate,
            downloadingStatus: status, isUploaded: values.ubiquitousItemIsUploaded,
            isUploading: values.ubiquitousItemIsUploading, isDownloading: values.ubiquitousItemIsDownloading,
            downloadRequested: values.ubiquitousItemDownloadRequested,
            hasConflicts: values.ubiquitousItemHasUnresolvedConflicts,
            downloadingError: values.ubiquitousItemDownloadingError?.localizedDescription,
            uploadingError: values.ubiquitousItemUploadingError?.localizedDescription
        )
    }
}
