import AppKit
import DriveCore
import SwiftUI
import XCTest

@testable import iCloudDriveManager

final class AppSmokeTests: XCTestCase {
    func testDisconnectedModelDoesNotAccessFiles() async {
        await MainActor.run {
            let model = DriveViewModel(restoreConnection: false)
            XCTAssertNil(model.rootURL)
            XCTAssertTrue(model.items.isEmpty)
            model.refresh()
            XCTAssertNil(model.lastUpdated)
        }
    }

    func testEachSessionDefaultsToDryRun() async {
        await MainActor.run {
            let model = DriveViewModel(restoreConnection: false)
            XCTAssertTrue(model.isDryRun)
            model.setDryRun(false)
            XCTAssertFalse(model.isDryRun)
            let nextSession = DriveViewModel(restoreConnection: false)
            XCTAssertTrue(nextSession.isDryRun)
            XCTAssertNil(nextSession.rootURL)
            XCTAssertTrue(nextSession.items.isEmpty)
        }
    }

    func testNativeRootViewRendersDisconnectedDryRunState() async {
        await MainActor.run {
            _ = NSApplication.shared
            let model = DriveViewModel(restoreConnection: false)
            let host = NSHostingView(rootView: ContentView().environmentObject(model))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780), styleMask: [.titled], backing: .buffered,
                defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            XCTAssertNotNil(host.window)
            XCTAssertGreaterThan(host.fittingSize.width, 0)
            XCTAssertGreaterThan(host.fittingSize.height, 0)
            window.close()
        }
    }
}
