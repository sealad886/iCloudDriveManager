import Foundation
import XCTest

@testable import DriveCore

final class MetadataFieldsTests: XCTestCase {
    func testMissingSpotlightUbiquityAndStateUseProviderFallback() {
        let spotlight = MetadataFields(percentDownloaded: 42)
        let provider = MetadataFields(
            isUbiquitous: true, downloadingStatus: NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
            isUploaded: true, isDownloading: true
        )
        let combined = spotlight.fallingBack(to: provider)
        XCTAssertEqual(combined.isUbiquitous, true)
        XCTAssertEqual(combined.syncFacts.state, .downloading)
        XCTAssertEqual(combined.syncFacts.progress, 0.42)
    }

    func testExplicitFalseIsNotTreatedAsMissingMetadata() {
        let spotlight = MetadataFields(isUbiquitous: false, isUploading: false)
        let combined = spotlight.fallingBack(to: MetadataFields(isUbiquitous: true, isUploading: true))
        XCTAssertEqual(combined.isUbiquitous, false)
        XCTAssertEqual(combined.syncFacts.state, .unknown)
    }

    func testProviderFallbackPreservesUnknownAndMissingProgress() {
        let combined = MetadataFields().fallingBack(to: MetadataFields(isUbiquitous: true))
        XCTAssertEqual(combined.syncFacts.state, .unknown)
        XCTAssertNil(combined.syncFacts.progress)
        XCTAssertEqual(
            MetadataFields().fallingBack(to: MetadataFields(downloadingError: "Unavailable")).syncFacts.state, .error)
    }
}
