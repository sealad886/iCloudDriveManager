import DriveCore
import Foundation

/// Reads aggregate diagnostics through the bundled, read-only service. File access
/// and download actions remain in the sandboxed app and their existing gates.
@MainActor
final class SystemActivityMonitor {
    var onChange: ((SystemActivitySnapshot?, Bool, String?) -> Void)?

    private var connection: NSXPCConnection?
    private var pollingTask: Task<Void, Never>?
    private var requestID: UUID?
    private var generation = UUID()
    private var snapshot: SystemActivitySnapshot?
    private var isRunning = false

    func start() {
        stop()
        isRunning = true
        refresh()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
                guard let self, self.isRunning else { return }
                self.refresh()
            }
        }
    }

    func refresh() {
        guard isRunning, requestID == nil else { return }
        let id = UUID()
        let generation = self.generation
        requestID = id
        onChange?(snapshot, true, nil)

        let connection = NSXPCConnection(serviceName: "com.local.iCloudDriveManager.ICloudStatusService")
        connection.remoteObjectInterface = NSXPCInterface(with: ICloudStatusReading.self)
        self.connection = connection
        connection.resume()
        let proxy =
            connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
                Task { @MainActor in
                    self?.finish(
                        id: id, generation: generation, data: nil,
                        error: "The read-only iCloud status service could not be reached. Try Refresh."
                    )
                }
            } as? ICloudStatusReading
        guard let proxy else {
            finish(id: id, generation: generation, data: nil, error: "The iCloud status service is unavailable.")
            return
        }
        proxy.readStatus { [weak self] data, error in
            Task { @MainActor in
                self?.finish(id: id, generation: generation, data: data, error: error)
            }
        }
    }

    func stop() {
        isRunning = false
        generation = UUID()
        requestID = nil
        pollingTask?.cancel()
        pollingTask = nil
        connection?.invalidate()
        connection = nil
        snapshot = nil
    }

    private func finish(id: UUID, generation: UUID, data: Data?, error: String?) {
        guard self.generation == generation, requestID == id else { return }
        requestID = nil
        connection?.invalidate()
        connection = nil
        if let data, let decoded = try? JSONDecoder().decode(SystemActivitySnapshot.self, from: data) {
            snapshot = decoded
            onChange?(decoded, false, nil)
        } else {
            onChange?(
                snapshot, false, error ?? "System iCloud activity could not be interpreted on this macOS version.")
        }
    }
}
