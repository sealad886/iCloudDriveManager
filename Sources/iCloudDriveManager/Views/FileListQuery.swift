import DriveCore
import Foundation

/// View-owned file queries run on a background worker, never during SwiftUI rendering.
enum FileListQuery {
    nonisolated static func execute(
        items: [DriveItem], sectionRawValue: String, search: String, ascending: Bool
    ) throws -> [DriveItem] {
        let section = DriveSection(rawValue: sectionRawValue) ?? .all
        var result: [DriveItem] = []
        result.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            if index & 255 == 0 { try Task.checkCancellation() }
            guard section.includes(item) else { continue }
            if search.isEmpty || item.name.localizedStandardContains(search)
                || item.relativePath.localizedStandardContains(search)
            {
                result.append(item)
            }
        }

        var comparisons = 0
        try result.sort { lhs, rhs in
            comparisons &+= 1
            if comparisons & 1023 == 0 { try Task.checkCancellation() }
            let order = lhs.name.localizedStandardCompare(rhs.name)
            if order == .orderedSame {
                return ascending ? lhs.relativePath < rhs.relativePath : lhs.relativePath > rhs.relativePath
            }
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
        try Task.checkCancellation()
        return result
    }
}
