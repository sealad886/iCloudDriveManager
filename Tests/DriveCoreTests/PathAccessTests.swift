import Foundation
import XCTest

@testable import DriveCore

final class PathAccessTests: XCTestCase {
    func testContainmentUsesComponentsAndRejectsRootItself() throws {
        let root = URL(fileURLWithPath: "/tmp/Selected.example", isDirectory: true)
        XCTAssertNotNil(try PathAccess.validatedURL(root.appendingPathComponent("notes.txt"), within: root))
        XCTAssertThrowsError(try PathAccess.validatedURL(root, within: root))
        XCTAssertThrowsError(
            try PathAccess.validatedURL(
                URL(fileURLWithPath: "/tmp/Selected.example-Other/private.txt"), within: root
            ))
        XCTAssertThrowsError(
            try PathAccess.validatedURL(
                root.appendingPathComponent("../private.txt"), within: root
            ))
        XCTAssertThrowsError(
            try PathAccess.validatedURL(
                URL(string: "https://example.invalid/notes.txt")!, within: root
            ))
    }

    func testSymlinkCannotEscapeUserSelectedFolder() throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        let root = scratch.appendingPathComponent("Selected", isDirectory: true)
        let outside = scratch.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let link = root.appendingPathComponent("link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertThrowsError(try PathAccess.validatedURL(link.appendingPathComponent("private.txt"), within: root))
        try Data("outside fixture".utf8).write(to: outside.appendingPathComponent("existing.txt"))
        XCTAssertThrowsError(try PathAccess.validatedURL(link.appendingPathComponent("existing.txt"), within: root))
    }

    func testInternalSymlinkIsAllowedWithExistingAndMissingLeaves() throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        let root = scratch.appendingPathComponent("Selected", isDirectory: true)
        let destination = root.appendingPathComponent("Destination", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let link = root.appendingPathComponent("Internal", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
        XCTAssertNoThrow(try PathAccess.validatedURL(link.appendingPathComponent("missing.txt"), within: root))
        try Data("inside fixture".utf8).write(to: destination.appendingPathComponent("existing.txt"))
        XCTAssertNoThrow(try PathAccess.validatedURL(link.appendingPathComponent("existing.txt"), within: root))
    }

    func testNonCloudFileCannotStartDownload() async throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let localFile = scratch.appendingPathComponent("local.txt")
        try Data("local fixture".utf8).write(to: localFile)
        do {
            try await SystemDownloadRequester().requestDownload(at: localFile, within: scratch)
            XCTFail("A local file must not reach the provider's download API")
        } catch DriveAccessError.notUbiquitous {
            // The authorization boundary rejected the request as required.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
