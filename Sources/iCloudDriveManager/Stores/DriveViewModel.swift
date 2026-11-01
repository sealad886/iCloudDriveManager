import AppKit
import Combine
import DriveCore
import DrivePersistence
import Foundation
import OSLog

@MainActor
final class DriveViewModel: ObservableObject {
    @Published private(set) var items: [DriveItem] = []
    @Published private(set) var stateCounts: [SyncState: Int] = [:]
    @Published private(set) var queueItems: [DownloadQueueItem] = []
    @Published private(set) var rootURL: URL?
    @Published private(set) var isGathering = false
    @Published private(set) var isDryRun = true
    @Published private(set) var isQueuePaused = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var systemActivity: SystemActivitySnapshot?
    @Published private(set) var isReadingSystemActivity = false
    @Published private(set) var systemActivityError: String?
    @Published private(set) var publishedTransfers: [PublishedTransferSnapshot] = []
    @Published private(set) var systemBacklog: SystemBacklogSnapshot?
    @Published private(set) var isReadingBacklog = false
    @Published private(set) var systemProgressError: String?
    @Published private(set) var systemBacklogError: String?
    @Published private(set) var hasStartedFileObservation = false
    @Published var notice: String?
    @Published var errorMessage: String?
    @Published var isShowingLongDiscoveryNotice = false
    @Published var askEachTime = true {
        didSet { preferences.set(askEachTime, forKey: "askBeforeLiveActions") }
    }

    private let monitor = MetadataMonitor()
    private let systemMonitor = SystemActivityMonitor()
    private let transfersMonitor = SystemTransfersMonitor()
    private let queue = DownloadQueue()
    private var storage: BookmarkStore?
    private var accessedURL: URL?
    private let preferences: UserDefaults
    private let logger = Logger(subsystem: "com.local.iCloudDriveManager", category: "Lifecycle")

    var scopeName: String { rootURL?.lastPathComponent ?? "iCloud Drive" }
    var unknownItemCount: Int { stateCounts[.unknown, default: 0] }
    var cloudOnlyCount: Int { stateCounts[.cloudOnly, default: 0] }
    var reportedIssueCount: Int { stateCounts[.conflict, default: 0] + stateCounts[.error, default: 0] }
    var reportedActivityCount: Int {
        SyncState.allCases.reduce(0) { $0 + ($1.isActive ? stateCounts[$1, default: 0] : 0) }
    }

