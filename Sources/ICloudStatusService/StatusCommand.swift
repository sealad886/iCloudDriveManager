import Darwin
import Foundation

enum StatusCommand {
    enum Failure: Error {
        case launch, outputLimit, read, unsuccessfulExit, invalidEncoding

        var message: String {
            switch self {
            case .launch: return "The macOS iCloud status tool could not start."
            case .outputLimit:
                return "The system activity output exceeded the safe size limit. Totals were not calculated."
            case .read: return "The system activity output could not be read."
            case .unsuccessfulExit: return "The macOS iCloud status tool did not complete successfully."
            case .invalidEncoding: return "The system activity output used an unsupported text encoding."
            }
        }
    }

    static func readOutput() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/brctl")
        process.arguments = ["status"]
        process.environment = ["PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]
        process.currentDirectoryURL = URL(fileURLWithPath: "/", isDirectory: true)
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        let termination = CommandTermination(process: process)
        defer {
            termination.finish()
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        do {
            try process.run()
        } catch {
            throw Failure.launch
        }
        try? pipe.fileHandleForWriting.close()

        let maximumBytes = 128 * 1024 * 1024
        var data = Data()
        do {
            while let chunk = try pipe.fileHandleForReading.read(upToCount: 64 * 1024), !chunk.isEmpty {
                if let failure = termination.failure { throw failure }
                guard data.count <= maximumBytes - chunk.count else {
                    termination.stop(with: .outputLimit)
                    throw Failure.outputLimit
                }
                data.append(chunk)
            }
        } catch let failure as Failure {
            termination.stop(with: failure)
            process.waitUntilExit()
            throw failure
        } catch {
            termination.stop(with: .read)
            process.waitUntilExit()
            throw Failure.read
        }
        process.waitUntilExit()
        if let failure = termination.failure { throw failure }
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw Failure.unsuccessfulExit
        }
        guard let output = String(data: data, encoding: .utf8) else { throw Failure.invalidEncoding }
        return output
    }
}

/// Read-error and output-limit handling can signal only this operation's child.
/// No cloud daemon, unrelated process, or user-selected executable is targeted.
private final class CommandTermination {
    private let process: Process
    private let lock = NSLock()
    private var reason: StatusCommand.Failure?
    private var finished = false

    init(process: Process) { self.process = process }

    var failure: StatusCommand.Failure? {
        lock.lock()
        defer { lock.unlock() }
        return reason
    }

    func finish() {
        lock.lock()
        finished = true
        lock.unlock()
    }

    func stop(with failure: StatusCommand.Failure) {
        lock.lock()
        guard !finished, reason == nil else {
            lock.unlock()
            return
        }
        reason = failure
        lock.unlock()
        if process.isRunning { process.terminate() }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) { [process] in
            if process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
        }
    }
}
