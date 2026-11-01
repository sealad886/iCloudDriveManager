import DriveCore
import Foundation

/// Keeps a connection alive so published system operations remain observable.
/// Both RPCs are read-only. No cancellation is inferred from diagnostic records.
@MainActor
final class SystemTransfersMonitor {
    var onProgress: (([PublishedTransferSnapshot], String?) -> Void)?
    var onBacklog: ((SystemBacklogSnapshot?, Bool, String?) -> Void)?

    private var connection: NSXPCConnection?
    private var connectionID = UUID()
    private var generation = UUID()
    private var progressRequestID: UUID?
    private var backlogRequestID: UUID?
    private var pollingTask: Task<Void, Never>?
    private var isRunning = false
    private var transfers: [PublishedTransferSnapshot] = []
    private var backlog: SystemBacklogSnapshot?

    func start() {
        stop()
        isRunning = true
        refresh()
        pollingTask = Task { [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                guard let self, self.isRunning else { return }
                self.readProgress()
                ticks += 1
                if ticks % 12 == 0 { self.readBacklog() }
            }
        }
    }

    func refresh() {
        guard isRunning else { return }
        readProgress()
        readBacklog()
    }

    func stop() {
        isRunning = false
        generation = UUID()
        progressRequestID = nil
        backlogRequestID = nil
        pollingTask?.cancel()
        pollingTask = nil
        connection?.invalidate()
        connection = nil
        transfers = []
        backlog = nil
    }

    private func activeConnection() -> NSXPCConnection {
        if let connection { return connection }
        let id = UUID()
        let generation = self.generation
        connectionID = id
        let connection = NSXPCConnection(serviceName: "com.local.iCloudDriveManager.ICloudStatusService")
        connection.remoteObjectInterface = NSXPCInterface(with: SystemTransfersReading.self)
        let interrupted: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == generation, self.connectionID == id else { return }
                self.connection?.invalidationHandler = nil
                self.connection?.interruptionHandler = nil
                self.connection?.invalidate()
                self.connection = nil
                self.progressRequestID = nil
                self.backlogRequestID = nil
                self.onProgress?(self.transfers, "Published system progress is unavailable. The next check will retry.")
                self.onBacklog?(
                    self.backlog, false,
                    "The system backlog reader was interrupted. The last observation may be out of date.")
            }
        }
        connection.interruptionHandler = interrupted
        connection.invalidationHandler = interrupted
        self.connection = connection
        connection.resume()
        return connection
    }

    private func readProgress() {
        guard progressRequestID == nil else { return }
        let id = UUID()
        let generation = self.generation
        progressRequestID = id
        let proxy =
            activeConnection().remoteObjectProxyWithErrorHandler { [weak self] _ in
                Task { @MainActor in
                    self?.finishProgress(
                        id: id, generation: generation, data: nil, error: "Published system progress could not be read."
                    )
                }
            } as? SystemTransfersReading
        guard let proxy else {
            finishProgress(
                id: id, generation: generation, data: nil, error: "The system progress reader is unavailable.")
            return
        }
        proxy.readPublishedTransfers { [weak self] data, error in
            Task { @MainActor in
                self?.finishProgress(id: id, generation: generation, data: data, error: error)
            }
        }
    }

    private func readBacklog() {
        guard backlogRequestID == nil else { return }
        let id = UUID()
        let generation = self.generation
        backlogRequestID = id
        onBacklog?(backlog, true, nil)
        let proxy =
            activeConnection().remoteObjectProxyWithErrorHandler { [weak self] _ in
                Task { @MainActor in
                    self?.finishBacklog(
                        id: id, generation: generation, data: nil,
                        error: "The system download backlog could not be read.")
                }
            } as? SystemTransfersReading
        guard let proxy else {
            finishBacklog(id: id, generation: generation, data: nil, error: "The system backlog reader is unavailable.")
            return
        }
        proxy.readBacklog { [weak self] data, error in
            Task { @MainActor in
                self?.finishBacklog(id: id, generation: generation, data: data, error: error)
            }
        }
    }

    private func finishProgress(id: UUID, generation: UUID, data: Data?, error: String?) {
        guard self.generation == generation, progressRequestID == id else { return }
        progressRequestID = nil
        if let data, let decoded = try? JSONDecoder().decode([PublishedTransferSnapshot].self, from: data) {
            transfers = decoded
            onProgress?(decoded, nil)
        } else {
            onProgress?(transfers, error ?? "Published progress used an unsupported format.")
        }
    }

    private func finishBacklog(id: UUID, generation: UUID, data: Data?, error: String?) {
        guard self.generation == generation, backlogRequestID == id else { return }
        backlogRequestID = nil
        if let data, let decoded = try? JSONDecoder().decode(SystemBacklogSnapshot.self, from: data) {
            backlog = decoded
            onBacklog?(decoded, false, nil)
        } else {
            onBacklog?(backlog, false, error ?? "The system backlog used an unsupported format.")
        }
    }
}
