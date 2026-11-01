# Native service API

Folder services are DriveCore, linked into the SwiftUI app. System observations use an embedded read-only XPC service. There is no HTTP endpoint, network listener, JWT, or OpenAPI client. **Cancellation of downloads already queued by Finder/macOS is unresolved and unavailable.** App-owned request controls do not implement it.

## Authorization model

The principal is the local macOS user and the Apple Account already configured in macOS. The app receives folder access through `NSOpenPanel`, remembers it as a security-scoped bookmark, and holds scope only while observing that root. macOS owns iCloud account authentication. There is no app login, account endpoint, URLSession, CloudKit, or CKContainer integration; folder permission is not account sign-in.

Selected-folder read and request operations are confined to the chosen root. The separate status service supplies provider backlog numbers, brctl diagnostic aggregates, and published progress descriptions/capabilities. Localized published descriptions can contain private names; they remain local, memory-only, and unlogged. Download submission revalidates canonical containment, iCloud membership, file type, and conflicts. Dry-run is the session default and cannot invoke the provider's mutation operation.

## Metadata observation

```swift
@MainActor
final class MetadataMonitor {
    var onSnapshot: ((MetadataSnapshot) -> Void)?
    var onLongDiscovery: (() -> Void)?
    func start(root: URL) throws
    func refresh()
    func cancelDiscovery()
    func stop()
}
```

The model calls `start` only when a selected-folder browser opens; connecting a root starts system observations without triggering detailed file enumeration. `start` binds the monitor to one root. `refresh` asks the monitor to update its results; it is not a command to force iCloud synchronization. `stop` ends observation and prevents a previous scope from supplying new UI data.

A `MetadataSnapshot` carries items, the authorized root, observation time, gathering state, and an optional warning. Results reflect available filesystem/provider metadata and can be incomplete.

Direct background directory enumeration discovers paths independently of Spotlight and progressively reads metadata. Containment and symlink checks restrict the selected scope. Unknown/unreadable metadata remains visible and non-actionable; explicit non-cloud entries are excluded. A separate optional root-bounded iCloud query supplements existing records, including percentages. Stop/root changes invalidate old work. No document bodies are read.

`onLongDiscovery` notifies once when initial discovery remains active after 60 seconds; it does not pause or restart the scan. Continue dismisses the notice. `cancelDiscovery` invalidates only discovery work, keeps partial observations/root and the optional query, and publishes a partial-results warning until refresh/new scope. There is no hard processing timeout and no iCloud-transfer cancellation.

## Download submission

```swift
protocol DownloadRequesting: Sendable {
    func requestDownload(at url: URL, within root: URL) async throws
}
```

The system implementation calls [`FileManager.startDownloadingUbiquitousItem(at:)`](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:)) after authorization checks. Success means macOS accepted a request; it does not mean bytes have transferred or the current version is available locally. Errors propagate to the queue and UI.

Unit cases can observe whether the requester was called without performing an iCloud operation. Real-data acceptance separately uses an explicitly selected folder.

## Queue commands

The main-actor `DownloadQueue` owns session state, publishes changes, and exposes:

| Command | Contract |
|---|---|
| `enqueue(_:root:)` | Add eligible real items as plans in dry-run or authorized waiting entries in live mode |
| `setDryRun(_:)` | Block dispatch, convert waiting work to plans, and invalidate pending tasks; enabling live never auto-executes plans |
| `setPaused(_:)` | Stop/resume submission of waiting entries |
| `cancel(_:)` | Remove a plan or cancel a waiting entry before submission |
| `retry(_:)` | Requeue a failed entry for an explicit retry |
| `moveToFront(_:)` | Prioritize a waiting entry in this app's queue |
| `clearFinished()` | Remove completed and canceled history entries; preserve failed entries for an explicit retry |
| `reconcile(with:)` | Apply observed current/error outcomes to submitted entries |
| `reset()` | Invalidate the previous session and clear its queue state |

The queue constructor defaults to dry-run and its pump independently checks mode. At most two live submitted requests await metadata outcome. Session and attempt tokens reject obsolete callbacks. This cannot revoke a request already delivered to macOS.

When observed metadata disappears or never confirms a terminal state, the submitted entry remains unresolved and keeps its slot. The app does not invent a completion or a cancellation. Check Finder and the account/network state; disconnecting ends the app's session without canceling a transfer already owned by macOS.

## Frontend orchestration

`DriveViewModel` supplies observed real items, queue entries, root, dry-run mode, Ask each time preference, refresh time, notice, and errors. Views use its folder, refresh, mode, disconnect, enqueue, queue-control, and reveal commands. Synchronization commands share one private live-action decision before queue work. Read-only inspection does not request a sync operation.

