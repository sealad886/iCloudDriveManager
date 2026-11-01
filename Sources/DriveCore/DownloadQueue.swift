import Foundation

public enum QueueStatus: String, Sendable {
    case planned, waiting, submitted, completed, failed, cancelled
}

public struct DownloadQueueItem: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public internal(set) var status: QueueStatus
    public internal(set) var error: String?

    public init(
        id: UUID = UUID(), url: URL, name: String,
        status: QueueStatus = .waiting, error: String? = nil
    ) {
        self.id = id
        self.url = url.standardizedFileURL
        self.name = name
        self.status = status
        self.error = error
    }
}

/// A session-only queue of this app's download requests, not Apple's global queue.
/// Dry run is the default and records plans without invoking the requester.
@MainActor
public final class DownloadQueue {
    public private(set) var items: [DownloadQueueItem] = []
    public private(set) var isPaused = false
    public private(set) var isDryRun: Bool
    public var onChange: (() -> Void)?
    private let requester: any DownloadRequesting
    private var root: URL?
    private var generation = UUID()
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var attempts: [UUID: UUID] = [:]
    private let maximumSubmitted = 2

    public init(requester: any DownloadRequesting = SystemDownloadRequester(), isDryRun: Bool = true) {
        self.requester = requester
        self.isDryRun = isDryRun
    }

    public func enqueue(_ newItems: [DriveItem], root: URL) {
        let root = root.standardizedFileURL
        guard root.isFileURL else { return }
        if let previousRoot = self.root, previousRoot != root { reset() }
        self.root = root
        for item in newItems where item.state.canRequestDownload && !item.isDirectory {
            guard PathAccess.relativePath(of: item.url, within: root) != nil else { continue }
            if let index = items.firstIndex(where: { $0.url == item.url }) {
                guard items[index].status != .waiting && items[index].status != .submitted else { continue }
                items[index].status = isDryRun ? .planned : .waiting
                items[index].error = nil
            } else {
                items.append(DownloadQueueItem(url: item.url, name: item.name, status: isDryRun ? .planned : .waiting))
            }
        }
        onChange?()
        pump()
    }

    public func setPaused(_ paused: Bool) {
        isPaused = paused
        onChange?()
        pump()
    }

    /// Plans never become live requests merely because the user changes modes.
    public func setDryRun(_ enabled: Bool) {
        guard isDryRun != enabled else { return }
        isDryRun = enabled
        if enabled {
            generation = UUID()
            for task in tasks.values { task.cancel() }
            tasks.removeAll()
            attempts.removeAll()
            for index in items.indices where items[index].status == .waiting {
                items[index].status = .planned
            }
            // A dispatched call may have reached macOS before its asynchronous
            // result is observed. Retain submitted records and observe metadata;
            // cancelling our task cannot revoke an accepted system download.
        }
        onChange?()
    }

    /// Submitted requests may already belong to macOS and cannot be cancelled here.
    public func cancel(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
            items[index].status == .waiting || items[index].status == .planned
        else { return }
        items[index].status = .cancelled
        onChange?()
        pump()
    }

    public func retry(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
            items[index].status == .failed || items[index].status == .planned
        else { return }
        items[index].status = isDryRun ? .planned : .waiting
        items[index].error = nil
        onChange?()
        pump()
    }

    /// Changes this app's plan/request order. Apple still schedules actual transfers.
    public func moveToFront(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
            items[index].status == .waiting || items[index].status == .planned
        else { return }
        let item = items.remove(at: index)
        items.insert(item, at: 0)
        onChange?()
    }

    public func clearFinished() {
        items.removeAll { $0.status == .completed || $0.status == .cancelled }
        onChange?()
    }

    public func reconcile(with observedItems: [DriveItem]) {
        let states = Dictionary(observedItems.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        var changed = false
        for index in items.indices where items[index].status == .submitted || items[index].status == .waiting {
            guard let observed = states[items[index].url.absoluteString] else { continue }
            if observed.state == .current {
                invalidateAttempt(items[index].id)
                items[index].status = .completed
                items[index].error = nil
                changed = true
            } else if observed.state.needsAttention {
                invalidateAttempt(items[index].id)
                items[index].status = .failed
                items[index].error = observed.issue ?? observed.state.title
                changed = true
            }
        }
        if changed { onChange?() }
        pump()
    }

    public func reset() {
        generation = UUID()
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        attempts.removeAll()
        root = nil
        items.removeAll()
        isPaused = false
        onChange?()
    }

    private func pump() {
        guard !isDryRun, !isPaused, let root else { return }
        let capacity = maximumSubmitted - items.filter { $0.status == .submitted }.count
        guard capacity > 0 else { return }
        let pendingIDs = items.filter { $0.status == .waiting }.prefix(capacity).map(\.id)
        let generation = self.generation
        let requester = self.requester
        for id in pendingIDs {
            guard let index = items.firstIndex(where: { $0.id == id }) else { continue }
            items[index].status = .submitted
            let url = items[index].url
            let attempt = UUID()
            attempts[id] = attempt
            tasks[id] = Task { [weak self] in
                do {
                    try Task.checkCancellation()
                    try await requester.requestDownload(at: url, within: root)
                    guard let self, self.generation == generation,
                        self.attempts[id] == attempt
                    else { return }
                    self.tasks[id] = nil
                    self.attempts[id] = nil
                } catch {
                    guard let self, self.generation == generation,
                        self.attempts[id] == attempt,
                        let index = self.items.firstIndex(where: { $0.id == id }),
                        self.items[index].status == .submitted
                    else { return }
                    self.tasks[id] = nil
                    self.attempts[id] = nil
                    self.items[index].status = .failed
                    self.items[index].error = error.localizedDescription
                    self.onChange?()
                    self.pump()
                }
            }
        }
        onChange?()
    }

    private func invalidateAttempt(_ id: UUID) {
        attempts[id] = nil
        tasks.removeValue(forKey: id)?.cancel()
    }
}
