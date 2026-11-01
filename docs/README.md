# Documentation

Start with the root [README](../README.md) for building from source and first use. These pages describe the current native app; recorded counts and screenshots are observations, not a live status feed.

**Current main-use-case gap:** cancellation of downloads already queued by Finder/macOS is unresolved and unavailable. The earlier 42-test pass and actual backlog-panel observation are preserved, but the latest full check reproduces a bookmark reopening failure that also affects current real-app restoration. See verification for the current red gate and separate build/artifact evidence. No completed main-use-case delivery is claimed.

## Using the app

| Guide | Use it for |
|---|---|
| [Troubleshooting and account FAQ](troubleshooting.md) | Understanding metadata warnings, system backlog, published batches, diagnostic records, and folder metadata, account ownership, unavailable counts, and slow scans |
| [Runbook](runbook.md) | Building, normal operation, bookmark recovery, diagnostics, and release gates |
| [Verification](verification.md) | Exact local checks, actual real-data evidence, and untested behavior/platforms |

## Developing the app

| Guide | Use it for |
|---|---|
| [Xcode development](xcode.md) | Native project, Run/Test/debugging, signing, resources, and shared SwiftPM modules |
| [Contributing](contributing.md) | Change workflow, invariants, focused checks, and milestone commits |
| [Architecture](architecture.md) | Sandboxed app, direct folder metadata, queue, and embedded read-only XPC service |
| [Service API](api.md) | Folder observation, download commands, mode policy, and aggregate XPC contract |
| [Data model](data-model.md) | Sync states, plans/requests, bookmarks, and preference lifetimes |
| [Architecture decisions](adr/001-native-stack.md) | Native stack, [authorization](adr/002-local-authorization.md), and [storage/jobs](adr/003-storage-and-jobs.md) |

## Design and assurance

| Guide | Use it for |
|---|---|
| [Branding kit](branding/README.md) | Selected Tidal identity, alternatives, and editable Icon Composer source |
| [Product Design audit](product-design-audit.md) | Current actual UI evidence and its scope |
| [Design QA](../design-qa.md) | Comparison with the selected board and accepted platform differences |
| [Security](security.md) | Permission/process boundaries, fixed-command controls, and sensitive metadata |
| [DPIA-lite](dpia-lite.md) and [compliance mapping](compliance.md) | Privacy data flows and assurance themes; no certification is implied |
| [Risk register](risk-register.md) | Known limits and remaining qualification |
| [Delivery plan](plan.md) | Current local delivery and commit milestones |
