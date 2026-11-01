import AppKit
import DriveCore
import SwiftUI

enum RowHoverContent {
    case file(DriveItem)
    case request(DownloadQueueItem, isDryRun: Bool)
    case navigation(title: String, purpose: String, count: String)
    case systemBacklog(SystemBacklogSnapshot)
    case publishedTransfer(PublishedTransferSnapshot)
    case diagnostic(title: String, count: Int?, logicalBytes: Int64?)
}

/// A passive detail card built only from the row's existing in-memory snapshot.
struct RowHoverCard: View {
    let content: RowHoverContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch content {
            case .file(let item):
                heading(item.name, symbol: DriveFormatting.fileSymbol(item))
                Text(item.relativePath).font(.system(size: 11)).foregroundStyle(.secondary)
                Divider()
                field(
                    "Type",
                    item.isDirectory
                        ? "Folder"
                        : item.url.pathExtension.isEmpty ? "File" : "\(item.url.pathExtension.uppercased()) file")
                field("Reported state", item.state.title)
                if item.state == .unknown {
                    note("macOS has not reported a per-file sync state for this item.")
                } else if item.state == .error {
                    note("This is a local metadata warning; it does not by itself confirm a failed transfer.")
                }
                field("Logical size", item.byteCount.map { DriveFormatting.bytes($0) } ?? "Not reported")
                if let modified = item.modifiedAt {
                    field("Modified", modified.formatted(date: .abbreviated, time: .shortened))
                }
                if let progress = item.progress {
                    field("Reported progress", progress.formatted(.percent.precision(.fractionLength(0))))
                }
                if let issue = item.issue {
                    message("macOS file metadata message", issue)
                }
            case .request(let item, let isDryRun):
                heading(item.name, symbol: "arrow.down.to.line")
                Text(item.url.path).font(.system(size: 11)).foregroundStyle(.secondary)
                Divider()
                field("Request state", requestTitle(item.status))
                note(requestMeaning(item.status))
                field("Current mode", isDryRun ? "Dry run active" : "Live actions active")
                if let error = item.error { message("Request message", error) }
            case .navigation(let title, let purpose, let count):
                heading(title, symbol: "sidebar.left")
                note(purpose)
                Divider()
                field("Reported count", count)
            case .systemBacklog(let snapshot):
                heading("System download backlog", symbol: "icloud.and.arrow.down")
                field("Pending items", snapshot.pendingItemCount.formatted())
                field("Requested logical size", DriveFormatting.bytes(snapshot.logicalBytes))
                note(snapshot.scopeDescription)
                note(
                    "Logical size describes requested items, not network bytes remaining. This source can overlap with published batches and diagnostic records."
                )
                field("Observed", snapshot.observedAt.formatted(date: .abbreviated, time: .shortened))
            case .publishedTransfer(let snapshot):
                heading(snapshot.description, symbol: "arrow.triangle.2.circlepath")
                if let description = snapshot.additionalDescription { note(description) }
                field("Reported direction", snapshot.reportedDirection)
                if let bytes = snapshot.validByteCounts {
                    field("Batch completed", DriveFormatting.bytes(bytes.completed))
                    field("Batch total", DriveFormatting.bytes(bytes.total))
                } else {
                    field("Byte progress", "Not published")
                }
                field("Published cancellation", snapshot.isCancellable ? "Advertised; not verified" : "Unavailable")
                field("Published pause", snapshot.isPausable ? "Advertised; not verified" : "Unavailable")
                note(
                    "macOS publishes this batch. It is not an individual queued-file listing, and cancellation of Finder queued downloads is not yet verified."
                )
                field("Observed", snapshot.observedAt.formatted(date: .abbreviated, time: .shortened))
            case .diagnostic(let title, let count, let bytes):
                heading(title, symbol: "info.circle")
                field("Diagnostic records", count.map { $0.formatted() } ?? "Unavailable")
                field("Logical size", bytes.map { DriveFormatting.bytes($0) } ?? "Unavailable")
                note(
                    "Source: brctl status, across the iCloud account. These records are not the full Finder download queue. Logical size is not remaining network traffic."
                )
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.primary)
        .padding(16)
        .frame(width: 350, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)) }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private func heading(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(BrandTheme.textAccent)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func field(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func message(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: "info.circle").font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.orange)
    }

    private func requestTitle(_ status: QueueStatus) -> String {
        switch status {
        case .planned: return "Dry-run plan"
        case .waiting: return "Waiting to be requested"
        case .submitted: return "Submitted to macOS"
        case .completed: return "Available locally"
        case .failed: return "Request failed"
        case .cancelled: return "Request cancelled"
        }
    }

    private func requestMeaning(_ status: QueueStatus) -> String {
        switch status {
        case .planned:
            return
                "Would request a download. This plan has not been sent to macOS "
                + "and does not run automatically when the mode changes."
        case .waiting: return "Waiting in this app's request list. macOS has not received this request yet."
        case .submitted:
            return
                "macOS received the download request. Apple controls transfer timing; "
                + "submission does not confirm completion."
        case .completed: return "The file was reported as current on this Mac."
        case .failed:
            return
                "The request or its reported status needs attention. "
                + "The message below provides the available details."
        case .cancelled:
            return
                "This pending request or plan was cancelled locally. "
                + "This does not stop a transfer already submitted to macOS."
        }
    }
}

