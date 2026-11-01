import Foundation
import XCTest

@testable import DriveCore

final class SystemStatusParserTests: XCTestCase {
    private let section = "<c{contract}>\n    Client local pending Items:\n"

    private func record(_ identity: Int, state: String = "idle", indentation: Int = 8) -> String {
        String(repeating: " ", count: indentation)
            + "r:\(identity) i:item al:1 foid:object up:\(state) uv:1 st{p:parent n:{downloading:99% up:needs-upload}}\n"
    }

    func testCountsOnlyTypedRecordStatesAndExplicitDownloadProgress() throws {
        let output =
            section + "\u{001B}[32m" + record(1, state: "needs-upload") + "\u{001B}[0m"
            + "        > downloader{[content:version downloading:0.0% progress:known]}\n"
            + record(2)
            + "        > downloader{[content:version active attempts:1 last:known next:known cleanup:known]}\n"
        let snapshot = try SystemStatusParser.parse(output: output)
        XCTAssertEqual(snapshot.itemCount, 2)
        XCTAssertEqual(snapshot.pendingUploadCount, 1)
        XCTAssertEqual(snapshot.downloadingCount, 1)
        XCTAssertNil(snapshot.pendingUploadBytes)
        XCTAssertNil(snapshot.downloadingBytes)
    }

    func testRepeatedIdentityUsesLastObservation() throws {
        let output =
            section + record(1, state: "needs-upload")
            + "        > downloader{[content:version downloading:5.0% progress:known]}\n"
            + record(1)
        let snapshot = try SystemStatusParser.parse(output: output)
        XCTAssertEqual(snapshot.itemCount, 1)
        XCTAssertEqual(snapshot.pendingUploadCount, 0)
        XCTAssertEqual(snapshot.downloadingCount, 0)
    }

    func testRecognizedEmptySectionDiffersFromUnavailableFormat() throws {
        let empty = try SystemStatusParser.parse(output: section)
        XCTAssertEqual(empty.itemCount, 0)
        XCTAssertEqual(empty.pendingUploadCount, 0)
        XCTAssertEqual(empty.downloadingCount, 0)
        XCTAssertThrowsError(try SystemStatusParser.parse(output: "unavailable"))
        XCTAssertThrowsError(try SystemStatusParser.parse(output: section + record(1, indentation: 7)))
        XCTAssertThrowsError(try SystemStatusParser.parse(output: section + record(1, state: "unsupported")))
        XCTAssertThrowsError(try SystemStatusParser.parse(output: section + "<c{second}>\n" + record(1)))
        XCTAssertThrowsError(try SystemStatusParser.parse(output: "<c{contract}>\n" + record(1)))
        XCTAssertThrowsError(
            try SystemStatusParser.parse(
                output: section + record(1)
                    + "        > downloader{[content:version downloading:101.0% progress:known]}\n"
            ))
        XCTAssertThrowsError(
            try SystemStatusParser.parse(
                output: section + record(1)
                    + "        > downloader{[content:version unsupported attempts:1]}\n"
            ))
    }
}
