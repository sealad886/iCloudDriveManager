import Foundation

public enum SystemStatusParseError: LocalizedError {
    case unavailable

    public var errorDescription: String? {
        "System activity is unavailable because macOS returned an unrecognized status format."
    }
}

/// Parses complete output from the read-only `brctl status` command. This is a
/// version-sensitive diagnostic format, so unsupported structures fail closed.
public enum SystemStatusParser {
    private struct Record {
        var pendingUpload: Bool
        var downloading = false
    }

    public static func parse(output: String) throws -> SystemActivitySnapshot {
        let ansi = try NSRegularExpression(pattern: "\\u001B\\[[0-?]*[ -/]*[@-~]")
        let plain = ansi.stringByReplacingMatches(
            in: output, range: NSRange(output.startIndex..., in: output), withTemplate: ""
        )
        let header = try NSRegularExpression(
            pattern: #"^ {8}r:(\d+)\s+i:\S+\s+al:\d+\s+foid:\S+(?:\s+ld\{[^}]*\})?\s+up:([a-z-]+)\s+uv:\d+\s+st\{p:"#
        )
        let content = try NSRegularExpression(pattern: #"^>\s+[^\s{}]+\{\[content:"#)
        let download = try NSRegularExpression(
            pattern: #"^ {8}>\s+[^\s{}]+\{\[content:[^\s]+\s+downloading:([0-9]+(?:\.[0-9]+)?)%\s+"#
        )
        let downloadOperation = try NSRegularExpression(
            pattern: #"^ {8}>\s+downloader\{\[content:\S+\s+(?:download:\S+\s+op:\S+\s+)?active\s+attempts:"#
        )
        var records: [String: Record] = [:]
        var container: String?
        var currentRecord: String?
        var foundItemsSection = false
        var currentContainerHasItems = false
        for rawLine in plain.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("<c{") {
                container = line.split(separator: " ", maxSplits: 1).first.map(String.init)
                currentRecord = nil
                currentContainerHasItems = false
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("Client ") && trimmed.hasSuffix("Items:") {
                guard container != nil else { throw SystemStatusParseError.unavailable }
                foundItemsSection = true
                currentContainerHasItems = true
                currentRecord = nil
                continue
            }
            let range = NSRange(line.startIndex..., in: line)
            if trimmed.hasPrefix("r:") {
                guard currentContainerHasItems, let container,
                    let match = header.firstMatch(in: line, range: range),
                    let identityRange = Range(match.range(at: 1), in: line),
                    let stateRange = Range(match.range(at: 2), in: line)
                else { throw SystemStatusParseError.unavailable }
                let state = String(line[stateRange])
                guard state == "needs-upload" || state == "idle" else {
                    throw SystemStatusParseError.unavailable
                }
                // Row identities are private, retained only while aggregating.
                // A repeated record replaces its prior observation.
                let identity = container + ":" + String(line[identityRange])
                records[identity] = Record(pendingUpload: state == "needs-upload")
                currentRecord = identity
            } else if content.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                guard let currentRecord, line.hasSuffix("]}") else {
                    throw SystemStatusParseError.unavailable
                }
                if let match = download.firstMatch(in: line, range: range) {
                    guard let percentRange = Range(match.range(at: 1), in: line),
                        let percent = Double(line[percentRange]), percent.isFinite, (0...100).contains(percent)
                    else { throw SystemStatusParseError.unavailable }
                    records[currentRecord]?.downloading = true
                } else if downloadOperation.firstMatch(in: line, range: range) == nil {
                    throw SystemStatusParseError.unavailable
                }
            } else if line.hasPrefix("    Under ") || (!trimmed.isEmpty && !line.hasPrefix("        ")) {
                currentRecord = nil
            }
        }
        guard container != nil, foundItemsSection else { throw SystemStatusParseError.unavailable }
        return SystemActivitySnapshot(
            pendingUploadCount: records.values.filter(\.pendingUpload).count,
            downloadingCount: records.values.filter(\.downloading).count,
            itemCount: records.count
        )
    }
}
