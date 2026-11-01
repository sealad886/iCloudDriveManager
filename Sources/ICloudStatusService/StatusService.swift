import DriveCore
import Foundation

/// All exported operations are read-only and argument-free. The same worker is
/// shared by accepted connections so diagnostic reads cannot fan out processes.
final class StatusService: NSObject, SystemTransfersReading {
    private let worker = DispatchQueue(label: "com.local.iCloudDriveManager.status-reader", qos: .utility)
    private let lock = NSLock()
    private var pendingObservations: Set<StatusCommand.Observation> = []
    private let progressRegistry: PublishedTransferRegistry

    init(progressRegistry: PublishedTransferRegistry) {
        self.progressRegistry = progressRegistry
        super.init()
    }

    func readStatus(reply: @escaping (Data?, String?) -> Void) {
        performRead(command: .cloudStatus, reply: reply) { output in
            try JSONEncoder().encode(SystemStatusParser.parse(output: output))
        }
    }

    func readBacklog(reply: @escaping (Data?, String?) -> Void) {
        performRead(command: .fileProviderBacklog, reply: reply) { output in
            try JSONEncoder().encode(FileProviderBacklogParser.parse(output: output))
        }
    }

    func readPublishedTransfers(reply: @escaping (Data?, String?) -> Void) {
        DispatchQueue.main.async { [progressRegistry] in
            do {
                reply(try JSONEncoder().encode(progressRegistry.snapshots()), nil)
            } catch {
                reply(nil, "The progress published by macOS could not be read.")
            }
        }
    }

    private func performRead(
        command: StatusCommand.Observation,
        reply: @escaping (Data?, String?) -> Void,
        encode: @escaping (String) throws -> Data
    ) {
        lock.lock()
        let alreadyReading = pendingObservations.contains(command)
        if !alreadyReading { pendingObservations.insert(command) }
        lock.unlock()
        guard !alreadyReading else {
            reply(nil, "A matching system activity check is already running or waiting. Try again shortly.")
            return
        }

        worker.async { [self] in
            defer {
                lock.lock()
                pendingObservations.remove(command)
                lock.unlock()
            }
            do {
                let output = try StatusCommand.readOutput(for: command)
                let data: Data
                do {
                    data = try encode(output)
                } catch {
                    reply(nil, "The system activity output could not be interpreted. No activity totals are available.")
                    return
                }
                reply(data, nil)
            } catch let error as StatusCommand.Failure {
                reply(nil, error.message)
            } catch {
                reply(nil, "The system activity check could not be completed.")
            }
        }
    }
}

final class StatusServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service: StatusService

    init(progressRegistry: PublishedTransferRegistry) {
        service = StatusService(progressRegistry: progressRegistry)
        super.init()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard ConnectionAuthorization.isContainingApp(connection) else { return false }
        connection.exportedInterface = NSXPCInterface(with: SystemTransfersReading.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}