    init(store: BookmarkStore? = nil, restoreConnection: Bool = true, preferences: UserDefaults = .standard) {
        self.preferences = preferences
        askEachTime = preferences.object(forKey: "askBeforeLiveActions") as? Bool ?? true
        storage = store
        monitor.onLongDiscovery = { [weak self] in
            self?.isShowingLongDiscoveryNotice = true
        }
        transfersMonitor.onProgress = { [weak self] transfers, error in
            guard let self else { return }
            self.publishedTransfers = transfers
            self.systemProgressError = error
        }
        transfersMonitor.onBacklog = { [weak self] backlog, isReading, error in
            guard let self else { return }
            self.systemBacklog = backlog
            self.isReadingBacklog = isReading
            self.systemBacklogError = error
        }
        systemMonitor.onChange = { [weak self] snapshot, isReading, error in
            guard let self else { return }
            self.systemActivity = snapshot
            self.isReadingSystemActivity = isReading
            self.systemActivityError = error
            if !isReading, let snapshot, error == nil {
                self.logger.info(
                    "Read-only system status: \(snapshot.itemCount, privacy: .public) records, \(snapshot.pendingUploadCount ?? -1, privacy: .public) pending uploads, \(snapshot.downloadingCount ?? -1, privacy: .public) downloading records"
                )
            } else if error != nil {
                self.logger.error("Read-only system status is unavailable")
            }
        }
        monitor.onSnapshot = { [weak self] snapshot in
            guard let self,
                self.rootURL?.standardizedFileURL == snapshot.root.standardizedFileURL
            else { return }
            self.items = snapshot.items
            self.stateCounts = snapshot.items.reduce(into: [:]) { $0[$1.state, default: 0] += 1 }
            self.isGathering = snapshot.isGathering
            self.lastUpdated = snapshot.observedAt
            self.notice = snapshot.warning
            self.queue.reconcile(with: snapshot.items)
            self.logger.debug(
                "Folder metadata: \(snapshot.items.count, privacy: .public) items, \(self.unknownItemCount, privacy: .public) unknown states; discovering=\(snapshot.isGathering, privacy: .public)"
            )
        }
        queue.onChange = { [weak self] in
            guard let self else { return }
            self.queueItems = self.queue.items
            self.isQueuePaused = self.queue.isPaused
        }
        if restoreConnection {
            do {
                if storage == nil { storage = try BookmarkStore.applicationStore() }
                try restoreBookmark()
            } catch {
                errorMessage =
                    "Folder access could not be restored. \(error.localizedDescription) Choose your folder again."
                logger.error("Saved folder access could not be restored")
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose an iCloud Drive folder"
        panel.message =
            "Select iCloud Drive or one of its folders. File details are read from this folder. A separate read-only diagnostic shows aggregate system iCloud activity."
        panel.prompt = "Monitor folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try connect(to: url, remember: true)
        } catch {
            errorMessage = "This folder could not be connected. \(error.localizedDescription)"
            logger.error("Folder connection failed")
        }
    }

    func refresh() {
        guard rootURL != nil else { return }
        isShowingLongDiscoveryNotice = false
        if hasStartedFileObservation { monitor.refresh() }
        systemMonitor.refresh()
        transfersMonitor.refresh()
    }

    func refreshSystemTransfers() {
        guard rootURL != nil else { return }
        systemMonitor.refresh()
        transfersMonitor.refresh()
    }

    /// Detailed folder reads start only when the user opens the file browser.
    func beginFileObservation() {
        guard !hasStartedFileObservation, let rootURL else { return }
        do {
            hasStartedFileObservation = true
            try monitor.start(root: rootURL)
        } catch {
            hasStartedFileObservation = false
            errorMessage = "Folder metadata could not be read. \(error.localizedDescription)"
        }
    }

    func continueDiscovery() {
        // Discovery was never paused; dismissing the notice keeps the same pass running.
        isShowingLongDiscoveryNotice = false
    }

    func cancelDiscovery() {
        isShowingLongDiscoveryNotice = false
        monitor.cancelDiscovery()
    }

    func setDryRun(_ enabled: Bool) {
        guard enabled != isDryRun else { return }
        isDryRun = enabled
        queue.setDryRun(enabled)
        notice =
            enabled
            ? "Dry run active. New downloads are planned only. macOS continues managing requests already submitted."
            : "Live actions enabled for this session. Existing dry-run plans will not run automatically."
    }

    func disconnect() {
        do {
            try storage?.clear()
            endSession()
            notice = nil
            errorMessage = nil
            logger.info("Folder disconnected")
        } catch {
            errorMessage = "Saved folder access could not be removed. \(error.localizedDescription)"
        }
    }

    func enqueue(_ selectedItems: [DriveItem]) {
        guard let root = rootURL else { return }
        // The queue revalidates eligibility and the platform requester revalidates permissions at dispatch.
        let known = Set(items.map(\.id))
        let eligible = selectedItems.filter { known.contains($0.id) && $0.state.canRequestDownload && !$0.isDirectory }
        guard !eligible.isEmpty,
            confirmLiveAction(
                "Request downloads?",
                detail: "Ask macOS to download \(eligible.count) selected file(s) from iCloud to this Mac.",
                maySubmitDownloads: true
            )
        else { return }
        queue.enqueue(eligible, root: root)
    }

    func setQueuePaused(_ paused: Bool) {
        guard paused != queue.isPaused else { return }
        guard
            confirmLiveAction(
                paused ? "Pause waiting requests?" : "Resume waiting requests?",
                detail: paused
                    ? "Hold requests that this app has not submitted. Transfers already owned by macOS will continue."
                    : "Allow this app's waiting download requests to be sent to macOS.",
                maySubmitDownloads: !paused
            )
        else { return }
        queue.setPaused(paused)
    }

    func cancelQueueItem(_ id: UUID) {
        guard let item = queue.items.first(where: { $0.id == id }) else { return }
        if item.status == .planned {
            queue.cancel(id)
            return
        }
        guard item.status == .waiting,
            confirmLiveAction(
                "Cancel waiting request?",
                detail:
                    "Cancel the waiting request for \(item.name) in this app. This cannot cancel a download already submitted to macOS."
            )
        else { return }
        queue.cancel(id)
    }

    func retryQueueItem(_ id: UUID) {
        guard let item = queue.items.first(where: { $0.id == id }), item.status == .failed || item.status == .planned,
            confirmLiveAction(
                item.status == .planned ? "Run planned download?" : "Retry download request?",
                detail: "Ask macOS to download \(item.name) to this Mac.",
                maySubmitDownloads: true
            )
        else { return }
        queue.retry(id)
    }

    func moveQueueItemToFront(_ id: UUID) {
        guard let item = queue.items.first(where: { $0.id == id }), item.status == .waiting,
            confirmLiveAction(
                "Move waiting request first?",
                detail:
                    "Move \(item.name) ahead of other waiting requests in this app. macOS controls the order of actual transfers."
            )
        else { return }
        queue.moveToFront(id)
    }
    func clearFinishedQueue() { queue.clearFinished() }

    /// End observation and pending work while leaving the remembered folder available for the next launch.
    func shutdown() { endSession() }

    func reveal(_ item: DriveItem) {
        guard items.contains(where: { $0.id == item.id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// All UI entry points share the same live-action decision. No/close never changes preferences or dispatches work.
    private func confirmLiveAction(_ title: String, detail: String, maySubmitDownloads: Bool = false) -> Bool {
        guard !isDryRun else { return true }
        guard askEachTime else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        let warning =
            maySubmitDownloads
            ? "This action will be performed on the live iCloud Drive architecture. Real data will be affected. Are you sure you want to continue?"
            : "Live actions are enabled. This changes waiting requests in this app; transfers already submitted to macOS are unaffected. Are you sure you want to continue?"
        alert.informativeText = detail + "\n\n" + warning
        alert.addButton(withTitle: "Yes").keyEquivalent = ""
        alert.addButton(withTitle: "No").keyEquivalent = "\r"
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Ask each time"
        alert.suppressionButton?.state = .on
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        askEachTime = alert.suppressionButton?.state != .off
        return true
    }

    private func restoreBookmark() throws {
        guard let record = try storage?.load() else { return }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: record.bookmarkData, options: [.withSecurityScope, .withoutUI],
            relativeTo: nil, bookmarkDataIsStale: &stale
        )
        try connect(to: url, remember: stale)
    }

    private func connect(to url: URL, remember: Bool) throws {
        let accessStarted = url.startAccessingSecurityScopedResource()
        var retained = false
        defer { if accessStarted && !retained { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
        guard values.isDirectory == true, values.isReadable != false else {
            throw CocoaError(.fileReadNoPermission)
        }
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil && !accessStarted {
            throw CocoaError(.fileReadNoPermission)
        }
        if remember {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            if storage == nil { storage = try BookmarkStore.applicationStore() }
            try storage?.save(bookmarkData: bookmark)
        }
        endSession()
        accessedURL = accessStarted ? url : nil
        retained = true
        rootURL = url
        isGathering = false
        errorMessage = nil
        systemMonitor.start()
        transfersMonitor.start()
        logger.info("System transfer observation started; folder metadata is read on demand")
    }

    private func endSession() {
        monitor.stop()
        systemMonitor.stop()
        transfersMonitor.stop()
        queue.reset()
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        rootURL = nil
        items = []
        stateCounts = [:]
        queueItems = []
        isGathering = false
        isQueuePaused = false
        lastUpdated = nil
        systemActivity = nil
        isReadingSystemActivity = false
        systemActivityError = nil
        publishedTransfers = []
        systemBacklog = nil
        isReadingBacklog = false
        systemProgressError = nil
        systemBacklogError = nil
        hasStartedFileObservation = false
        isShowingLongDiscoveryNotice = false
    }
}
