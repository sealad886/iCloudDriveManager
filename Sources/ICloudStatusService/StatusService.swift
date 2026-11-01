import DriveCore
import Foundation

/// The service exports one read-only, argument-free operation. The same worker
/// is shared by all accepted connections so requests cannot fan out processes.
final class StatusService: NSObject, ICloudStatusReading {
    private let worker = DispatchQueue(label: "com.local.iCloudDriveManager.status-reader", qos: .utility)
    private let lock = NSLock()
    private var isReading = false

    func readStatus(reply: @escaping (Data?, String?) -> Void) {
        lock.lock()
        let alreadyReading = isReading
        if !alreadyReading { isReading = true }
        lock.unlock()
        guard !alreadyReading else {
            reply(nil, "A system activity check is already running. Try again shortly.")
            return
        }

        worker.async { [self] in
            defer {
                lock.lock()
                isReading = false
                lock.unlock()
            }
            do {
                let output = try StatusCommand.readOutput()
                let snapshot: SystemActivitySnapshot
                do {
                    snapshot = try SystemStatusParser.parse(output: output)
                } catch {
                    reply(nil, "The system activity output could not be interpreted. No activity totals are available.")
                    return
                }
                reply(try JSONEncoder().encode(snapshot), nil)
            } catch let error as StatusCommand.Failure {
                reply(nil, error.message)
            } catch {
                reply(nil, "The system activity check could not be completed.")
            }
        }
    }
}

final class StatusServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service = StatusService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard ConnectionAuthorization.isContainingApp(connection) else { return false }
        connection.exportedInterface = NSXPCInterface(with: ICloudStatusReading.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}
