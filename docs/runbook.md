# Runbook

## Environments and ownership

The development environment is a Mac with full Xcode 16 or later and a Swift 6 toolchain. Open `iCloudDriveManager.xcodeproj` for the native app. The deployment target is macOS 15; runtime families 15, 26, and 27 remain subject to the [verification matrix](verification.md). There is no application server or database to operate.

The current bundle is a local development artifact. A release owner must qualify, sign, notarize, and distribute a public build only after explicit authorization. The app is not a backup, repair, or daemon-administration tool.

## Configuration and secrets

No environment variables are required. `.env.example` documents this boundary. Never put Apple Account passwords, app-specific passwords, certificate private keys, or notarization credentials in source files or local diagnostics.

The app uses the Apple Account already configured in macOS. It has no account API or app-managed authentication flow. Fixed diagnostic tools and public Progress observation use that existing session; Foundation resource values and the optional query read local/provider metadata. A per-file metadata message does not establish that the account or all transfers failed. The [account and troubleshooting FAQ](troubleshooting.md) explains the distinction.

The user authorizes one folder through the macOS picker. The app persists `schemaVersion: 1` and opaque bookmark data in `Application Support/iCloudDriveManager/connection.json`. A sandboxed app's application-support directory is inside its container. No queue or file snapshot is persisted.

## Build, launch, and checks

```sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh
./script/build_and_run.sh --verify
swift test
./script/check.sh
```

`dist/iCloudDriveManager.app` is the staged native Xcode development bundle. Open it through Finder or the script. Use `iCloudDriveManager.xcodeproj` for IDE Run/Test/debugging; `swift test` remains the shared-package fast-test route.

Use `./script/build_and_run.sh --universal` to request both Intel and Apple silicon slices. Inspect the binary with `lipo -archs dist/iCloudDriveManager.app/Contents/MacOS/iCloudDriveManager`. Producing both slices is not hardware acceptance.

The optional `--logs` and `--telemetry` modes open the app and stream its macOS logs. Review logs before sharing; system components can include details beyond the app's own logging policy. `--debug` starts a debugger and is intended for local developer use.

The Xcode app embeds `ICloudStatusService.xpc` for read-only whole-account activity. No helper installer, administrator access, or Apple credentials are required. The main app remains sandboxed; the unsandboxed same-user service exposes only argument-free read-only provider backlog, brctl status, and public published-progress observation. Localized published descriptions can contain names, remain memory-only, and must not be logged. Do not replace it with a shell or a configurable command.

## Normal operating procedure

1. Choose the real iCloud Drive folder you intend to inspect.
2. Confirm the real folder scope and visible DRY RUN / live actions inactive state.
3. Inspect System downloads first. Backlog, published batches, and brctl records have different units/scopes and can overlap; never add them or read the diagnostic count as the full Finder queue. Open a file-browser section only when detailed resource metadata is wanted. Wait for its initial metadata gathering. Treat missing results as unknown coverage. A scan exceeding 60 seconds offers Continue or Cancel without a hard timeout. Continue keeps the same scan; Cancel retains partial results and allows choosing a lower folder. Refresh starts discovery again. Cancel does not stop iCloud transfers.
4. Preview intended requests in dry-run. For actual downloads, enable live actions in Settings and answer Yes/No. Accepted live downloads can consume disk space and bandwidth.
5. App requests controls only plans/waiting requests created here. Cancellation of Finder/macOS already queued downloads is unresolved and unavailable; no apparent local cancellation can be reported as stopping the system operation.
6. Use Finder for document management and the owning app for conflict resolution.
7. Disconnect when access should no longer be remembered.

## Troubleshooting

| Symptom | Checks and recovery | Meaning |
|---|---|---|
| No files appear | Confirm the selected folder is in iCloud Drive, verify Finder access, open a file-browser section, allow background discovery to finish, and refresh; treat the known protected-bookmark failure separately | Direct discovery does not require Spotlight; an empty result does not prove all files are synchronized |
| A file says it could not access iCloud | Check the same item in Finder and compare the fresh system-activity card; read the inspector's macOS file metadata attribution | It is not an app login response or proof all transfers failed. Use System Settings only if macOS itself reports an account problem |
| System activity is unavailable | Check the embedded service/signatures and retry. Unsupported OS output, read failure, or output cap must remain unavailable | No hard processing timeout is imposed; do not publish raw status output or treat failure as zero activity |
| Status differs from Finder | Wait for metadata delivery and refresh; inspect the same file in Finder | Provider and query metadata may lag or be incomplete |
| Request remains submitted | Check Finder, connectivity, available disk space, and macOS iCloud status | Foundation accepted a request; the app cannot force system completion |
| Download fails | Read the local error, inspect Finder, resolve account or file access problems, then explicitly retry | Do not restart system daemons or delete provider databases |
| Conflict appears | Reveal the item and use Finder/the owning application to review versions | The app does not choose or discard a version |
| Current protected saved folder cannot be restored | Preserve the record and diagnostics; do not promise choosing the same folder repairs it, because save validates the unreadable existing record first. Do not delete it or change protection/permissions to force a pass | Actual current app restoration and round-trip tests both fail; cause remains unestablished, independent of process-launch success |
| Pause appears ineffective | Check whether entries were already submitted | Pause affects app-owned waiting requests only |
| App will not open on another Mac | Check OS minimum, architecture slice, signing/notarization, and Gatekeeper's report | A local development artifact is not a qualified distribution build |

