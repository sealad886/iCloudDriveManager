import Foundation
import XCTest

@testable import DriveCore

private enum RequestFailure: LocalizedError {
    case unavailable
    var errorDescription: String? { "Test provider unavailable" }
}

private actor RecordingRequester: DownloadRequesting {
    private(set) var calls: [URL] = []
    var shouldFail = false
    func setFailure(_ value: Bool) { shouldFail = value }
    func requestDownload(at url: URL, within root: URL) async throws {
        calls.append(url)
        if shouldFail { throw RequestFailure.unavailable }
    }
}

private actor GatedRequester: DownloadRequesting {
    private var gates: [CheckedContinuation<Void, Never>] = []
    private(set) var calls: [URL] = []
    func requestDownload(at url: URL, within root: URL) async throws {
        calls.append(url)
        await withCheckedContinuation { gates.append($0) }
        throw RequestFailure.unavailable
    }
    func release() {
        let pending = gates
        gates.removeAll()
        for gate in pending { gate.resume() }
    }
}

private actor AttemptRequester: DownloadRequesting {
    private var continuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private(set) var callCount = 0

    func requestDownload(at url: URL, within root: URL) async throws {
        let index = callCount
        callCount += 1
        try await withCheckedThrowingContinuation { continuations[index] = $0 }
    }

    func finish(_ index: Int, failing: Bool) {
        guard let continuation = continuations.removeValue(forKey: index) else { return }
        if failing { continuation.resume(throwing: RequestFailure.unavailable) } else { continuation.resume() }
    }
}

