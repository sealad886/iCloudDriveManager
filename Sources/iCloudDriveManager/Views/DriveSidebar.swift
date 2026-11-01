import DriveCore
import SwiftUI

struct DriveSidebar: View {
    @EnvironmentObject private var model: DriveViewModel
    @Binding var section: DriveSection?
    @StateObject private var rowHover = RowHoverController()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 9) {
                    BrandMark(size: 36)
                    Text("iCloud Drive\nManager")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(BrandTheme.textAccent)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(BrandTheme.productName)
                }
                Text(BrandTheme.tagline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    ActionModeBadge(isDryRun: model.isDryRun)
                    Text(model.isDryRun ? "Live actions inactive" : "Dry run inactive")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 24)
            .fixedSize(horizontal: false, vertical: true)

            List(selection: $section) {
                Section("iCloud activity") {
                    sidebarRow(.systemDownloads)
                }
                Section("Selected folder") {
                    ForEach([DriveSection.all, .activity, .cloud, .attention]) { destination in
                        sidebarRow(destination)
                    }
                }
                Section("Manage") {
                    sidebarRow(.queue)
                }
            }
            .listStyle(.sidebar)
            .frame(minHeight: 0, maxHeight: .infinity)
            .layoutPriority(-1)

            VStack(alignment: .leading, spacing: 11) {
                Divider()
                HStack(spacing: 9) {
                    Circle()
                        .fill(model.rootURL == nil ? Color.secondary : BrandTheme.accent)
                        .frame(width: 6, height: 6)
                    Text(
                        model.rootURL == nil
                            ? "No folder selected"
                            : model.hasStartedFileObservation ? "Observing folder" : "Folder connected"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                if model.rootURL != nil {
                    HStack(alignment: .top) {
                        Label(model.scopeName, systemImage: "folder")
                            .font(.system(size: 12))
                            .lineLimit(2)
                            .help(model.rootURL?.path ?? "Selected folder")
                        Spacer(minLength: 0)
                        Menu {
                            Button("Choose another folder…", action: model.chooseFolder)
                            Button("Disconnect folder", action: model.disconnect)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("Folder options")
                        .accessibilityLabel("Folder options")
                    }
                } else {
                    Button("Choose folder…", action: model.chooseFolder)
                        .font(.system(size: 12))
                }
                Text("Private to this Mac")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 17)
            .padding(.bottom, 18)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
        .onChange(of: section) { _, _ in rowHover.dismiss() }
        .onChange(of: model.rootURL) { _, _ in rowHover.dismiss() }
        .onDisappear { rowHover.dismiss() }
    }

    private func sidebarRow(_ destination: DriveSection) -> some View {
        HStack {
            Label(destination.title, systemImage: destination.symbol)
            Spacer(minLength: 4)
            if model.rootURL != nil {
                Text(countLabel(for: destination))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .tag(destination)
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .rowHoverCard(
            .navigation(
                title: destination.title, purpose: purpose(for: destination),
                count: model.rootURL == nil ? "No folder connected" : countLabel(for: destination)
            ), id: destination.id, controller: rowHover)
    }

    private func purpose(for destination: DriveSection) -> String {
        switch destination {
        case .systemDownloads:
            return "macOS download backlog and published transfer batches. "
                + "Diagnostic status records are separate from the full Finder queue."
        case .all:
            return "All files and folders discovered in your selected folder, "
                + "including items with unknown status."
        case .activity: return "Items with transfer activity reported by macOS in your selected folder."
        case .cloud: return "Items macOS reports as stored in iCloud without a local copy."
        case .attention: return "Items with reported version conflicts or local macOS metadata warnings."
        case .queue:
            return "Download plans and requests created in this app. "
                + "These controls do not cancel downloads already queued by Finder."
        }
    }

    private func countLabel(for destination: DriveSection) -> String {
        if destination == .systemDownloads {
            return model.systemBacklog?.pendingItemCount.formatted() ?? "Unavailable"
        }
        if destination != .queue && !model.hasStartedFileObservation { return "Not scanned" }
        let value = count(for: destination)
        if destination != .all && destination != .queue && value == 0
            && model.unknownItemCount > 0
        {
            return "—"
        }
        return value.formatted()
    }

    private func count(for destination: DriveSection) -> Int {
        if destination == .queue {
            return model.queueItems.filter { $0.status == .planned || $0.status == .waiting || $0.status == .submitted }
                .count
        }
        switch destination {
        case .systemDownloads: return model.systemBacklog?.pendingItemCount ?? 0
        case .all: return model.items.count
        case .activity: return model.reportedActivityCount
        case .cloud: return model.cloudOnlyCount
        case .attention: return model.reportedIssueCount
        case .queue: return 0
        }
    }
}
