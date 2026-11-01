import Foundation

struct MetadataCandidate: Sendable {
    let url: URL
    let name: String
    let relativePath: String
    let fields: MetadataFields
}

struct MetadataDiscoveryBatch: Sendable {
    let candidates: [MetadataCandidate]
    let inspected: Int
    let unreadable: Int
}

struct MetadataDiscoveryResult: Sendable {
    let seenIDs: Set<String>
    let inspected: Int
    let unreadable: Int
    let completed: Bool
}

/// Reads directory entries and resource metadata only. It never opens document contents.
enum MetadataDiscovery {
    static func scan(
        root: URL,
        knownURLs: [URL]? = nil,
        readFields: @Sendable (URL) throws -> MetadataFields = { try MetadataFields.readResources(at: $0) },
        progress: @Sendable (MetadataDiscoveryBatch) async -> Void
    ) async throws -> MetadataDiscoveryResult {
        var unreadable = 0
        let enumerator: FileManager.DirectoryEnumerator?
        if knownURLs == nil {
            enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: Array(
                    MetadataFields.resourceKeys.union([
                        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
                    ])),
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in
                    unreadable += 1
                    return !Task.isCancelled
                }
            )
            guard enumerator != nil else {
                return MetadataDiscoveryResult(seenIDs: [], inspected: 0, unreadable: 1, completed: false)
            }
        } else {
            enumerator = nil
        }
        var suppliedIndex = 0
        func nextURL() -> URL? {
            if let knownURLs {
                guard suppliedIndex < knownURLs.count else { return nil }
                defer { suppliedIndex += 1 }
                return knownURLs[suppliedIndex]
            }
            return enumerator?.nextObject() as? URL
        }
        var inspected = 0
        var seenIDs = Set<String>()
        var batch: [MetadataCandidate] = []
        var lastPublication = Date()
        var publishedFirstBatch = false
        while let entry = nextURL() {
            try Task.checkCancellation()
            inspected += 1
            let structure = try? entry.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isPackageKey])
            if structure?.isSymbolicLink == true {
                enumerator?.skipDescendants()
                continue
            }
            guard let relativePath = PathAccess.relativePath(of: entry, within: root),
                let canonical = try? PathAccess.validatedURL(entry, within: root)
            else {
                enumerator?.skipDescendants()
                continue
            }
            let fields: MetadataFields
            do {
                fields = try readFields(canonical)
            } catch {
                unreadable += 1
                // A visible path with unavailable provider metadata is unknown,
                // not evidence of an empty or fully synchronized folder.
                fields = MetadataFields(isDirectory: structure?.isDirectory)
            }
            if fields.isUbiquitous != false {
                let url = entry.standardizedFileURL
                seenIDs.insert(url.absoluteString)
                batch.append(
                    MetadataCandidate(
                        url: url, name: entry.lastPathComponent, relativePath: relativePath,
                        fields: fields.fallingBack(to: MetadataFields(isDirectory: structure?.isDirectory))
                    ))
            }
            if (!publishedFirstBatch && inspected >= 200) || Date().timeIntervalSince(lastPublication) >= 0.75 {
                try Task.checkCancellation()
                await progress(MetadataDiscoveryBatch(candidates: batch, inspected: inspected, unreadable: unreadable))
                batch.removeAll(keepingCapacity: true)
                lastPublication = Date()
                publishedFirstBatch = true
            }
        }
        try Task.checkCancellation()
        await progress(MetadataDiscoveryBatch(candidates: batch, inspected: inspected, unreadable: unreadable))
        return MetadataDiscoveryResult(seenIDs: seenIDs, inspected: inspected, unreadable: unreadable, completed: true)
    }
}

@MainActor
public final class MetadataMonitor {
    public var onSnapshot: ((MetadataSnapshot) -> Void)?
    public var onLongDiscovery: (() -> Void)?
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var selectedRoot: URL?
    private var generation = UUID()
    private var discoveryGeneration = UUID()
    private var monitoringTask: Task<Void, Never>?
    private var longDiscoveryNoticeTask: Task<Void, Never>?
    private var providerRecords: [String: MetadataCandidate] = [:]
    private var cloudFields: [String: MetadataFields] = [:]
    private var items: [String: DriveItem] = [:]
    private var inspected = 0
    private var unreadable = 0
    private var isDiscovering = false
    private var discoveryCancelled = false
    private var queryAvailable = false

    public init() {}

