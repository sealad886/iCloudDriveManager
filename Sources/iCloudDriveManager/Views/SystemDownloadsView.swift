import DriveCore
import SwiftUI

struct SystemDownloadsView: View {
    @EnvironmentObject private var model: DriveViewModel
    @StateObject private var rowHover = RowHoverController()
    @State private var showsDiagnostics = false
    let search: String

    private var matchingTransfers: [PublishedTransferSnapshot] {
        model.publishedTransfers.filter {
            search.isEmpty || $0.description.localizedStandardContains(search)
                || ($0.additionalDescription?.localizedStandardContains(search) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                cancellationStatus
                backlog
                publishedBatches
                Text(
                    "Backlog totals, published batches, and diagnostic records can overlap. "
                        + "They are shown separately and are not added together."
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                DisclosureGroup("Additional brctl diagnostics", isExpanded: $showsDiagnostics) {
                    diagnostics.padding(.top, 12)
                }
                .font(.system(size: 12, weight: .medium))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { model.refreshSystemTransfers() }
        .onChange(of: model.rootURL) { _, _ in rowHover.dismiss() }
        .onChange(of: search) { _, _ in rowHover.dismiss() }
        .onDisappear { rowHover.dismiss() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("System downloads")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.5)
                Spacer()
                if model.isReadingBacklog { ProgressView().controlSize(.small) }
            }
            Text("Download backlog and transfer batches reported by macOS.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var cancellationStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Finder queue cancellation is not available in this build", systemImage: "info.circle")
                .font(.system(size: 12, weight: .semibold))
            Text("App request controls manage requests created here; they do not cancel Finder’s existing queue.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private var backlog: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("System download backlog", systemImage: "arrow.down.to.line")
                .font(.system(size: 14, weight: .semibold))
            if let backlog = model.systemBacklog {
                HStack(spacing: 30) {
                    summary("Pending items", value: backlog.pendingItemCount.formatted())
                    Divider().frame(height: 38)
                    summary("Requested logical size", value: DriveFormatting.bytes(backlog.logicalBytes))
                    Spacer(minLength: 0)
                }
                Text(backlog.scopeDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Observed \(backlog.observedAt, style: .time)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Text(model.isReadingBacklog ? "Reading macOS download backlog…" : "Backlog unavailable")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text("Logical size describes the requested items. It is not network bytes remaining or transfer speed.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let error = model.systemBacklogError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                if model.systemBacklog != nil {
                    Text("Showing the last successful backlog observation.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandTheme.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(BrandTheme.accent.opacity(0.15)) }
        .background {
            if let snapshot = model.systemBacklog {
                Color.clear.rowHoverCard(.systemBacklog(snapshot), id: "system-backlog", controller: rowHover)
            }
        }
    }

    private var publishedBatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Published transfer batches")
                .font(.system(size: 14, weight: .semibold))
            Text(
                "Descriptions are shown as macOS provides them. Each batch can cover an operation, "
                    + "rather than list individual queued files."
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            if let error = model.systemProgressError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.publishedTransfers.isEmpty {
                    Text("Showing the last successful published-transfer observations.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if matchingTransfers.isEmpty {
                Text(
                    search.isEmpty
                        ? "No published transfer observations are available."
                        : "No published batches match this search."
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(matchingTransfers) { transfer in
                        PublishedTransferRow(transfer: transfer)
                            .rowHoverCard(.publishedTransfer(transfer), id: transfer.id, controller: rowHover)
                    }
                }
            }
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                "brctl status lists diagnostic records, not all downloads queued by Finder. "
                    + "The record count below is not the Finder queued-item count."
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            if let snapshot = model.systemActivity {
                diagnosticRow("Downloading records", count: snapshot.downloadingCount, bytes: snapshot.downloadingBytes)
                diagnosticRow(
                    "Waiting-to-upload records", count: snapshot.pendingUploadCount, bytes: snapshot.pendingUploadBytes)
                Text("Observed \(snapshot.observedAt, style: .time) · Whole account diagnostics")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                Text(model.isReadingSystemActivity ? "Reading diagnostic records…" : "Diagnostic records unavailable")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            if let error = model.systemActivityError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
            Text("Diagnostic sizes are logical file sizes, not remaining network traffic.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func summary(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 27, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(BrandTheme.textAccent)
        }
        .accessibilityElement(children: .combine)
    }

    private func diagnosticRow(_ title: String, count: Int?, bytes: Int64?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(count.map { $0.formatted() } ?? "Unavailable").monospacedDigit()
            if let bytes {
                Text("\(DriveFormatting.bytes(bytes)) logical")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .rowHoverCard(
            .diagnostic(title: title, count: count, logicalBytes: bytes), id: "diagnostic-\(title)",
            controller: rowHover)
    }
}

private struct PublishedTransferRow: View {
    let transfer: PublishedTransferSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(BrandTheme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(transfer.description)
                        .font(.system(size: 13, weight: .semibold))
                    if let description = transfer.additionalDescription {
                        Text(description).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if transfer.operationKind != .unknown {
                    Text(transfer.reportedDirection)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if let bytes = transfer.validByteCounts {
                if bytes.total > 0 {
                    ProgressView(value: Double(bytes.completed), total: Double(bytes.total))
                        .tint(BrandTheme.accent)
                        .accessibilityLabel("Published batch byte progress")
                }
                Text(
                    "\(DriveFormatting.bytes(bytes.completed)) completed of \(DriveFormatting.bytes(bytes.total)) batch total"
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            } else {
                Text("Byte progress is not published for this batch.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label(
                    transfer.isCancellable
                        ? "Cancellation advertised; not verified" : "Published cancellation unavailable",
                    systemImage: "info.circle")
                Text(transfer.isPausable ? "Pause advertised; not verified" : "Published pause unavailable")
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.05)) }
        .accessibilityElement(children: .combine)
    }
}

extension PublishedTransferSnapshot {
    var validByteCounts: (completed: Int64, total: Int64)? {
        guard let completed = completedBytes, let total = totalBytes,
            completed >= 0, total >= 0, completed <= total
        else { return nil }
        return (completed, total)
    }

    var reportedDirection: String {
        switch operationKind {
        case .downloading: return "Downloading"
        case .uploading: return "Uploading"
        case .unknown: return "Direction not reported"
        }
    }
}
