import Foundation
import XCTest

@testable import DriveCore

final class SyncClassifierTests: XCTestCase {
    func testMissingMetadataDoesNotClaimSyncCompletion() {
        XCTAssertEqual(SyncFacts().state, .unknown)
        XCTAssertEqual(SyncFacts(downloadingStatus: NSMetadataUbiquitousItemDownloadingStatusCurrent).state, .unknown)
    }

    func testCurrentRequiresKnownUploadedState() {
        XCTAssertEqual(
            SyncFacts(
                downloadingStatus: NSMetadataUbiquitousItemDownloadingStatusCurrent, isUploaded: true
            ).state, .current)
        XCTAssertEqual(
            SyncFacts(
                downloadingStatus: NSMetadataUbiquitousItemDownloadingStatusCurrent, isUploaded: false
            ).state, .pendingUpload)
    }

    func testDownloadedCopyCanBeStale() {
        let facts = SyncFacts(
            downloadingStatus: NSMetadataUbiquitousItemDownloadingStatusDownloaded, isUploaded: true
        )
        XCTAssertEqual(facts.state, .downloaded)
        XCTAssertTrue(facts.state.canRequestDownload)
    }

    func testActiveTransferAndRequestStates() {
        XCTAssertEqual(SyncFacts(isUploading: true).state, .uploading)
        XCTAssertEqual(SyncFacts(isDownloading: true).state, .downloading)
        XCTAssertEqual(SyncFacts(downloadRequested: true).state, .queued)
        XCTAssertEqual(
            SyncFacts(
                downloadingStatus: NSMetadataUbiquitousItemDownloadingStatusNotDownloaded, isUploaded: true
            ).state, .cloudOnly)
    }

    func testConflictAndErrorsTakePriorityOverProgress() {
        XCTAssertEqual(SyncFacts(isUploading: true, hasConflicts: true).state, .conflict)
        XCTAssertEqual(SyncFacts(isDownloading: true, downloadingError: "Provider error").state, .error)
    }

    func testProgressUsesCorrectDirectionAndClampsProviderValues() {
        XCTAssertEqual(SyncFacts(isUploading: true, percentDownloaded: 3, percentUploaded: 64).progress, 0.64)
        XCTAssertEqual(SyncFacts(isDownloading: true, percentDownloaded: 120).progress, 1)
        XCTAssertEqual(SyncFacts(isDownloading: true, percentDownloaded: -10).progress, 0)
        XCTAssertNil(SyncFacts(isDownloading: true, percentDownloaded: .nan).progress)
        XCTAssertNil(SyncFacts(isDownloading: true).progress)
    }

    func testItemProgressNeverExposesNonfiniteOrOutOfRangeValues() {
        func item(_ progress: Double?) -> DriveItem {
            DriveItem(
                url: URL(fileURLWithPath: "/example/a"), name: "a", relativePath: "a", state: .downloading,
                progress: progress)
        }
        XCTAssertNil(item(.infinity).progress)
        XCTAssertEqual(item(2).progress, 1)
        XCTAssertEqual(item(-1).progress, 0)
    }
}
