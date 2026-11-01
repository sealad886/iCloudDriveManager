import AppKit
import DriveCore
import SwiftUI

@main
struct ICloudDriveManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = DriveViewModel(
        restoreConnection: ProcessInfo.processInfo.environment["ICLOUD_DRIVE_MANAGER_TESTING"] != "1"
            && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    )

    var body: some Scene {
        WindowGroup("iCloud Drive Manager", id: "main") {
            ContentView()
                .environmentObject(model)
                .tint(BrandTheme.accent)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear { appDelegate.onTerminate = { model.shutdown() } }
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose iCloud Drive Folder…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Refresh Metadata") { model.refresh() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(model.rootURL == nil)
                Divider()
                Button(model.isQueuePaused ? "Resume Download Requests" : "Pause Download Requests") {
                    model.setQueuePaused(!model.isQueuePaused)
                }
                .disabled(model.rootURL == nil)
            }
            CommandGroup(replacing: .help) {
                Button("How iCloud Drive Manager Works") { showHelp() }
            }
        }

        Settings {
            SettingsView().environmentObject(model)
        }

        MenuBarExtra {
            MenuBarView().environmentObject(model)
        } label: {
            HStack(spacing: 4) {
                BrandTheme.markImage
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(model.isDryRun ? "DRY" : "LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(model.isDryRun ? Color.blue : Color.orange)
            }
            .accessibilityLabel(
                model.isDryRun ? "iCloud Drive Manager. Dry run active." : "iCloud Drive Manager. Live actions active.")
        }
    }

    private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Your iCloud Drive, at a glance"
        alert.informativeText =
            "Choose a folder to see the real iCloud metadata macOS reports for its indexed files. Missing or empty results do not prove everything is synchronized.\n\nEvery launch starts in dry run. Download actions create plans only. Settings can enable live actions for this session, with a Yes/No confirmation and an Ask each time preference.\n\nYou can cancel waiting requests in this app. macOS owns transfers already submitted. The app never deletes your files or asks for your Apple Account password."
        alert.addButton(withTitle: "Got it")
        alert.runModal()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) { onTerminate?() }
}

private struct MenuBarView: View {
    @EnvironmentObject var model: DriveViewModel
    @Environment(\.openWindow) var openWindow

    var body: some View {
        Text(model.isDryRun ? "Dry run active" : "Live actions active")
        Text(model.rootURL == nil ? "No folder connected" : "Monitoring selected folder")
        if model.rootURL != nil {
            Text(
                "\(model.items.filter { $0.state.isActive }.count) active · \(model.items.filter { $0.state.needsAttention }.count) issues"
            )
        }
        Divider()
        Button("Open Manager") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Choose Folder…") { model.chooseFolder() }
        Button("Refresh") { model.refresh() }.disabled(model.rootURL == nil)
        Button(model.isQueuePaused ? "Resume Requests" : "Pause Requests") {
            model.setQueuePaused(!model.isQueuePaused)
        }
        .disabled(model.rootURL == nil)
        SettingsLink { Text("Action Settings…") }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
