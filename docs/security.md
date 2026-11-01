# Security and threat model

## System overview

A sandboxed SwiftUI app reads one selected folder and submits explicitly authorized downloads through Foundation. A separate embedded, same-user, unprivileged XPC service reads fixed provider/account diagnostics and public published Progress. Replies contain aggregates and localized published descriptions. macOS owns authentication, synchronization, and transport. There is no app server, remote telemetry endpoint, administrator helper, or helper installation.

The development bundle is intended for local evaluation. Its security controls do not establish that it is ready for public distribution.

## Assets

- User documents and the integrity of their local and cloud versions.
- Sensitive file names, relative paths, sizes, dates, and sync error metadata.
- The security-scoped folder bookmark and its authorization capability.
- Accurate presentation of sync state and submitted request outcomes.
- Availability of the Mac while processing large metadata queries.
- Private whole-account diagnostic output, which is confined to bounded helper memory and must not be logged or returned raw.

## Trust boundaries and entry points

The UI is the user's command boundary. The folder picker and bookmark resolution establish access to one folder. Metadata callbacks and resource values are external observations, not unquestioned proof of file safety or completeness. The requester revalidates each target before passing it to Foundation.

The status service is a separate trust boundary with broader ambient user permissions because it is unsandboxed. Its exported methods are argument-free read-only status, provider backlog, and published progress observation; none mutates system transfers. Caller validation requires the same effective UID, valid code, the expected identifier, and the executable path of the enclosing app. This does not grant administrator or cross-user authority.

Entry points include folder selection, bookmark loading, metadata notifications, action-mode Settings, Yes/No confirmation, queue commands, and Finder reveal. Names and error descriptions are untrusted display data, never shell commands or remote instructions.

## STRIDE analysis

| Threat | Component | Description | Mitigations | Residual risk |
|---|---|---|---|---|
| Spoofing | Folder and file identity | A stale bookmark or changed path could refer to an unexpected item | User selection, scoped bookmark resolution, canonical containment and resource revalidation at submission | Medium: filesystem state can change between validation and the system call |
| Tampering | User files | An operation could act on a file outside the selected folder or destroy a local version | No delete/evict/write-content operation; containment and symlink checks; reject directories and conflicts for downloads | Low for implemented operations; cloud semantics still belong to macOS |
| Repudiation | Queue state | Request submission could be mistaken for completed download or canceled transfer | Explicit waiting/submitted/completed states; completion requires metadata; no claim to cancel submitted work | Low; no durable audit history is provided |
| Information disclosure | Metadata and bookmark | Paths, names, errors, or bookmark bytes could leak through logs or exports | Local-only display; no analytics or export; logging excludes paths and content; bookmark file mode `0600` | Medium on shared/unlocked Macs; screenshots expose visible metadata |
| Denial of service | Metadata query and rendering | Large folders or delayed transfers can consume resources or occupy queue slots | Two outstanding requests; async request work; stop/reset lifecycle; no silent claim of full query coverage | Medium pending large-library profiling and real-provider acceptance |
| Elevation of privilege | Folder access | A symlink or old async callback could escape the root or reuse obsolete access | Canonical path guard; scoped authorization; session invalidation; no privileged helper or daemon control | Medium pending physical integration testing |

## Security controls summary

Authentication is the local macOS user session. The app neither collects Apple Account credentials nor supplies an independent login. Authorization is the selected folder's scope plus per-request validation. A bookmark is not an authentication token for iCloud and must still be protected as a capability.

The source contains no URLSession, CloudKit, CKContainer, or account API. The status tool uses the existing macOS iCloud session. Per-file resource/query error text is attributed as macOS metadata, not an app authentication result. This attribution does not itself resolve an underlying account, provider, or file-access problem.

Persistent state is `Application Support/iCloudDriveManager/connection.json`, relative to the process's macOS application-support directory. The sandboxed bundle resolves that directory inside its container. The envelope has `schemaVersion: 1` and opaque `bookmarkData`. Writes are atomic within that directory and the file uses POSIX mode `0600`. Unknown schema versions are rejected. This new project has no existing legacy store to migrate.

The app does not provide encryption of its own. Local storage protection depends on macOS permissions and the user's device configuration, including FileVault where enabled. iCloud transport and server storage protection depend on Apple's services and account settings.

