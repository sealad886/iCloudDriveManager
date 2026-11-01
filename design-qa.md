# Design QA

Updated: 2026-11-01.

final result: needs work — primary Finder queued-download cancellation unresolved; new system view awaits runtime review

The user clarified that cancelling Finder/macOS already queued downloads is the main use case. The earlier app-owned queue and explicit downloading-record count did not fulfill it. No complete product pass is claimed. The read-only correction passed source review and integration-owner observation of the real primary panel. Its earlier 42-test run passed; the latest full check compiles the final error/stale-label adjustment but fails a protected-bookmark round-trip test, also reproduced in isolation. The current real app also shows bookmark restoration failure despite process launch. Cause is unestablished; the earlier populated panel is historical, not current restored-state acceptance. C3 packaging now passed universal/minimum-OS/signature/archive checks, independently of the failed functional gate. No new screenshot comparison is claimed. [Verification](docs/verification.md) distinguishes that work from preserved C1/C2 checks.

## Current required journey

| Step | Current evidence / gate |
|---|---|
| Understand what Finder queued | New primary System downloads view separates materialization backlog, published batches, and collapsed brctl records; source-reviewed; integration owner observed real 84,632-item / 256.91 GB backlog at 07:14 with Not scanned folder sections, no existing-queue cancellation, and two upload summaries. No current image comparison yet |
| Reconcile roughly 300 GB with dozens of records | Units/scope labels explain batch bytes versus explicit downloading records; no sums or complete-queue inference |
| Cancel that existing system request | Unavailable and prominently disclosed; no verified mechanism or successful cancellation |
| Avoid unnecessary file metadata work | Selected-folder browser is on demand; connecting starts system observations without automatically probing the full library |
| Inspect without mutation | Existing default dry-run policy retained; new service methods expose no actions |
| Read a row's details | Existing hover implementation source/build passed; user confirmed physical card appearance. New system-row attachments reviewed in source, not yet runtime |

Public Progress direction comes only from its public operation kind; no inference from English descriptions. Byte ranges are shown only when file-kind/valid. Published cancellation/pause flags are informational and the observed aggregate advertised neither. An exposed advertised flag would not itself prove an action works.

## Visual identity and preserved evidence

The selected [Tidal board](Resources/Branding/Concepts/01-tidal-board.png) and earlier [actual system-activity capture](docs/screenshots/09-real-system-activity.png) were independently compared together. The interlocking mark, adaptive teal identity, native typography, and product name remain accepted. The board's invented Sync Now control, storage figures, sample file illustration, and sync-complete claim are not functional requirements. Native dark materials and controls intentionally differ from its light illustration.

| Capture | Scope and qualification |
|---|---|
| [09 real activity](docs/screenshots/09-real-system-activity.png) | **Superseded primary-view evidence.** At 1180×780 on 2026-11-01 00:13:20 UTC it showed 47,511 gathering folder items and 42,908/59 diagnostic records. This was not a complete Finder queue inventory |
| [10 live Settings](docs/screenshots/10-live-mode-settings.png) | 00:15:16 UTC; temporary orange live/inactive dry-run, Ask each time temporarily on |
| [11 dry-run Settings](docs/screenshots/11-dry-run-settings.png) | 00:20:57 UTC; dry-run restored, live inactive, existing Ask each time off preference restored |
| Icon Composer [Default](docs/screenshots/05-icon-composer.png), [Dark](docs/screenshots/06-icon-composer-dark.png), [Mono](docs/screenshots/07-icon-composer-mono.png) | Actual editable source inspected in Apple's editor; identity resources unchanged |

Earlier default-window review found no remaining clipping after layout corrections and the table scrolled internally. Actual metadata discovery and rendering defects were fixed: direct discovery replaced Spotlight-only discovery, and cached cancellable background filtering/sorting removed a real-library main-thread stall. The initial pass later observed 50,371 items; it did not certify complete provider coverage.

## Interaction evidence

The natural 60s discovery notice's Continue preserved the same scan. Settings mode labels matched the inspected state and dry-run was restored. No provider mutation occurred. Actual confirmation No/close and discovery Cancel were not completed; source review passed. Cancelling app discovery is not cancelling iCloud synchronization.

Existing file/folder/app-request/sidebar cards use snapshots only, with passive mouse-transparent/non-key panels and event/scope cleanup. The user answered Yes to actual physical appearance; this is limited manual acceptance, not an automated pointer capture or exhaustive row/state/column matrix. The persistent file inspector remains the keyboard alternate. New system rows follow the same implementation and require current runtime inspection.

The integration owner observed no published download batch at that panel instant; the earlier roughly 300 GB download batch was a standalone public-progress probe. The app is not claimed to have displayed that download batch. This distinction remains material to the user’s actual queue investigation.

## Privacy and remaining gates

The earlier aggregate/Settings images contain no private document names. New published descriptions can contain names, so system-view captures require privacy review; raw CLI and real file-list captures stay private/ignored. A macOS per-file metadata warning is separate from app authentication or a global failure; the [FAQ](docs/troubleshooting.md) explains attribution.

Main Finder cancellation, current system layout, minimum window size, all appearances, full keyboard/VoiceOver, affirmative live requests, macOS 15/26 and Intel runtime, diagnostic grammar portability, and notarized distribution remain unqualified. The current engineering phase must not be declared complete on old screenshots or read-only parser success.
