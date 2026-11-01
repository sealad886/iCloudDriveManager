import Foundation

public enum DriveAccessError: LocalizedError {
    case invalidRoot, outsideRoot, notUbiquitous, directory, conflicts, queryUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidRoot: return "Choose a local iCloud Drive folder."
        case .outsideRoot: return "This item is outside the selected folder, or resolves outside it."
        case .notUbiquitous: return "macOS does not identify this item as an iCloud file."
        case .directory: return "Choose individual files to request downloads."
        case .conflicts: return "Resolve this file's conflicting versions before requesting a download."
        case .queryUnavailable:
            return "The metadata query could not start. Select the folder again or check Spotlight settings."
        }
    }
}

enum PathAccess {
    static func relativePath(of url: URL, within root: URL) -> String? {
        guard url.isFileURL, root.isFileURL else { return nil }
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.count > rootComponents.count,
            Array(components.prefix(rootComponents.count)) == rootComponents
        else { return nil }
        return components.dropFirst(rootComponents.count).joined(separator: "/")
    }

    /// Component boundaries prevent sibling-prefix escapes. Resolving both sides
    /// prevents a selected subtree's symbolic links from authorizing other files.
    static func validatedURL(_ url: URL, within root: URL) throws -> URL {
        guard root.isFileURL else { throw DriveAccessError.invalidRoot }
        guard relativePath(of: url, within: root) != nil else { throw DriveAccessError.outsideRoot }
        let canonicalRoot = try canonicalizingExistingAncestor(root)
        let canonicalURL = try canonicalizingExistingAncestor(url)
        guard relativePath(of: canonicalURL, within: canonicalRoot) != nil else {
            throw DriveAccessError.outsideRoot
        }
        return canonicalURL
    }

    /// Foundation can leave every symlink unresolved when the final component
    /// does not exist. Resolve the nearest existing ancestor, then append only
    /// its missing descendants. Reject dangling links rather than treating them
    /// as ordinary missing path components.
    private static func canonicalizingExistingAncestor(_ url: URL) throws -> URL {
        var ancestor = url.standardizedFileURL
        var missingComponents: [String] = []
        while !FileManager.default.fileExists(atPath: ancestor.path) {
            if (try? FileManager.default.destinationOfSymbolicLink(atPath: ancestor.path)) != nil {
                throw DriveAccessError.outsideRoot
            }
            guard ancestor.path != "/" else { break }
            missingComponents.append(ancestor.lastPathComponent)
            ancestor.deleteLastPathComponent()
        }
        var canonical = ancestor.resolvingSymlinksInPath()
        for component in missingComponents.reversed() {
            canonical.appendPathComponent(component)
        }
        return canonical.standardizedFileURL
    }
}

public protocol DownloadRequesting: Sendable {
    func requestDownload(at url: URL, within root: URL) async throws
}

public struct SystemDownloadRequester: DownloadRequesting {
    public init() {}

    public func requestDownload(at url: URL, within root: URL) async throws {
        // File-provider metadata and the download request can block. Keep them off
        // the main actor, and check cancellation before handing work to macOS.
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let target = try PathAccess.validatedURL(url, within: root)
            let values = try target.resourceValues(forKeys: [
                .isUbiquitousItemKey, .isDirectoryKey, .isSymbolicLinkKey,
                .ubiquitousItemHasUnresolvedConflictsKey,
            ])
            guard values.isUbiquitousItem == true else { throw DriveAccessError.notUbiquitous }
            guard values.isDirectory == false else { throw DriveAccessError.directory }
            guard values.ubiquitousItemHasUnresolvedConflicts != true else { throw DriveAccessError.conflicts }
            try Task.checkCancellation()
            // This requests a download. Success is not confirmation of completion.
            try FileManager.default.startDownloadingUbiquitousItem(at: target)
        }
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
