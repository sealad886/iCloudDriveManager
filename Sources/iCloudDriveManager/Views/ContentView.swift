import DriveCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DriveViewModel
    @State private var section: DriveSection? = .all
    @State private var search = ""
    @State private var selectedIDs = Set<String>()
    @State private var showingInspector = false
    @State private var showingHelp = false

    private var connected: Bool { model.rootURL != nil }
    private var selectedItems: [DriveItem] {
        selectedIDs.isEmpty ? [] : model.items.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationSplitView {
            DriveSidebar(section: $section)
                .navigationSplitViewColumnWidth(min: 185, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                ActionModeBanner(isDryRun: model.isDryRun)
                if let notice = model.notice, connected {
                    NoticeStrip(symbol: "info.circle", title: notice, tint: .secondary)
                }
                if connected {
                    if section == .queue {
                        DownloadRequestsView(search: search)
                    } else {
                        FileOverviewView(
                            section: section ?? .all,
                            search: search,
                            selectedIDs: $selectedIDs,
                            showingInspector: $showingInspector
                        )
                    }
                } else {
                    WelcomeView()
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(section == .queue ? "Download requests" : BrandTheme.productName)
            .searchable(text: $search, placement: .toolbar, prompt: "Search files and folders")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: model.chooseFolder) {
                        Label("Choose folder", systemImage: "folder.badge.plus")
                    }
                    .help("Choose an iCloud Drive folder to observe")
                    .keyboardShortcut("o", modifiers: [.command])
                    Button(action: model.refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(!connected)
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Refresh reported file metadata")
                    Button {
                        showingInspector.toggle()
                    } label: {
                        Label("File details", systemImage: "sidebar.right")
                    }
                    .disabled(!connected || section == .queue)
                    .help("Show selected file details")
                    Button {
                        showingHelp.toggle()
                    } label: {
                        Label("About sync information", systemImage: "questionmark.circle")
                    }
                    .help("Learn what macOS reports")
                }
            }
            .inspector(isPresented: $showingInspector) {
                FileInspectorView(items: selectedItems)
                    .inspectorColumnWidth(min: 250, ideal: 270, max: 330)
            }
            .popover(isPresented: $showingHelp) {
                SyncHelpView()
            }
        }
        .tint(BrandTheme.accent)
        .frame(minWidth: 980, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity, alignment: .top)
        .alert(
            "Unable to complete action",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert(
            "The initial discovery scan is taking longer than expected",
            isPresented: $model.isShowingLongDiscoveryNotice
        ) {
            Button("Continue", action: model.continueDiscovery)
            Button("Cancel", role: .cancel, action: model.cancelDiscovery)
        } message: {
            Text(
                "Continue the scan, or cancel and choose a lower folder in the file tree. Discovery keeps running while this notice is open. Cancel retains results already found and does not stop iCloud transfers."
            )
        }
        .onChange(of: model.rootURL) { _, _ in
            selectedIDs.removeAll()
            section = .all
            showingInspector = false
        }
        .onChange(of: model.lastUpdated) { _, _ in
            guard !selectedIDs.isEmpty else { return }
            selectedIDs.formIntersection(model.items.lazy.map(\.id))
        }
    }
}

private struct SyncHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("A clearer view of iCloud Drive", systemImage: "info.circle")
                .font(.headline)
            Text(
                "This app observes the file metadata macOS makes available in your selected folder. Indexing, provider support, permissions, and network availability can affect which files and states appear."
            )
            Text(
                "Download requests are this app’s list of requests to macOS. Apple controls transfer scheduling, upload order, and the system-wide sync queue. Pausing requests affects only requests this app has not submitted yet."
            )
            Text(
                "Dry run uses your real folder metadata and records planned actions without requesting downloads. Enable live actions in Settings when you want to send requests to macOS."
            )
            Text(
                "An empty list does not prove that your drive is fully synced. Check Finder for additional information, conflicts, and account or storage issues."
            )
            .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .padding(22)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}