    public func start(root: URL) throws {
        guard root.isFileURL else { throw DriveAccessError.invalidRoot }
        stop()
        let root = root.standardizedFileURL
        selectedRoot = root
        providerRecords.removeAll()
        cloudFields.removeAll()
        items.removeAll()
        inspected = 0
        unreadable = 0
        isDiscovering = true
        discoveryCancelled = false
        publish(root: root)
        startCloudQuery(root: root)
        let generation = self.generation
        let discoveryGeneration = self.discoveryGeneration
        longDiscoveryNoticeTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch { return }
            guard let self, !Task.isCancelled, self.generation == generation,
                self.discoveryGeneration == discoveryGeneration, self.selectedRoot == root, self.isDiscovering
            else { return }
            // Notification only: the same discovery pass keeps running until
            // completion or an explicit user cancellation.
            self.onLongDiscovery?()
        }
        monitoringTask = Task { [weak self] in
            var lastDiscovery: Date?
            while !Task.isCancelled {
                guard let self, self.generation == generation,
                    self.discoveryGeneration == discoveryGeneration
                else { return }
                let discover = lastDiscovery.map { Date().timeIntervalSince($0) >= 60 } ?? true
                let knownURLs = discover ? nil : self.providerRecords.values.map(\.url)
                self.isDiscovering = discover
                self.publish(root: root)
                let worker = Task.detached(priority: .utility) {
                    try await MetadataDiscovery.scan(root: root, knownURLs: knownURLs) { [weak self] batch in
                        await MainActor.run {
                            guard let self, self.generation == generation,
                                self.discoveryGeneration == discoveryGeneration
                            else { return }
                            self.apply(batch)
                            self.publish(root: root)
                        }
                    }
                }
                do {
                    let result = try await withTaskCancellationHandler {
                        try await worker.value
                    } onCancel: {
                        worker.cancel()
                    }
                    guard !Task.isCancelled, self.generation == generation,
                        self.discoveryGeneration == discoveryGeneration
                    else { return }
                    self.longDiscoveryNoticeTask?.cancel()
                    self.longDiscoveryNoticeTask = nil
                    self.inspected = result.inspected
                    self.unreadable = result.unreadable
                    if discover {
                        lastDiscovery = Date()
                        // Preserve earlier observations when part of the tree is
                        // unreadable rather than implying those files vanished.
                        if result.completed && result.unreadable == 0 {
                            self.providerRecords = self.providerRecords.filter { result.seenIDs.contains($0.key) }
                            self.items = self.items.filter { result.seenIDs.contains($0.key) }
                        }
                    }
                    self.isDiscovering = false
                    self.publish(root: root)
                } catch is CancellationError {
                    return
                } catch {
                    guard self.generation == generation, self.discoveryGeneration == discoveryGeneration else {
                        return
                    }
                    self.longDiscoveryNoticeTask?.cancel()
                    self.longDiscoveryNoticeTask = nil
                    self.isDiscovering = false
                    self.unreadable += 1
                    self.publish(root: root)
                }
                // No overlapping scan or task per file. A slow provider finishes
                // its current pass before the next refresh interval begins.
                do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { return }
            }
        }
    }

    public func refresh() {
        guard let root = selectedRoot else { return }
        try? start(root: root)
    }

    /// Stops this app's metadata discovery, preserving its partial observations
    /// and optional metadata query. It does not affect iCloud synchronization.
    public func cancelDiscovery() {
        guard let root = selectedRoot, monitoringTask != nil else { return }
        discoveryGeneration = UUID()
        monitoringTask?.cancel()
        monitoringTask = nil
        longDiscoveryNoticeTask?.cancel()
        longDiscoveryNoticeTask = nil
        isDiscovering = false
        discoveryCancelled = true
        publish(root: root)
    }

    public func stop() {
        generation = UUID()
        discoveryGeneration = UUID()
        monitoringTask?.cancel()
        monitoringTask = nil
        longDiscoveryNoticeTask?.cancel()
        longDiscoveryNoticeTask = nil
        query?.stop()
        query = nil
        queryAvailable = false
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    private func startCloudQuery(root: URL) {
        let query = NSMetadataQuery()
        // iCloud metadata searches are distinct from filesystem Spotlight
        // searches. Folder discovery must never depend on either query's results.
        query.searchScopes = [NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope]
        let pathPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey),
            NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, pathPrefix),
        ])
        query.notificationBatchingInterval = 1
        query.operationQueue = .main
        self.query = query
        let generation = self.generation
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(
                NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) {
                    [weak self] notification in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == generation, let query = self.query else { return }
                        self.ingest(query: query, notification: notification, root: root)
                    }
                })
        }
        queryAvailable = query.start()
    }

    private func apply(_ batch: MetadataDiscoveryBatch) {
        inspected = batch.inspected
        unreadable = batch.unreadable
        for record in batch.candidates {
            providerRecords[record.url.absoluteString] = record
            updateItem(record)
        }
    }

    private func updateItem(_ record: MetadataCandidate) {
        // Fresh resource values are authoritative. The iCloud query supplements
        // fields the provider omits, including optional percentages.
        let fields = record.fields.fallingBack(to: cloudFields[record.url.absoluteString] ?? MetadataFields())
        let facts = fields.syncFacts
        items[record.url.absoluteString] = DriveItem(
            url: record.url, name: record.name, relativePath: record.relativePath,
            byteCount: fields.byteCount, modifiedAt: fields.modifiedAt,
            state: facts.state, progress: facts.progress, issue: facts.issue,
            isDirectory: fields.isDirectory ?? false
        )
    }

    private func publish(root: URL) {
        let unknown = items.values.filter { $0.state == .unknown }.count
        var coverage =
            "Read \(inspected.formatted()) entries directly; showing \(items.count.formatted()) iCloud or unclassified items."
        if isDiscovering { coverage += " Discovering this folder…" }
        if discoveryCancelled {
            coverage +=
                " Discovery canceled; these results are partial. Refresh or choose another folder to scan again."
        }
        if unknown > 0 {
            coverage +=
                " Sync activity metadata is unavailable for \(unknown.formatted()) items; zero reported activity does not mean no transfers."
        }
        if unreadable > 0 { coverage += " \(unreadable.formatted()) metadata locations could not be read." }
        if !queryAvailable { coverage += " The optional iCloud metadata query is unavailable." }
        coverage += " This is not Apple's complete system transfer queue."
        onSnapshot?(
            MetadataSnapshot(
                items: Array(items.values), root: root, isGathering: isDiscovering, warning: coverage
            ))
    }

    private func ingest(query: NSMetadataQuery, notification: Notification, root: URL) {
        query.disableUpdates()
        defer { query.enableUpdates() }
        if notification.name == .NSMetadataQueryDidFinishGathering {
            cloudFields.removeAll()
            for index in 0..<query.resultCount {
                if let metadata = query.result(at: index) as? NSMetadataItem { ingest(metadata, root: root) }
            }
            for record in providerRecords.values { updateItem(record) }
        } else {
            for key in [NSMetadataQueryUpdateAddedItemsKey, NSMetadataQueryUpdateChangedItemsKey] {
                for metadata in notification.userInfo?[key] as? [NSMetadataItem] ?? [] {
                    ingest(metadata, root: root)
                }
            }
            for metadata in notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] ?? [] {
                guard let candidate = makeCandidate(metadata, root: root) else { continue }
                cloudFields[candidate.url.absoluteString] = nil
                if let record = providerRecords[candidate.url.absoluteString] { updateItem(record) }
            }
        }
        publish(root: root)
    }

    private func ingest(_ metadata: NSMetadataItem, root: URL) {
        guard let candidate = makeCandidate(metadata, root: root) else { return }
        cloudFields[candidate.url.absoluteString] = candidate.fields
        if let record = providerRecords[candidate.url.absoluteString] { updateItem(record) }
    }

    private func makeCandidate(_ item: NSMetadataItem, root: URL) -> MetadataCandidate? {
        let url: URL?
        if let itemURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
            url = itemURL.standardizedFileURL
        } else if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
            url = URL(fileURLWithPath: path).standardizedFileURL
        } else {
            url = nil
        }
        guard let url, let relativePath = PathAccess.relativePath(of: url, within: root) else { return nil }
        func boolean(_ key: String) -> Bool? { (item.value(forAttribute: key) as? NSNumber)?.boolValue }
        func number(_ key: String) -> Double? { (item.value(forAttribute: key) as? NSNumber)?.doubleValue }
        func issue(_ key: String) -> String? { (item.value(forAttribute: key) as? NSError)?.localizedDescription }
        let types = item.value(forAttribute: NSMetadataItemContentTypeTreeKey) as? [String]
        let fields = MetadataFields(
            isUbiquitous: boolean(NSMetadataItemIsUbiquitousKey),
            isDirectory: types.map { $0.contains("public.folder") || $0.contains("public.directory") },
            byteCount: (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value,
            modifiedAt: item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date,
            downloadingStatus: item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
            isUploaded: boolean(NSMetadataUbiquitousItemIsUploadedKey),
            isUploading: boolean(NSMetadataUbiquitousItemIsUploadingKey),
            isDownloading: boolean(NSMetadataUbiquitousItemIsDownloadingKey),
            downloadRequested: boolean(NSMetadataUbiquitousItemDownloadRequestedKey),
            hasConflicts: boolean(NSMetadataUbiquitousItemHasUnresolvedConflictsKey),
            downloadingError: issue(NSMetadataUbiquitousItemDownloadingErrorKey),
            uploadingError: issue(NSMetadataUbiquitousItemUploadingErrorKey),
            percentDownloaded: number(NSMetadataUbiquitousItemPercentDownloadedKey),
            percentUploaded: number(NSMetadataUbiquitousItemPercentUploadedKey)
        )
        return MetadataCandidate(
            url: url, name: item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? url.lastPathComponent,
            relativePath: relativePath, fields: fields
        )
    }
}
