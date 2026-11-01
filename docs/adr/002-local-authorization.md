# ADR-002: macOS identity and explicit folder authorization

Date: 2026-10-31
Status: Accepted

## Context

The app acts on a person's existing iCloud Drive. It has no independent multi-user service and should not obtain Apple Account credentials or silently access unrelated folders.

## Decision

Use the local macOS user session as the application identity. Ask the user to choose one folder through `NSOpenPanel`, persist a security-scoped bookmark, and manage its access lifetime explicitly. Revalidate canonical containment and item eligibility at download submission. Expose disconnect as a way to stop observation and forget the connection.

Use no application passwords, JWTs, API keys, privileged helper, or remote authentication service. macOS owns iCloud authentication. Every launch starts in dry-run. Live actions require an explicit session setting and the configured Yes/No decision.

No URLSession, CloudKit, CKContainer, or app account client is implemented. Whole-account diagnostics use the existing macOS session; local metadata errors are not responses from an app sign-in. Their attribution must remain distinct from account-wide status.

Folder authorization applies to the sandboxed app's selected-folder metadata and download requests. A separate embedded, same-user, unprivileged XPC service supplies read-only provider/account diagnostic aggregates and public Progress snapshots; localized progress descriptions may include names and stay local/unlogged. It does not accept a folder, command, or options from the app. Its narrower operation and separate scope are described in the [security model](../security.md).

## Alternatives considered

- Apple Account password collection: unnecessary and expands credential risk.
- Broad filesystem scanning: broader scope than the user chose and poor fit for least privilege.
- App-specific iCloud container: cannot represent the general selected-folder utility requested here.

## Consequences

Bookmarks can become stale or invalid after moves, identity changes, or permission changes, so restoration needs a recoverable failure path. Folder permission does not authorize a global sync operation. Whole-account diagnostics are displayed separately and do not expose a controllable global queue.

## References

- [NSOpenPanel](https://developer.apple.com/documentation/appkit/nsopenpanel)
- [URL bookmark data](https://developer.apple.com/documentation/foundation/url/bookmarkdata(options:includingresourcevaluesforkeys:relativeto:))
- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
