import Foundation

/// Values are optional because absent metadata is not evidence of a completed sync.
struct SyncFacts {
    var downloadingStatus: String?
    var isUploaded: Bool?
    var isUploading = false
    var isDownloading = false
    var downloadRequested = false
    var hasConflicts = false
    var downloadingError: String?
    var uploadingError: String?
    var percentDownloaded: Double?
    var percentUploaded: Double?

    var state: SyncState {
        if hasConflicts { return .conflict }
        if downloadingError != nil || uploadingError != nil { return .error }
        if isUploading { return .uploading }
        if isDownloading { return .downloading }
        if downloadRequested && downloadingStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent {
            return .queued
        }
        if isUploaded == false { return .pendingUpload }
        switch downloadingStatus {
        case NSMetadataUbiquitousItemDownloadingStatusNotDownloaded: return .cloudOnly
        case NSMetadataUbiquitousItemDownloadingStatusDownloaded: return .downloaded
        case NSMetadataUbiquitousItemDownloadingStatusCurrent:
            return isUploaded == true ? .current : .unknown
        default: return .unknown
        }
    }

    var progress: Double? {
        let percentage: Double?
        switch state {
        case .uploading: percentage = percentUploaded
        case .downloading: percentage = percentDownloaded
        default: percentage = nil
        }
        return percentage.flatMap { $0.isFinite ? min(100, max(0, $0)) / 100 : nil }
    }

    var issue: String? {
        if hasConflicts { return "This item has unresolved versions. Review it in Finder or its originating app." }
        return downloadingError ?? uploadingError
    }
}
