import DriveCore
import Foundation

/// NSProgress invokes publication and unpublication handlers on the main
/// thread. The service's NSRunLoop keeps those callbacks and cached proxies live.
@MainActor
final class PublishedTransferRegistry {
    private var subscriber: Any?
    private var progressByID: [String: Progress] = [:]

    init() {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Mobile Documents", isDirectory: true)
        subscriber = Progress.addSubscriber(forFileURL: root) { [weak self] progress in
            let id = UUID().uuidString
            MainActor.assumeIsolated {
                self?.progressByID[id] = progress
            }
            return { [weak self] in
                MainActor.assumeIsolated {
                    _ = self?.progressByID.removeValue(forKey: id)
                }
            }
        }
    }

    func snapshots() -> [PublishedTransferSnapshot] {
        let observedAt = Date()
        return progressByID.keys.sorted().compactMap { id in
            guard let progress = progressByID[id] else { return nil }
            let operation: PublishedTransferKind
            switch progress.fileOperationKind {
            case .downloading: operation = .downloading
            case .uploading: operation = .uploading
            default: operation = .unknown
            }
            let byteUnits = progress.kind == .file
            let total = progress.totalUnitCount
            let completed = progress.completedUnitCount
            return PublishedTransferSnapshot(
                id: id, observedAt: observedAt,
                description: progress.localizedDescription,
                additionalDescription: progress.localizedAdditionalDescription,
                operationKind: operation,
                totalBytes: byteUnits && total > 0 ? total : nil,
                completedBytes: byteUnits && completed >= 0 ? completed : nil,
                isCancellable: progress.isCancellable,
                isPausable: progress.isPausable
            )
        }
    }
}
