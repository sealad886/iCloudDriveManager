# iCloud Drive Manager

A native macOS utility for viewing iCloud Drive download activity and inspecting selected-folder metadata. Built with SwiftUI, AppKit, and Foundation, using the Apple Account already configured in macOS.

**The main requested capability—cancel downloads already queued by Finder/macOS—is unresolved and unavailable in this build.** App-request controls apply to requests created here. They do not cancel Finder's existing queue. Current work corrects the activity display while the system cancellation mechanism is investigated; the main use case is not complete.

Start with the [documentation index](docs/README.md), [troubleshooting FAQ](docs/troubleshooting.md), or [current verification](docs/verification.md).

## Requirements

- macOS 15 or later. This target covers Sequoia 15, Tahoe 26, and Golden Gate 27, listed in [Apple security releases](https://support.apple.com/en-us/100100) as receiving updates on 26 October 2026. Build compatibility does not establish runtime qualification on every release.
- Full Xcode with a Swift 6 toolchain. File-system synchronized groups require Xcode 16 or later. Current local checks used Xcode 27, macOS 27.2, and Apple silicon.
- An existing macOS Apple Account with iCloud Drive enabled. There is no app sign-in, credential collection, or API key.

## Build and run

Open [iCloudDriveManager.xcodeproj](iCloudDriveManager.xcodeproj), select **iCloudDriveManager** and **My Mac**, then press **Command-R**. **Command-U** runs the three native XCTest targets. Local Debug uses ad hoc signing with debugger access; no Apple development team is required. See the [Xcode guide](docs/xcode.md).

The shell and Codex Run action use the same native project:

```sh
./script/build_and_run.sh                 # Build, stage, and open
./script/build_and_run.sh --verify        # Also verify the exact app process
./script/build_and_run.sh --build-only    # Stage without opening
./script/build_and_run.sh --universal     # Intel and Apple silicon slices
./script/check.sh                        # Syntax, formatting, native tests
swift test                               # Shared-module fast tests
```

The development bundle is staged at `dist/iCloudDriveManager.app`. SwiftPM shares the same module sources; it is not a second app implementation. There is no Demo scheme or production sample library. Developer ID signing, notarization, and platform acceptance remain separate distribution work.

## Read the system view first

Choose a real iCloud Drive folder. **System downloads** is the default view; detailed file enumeration starts only when a selected-folder browser is opened. Connecting a folder does not automatically perform tens of thousands of per-file resource probes.

| Display | Source | Meaning and limits |
|---|---|---|
| System download backlog | Fixed provider-scoped `fileproviderctl dump -l` read | Outstanding materialization items and their requested logical size; not remaining network bytes or an ordered filename queue |
| Published transfer batches | Public Foundation `Progress` subscription | macOS-published descriptions, byte progress when explicitly file-kind, and advertised capabilities; a batch can cover many files and its direction can be unknown |
| Additional diagnostics | Fixed `brctl status` read | Recognized records, including explicit downloading progress; a subset, not Finder's complete queued-item count |
| Selected-folder browser | Foundation resource metadata and optional root-scoped query | Per-file state, metadata warnings, conflicts, and available progress in the selected folder |

These sources can overlap and are **never added together**. Finder's roughly 300 GB batch can coexist with only dozens of explicit downloading records: one is a byte total for an operation, the other a count of recognized records. A provider backlog observation of 84,715 items / 257,188,454,073 logical bytes is another distinct measurement, recorded during investigation on 1 November 2026. None establishes exact remaining network traffic.

Descriptions are shown as macOS supplies them. Direction is inferred only from the public operation kind, never English text. Advertised cancellation/pausing flags are observations, not proof of working controls; the observed aggregate advertised neither. No cancellation or pause action is exposed for published batches.

Detailed folder discovery has no hard processing timeout. A soft notice after 60 seconds offers Continue or Cancel: Continue preserves the pass; Cancel stops app discovery and retains partial observations. It does not cancel an iCloud transfer. File search/sort uses cancellable background work with cached results.

## App-owned requests and action mode

Every launch starts in **dry-run**. Plans use real selected-file metadata without calling the download API. Settings can enable live actions for the session. **Ask each time** defaults on and is persisted separately; while on, live commands need Yes/No confirmation, with No as the Return-key default. Enabling live mode never runs existing plans automatically.

**App requests** can enqueue eligible files, pause submission, prioritize or cancel waiting entries, and retry failures. At most two submitted requests await a metadata outcome. Submission means macOS accepted a request, not that a download completed. Already submitted transfers remain owned by macOS. These controls do not manage the queue previously created by Finder.

The app does not delete files, evict local copies, force uploads, restart services, or read document bodies. Selected-folder access is remembered with a security-scoped bookmark; disconnect forgets it. Requests and observations stay in memory, with no replay on restart.

## Row details

File/folder, app-request, sidebar navigation, and new observation rows have passive hover cards using existing snapshots. Hovering performs no new metadata, network, or document-content read and triggers no action. The user confirmed physical card appearance for the existing implementation; exhaustive row/state/column and new system-row runtime coverage are not claimed. Select a file and use **File details** or **Show details** for a persistent inspector alternate.

## Privacy and account ownership

macOS handles iCloud authentication and transport. The app contains no URLSession, CloudKit, CKContainer, account endpoint, or credential flow. A **Metadata warning** such as “Couldn't access iCloud” comes from macOS file metadata; it is not an app sign-in response or proof that all transfers failed. See the [account FAQ](docs/troubleshooting.md).

The main app remains sandboxed. An embedded same-user, unprivileged, unsandboxed XPC service performs only fixed read-only diagnostic calls and public progress observation. It accepts no arbitrary command or path. Raw diagnostic output stays in bounded memory, is not logged or returned, and has no hard elapsed-time deadline. Published localized descriptions can contain private names and cross XPC for local display; they are not persisted or logged. The app stores only its bookmark and Ask each time preference and has no remote telemetry.

## Project and identity

| Location | Purpose |
|---|---|
| `iCloudDriveManager.xcodeproj/` | Canonical app, XPC, tests, resources, and debugging |
| `Sources/DriveCore/` | Metadata, typed observations, parsers, authorization, app-request queue |
| `Sources/DrivePersistence/` | Versioned bookmark persistence |
| `Sources/iCloudDriveManager/` | Native UI, model, scoped access, and XPC clients |
| `Sources/ICloudStatusService/` | Authenticated same-user read-only observation service |
| `Tests/` and `script/` | Behavioral checks and native build workflows |
| `docs/` | Architecture, contracts, privacy, operation, and evidence |

The user selected Tidal from three generated identity boards. The product name remains **iCloud Drive Manager**. The [branding kit](docs/branding/README.md) includes the bespoke icon assembled in Apple Icon Composer, editable [AppIcon.icon](Resources/Branding/Tidal/AppIcon.icon), and [source mark](Resources/Branding/Tidal/TidalMark.png). Normal builds use precompiled Apple resources. Deliberate icon changes can be exported with:

```sh
./script/export_icon.sh Resources/Branding/Tidal/AppIcon.icon Resources/CompiledIcon
```

See [Contributing](docs/contributing.md), [architecture](docs/architecture.md), [security](docs/security.md), [design QA](design-qa.md), and [runbook](docs/runbook.md). The latest full check fails one bookmark round-trip test at two assertions (permission error reopening its protected record); the current real app also fails to restore that bookmark. Process launch succeeds, but restoration does not. Preserve the existing record; choosing the same folder is not a verified recovery. The 36 core and 3 hosted app tests pass. The earlier 42-test pass is historical. Current build/artifact and diagnostic results are tracked in verification. No completed main-use-case delivery or public release is claimed.
