import AppKit
import DriveCore
import SwiftUI

enum DriveSection: String, CaseIterable, Identifiable {
    case all, activity, cloud, attention, queue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All files"
        case .activity: return "Sync activity"
        case .cloud: return "In iCloud"
        case .attention: return "Needs attention"
        case .queue: return "Download requests"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .activity: return "arrow.triangle.2.circlepath"
        case .cloud: return "icloud"
        case .attention: return "exclamationmark.circle"
        case .queue: return "arrow.down.to.line"
        }
    }

    func includes(_ item: DriveItem) -> Bool {
        switch self {
        case .all: return true
        case .activity: return item.state.isActive || item.state == .queued || item.state == .pendingUpload
        case .cloud: return item.state == .cloudOnly
        case .attention: return item.state.needsAttention
        case .queue: return false
        }
    }
}

extension SyncState {
    var symbol: String {
        switch self {
        case .current: return "checkmark.circle.fill"
        case .cloudOnly: return "icloud"
        case .downloaded: return "arrow.clockwise.circle"
        case .downloading: return "arrow.down.circle.fill"
        case .uploading: return "arrow.up.circle.fill"
        case .queued: return "clock"
        case .pendingUpload: return "arrow.up.circle"
        case .conflict: return "exclamationmark.icloud"
        case .error: return "exclamationmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .current: return .teal
        case .cloudOnly: return .secondary
        case .downloading, .uploading: return .blue
        case .downloaded, .queued, .pendingUpload: return .orange
        case .conflict, .error: return .red
        case .unknown: return .secondary
        }
    }
}

enum DriveFormatting {
    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func fileSymbol(_ item: DriveItem) -> String {
        if item.isDirectory { return "folder.fill" }
        switch item.url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "heic", "tiff", "gif": return "photo"
        case "mov", "mp4", "m4v": return "film"
        case "mp3", "wav", "aiff", "m4a": return "waveform"
        case "zip", "gz", "tar": return "archivebox"
        case "numbers", "xlsx", "csv": return "tablecells"
        case "key", "pptx": return "rectangle.on.rectangle"
        default: return "doc.text"
        }
    }
}

struct SyncStateLabel: View {
    let item: DriveItem

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.state.symbol)
                .foregroundStyle(item.state.tint)
                .frame(width: 15)
            if item.state.isActive, let progress = item.progress {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(item.state.title)
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    ProgressView(value: progress)
                        .tint(item.state.tint)
                        .frame(maxWidth: 120)
                        .accessibilityLabel("Transfer progress")
                }
            } else {
                Text(item.state.title)
            }
        }
        .font(.system(size: 12))
        .accessibilityElement(children: .combine)
    }
}

struct NoticeStrip: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(tint.opacity(0.08))
            .accessibilityElement(children: .combine)
    }
}
