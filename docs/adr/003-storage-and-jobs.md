# ADR-003: Minimal bookmark persistence and process-lifetime request queue

Date: 2026-10-31
Status: Accepted

## Context

Remembering one folder improves usability. Persisting metadata or replayable file operations would retain sensitive names and could trigger unexpected downloads after relaunch. The operating system already owns durable synchronization.

## Decision

Persist a versioned bookmark envelope in `Application Support/iCloudDriveManager/connection.json`, inside the sandbox container when bundled. Schema version 1 contains `schemaVersion` and `bookmarkData`. Use same-directory atomic writes and POSIX mode `0600`; reject unsupported versions. Renew a stale bookmark through the authorized flow. The separate local UserDefaults preference `askBeforeLiveActions` remembers Ask each time, defaulting to true. The alert saves an opt-out only after Yes. Live mode itself is never persisted. There are no previous production records requiring a legacy-data migration.

Keep snapshots and download queue entries in memory. Dry-run creates planned entries without a provider request; enabling live does not automatically submit plans. Allow at most two outstanding submitted requests. Successful Foundation submission is not completion; reconcile against observed metadata. Pause/reorder/cancel applies only to the app's waiting requests. Root changes invalidate old session callbacks. Relaunch does not replay requests.

The production library contains only real selected-folder metadata; there is no seeded dataset. Provider/account aggregates and public Progress snapshots, including localized descriptions, are also memory-only. The current system view starts without automatically enumerating detailed folder metadata. App requests cannot cancel Finder’s pre-existing queue; that requirement remains unresolved. The embedded status reader is observational and does not execute queue jobs. No SQL migration engine, Redis worker, or durable job service is necessary.

## Alternatives considered

- SQLite metadata and queue database: retains sensitive data and creates replay/migration complexity without an MVP requirement.
- Durable background worker: duplicates macOS scheduling and risks surprising post-relaunch behavior.
- No saved folder: simple but forces repeated selection for ordinary read-only use.

## Consequences

Quitting clears queue history, so the app is not an audit trail. A lost bookmark can be recovered through the picker. Already submitted transfers can continue after disconnect or exit because they belong to macOS. Future storage changes require a local backup and explicit one-time conversion before replacing an existing record.

## References

- [Request a ubiquitous item download](https://developer.apple.com/documentation/foundation/filemanager/startdownloadingubiquitousitem(at:))
- [URL resource values](https://developer.apple.com/documentation/foundation/urlresourcevalues)