OSLog is the diagnostic boundary. Application logging must exclude names, paths, bookmark bytes, and document content by default. There is no remote error capture hook enabled. System frameworks can produce their own diagnostics under macOS policy.

The queue is session memory only. A restart cannot replay previous requests. Disconnect and root switching invalidate pending app work, while already submitted requests remain with macOS. There is no global queue reorder, global sync pause, forced upload, or automatic conflict resolution.

## Embedded status-service controls

The service executes only fixed `/usr/bin/brctl status` and `/usr/bin/fileproviderctl dump -l com.apple.CloudDocs.iCloudDriveFileProvider`; it uses no shell or client-supplied path/argument. A singleton serial worker admits at most one pending request of each command kind. Public Progress proxies are observed separately on the main run loop with NSRunLoop and the requesting app audit session. Output is drained while the child runs, capped at 128 MiB, and processed only in memory; stderr is discarded. Per the requested processing behavior, there is no hard elapsed-time deadline in the service or client. Read errors and output-cap failures can terminate only the operation's own child, followed by a one-second kill fallback; no cloud daemon or unrelated process is targeted.

Diagnostic replies contain aggregate counts/sizes/time or generic errors; no raw CLI output crosses XPC. Published-progress replies additionally contain macOS localized descriptions, which can contain private names. These cross XPC only for local memory-only presentation, are not parsed as commands, and must not enter logs/persistence. Client request/session guards prevent overlapping same-kind reads; an unfinished read can remain in flight without an automatic timeout. Diagnostic format is undocumented; parsing failure must not appear as zero activity. The main app's sandbox remains enabled, and the helper has no mutation command, network endpoint, privileged installation, or administrator prompt. Real signed-client and aggregate correctness acceptance is tracked separately from source review.

The primary user goal—cancel Finder/macOS already queued downloads—is unresolved. The service exposes no cancel/pause/resume/evict mutation. Public Progress capability flags are advisory and the observed aggregate advertised neither cancellation nor pause. macOS 26 per-item pause affects uploads and downloads and persists; ordinary directories are unsupported. It is not a substitute for queue cancellation, nor is file eviction.

## Backup and recovery

The app is not a backup tool. Documents remain under the user's backup/iCloud policies. Losing the bookmark requires choosing the folder again; losing the separate confirmation preference restores its safe default. Never restore another user's bookmarks.

A corrupt record should produce a recoverable connection error without generating file operations. An unsupported future schema should remain intact for diagnosis rather than being silently overwritten. See the [runbook](runbook.md).

## Verification and release gates

Tests must cover canonical containment, sibling-prefix rejection, symlink escape, eligibility, queue deduplication, paused submission, maximum outstanding requests, retry, and late callbacks after reset. These tests cannot establish the behavior of a signed app with a real iCloud account.

Before distribution: verify App Sandbox entitlements, real bookmark access after relaunch, actual iCloud requests on each supported OS, a Developer ID signature, notarization, keyboard/VoiceOver behavior, and metadata performance. No security scan or certification is implied by this document.

## Primary references

- [NSMetadataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)
- [Request a ubiquitous item download](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:))
- [URL resource values](https://developer.apple.com/documentation/foundation/urlresourcevalues)
- [Security-scoped bookmark data](https://developer.apple.com/documentation/foundation/url/bookmarkdata(options:includingresourcevaluesforkeys:relativeto:))
- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)

## Dry-run safety boundary

Every session uses real selected-folder metadata in dry-run by default. Live actions require Settings opt-in and Yes/No confirmation while Ask each time is enabled. No is the Return-key default; No/close dispatches no work and changes no preference. A dialog opt-out persists only on Yes. The confirmation Boolean is stored in local UserDefaults; live mode is session-only.

The model shares one decision across commands, and the queue separately refuses dispatch in dry-run. Switching back converts waiting records to plans, cancels pending tasks, and invalidates callbacks. Enabling live never auto-executes plans. Already accepted macOS transfers cannot be revoked. Real-data validation must not submit iCloud mutations; historical UI captures do not certify this changed policy. See [current evidence](xcode.md#current-dry-run-validation).
