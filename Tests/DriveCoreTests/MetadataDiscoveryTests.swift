import Foundation
import XCTest

@testable import DriveCore

private actor DiscoveryBatches {
    private(set) var candidates: [MetadataCandidate] = []
    func append(_ batch: MetadataDiscoveryBatch) { candidates.append(contentsOf: batch.candidates) }
}

final class MetadataDiscoveryTests: XCTestCase {
    func testFilesystemDiscoveryPreservesUnknownAndHiddenEntriesWithoutAnIndex() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["visible.txt", ".pending.icloud"] {
            XCTAssertTrue(FileManager.default.createFile(atPath: root.appendingPathComponent(name).path, contents: nil))
        }
        let batches = DiscoveryBatches()
        let result = try await MetadataDiscovery.scan(
            root: root, readFields: { _ in MetadataFields() },
            progress: { await batches.append($0) }
        )
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.inspected, 2)
        XCTAssertEqual(result.seenIDs.count, 2)
        let candidates = await batches.candidates
        XCTAssertEqual(Set(candidates.map(\.name)), ["visible.txt", ".pending.icloud"])
        XCTAssertTrue(candidates.allSatisfy { $0.fields.syncFacts.state == .unknown })
        XCTAssertTrue(candidates.allSatisfy { !$0.fields.syncFacts.state.canRequestDownload })
    }

    func testFilesystemDiscoveryDoesNotFollowLinksOutsideSelectedRoot() async throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true)
        let root = scratch.appendingPathComponent("Selected", isDirectory: true)
        let outside = scratch.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        XCTAssertTrue(
            FileManager.default.createFile(atPath: root.appendingPathComponent("visible.txt").path, contents: nil))
        XCTAssertTrue(
            FileManager.default.createFile(atPath: outside.appendingPathComponent("outside.txt").path, contents: nil))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: outside)
        let batches = DiscoveryBatches()
        let result = try await MetadataDiscovery.scan(
            root: root, readFields: { _ in MetadataFields() },
            progress: { await batches.append($0) }
        )
        XCTAssertTrue(result.completed)
        let candidates = await batches.candidates
        XCTAssertEqual(candidates.map(\.name), ["visible.txt"])
    }

    func testExplicitNonCloudMetadataIsExcludedButReadErrorsRemainUnknown() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["ordinary.txt", "unavailable.txt"] {
            XCTAssertTrue(FileManager.default.createFile(atPath: root.appendingPathComponent(name).path, contents: nil))
        }
        let batches = DiscoveryBatches()
        let result = try await MetadataDiscovery.scan(
            root: root,
            readFields: { url in
                if url.lastPathComponent == "unavailable.txt" { throw CocoaError(.fileReadNoPermission) }
                return MetadataFields(isUbiquitous: false)
            },
            progress: { await batches.append($0) }
        )
        XCTAssertEqual(result.unreadable, 1)
        let candidates = await batches.candidates
        XCTAssertEqual(candidates.map(\.name), ["unavailable.txt"])
        XCTAssertEqual(candidates.first?.fields.syncFacts.state, .unknown)
    }
}