/// AppKit supplies a non-activating panel; SwiftUI retains ownership of row data and actions.
@MainActor
final class RowHoverController: ObservableObject {
    private var rowID: String?
    private weak var anchor: NSView?
    private var currentContent: RowHoverContent?
    private var panel: PassiveHoverPanel?
    private var showTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var eventMonitor: Any?

    fileprivate func enter(id: String, anchor: NSView, content: RowHoverContent) {
        hideTask?.cancel()
        if rowID == id {
            update(id: id, content: content)
            return
        }
        dismiss()
        rowID = id
        self.anchor = anchor
        currentContent = content
        showTask = Task { @MainActor [weak self, weak anchor] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self, let anchor, self.rowID == id,
                let content = self.currentContent
            else { return }
            self.show(content, at: anchor)
        }
    }

    fileprivate func leave(id: String) {
        guard rowID == id else { return }
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    fileprivate func update(id: String, content: RowHoverContent) {
        guard rowID == id else { return }
        currentContent = content
        if let panel, let host = panel.contentView as? NSHostingView<RowHoverCard> {
            host.rootView = RowHoverCard(content: content)
            if let anchor { position(panel, host: host, at: anchor) }
        }
    }

    fileprivate func remove(_ view: NSView) {
        if anchor === view { dismiss() }
    }

    func dismiss() {
        showTask?.cancel()
        hideTask?.cancel()
        showTask = nil
        hideTask = nil
        rowID = nil
        anchor = nil
        currentContent = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        if let panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        panel = nil
    }

    private func show(_ content: RowHoverContent, at anchor: NSView) {
        guard let window = anchor.window, window.isKeyWindow, NSApp.isActive else { return }
        let host = NSHostingView(rootView: RowHoverCard(content: content))
        let size = host.fittingSize
        let panel = PassiveHoverPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.ignoresMouseEvents = true
        panel.appearance = window.effectiveAppearance
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.contentView = host
        position(panel, host: host, at: anchor)
        self.panel = panel
        window.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .scrollWheel, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            if event.type != .keyDown || event.keyCode == 53 { self?.dismiss() }
            return event
        }
    }

    private func position(_ panel: NSPanel, host: NSHostingView<RowHoverCard>, at anchor: NSView) {
        guard let window = anchor.window else { return }
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        panel.setContentSize(size)
        let rect = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let screen = window.screen?.visibleFrame ?? rect
        let x = min(max(rect.minX, screen.minX + 8), screen.maxX - size.width - 8)
        let below = rect.minY - size.height - 8
        let y = below >= screen.minY ? below : min(rect.maxY + 8, screen.maxY - size.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: max(screen.minY + 8, y)))
    }
}

private final class PassiveHoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct RowHoverAnchor: NSViewRepresentable {
    let controller: RowHoverController
    let id: String
    let content: RowHoverContent

    func makeNSView(context: Context) -> HoverAnchorView { HoverAnchorView() }

    func updateNSView(_ view: HoverAnchorView, context: Context) {
        if view.rowID != id { view.controller?.remove(view) }
        view.controller = controller
        view.rowID = id
        view.cardContent = content
        controller.update(id: id, content: content)
    }

    static func dismantleNSView(_ view: HoverAnchorView, coordinator: ()) {
        view.controller?.remove(view)
    }
}

private final class HoverAnchorView: NSView {
    weak var controller: RowHoverController?
    var rowID = ""
    var cardContent: RowHoverContent?
    private var hoverArea: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        guard let cardContent else { return }
        controller?.enter(id: rowID, anchor: self, content: cardContent)
    }

    override func mouseExited(with event: NSEvent) { controller?.leave(id: rowID) }
}

extension View {
    func rowHoverCard(_ content: RowHoverContent, id: String, controller: RowHoverController) -> some View {
        background {
            RowHoverAnchor(controller: controller, id: id, content: content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