final class DownloadQueueTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/Queue-Tests.example", isDirectory: true)

    private func item(_ name: String, state: SyncState = .cloudOnly, isDirectory: Bool = false) -> DriveItem {
        DriveItem(
            url: root.appendingPathComponent(name), name: name, relativePath: name, state: state,
            isDirectory: isDirectory)
    }

    @MainActor
    private func eventually(_ predicate: @escaping () async -> Bool) async -> Bool {
        for _ in 0..<100 {
            if await predicate() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }

    @MainActor
    func testDefaultDryRunOnlyRecordsPlans() async {
        let requester = RecordingRequester()
        let queue = DownloadQueue(requester: requester)
        XCTAssertTrue(queue.isDryRun)
        queue.enqueue([item("a"), item("b")], root: root)
        queue.setPaused(false)
        XCTAssertEqual(queue.items.map(\.status), [.planned, .planned])
        let calls = await requester.calls
        XCTAssertTrue(calls.isEmpty)

        // Observing a current file is not evidence that a dry-run plan executed.
        queue.reconcile(with: [item("a", state: .current)])
        XCTAssertEqual(queue.items.first?.status, .planned)
        queue.cancel(queue.items[0].id)
        XCTAssertEqual(queue.items.first?.status, .cancelled)
    }

    @MainActor
    func testEnablingLiveModeDoesNotReplayPlans() async {
        let requester = RecordingRequester()
        let queue = DownloadQueue(requester: requester)
        queue.enqueue([item("a")], root: root)
        let planID = queue.items[0].id
        queue.setDryRun(false)
        queue.setPaused(false)
        XCTAssertEqual(queue.items.first?.status, .planned)
        let beforeExplicitAction = await requester.calls
        XCTAssertTrue(beforeExplicitAction.isEmpty)

        queue.retry(planID)
        let submitted = await eventually { await requester.calls.count == 1 }
        XCTAssertTrue(submitted)
        XCTAssertEqual(queue.items.first?.status, .submitted)
    }

    @MainActor
    func testDryRunTransitionHoldsWaitingWorkAndInvalidatesCallbacks() async {
        let requester = GatedRequester()
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.enqueue([item("a"), item("b"), item("c")], root: root)
        let started = await eventually { await requester.calls.count == 2 }
        XCTAssertTrue(started)

        queue.setDryRun(true)
        queue.setPaused(true)
        queue.setPaused(false)
        XCTAssertEqual(queue.items.filter { $0.status == .planned }.count, 1)
        XCTAssertEqual(queue.items.filter { $0.status == .submitted }.count, 2)
        await requester.release()
        try? await Task.sleep(nanoseconds: 20_000_000)
        let calls = await requester.calls
        XCTAssertEqual(calls.count, 2)
        // The old attempt's error cannot overwrite the new mode's records.
        XCTAssertFalse(queue.items.contains { $0.status == .failed })
        queue.cancel(queue.items[0].id)
        XCTAssertEqual(queue.items.first?.status, .submitted)
    }

    @MainActor
    func testRetryInDryRunPlansWithoutRepeatingFailedProviderCall() async {
        let requester = RecordingRequester()
        await requester.setFailure(true)
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.enqueue([item("a")], root: root)
        let failed = await eventually { queue.items.first?.status == .failed }
        XCTAssertTrue(failed)
        queue.setDryRun(true)
        queue.retry(queue.items[0].id)
        XCTAssertEqual(queue.items.first?.status, .planned)
        XCTAssertNil(queue.items.first?.error)
        let calls = await requester.calls
        XCTAssertEqual(calls.count, 1)
    }

    @MainActor
    func testPauseDeduplicationAndTwoSubmittedSlotLimit() async {
        let requester = RecordingRequester()
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.setPaused(true)
        let fixtures = [item("a"), item("b"), item("c")]
        queue.enqueue(fixtures + [fixtures[0]], root: root)
        XCTAssertEqual(queue.items.count, 3)
        XCTAssertTrue(queue.items.allSatisfy { $0.status == .waiting })
        queue.setPaused(false)
        let requestedTwo = await eventually { await requester.calls.count == 2 }
        XCTAssertTrue(requestedTwo)
        XCTAssertEqual(queue.items.filter { $0.status == .submitted }.count, 2)
        XCTAssertEqual(queue.items.filter { $0.status == .waiting }.count, 1)
        // Returning from requestDownload is not proof of download completion.
        XCTAssertFalse(queue.items.contains { $0.status == .completed })
        queue.reconcile(with: [item("a", state: .downloaded)])
        XCTAssertEqual(queue.items.first?.status, .submitted)
        queue.reconcile(with: [item("a", state: .current)])
        let requestedThree = await eventually { await requester.calls.count == 3 }
        XCTAssertTrue(requestedThree)
        XCTAssertEqual(queue.items.first?.status, .completed)
    }

    @MainActor
    func testWaitingCancellationAndPriorityDoNotCancelSubmittedWork() async {
        let requester = RecordingRequester()
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.setPaused(true)
        queue.enqueue([item("a"), item("b"), item("c")], root: root)
        let cancelledID = queue.items[1].id
        let promotedID = queue.items[2].id
        queue.cancel(cancelledID)
        queue.moveToFront(promotedID)
        XCTAssertEqual(queue.items.first?.id, promotedID)
        XCTAssertEqual(queue.items.first(where: { $0.id == cancelledID })?.status, .cancelled)
        queue.setPaused(false)
        let requestedTwo = await eventually { await requester.calls.count == 2 }
        XCTAssertTrue(requestedTwo)
        queue.cancel(promotedID)
        XCTAssertEqual(queue.items.first?.status, .submitted)
        let calls = await requester.calls
        XCTAssertEqual(Set(calls.map(\.lastPathComponent)), ["c", "a"])
    }

    @MainActor
    func testRequestFailureCanBeRetriedAndMetadataErrorIsSurfaced() async {
        let requester = RecordingRequester()
        await requester.setFailure(true)
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.enqueue([item("a")], root: root)
        let failed = await eventually { queue.items.first?.status == .failed }
        XCTAssertTrue(failed)
        XCTAssertNotNil(queue.items.first?.error)
        await requester.setFailure(false)
        queue.retry(queue.items[0].id)
        let retried = await eventually { await requester.calls.count == 2 }
        XCTAssertTrue(retried)
        queue.reconcile(with: [item("a", state: .conflict)])
        XCTAssertEqual(queue.items.first?.status, .failed)
    }

    @MainActor
    func testResetIgnoresOldAsynchronousCallbacks() async {
        let requester = GatedRequester()
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.enqueue([item("old")], root: root)
        let oldStarted = await eventually { await requester.calls.count == 1 }
        XCTAssertTrue(oldStarted)
        queue.reset()
        queue.setPaused(true)
        queue.enqueue([item("new")], root: root)
        await requester.release()
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.items.first?.name, "new")
        XCTAssertEqual(queue.items.first?.status, .waiting)
        XCTAssertNil(queue.items.first?.error)
    }

    @MainActor
    func testOldFailureCannotOverwriteRetriedAttempt() async {
        let requester = AttemptRequester()
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.enqueue([item("retry")], root: root)
        let firstStarted = await eventually { await requester.callCount == 1 }
        XCTAssertTrue(firstStarted)
        queue.reconcile(with: [item("retry", state: .error)])
        XCTAssertEqual(queue.items.first?.status, .failed)
        queue.retry(queue.items[0].id)
        let retryStarted = await eventually { await requester.callCount == 2 }
        XCTAssertTrue(retryStarted)
        // The first request can finish after its cancellation was requested.
        await requester.finish(0, failing: true)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(queue.items.first?.status, .submitted)
        XCTAssertNil(queue.items.first?.error)
        await requester.finish(1, failing: false)
        queue.reconcile(with: [item("retry", state: .current)])
        XCTAssertEqual(queue.items.first?.status, .completed)
    }

    @MainActor
    func testUnapprovedStatesDirectoriesAndOutsidePathsAreRejected() async {
        let queue = DownloadQueue(requester: RecordingRequester(), isDryRun: false)
        queue.setPaused(true)
        let outside = DriveItem(
            url: URL(fileURLWithPath: "/Other.example/a"), name: "a", relativePath: "a", state: .cloudOnly)
        queue.enqueue(
            [item("conflict", state: .conflict), item("folder", isDirectory: true), outside, item("valid")], root: root)
        XCTAssertEqual(queue.items.map(\.name), ["valid"])
    }

    @MainActor
    func testWaitingItemsCompletedElsewhereDoNotConsumeSubmittedSlots() async {
        let requester = RecordingRequester()
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.setPaused(true)
        queue.enqueue([item("a"), item("b"), item("c")], root: root)
        queue.reconcile(with: [item("a", state: .current), item("b", state: .current)])
        XCTAssertEqual(queue.items.filter { $0.status == .completed }.count, 2)
        queue.setPaused(false)
        let requested = await eventually { await requester.calls.count == 1 }
        XCTAssertTrue(requested)
        let calls = await requester.calls
        XCTAssertEqual(calls.map(\.lastPathComponent), ["c"])
        XCTAssertEqual(queue.items.filter { $0.status == .submitted }.count, 1)
    }

    @MainActor
    func testWaitingConflictsAndErrorsAreNotSubmittedOnResume() async {
        let requester = RecordingRequester()
        let queue = DownloadQueue(requester: requester, isDryRun: false)
        queue.setPaused(true)
        queue.enqueue([item("conflict"), item("error")], root: root)
        queue.reconcile(with: [item("conflict", state: .conflict), item("error", state: .error)])
        queue.setPaused(false)
        XCTAssertTrue(queue.items.allSatisfy { $0.status == .failed })
        let calls = await requester.calls
        XCTAssertTrue(calls.isEmpty)
    }

    @MainActor
    func testChangingRootResetsQueueSession() async {
        let queue = DownloadQueue(requester: RecordingRequester(), isDryRun: false)
        queue.setPaused(true)
        queue.enqueue([item("old")], root: root)
        let nextRoot = URL(fileURLWithPath: "/Next-Root.example", isDirectory: true)
        queue.enqueue(
            [
                DriveItem(
                    url: nextRoot.appendingPathComponent("new"), name: "new", relativePath: "new", state: .cloudOnly)
            ], root: nextRoot)
        XCTAssertEqual(queue.items.map(\.name), ["new"])
    }
}