## Persistence recovery and rollback

Disconnect is the ordinary product command for intentionally forgetting a connection. It does not remove documents or cancel system requests already submitted. It is not authorized as a workaround for the current protected-record failure; preserve that existing record for diagnosis.

If the app cannot load its record, quit the app and retain the original `connection.json` locally for diagnosis before any manual recovery. Bookmark bytes are sensitive and should not be uploaded. A developer may inspect only the schema/version shape without exposing the bookmark. Unknown future schemas must not be silently downgraded. For ordinary stale authorization, reconnection belongs in the user-facing picker. In the current protected-record read failure, choosing a folder is not a verified recovery because save validates the unreadable existing record first. Do not promise it fixes this condition or remove/relax the protected record to work around it.

There is no historic schema to migrate in this new repository. A future migration must back up the existing record locally, convert it once, validate it, and atomically replace it. Never transplant another user's bookmark.

To roll back application code, use a previously verified build after preserving the current source and relevant diagnostics. No app database rollback is needed. Previously submitted macOS requests are independent of the app's executable version; replacing the app cannot undo them.

## Monitoring and incidents

There is no remote health check, pager, analytics dashboard, or automated crash upload. The user observes query gathering, state, request outcomes, and errors in the app. Local OSLog supports developer diagnosis without intentionally recording file names, paths, bookmark bytes, or document contents.

Provider backlog and brctl counts come from separate bounded local diagnostic reads, not from the selected-folder table. Published batches use public Progress. Counts and logical sizes can overlap and are not exact remaining traffic or speed. Raw production status output stays in helper memory. Private development captures must remain in ignored local storage with restricted permissions; reports use aggregates. Published localized descriptions can contain private names and require redaction before screenshots or issue reports.

For a suspected authorization bug, enable dry-run, disconnect, quit, retain sanitized reproduction details, and inspect the containment/requester boundary before another live test. Do not use destructive files or valuable unique documents for reproduction. Report the OS, processor, app/source revision, expected/actual behavior, and redacted relative paths rather than private names.

For an Apple service outage or account problem, use macOS and Apple's support channels. The app must not attempt account-password collection, global synchronization repair, or provider database modification.

## Public release gate

Before a release, obtain evidence for:

- Real authenticated iCloud observation and download requests on macOS 15, 26, and 27.
- Intel and Apple silicon launch, bookmark restoration, queue controls, and permission failures.
- Read-only observation with no unexpected file downloads, writes, or broadening of access.
- Offline/online transitions, stale metadata, errors, conflicts, large folders, and root switching during submission.
- Keyboard navigation, VoiceOver, reduced motion, high contrast, and light/dark presentation.
- Final App Sandbox entitlements, Developer ID signing, notarization, and Gatekeeper validation.
- A release-specific version, privacy notice, support owner, and update strategy.

Record results in [verification](verification.md). No push, publication, deployment, signing identity enrollment, or release action is authorized by this runbook alone.

## Real-data dry-run workflow

Use the native iCloudDriveManager scheme or normal script. Every launch starts in dry-run; live mode is not persisted. Ask each time defaults on and is stored separately in local UserDefaults. A dialog opt-out is saved only on Yes, while No/close preserves the prior preference. Choose a real folder and inspect controls without accepting provider mutation; return to dry-run for handoff.

Inspect real metadata and preview intended operations in dry-run. For deliberate live use, enable live actions in Settings and answer the Yes/No confirmation. The Ask each time checkbox controls future confirmation prompts; it does not itself authorize an operation. Returning to dry-run stops further app-owned submission, while transfers already accepted by macOS remain independently managed.

Historical screenshots and totals remain historical evidence. Record current real-data/default-mode, Settings, confirmation-decline, and policy-gate results before claiming the flow validated. The [Xcode guide](xcode.md) records the native baseline and current policy evidence.
