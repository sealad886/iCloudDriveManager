import Foundation
import XCTest

@testable import DrivePersistence

final class BookmarkStoreTests: XCTestCase {
    private func withStore(_ body: (BookmarkStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(BookmarkStore(fileURL: directory.appendingPathComponent("connection.json")))
    }

    func testRoundTripAndDisconnect() throws {
        try withStore { store in
            XCTAssertNil(try store.load())
            let bookmark = Data("synthetic-bookmark".utf8)
            try store.save(bookmarkData: bookmark)
            XCTAssertEqual(try store.load(), BookmarkRecord(bookmarkData: bookmark))
            let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
            try store.clear()
            XCTAssertNil(try store.load())
        }
    }

    func testFutureSchemaIsPreservedOnSaveAndDisconnect() throws {
        try withStore { store in
            try FileManager.default.createDirectory(
                at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let future = Data(#"{"schemaVersion":2,"bookmarkData":"YQ=="}"#.utf8)
            try future.write(to: store.fileURL)
            XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? BookmarkStoreError, .unsupportedSchema(2)) }
            XCTAssertThrowsError(try store.save(bookmarkData: Data()))
            XCTAssertThrowsError(try store.clear())
            XCTAssertEqual(try Data(contentsOf: store.fileURL), future)
        }
    }

    func testCorruptRecordIsPreserved() throws {
        try withStore { store in
            try FileManager.default.createDirectory(
                at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let corrupt = Data("invalid json".utf8)
            try corrupt.write(to: store.fileURL)
            XCTAssertThrowsError(try store.save(bookmarkData: Data()))
            XCTAssertEqual(try Data(contentsOf: store.fileURL), corrupt)
        }
    }
}
