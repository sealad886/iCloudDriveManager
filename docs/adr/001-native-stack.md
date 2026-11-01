# ADR-001: Native SwiftUI frontend and Foundation backend

Date: 2026-10-31
Status: Accepted

## Context

The requested product is a native macOS app that inspects iCloud Drive state and runs across macOS versions currently receiving regular updates. A browser runtime or remote backend would add deployment and privacy boundaries without improving access to the system APIs.

## Decision

Use SwiftUI and AppKit for the frontend and a Foundation `DriveCore` module for folder observation and downloads. The native Xcode project is the canonical IDE/app-bundle workflow; its local Swift package products share the same module sources and retain a fast-test route. Target macOS 15, which covers Sequoia 15, Tahoe 26, and Golden Gate 27 as verified against Apple's current update list. Use Swift tools 6.0 with Swift 5 language mode and no third-party runtime dependencies. Stage a development `.app` through one project build/run script.

The user's native requirement replaces the app-from-scratch skill's default FastAPI/Next.js stack. Folder backend and frontend are separate responsibilities within the sandboxed app. Whole-account activity adds an embedded unprivileged XPC reader with two internally allowlisted read-only local diagnostic operations and public Progress observation, with aggregate diagnostic replies and memory-only localized progress descriptions, and its own caller/execution boundary. API contracts are typed Swift interfaces; no HTTP service is introduced.

## Alternatives considered

- FastAPI and Next.js: adds local servers, package ecosystems, and a browser without replacing Foundation integration.
- Electron or Tauri: introduces a web frontend/runtime boundary and still requires native iCloud integration.
- A command-line utility: does not satisfy the requested native management interface.

## Consequences

The app uses native desktop controls and platform authorization without account secrets. Compatibility depends on API availability and real runtime qualification. Native universal builds have produced Intel and Apple silicon slices; build success does not establish device acceptance. The undocumented status format needs separate per-OS qualification. Public distribution still requires signing and notarization.

## References

- [Apple security releases](https://support.apple.com/en-us/100100)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [NSMetadataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)
