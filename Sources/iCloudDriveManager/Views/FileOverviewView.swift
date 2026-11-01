import DriveCore
import Foundation
import SwiftUI

struct FileOverviewView: View {
    @EnvironmentObject private var model: DriveViewModel
    let section: DriveSection
    let search: String
    @Binding var selectedIDs: Set<String>
    @Binding var showingInspector: Bool
    @State private var sortOrder = [KeyPathComparator(\DriveItem.name)]
    @State private var filteredItems: [DriveItem] = []
    @State private var isUpdatingList = true
    @State private var queryGeneration = UUID()
    @State private var queryRootURL: URL?
    @State private var queryTask: Task<Void, Never>?

    private var selectedItems: [DriveItem] {
        guard !selectedIDs.isEmpty else { return [] }
        return model.items.filter { selectedIDs.contains($0.id) }
    }
    private var downloadableItems: [DriveItem] {
        selectedItems.filter { $0.state.canRequestDownload && !$0.isDirectory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            overviewHeader
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(section.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(filteredItems.count, format: .number)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Spacer()
                if isUpdatingList || model.isGathering {
                    ProgressView().controlSize(.small)
                    Text(isUpdatingList ? "Updating file list…" : "Gathering metadata…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 23)
            .padding(.bottom, 12)
            .fixedSize(horizontal: false, vertical: true)

            fileTable
                .layoutPriority(-1)

            HStack(spacing: 12) {
                if selectedIDs.isEmpty {
                    Label(
                        model.isDryRun
                            ? "Select files to plan downloads or view details"
                            : "Select files to request a download or view details", systemImage: "cursorarrow"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                } else {
                    Text("\(selectedIDs.count) selected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button {
                        model.enqueue(downloadableItems)
                    } label: {
                        Label(
                            model.isDryRun ? "Plan selected downloads" : "Download selected",
                            systemImage: "arrow.down.to.line")
                    }
                    .disabled(downloadableItems.isEmpty)
                    .keyboardShortcut("d", modifiers: [.command])
                    Button("Show details") { showingInspector = true }
                }
                Spacer(minLength: 0)
                if let updated = model.lastUpdated {
                    Text("Updated \(updated, style: .time)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .help("Time of the latest metadata snapshot")
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(model.$items) { items in
            updateQuery(items: items, clearResults: queryRootURL != model.rootURL?.standardizedFileURL)
        }
        .onChange(of: section) { _, _ in
            selectedIDs.removeAll()
            updateQuery(items: model.items, clearResults: true)
        }
        .onChange(of: search) { _, _ in
            selectedIDs.removeAll()
            updateQuery(items: model.items, clearResults: true)
        }
        .onChange(of: sortOrder.first?.order) { _, _ in
            updateQuery(items: model.items, clearResults: true)
        }
        .onChange(of: model.rootURL) { _, _ in
            updateQuery(items: model.items, clearResults: true)
        }
        .onDisappear {
            queryGeneration = UUID()
            queryTask?.cancel()
            queryTask = nil
        }
    }

    @MainActor
    private func updateQuery(items: [DriveItem], clearResults: Bool) {
        queryTask?.cancel()
        let generation = UUID()
        queryGeneration = generation
        let root = model.rootURL?.standardizedFileURL
        queryRootURL = root
        let sectionRawValue = section.rawValue
        let querySearch = search
        let ascending = sortOrder.first?.order != .reverse
        if clearResults { filteredItems = [] }
        isUpdatingList = true

        queryTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            let worker = Task.detached(priority: .userInitiated) {
                try FileListQuery.execute(
                    items: items, sectionRawValue: sectionRawValue, search: querySearch, ascending: ascending)
            }
            let result = await withTaskCancellationHandler {
                try? await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, queryGeneration == generation,
                model.rootURL?.standardizedFileURL == root, let result
            else { return }
            filteredItems = result
            isUpdatingList = false
            queryTask = nil
        }
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sync overview")
                        .font(.system(size: 26, weight: .semibold))
                        .tracking(-0.5)
                    Text("Files discovered in your selected folder.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.rootURL?.path ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(model.rootURL?.path ?? "")
                }
                Spacer(minLength: 15)
                Label(
                    "Observing",
                    systemImage: "dot.radiowaves.left.and.right"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BrandTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BrandTheme.accent.opacity(0.09), in: Capsule())
            }
            SystemActivityView(
                snapshot: model.systemActivity,
                isReading: model.isReadingSystemActivity,
                error: model.systemActivityError
            )
            HStack(spacing: 0) {
                metric(
                    title: "Discovered items", value: model.items.count.formatted(), symbol: "doc.on.doc",
                    tint: .primary)
                Divider().frame(height: 39)
                metric(
                    title: "Folder activity reported",
                    value: reportedCount(model.reportedActivityCount),
                    symbol: "arrow.triangle.2.circlepath", tint: .blue)
                Divider().frame(height: 39)
                metric(
                    title: "Folder issues reported", value: reportedCount(model.reportedIssueCount),
                    symbol: "exclamationmark.circle", tint: .orange)
            }
            .padding(.vertical, 16)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.05))
            }
            Label("Selected folder only · Apple controls transfer scheduling", systemImage: "info.circle")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 1)
    }

    private func reportedCount(_ count: Int) -> String {
        if count == 0 && model.unknownItemCount > 0 { return "Unavailable" }
        return count.formatted()
    }

    private func metric(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 25, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 18)
        .accessibilityElement(children: .combine)
    }

    private var fileTable: some View {
        Table(filteredItems, selection: $selectedIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 10) {
                    Image(systemName: DriveFormatting.fileSymbol(item))
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(BrandTheme.accent)
                        .frame(width: 25)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(item.relativePath)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 6)
                }
                .help(item.relativePath)
            }
            .width(min: 170, ideal: 300)

            TableColumn("Sync state") { item in
                SyncStateLabel(item: item)
            }
            .width(min: 140, ideal: 170)

            TableColumn("Size") { item in
                Text(DriveFormatting.bytes(item.byteCount))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .help("Reported logical file size; not local disk usage")
            }
            .width(80)

            TableColumn("Modified") { item in
                Group {
                    if let modified = item.modifiedAt {
                        Text(modified, format: .dateTime.month(.abbreviated).day())
                    } else {
                        Text("—")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .width(80)
        }
        .frame(minHeight: 0, maxHeight: .infinity)
        .accessibilityIdentifier("file-table")
        .contextMenu(forSelectionType: String.self) { ids in
            let selection = ids.isEmpty ? [] : model.items.filter { ids.contains($0.id) }
            let downloads = selection.filter { $0.state.canRequestDownload && !$0.isDirectory }
            Button(model.isDryRun ? "Plan selected downloads" : "Download selected") { model.enqueue(downloads) }
                .disabled(downloads.isEmpty)
            Button("Show details") { showingInspector = true }
                .disabled(selection.isEmpty)
            if selection.count == 1, let item = selection.first {
                Button("Reveal in Finder") { model.reveal(item) }
            }
        } primaryAction: { _ in
            showingInspector = true
        }
        .overlay {
            if filteredItems.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            if isUpdatingList {
                ProgressView().controlSize(.large)
            } else {
                Image(systemName: emptySymbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
            }
            Text(emptyTitle)
                .font(.system(size: 14, weight: .semibold))
            Text(emptyDescription)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
        }
        .padding(30)
    }

    private var emptySymbol: String {
        if !search.isEmpty { return "magnifyingglass" }
        if model.isGathering { return "arrow.triangle.2.circlepath" }
        return section == .attention ? "checkmark.circle" : "icloud"
    }

    private var emptyTitle: String {
        if isUpdatingList { return "Updating file list" }
        if !search.isEmpty { return "No matching files" }
        if model.isGathering { return "Reading file metadata" }
        if section == .attention || section == .activity, model.unknownItemCount > 0 {
            return "Per-file sync metadata unavailable"
        }
        if section == .attention { return "No reported issues" }
        if section == .activity { return "No reported sync activity" }
        if section == .cloud { return "No cloud-only files reported" }
        return "No iCloud files reported"
    }

    private var emptyDescription: String {
        if isUpdatingList { return "Sorting and filtering the files discovered in your selected folder." }
        if !search.isEmpty { return "Try another file name or folder path." }
        if model.isGathering { return "Reading file metadata directly from your selected folder." }
        return "This view depends on the metadata macOS provides. Finder may show additional items or sync information."
    }
}
