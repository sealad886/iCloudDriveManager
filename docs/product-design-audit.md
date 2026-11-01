# Product Design audit

Updated: 2026-11-01. **Result: needs work for the main use case.** Cancelling downloads already queued by Finder/macOS is unresolved. The read-only correction passed independent source review and integration-owner observation of the real backlog panel. An earlier 42-test run passed, but the latest full check and narrow recheck fail one protected-bookmark round-trip test; no all-green current test gate is claimed. The final error/stale-label adjustment compiled and passed source review. Current exact-app inspection also shows protected-bookmark restoration failure despite successful process launch; the earlier populated panel is historical. No new image comparison is claimed.

## Material journey correction

The user expected control over an existing roughly 300 GB Finder download job. The previous app-owned request queue did not control it, and dozens of explicit brctl downloading records did not describe its full backlog. This was a product-contract gap, not proof the user's transfers were absent.

The new primary System downloads view presents provider materialization backlog, public published batches, and optional brctl diagnostics separately. Labels distinguish requested logical bytes, batch byte progress, and explicit diagnostic record counts. These observations can overlap and are never added. App requests is a separate navigation destination with a clear existing-Finder-queue limitation. Detailed folder metadata begins only when its browser opens.

Public direction can remain unknown. Localized descriptions are displayed rather than parsed to infer direction; advertised capabilities do not become unverified buttons. Cancellation is explicitly unavailable. The observed published aggregate advertised neither cancellation nor pause. No file eviction, global upload/download pause, or local row removal is accepted as an equivalent outcome.

## Preserved design evidence

The selected [Tidal board](../Resources/Branding/Concepts/01-tidal-board.png) remains the identity reference. The [Icon Composer Default](screenshots/05-icon-composer.png), [Dark](screenshots/06-icon-composer-dark.png), and [Mono](screenshots/07-icon-composer-mono.png) are actual editor evidence. The mark, adaptive teal, system typography and unchanged product name remain integrated.

The [earlier real overview](screenshots/09-real-system-activity.png) is superseded as primary-system-view evidence. At 00:13:20 UTC on 1 November 2026 it showed gathering 47,511 folder items and 42,908/59 diagnostic records in a visible 1180×780 layout. That count was not a complete Finder queue. The [live](screenshots/10-live-mode-settings.png) and [restored dry-run](screenshots/11-dry-run-settings.png) captures retain Settings evidence; the existing Ask each time off preference was restored. The integration owner observed the new real system panel at 07:14 with 84,632 items / 256.91 GB logical backlog, Not scanned folder sections, and two published upload summaries. No download batch appeared at that instant; the earlier roughly 300 GB download was seen only by a standalone probe. A new privacy-reviewed screenshot comparison is not claimed.

The board's illustrative Sync Now action, storage totals, sample rows and sync-complete claim are outside the product contract. Native dark materials and controls intentionally differ from the light canvas. [Design QA](../design-qa.md) records comparison and qualifications.

## Interaction and privacy

Existing snapshot-only hover cards passed source/build checks, and the user confirmed physical appearance on file/folder/sidebar hover. This does not establish every state/column/queue row or new observation-row runtime. Persistent file inspection remains available without hover. No hover-triggered metadata, network, content read, or action is permitted.

Actual large-library discovery/rendering and soft-notice Continue were observed before this phase. No live mutation was accepted. No/close and discovery Cancel remain unexercised runtime branches. Published operation descriptions can contain filenames, so a new system screenshot cannot automatically be treated as aggregate-only; raw/private data stays out of public evidence.

Main cancellation acceptance, corrected system native layout, complete keyboard/VoiceOver, minimum size/appearances, other OS/Intel runtime, affirmative live actions, and public distribution remain open. Exact checks, preserved milestones and new pending gates are in [verification](verification.md).
