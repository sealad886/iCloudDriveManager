import DriveCore
import SwiftUI

struct FileInspectorView: View {
    @EnvironmentObject private var model: DriveViewModel
    let items: [DriveItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("File details")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                if let item = items.first, items.count == 1 {
                    singleFile(item)
                } else if items.count > 1 {
                    multipleFiles
                } else {
                    VStack(spacing: 13) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("Select a file")
                            .font(.system(size: 14, weight: .medium))
                        Text("Inspect its reported sync state and request a local copy.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(20)
        }
    }

    private func singleFile(_ item: DriveItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: DriveFormatting.fileSymbol(item))
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(BrandTheme.accent)
                    .accessibilityHidden(true)
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                SyncStateLabel(item: item)
            }

            Text(explanation(for: item.state))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let issue = item.issue {
                VStack(alignment: .leading, spacing: 6) {
                    Label("macOS file metadata message", systemImage: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(issue)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }

            Divider()
            VStack(alignment: .leading, spacing: 15) {
                detail("Location", value: item.relativePath)
                detail("File size", value: DriveFormatting.bytes(item.byteCount))
                if let modified = item.modifiedAt {
                    detail("Modified", value: modified.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    model.enqueue([item])
                } label: {
                    Label(model.isDryRun ? "Plan download" : "Request download", systemImage: "arrow.down.to.line")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!item.state.canRequestDownload || item.isDirectory)

                Button {
                    model.reveal(item)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)

            Text("macOS decides when transfers run. This app does not alter file contents or resolve conflicts.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var multipleFiles: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(BrandTheme.accent)
            Text("\(items.count) files selected")
                .font(.system(size: 17, weight: .semibold))
            let downloads = items.filter { $0.state.canRequestDownload && !$0.isDirectory }
            Text("\(downloads.count) selected files can be requested for download.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button {
                model.enqueue(downloads)
            } label: {
                Label(
                    model.isDryRun ? "Plan selected downloads" : "Download selected", systemImage: "arrow.down.to.line")
            }
            .buttonStyle(.borderedProminent)
            .disabled(downloads.isEmpty)
        }
    }

    private func detail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explanation(for state: SyncState) -> String {
        switch state {
        case .current:
            return
                "The local copy is the latest version known to this Mac. Upload state is reported separately by macOS."
        case .cloudOnly: return "This file is stored in iCloud. Request a download to make a local copy available."
        case .downloaded:
            return "A local copy exists, but macOS reports that a newer version may be available in iCloud."
        case .downloading:
            return "macOS reports that this file is downloading. Progress may update at irregular intervals."
        case .uploading: return "macOS reports that this file is uploading to iCloud. Apple manages its schedule."
        case .queued:
            return "macOS reports that a download has been requested. The transfer has not been reported as active."
        case .pendingUpload:
            return "macOS has not reported this file as fully uploaded. Check Finder for additional sync information."
        case .conflict:
            return
                "macOS reports an unresolved version conflict. Reveal the file in Finder or open it in its app to review versions."
        case .error:
            return "macOS returned a warning while reading this file’s status. "
                + "This message alone does not confirm a failed transfer. "
                + "Overall activity comes from brctl status using this Mac’s existing iCloud session. "
                + "This app does not sign in or ask for credentials."
        case .unknown: return "macOS has not provided enough metadata to determine this file’s sync state."
        }
    }
}
