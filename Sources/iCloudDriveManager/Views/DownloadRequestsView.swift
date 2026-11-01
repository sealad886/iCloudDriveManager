import DriveCore
import SwiftUI

struct DownloadRequestsView: View {
    @EnvironmentObject private var model: DriveViewModel
    @StateObject private var rowHover = RowHoverController()
    let search: String

    private var requests: [DownloadQueueItem] {
        model.queueItems.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
    }

    private var waitingCount: Int { model.queueItems.filter { $0.status == .waiting }.count }
    private var submittedCount: Int { model.queueItems.filter { $0.status == .submitted }.count }
    private var plannedCount: Int { model.queueItems.filter { $0.status == .planned }.count }
    private var hasFinished: Bool {
        model.queueItems.contains { $0.status == .completed || $0.status == .cancelled }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("App requests")
                            .font(.system(size: 26, weight: .semibold))
                            .tracking(-0.5)
                        Text(
                            model.isDryRun
                                ? "Download plans created in this app."
                                : "Download requests created in this app."
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        model.setQueuePaused(!model.isQueuePaused)
                    } label: {
                        Label(
                            model.isQueuePaused ? "Resume requests" : "Pause requests",
                            systemImage: model.isQueuePaused ? "play.fill" : "pause.fill")
                    }
                    .controlSize(.large)
                    .disabled(!model.queueItems.contains { $0.status == .waiting || $0.status == .submitted })
                    .help("Affects only requests this app has not submitted to macOS")
                }

                HStack(spacing: 19) {
                    if plannedCount > 0 || model.isDryRun {
                        Label("\(plannedCount) planned", systemImage: "checklist")
                    }
                    Label("\(waitingCount) waiting", systemImage: "clock")
                    if submittedCount > 0 || !model.isDryRun {
                        Label("\(submittedCount) submitted to macOS", systemImage: "arrow.down.circle")
                    }
                    Spacer()
                    if model.isQueuePaused {
                        Label("Requests paused", systemImage: "pause.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(14)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))

                Text(
                    model.isDryRun
                        ? "Dry-run plans use your real files. Planned downloads are not submitted to macOS."
                        : "This is your request list. macOS controls the actual transfer queue and order. Pausing does not stop submitted downloads."
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            if requests.isEmpty {
                queueEmptyState
                    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .layoutPriority(-1)
            } else {
                List {
                    ForEach(requests) { item in
                        DownloadRequestRow(item: item, rowHover: rowHover)
                            .listRowSeparator(.visible)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 0, maxHeight: .infinity)
                .layoutPriority(-1)
                .accessibilityIdentifier("download-request-list")
            }

            Divider()
            HStack {
                Text("Requests are kept for this session only.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear finished", action: model.clearFinishedQueue)
                    .disabled(!hasFinished)
                    .controlSize(.small)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: search) { _, _ in rowHover.dismiss() }
        .onChange(of: model.rootURL) { _, _ in rowHover.dismiss() }
        .onChange(of: model.isDryRun) { _, _ in rowHover.dismiss() }
        .onDisappear { rowHover.dismiss() }
    }

    private var queueEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: search.isEmpty ? "arrow.down.to.line.circle" : "magnifyingglass")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(BrandTheme.accent)
            Text(search.isEmpty ? "Ready when you are" : "No matching requests")
                .font(.system(size: 18, weight: .medium))
            Text(
                search.isEmpty
                    ? model.isDryRun
                        ? "Select cloud files in your library and choose Plan selected downloads. Your plans will appear here."
                        : "Select cloud files in your library and choose Download selected. Your requests will appear here."
                    : "Try searching for another file name."
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
        }
        .padding(35)
    }
}

private struct DownloadRequestRow: View {
    @EnvironmentObject private var model: DriveViewModel
    let item: DownloadQueueItem
    let rowHover: RowHoverController

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(tint)
                .frame(width: 27)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(item.error ?? statusTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(item.status == .failed ? Color.orange : Color.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 15)
            if item.status == .waiting || item.status == .planned {
                if item.status == .waiting {
                    Button {
                        model.moveQueueItemToFront(item.id)
                    } label: {
                        Label("Move first", systemImage: "arrow.up.to.line")
                    }
                    .help("Move ahead of other requests waiting in this app")
                }
                if item.status == .planned && !model.isDryRun {
                    Button {
                        model.retryQueueItem(item.id)
                    } label: {
                        Label("Request live download", systemImage: "arrow.down.to.line")
                    }
                    .help("Request this planned download from macOS")
                }
                Button {
                    model.cancelQueueItem(item.id)
                } label: {
                    Label(item.status == .planned ? "Remove plan" : "Cancel request", systemImage: "xmark")
                }
            } else if item.status == .failed {
                Button {
                    model.retryQueueItem(item.id)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            } else {
                Text(statusTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.08), in: Capsule())
            }
        }
        .controlSize(.small)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
        .rowHoverCard(.request(item, isDryRun: model.isDryRun), id: item.id.uuidString, controller: rowHover)
    }

    private var statusTitle: String {
        switch item.status {
        case .planned: return "Dry-run plan · Would request download"
        case .waiting: return "Waiting to be requested"
        case .submitted: return "Submitted to macOS"
        case .completed: return "Available locally"
        case .failed: return "Request failed"
        case .cancelled: return "Request cancelled"
        }
    }

    private var symbol: String {
        switch item.status {
        case .planned: return "checklist"
        case .waiting: return "clock"
        case .submitted: return "arrow.down.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    private var tint: Color {
        switch item.status {
        case .planned: return .blue
        case .waiting, .cancelled: return .secondary
        case .submitted: return .blue
        case .completed: return .teal
        case .failed: return .orange
        }
    }
}
