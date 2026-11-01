import XCTest

@testable import DriveCore

final class FileProviderBacklogParserTests: XCTestCase {
    private func section(_ identifier: String = FileProviderBacklogParser.iCloudProviderIdentifier) -> String {
        "================\n\(identifier)\n================\n"
    }

    private func counter(_ count: String, bytes: String) -> String {
        "      + Materialize counters : \(count) items with size \(bytes)\n"
    }

    func testReadsCounterOnlyWithinKnownProviderScope() throws {
        let output =
            section("com.example.OtherProvider") + counter("999", bytes: "999")
            + section() + "\u{001B}[32m" + counter("2", bytes: "4096") + "\u{001B}[0m"
        let snapshot = try FileProviderBacklogParser.parse(output: output)
        XCTAssertEqual(snapshot.pendingItemCount, 2)
        XCTAssertEqual(snapshot.logicalBytes, 4096)
    }

    func testRecognizedEmptyCounterDiffersFromUnavailableOrMalformedOutput() throws {
        let empty = try FileProviderBacklogParser.parse(output: section() + counter("0", bytes: "0"))
        XCTAssertEqual(empty.pendingItemCount, 0)
        XCTAssertEqual(empty.logicalBytes, 0)
        XCTAssertThrowsError(try FileProviderBacklogParser.parse(output: "unavailable"))
        XCTAssertThrowsError(try FileProviderBacklogParser.parse(output: counter("0", bytes: "0")))
        XCTAssertThrowsError(
            try FileProviderBacklogParser.parse(
                output: section("com.example.OtherProvider") + counter("0", bytes: "0")
            ))
        XCTAssertThrowsError(
            try FileProviderBacklogParser.parse(output: section() + counter("1", bytes: "unknown")))
        XCTAssertThrowsError(
            try FileProviderBacklogParser.parse(output: section() + counter("1", bytes: "999999999999999999999999")))
    }

    func testRejectsDuplicateCountersOrProviderSectionsInsteadOfDoubleCounting() {
        XCTAssertThrowsError(
            try FileProviderBacklogParser.parse(
                output: section() + counter("2", bytes: "4096") + counter("2", bytes: "4096")
            ))
        XCTAssertThrowsError(
            try FileProviderBacklogParser.parse(
                output: section() + counter("2", bytes: "4096") + section() + counter("2", bytes: "4096")
            ))
    }
}
