import Foundation

public enum FileProviderBacklogParseError: LocalizedError {
    case unavailable

    public var errorDescription: String? {
        "The iCloud backlog is unavailable because macOS returned unrecognized or ambiguous provider diagnostics."
    }
}

/// Extracts one explicitly scoped materialization counter from complete output of
/// `fileproviderctl dump -l`. This diagnostic format is version-sensitive; unknown
/// provider scope, malformed counters, or multiple counter sources fail closed.
public enum FileProviderBacklogParser {
    public static let iCloudProviderIdentifier = "com.apple.CloudDocs.iCloudDriveFileProvider"

    public static func parse(output: String) throws -> SystemBacklogSnapshot {
        let provider = try NSRegularExpression(pattern: #"^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+$"#)
        let counter = try NSRegularExpression(
            pattern: #"^\s*\+\s+Materialize counters\s*:\s*(\d+)\s+items\s+with\s+size\s+(\d+)\s*$"#
        )
        let ansi = try NSRegularExpression(pattern: "\\u001B\\[[0-?]*[ -/]*[@-~]")
        var previousWasSeparator = false
        var pendingProvider: String?
        var currentProvider: String?
        var knownProviderSections = 0
        var observation: (count: Int, bytes: Int64)?
        var invalid = false
        output.enumerateLines { rawLine, stop in
            let line = ansi.stringByReplacingMatches(
                in: rawLine, range: NSRange(rawLine.startIndex..., in: rawLine), withTemplate: ""
            )
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isSeparator = trimmed.count >= 8 && trimmed.allSatisfy { $0 == "=" }
            if let candidate = pendingProvider {
                guard isSeparator else {
                    invalid = true
                    stop = true
                    return
                }
                currentProvider = candidate
                if candidate == iCloudProviderIdentifier { knownProviderSections += 1 }
                pendingProvider = nil
            } else if previousWasSeparator,
                provider.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
            {
                pendingProvider = trimmed
            }
            previousWasSeparator = isSeparator
            if trimmed.hasPrefix("+ Materialize counters") {
                guard let currentProvider else {
                    invalid = true
                    stop = true
                    return
                }
                guard currentProvider == iCloudProviderIdentifier else { return }
                guard observation == nil,
                    let match = counter.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                    let countRange = Range(match.range(at: 1), in: line),
                    let bytesRange = Range(match.range(at: 2), in: line),
                    let count = Int(line[countRange]), let bytes = Int64(line[bytesRange])
                else {
                    invalid = true
                    stop = true
                    return
                }
                observation = (count, bytes)
            }
        }
        guard !invalid, pendingProvider == nil, knownProviderSections == 1, let observation else {
            throw FileProviderBacklogParseError.unavailable
        }
        return SystemBacklogSnapshot(
            pendingItemCount: observation.count, logicalBytes: observation.bytes,
            scopeDescription: "iCloud Drive provider"
        )
    }
}
