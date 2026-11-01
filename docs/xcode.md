# Xcode development

The native [iCloudDriveManager.xcodeproj](../iCloudDriveManager.xcodeproj) is the IDE entry point. It builds the app from existing sources. SwiftPM supplies DriveCore and DrivePersistence and remains a shared-source fast-test workflow; no implementation is mirrored.

## Open and run

1. Open iCloudDriveManager.xcodeproj in Xcode 16 or later.
2. Select **iCloudDriveManager** and **My Mac**.
3. Press **Command-R** to build and run with the debugger.
4. Choose an actual iCloud Drive folder. System downloads opens first in default **dry-run** mode. Detailed file metadata starts only when a selected-folder browser is opened.

The repository has one shared app scheme. The Demo scheme, sample library, and synthetic preview workflow have been removed from the current product direction. No special launch argument is needed for normal dry-run use.

## Dry-run and live actions

Dry-run applies to synchronization actions, not to reading the selected folder's metadata. Folder selection, monitoring, refresh, and ordinary read-only inspection remain useful without enabling live actions.

Discovery has no hard processing deadline. If its initial pass exceeds 60 seconds, Continue dismisses a soft notice and keeps the same work running. Cancel retains partial results and stops only app-owned discovery; it does not cancel iCloud transfers. Refresh or a new folder starts another pass. The system readers likewise have no hard elapsed-time deadline. Same-kind reads do not overlap; the helper serializes its two CLI operations while public progress observation uses the main run loop.

The required lifecycle is:

1. Preview an intended action against real selected items while dry-run is enabled. Do not call the provider's mutation API or report a simulated action as submitted/completed.
2. Enable live actions explicitly in **Settings** when an actual operation is intended.
3. With **Ask each time** enabled, present **Yes** and **No** for the intended live action, with an **Ask each time** checkbox. It is enabled by default.
4. **No** declines the operation. **Yes** authorizes that intended action. An explicit opt-out controls future confirmation prompts.
5. Returning to dry-run prevents further app-owned submission. Already submitted macOS transfers cannot be revoked by changing an app setting.

Real-data acceptance must not submit provider mutations. Default dry-run checks keep live actions disabled; inspecting the requested toggle or verified confirmation-decline path does not authorize an operation. Opening a confirmation and declining it must not cause provider mutation. Current source/build/runtime scope is recorded in verification. No test result closes the unresolved requirement to cancel downloads already queued by Finder/macOS.

## Test in Xcode

Press **Command-U** to run the native XCTest targets:

| Target | Scope |
|---|---|
| DriveCoreTests | Classification, metadata, containment, queue, and action-policy invariants |
| DrivePersistenceTests | Versioned bookmark persistence and preservation of unsupported/corrupt records |
| DriveAppTests | App model and native view/action-policy integration, hosted by the app |

The Test action sets **ICLOUD_DRIVE_MANAGER_TESTING=1** and does not inherit Run arguments. The host skips remembered-folder restoration; onboarding may still appear. This flag is test infrastructure, not a user credential or required production setting.

Unit cases do not replace validation against the user's explicitly selected real folder. No production sample library or synthetic acceptance screen is retained.

## Signing and debugging

Debug uses local ad hoc signing and Xcode's base-entitlement injection without an Apple development team. Signed Debug entitlements were inspected and include get-task-allow, App Sandbox, user-selected folder access, and scoped bookmarks.

Release disables base-entitlement injection. The current C3 Release app and helper were actually inspected: both have ad hoc signatures with hardened-runtime flags and no Debug entitlement. Debug builds can report that Xcode disables hardened runtime with ad hoc signing; inspect the actual target/configuration signature rather than infer it from a project setting. Developer ID signing/notarization remains separate distribution work.

The deployment target is macOS 15. Universal builds explicitly request arm64 and x86_64 with active-architecture-only disabled. Producing both slices does not qualify runtime on each OS/hardware combination.

## Sources and resources

- The synchronized app folder is Sources/iCloudDriveManager; each native test target has its matching folder under Tests.
- New Swift files in those folders use automatic target discovery. Do not duplicate their file references.
- DriveCore and DrivePersistence are products of the local root package and reuse existing Sources directories.
- Sources/ICloudStatusService is a separate embedded XPC target. The app target builds, signs, and embeds it under Contents/XPCServices. The main app retains App Sandbox; this same-user service has no sandbox entitlement and exposes argument-free read-only backlog, status, and published-progress observation. Public descriptions can contain names and must not be logged or persisted. Inspect both nested and outer signatures when changing this boundary.
- The native app decodes TidalMark.png from its main bundle; the SwiftPM executable uses its package resource bundle.
- Precompiled Assets.car and AppIcon.icns are native resources. The editable Icon Composer source is a non-build reference.

Normal app builds do not require Icon Composer. See the [README](../README.md) for deliberate icon regeneration.

## Command-line workflows

```sh
./script/build_and_run.sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh --universal --build-only
./script/check.sh
swift test
```

The build/run script uses xcodebuild, stages the whole Debug app from **.build/Xcode/Build/Products/Debug/**, and preserves its signature. The check script validates configuration/formatting and runs native tests. Local package intermediates are under **.build/SourcePackages/**. SwiftPM remains the fast shared-source test route.

## Current dry-run validation

C1 and C2 passed 39 native tests on Xcode 27/macOS 27.2 Apple silicon. Their universal app and embedded service both contained arm64/x86_64 with minimum 15.0, and deep strict signatures passed. Debug debugger/sandbox/folder/bookmark entitlements were inspected. The actual native project opened with My Mac selected; opening alone does not prove a successful Command-R action. New Swift files were discovered without manual references.

Actual real-data discovery completed an initial pass with 50,371 items after Spotlight-only discovery and repeated main-thread sorting were corrected. The natural 60s notice's Continue preserved that pass. Temporary live and restored dry-run Settings were inspected; existing Ask each time off was restored. No/close and discovery Cancel were not exercised; no provider mutation occurred. The user subsequently confirmed actual hover-card appearance in the existing implementation.

The current read-only correction makes system observations primary, separates provider backlog/public batches/brctl records, and makes file metadata on demand. Independent source and exact provider-command parser checks passed. An earlier 42-test run and exact-path launch passed, and the actual panel displayed the provider backlog without automatically starting file probes. The latest full run compiles the later error/stale-label adjustment and passes 36 core/3 hosted app tests, but one persistence round-trip test fails at two assertions reopening its protected record; a narrow recheck reproduces it. The current real app also shows a bookmark restoration permission alert despite successful process launch. Cause is unestablished and protection/test expectations remain intact. Preserve the existing record; choosing the same folder is not an established recovery. The C3 universal app/archive has now been refreshed and verified for slices, minimum macOS 15.0, nested signatures, file hashes and modes. This packaging result does not repair restoration or implement existing Finder queue cancellation. See [verification](verification.md) for exact logs, commits, artifact identity, and omissions.