The [row-hover presenter](../Sources/iCloudDriveManager/Views/RowHoverCard.swift) receives existing `DriveItem`, `DownloadQueueItem`, or navigation values. It has no backend request method. Full-cell anchors cover each file column; request and navigation rows share per-list controllers. The panel is mouse-transparent, non-key, and non-main, with cleanup on row/scope/view/event changes. Source/build review passed, and the user confirmed physical appearance in the existing implementation. Exhaustive row/state/column and new system-row runtime coverage are not claimed. The file inspector is the persistent alternate to hover.

## Errors and diagnostics

Operational errors appear locally with enough detail for the user to retry or choose a folder again. Paths and file names can be sensitive; they must not be emitted to logs by default. The app does not send errors or diagnostics to a vendor service.

Per-file `issue` text can come from Foundation ubiquitous-item download/upload error fields or optional query metadata. It is shown as a macOS file metadata message, with the `error` enum state labeled Metadata warning. This is separate from a rejected app-owned download request and does not establish a global transfer or authentication failure. See the [account FAQ](troubleshooting.md). Whole-account activity is primarily observed through the status XPC path; the per-file resource/query reads remain active.

See [verification](verification.md) for behavior tested through these contracts and [runbook](runbook.md) for platform failures that cannot be diagnosed by a unit test.

## Read-only system XPC

```swift
@objc protocol SystemTransfersReading: ICloudStatusReading {
    func readPublishedTransfers(reply: @escaping (Data?, String?) -> Void)
    func readBacklog(reply: @escaping (Data?, String?) -> Void)
}
```

The base `readStatus(reply:)` and both derived methods are argument-free and observational. The exported interface contains no cancellation, pause, resume, eviction, arbitrary path, or command parameter. Same-UID, valid-code, expected-identifier and enclosing-app executable authorization is unchanged.

| Method | Implementation and DTO |
|---|---|
| `readPublishedTransfers` | Main-actor public Progress proxy cache → `[PublishedTransferSnapshot]`: local stable ID, observed time, localized descriptions, public operation kind, optional file-kind total/completed bytes, advertised cancellation/pausing flags |
| `readBacklog` | Fixed `/usr/bin/fileproviderctl dump -l com.apple.CloudDocs.iCloudDriveFileProvider` → `SystemBacklogSnapshot`: observed time, pending item count, requested logical bytes, scope description |
| `readStatus` | Fixed `/usr/bin/brctl status` → `SystemActivitySnapshot`: observation time, optional record/item counts and logical sizes |

The service runs CLI reads on one serial worker and admits at most one pending request of each kind. A blocked CLI read does not block the main-run-loop published-progress RPC. Raw output is bounded at 128 MiB, never logged or returned; stderr is discarded. No hard elapsed-time deadline applies. Read/output-limit failures may terminate only the owned child.

The persistent SystemTransfersMonitor connection polls progress every 5s and backlog every 60s, with separate in-flight IDs. Stop/restart invalidates connection/generation; interrupted/error results preserve observations with unavailable/stale reporting rather than zero. The supplemental status client polls every 30s with one request in flight. No client deadline is imposed.

Progress subscriptions match an exact URL or immediate child, not a recursive full queue. IDs last until unpublish/service restart. Direction is based only on the public operation kind. Localized English descriptions are never parsed to guess download direction. Only `.file` unit counts are exposed as bytes, and the UI requires `0 <= completed <= total`; missing/invalid values remain unavailable. Capability flags are advisory: this build invokes none, and the observed aggregate advertised both false.

The backlog parser requires one known iCloud provider section and one materialization counter; duplicate sections/counters, unknown/malformed/overflow values fail unavailable. It does not add scheduler layers. Recognized `0 items / 0 bytes` differs from unsupported output. Logical size is requested item size, not remaining network traffic.

brctl counts recognized `needs-upload` records and explicit valid downloading-percentage records, deduplicated by container/record identity. A generic active/retry operation is not counted as downloading; byte aggregates can be unavailable. **These records are not a complete Finder queued-item list.** Provider backlog, published batches, and brctl diagnostics can overlap, are kept separate, and are never summed.

The current phase corrects observation scope only. Public Progress cooperative cancellation does not establish a general Finder queue-cancellation API. No successful cancellation or full main-use-case acceptance is claimed. See [verification](verification.md) and [account/queue FAQ](troubleshooting.md).

## Live-action decision

Every session starts in dry-run against real selected-item metadata. Plans do not reach the mutation API and are not reported as submitted/completed. Ask each time is a local UserDefaults preference, default true; live mode is session-only.

Live operations require Settings opt-in and, while Ask each time is on, an affirmative Yes/No decision. No is the Return-key default. No/close precedes queue work or preference changes; dialog opt-out persists only on Yes. The same decision covers enqueue, retry, pause/resume, waiting cancellation, and reorder. See [current requirements and evidence](xcode.md#dry-run-and-live-actions).
