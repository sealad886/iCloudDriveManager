# Troubleshooting and account FAQ

## Can this cancel downloads already queued by Finder?

Not in the current build. This is the main requested use case and remains unresolved. **App requests** manages only plans/waiting requests created here. Removing a plan, pausing submission, disconnecting, or closing the app does not revoke an operation already accepted by macOS.

Public Foundation Progress exposes cooperative cancellation for published operations, but no general complete Finder download-queue API was established. The observed system aggregate advertised neither cancellation nor pausing. No unverified control is exposed. File eviction, global upload/download pause, service restarts, and local queue-row removal are not substitutes.

## Why does Finder show roughly 300 GB while this app showed only dozens of downloads?

The earlier display counted explicit downloading-progress **records** in brctl diagnostics. It did not count every requested file. Finder can publish an aggregate byte-progress operation covering many files, while provider diagnostics expose a larger materialization backlog.

| Observation | Scope and unit |
|---|---|
| Provider backlog | Materialization items and requested logical bytes; one provider-scoped counter, without summing duplicate scheduler layers |
| Published batch | macOS operation description and file-kind byte progress; may cover many files, with unknown public direction |
| brctl downloading records | Recognized records with explicit valid progress; a subset, not all pending downloads |
| Selected-folder table | Resource/query metadata in the selected subtree, read only when the browser is opened |

These measurements overlap and are not summed. The exact fixed provider-filtered command returned 84,715 items and 257,188,454,073 logical bytes during investigation on 1 November 2026. An earlier unfiltered capture contained 85,459 items / 259,736,364,226 logical bytes. A separate published operation was roughly 300 GB. These are changing observations from different scopes/times, not remaining network bytes, speed, or promises of one-to-one Finder matching. Unknown/malformed diagnostics are unavailable, not fabricated zeros.

## Does the app need an iCloud login or API key?

No. The app uses the Apple Account already configured in macOS and never collects credentials. There is no app URLSession, CloudKit, CKContainer, or account client. Local tools and public Progress observation use the existing macOS session. Folder permission is a separate security-scoped authorization.

## What does “Couldn't access iCloud” mean in a file's details?

The text can be a localized error supplied by Foundation ubiquitous-item resource fields or optional query metadata. The app labels it **Metadata warning** / **macOS file metadata message**. It is not a response from app authentication and alone does not establish that all transfers failed.

Compare the same item in Finder and refresh. If macOS itself reports an account problem, use its System Settings guidance. Do not enter an Apple Account password, app-specific password, token, or key into this app. The label explains the source; it does not repair an underlying account/provider condition.

## Observation and action problems

| Symptom | Action / interpretation |
|---|---|
| Folder sections say Not scanned | Open a file-browser section to start detailed resource metadata observation; the system view intentionally avoids it |
| Backlog or published progress unavailable | Refresh and inspect the source/error/time; diagnostic format/session availability varies by OS. An unavailable source is not zero work |
| Published direction unavailable | macOS omitted the public operation kind. English descriptions are displayed but are not used to guess direction |
| Scan exceeds 60 seconds | Continue keeps the same pass running; Cancel retains partial observations and stops only app discovery. No hard processing timeout applies |
| An app request stays submitted | Submission is not completion. Metadata may be delayed/unavailable. Check Finder; the app does not invent a terminal state |
| The current protected bookmark cannot restore | Preserve the existing record. Current app restoration and tests both fail with a permission error. Choosing the same folder is not a verified fix: save validates the existing unreadable record first. Do not delete the record or change protection/permissions as a workaround |
| No hover card appears | Activate the app window and pause over a row. The user confirmed cards appear in the existing implementation; exhaustive row/appearance coverage is not established. Use the persistent file inspector alternate |

Every launch starts dry-run. Live mode is session-only. Ask each time is a separate persisted preference and can already be off from a previous explicit choice. Returning to dry-run does not cancel previously accepted system work.

## Current bookmark restoration and test failure

The latest full native check and narrow persistence recheck fail `testRoundTripAndDisconnect` while reopening a protected bookmark record (Cocoa 257/POSIX EPERM), with two assertions in one failing test. An earlier 42-test run passed. A standalone Foundation diagnostic reproduced the same read restriction for `.completeUnlessOpen` files in both temporary and ignored workspace locations, while ordinary/class-C writes read back successfully. The current exact dist app subsequently showed the same restoration permission alert, so this affects real app startup, not only XCTest. Process presence is not successful restoration. These observations narrow the host/launch context but do not prove its underlying cause or qualify persistence as correct. Production protection and test expectations remain unchanged; do not remove protection or broadly change permissions to make the check pass. See [verification](verification.md).

## Sharing a problem safely

Include app revision, macOS/Xcode version, source label, observation time, and redacted aggregate values. Names, localized batch descriptions, account identifiers, paths, bookmark data, raw diagnostic output, and file-list screenshots can be private. Keep raw captures out of the repository and public issue text. See [runbook](runbook.md), [security](security.md), and [verification](verification.md).
