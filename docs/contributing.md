# Contributing

Open [iCloudDriveManager.xcodeproj](../iCloudDriveManager.xcodeproj), select iCloudDriveManager / My Mac, and use Command-R or Command-U. The native project is the canonical app-bundle workflow. DriveCore and DrivePersistence are local Swift package products sharing the same source; keep one implementation. [Xcode development](xcode.md) explains resources and signing.

## Change workflow

1. Inspect Git status, current branch, repository instructions, and overlapping edits. Preserve work owned by others; do not create a worktree automatically.
2. Identify the contract being changed and its source owner using [architecture](architecture.md) and [API](api.md).
3. Make the focused change and add a regression test only for meaningful behavior. Synchronized source groups discover new Swift files automatically.
4. Run `./script/check.sh` for formatting/configuration checks and the native tests. `swift test` is the shared-package fast route. Use `./script/build_and_run.sh --build-only` to stage a Debug app; use the normal script to launch it.
5. For UI or provider changes, inspect the actual native app with real selected metadata and dry-run enabled. Unit cases do not replace real-data acceptance. Do not accept a live provider mutation as part of read-only validation.
6. Update the relevant canonical docs and [verification](verification.md) with actual results and explicit omissions. Review the complete diff before creating a focused Conventional Commit milestone.

## Invariants to preserve

- Every launch starts in dry-run. Plans never invoke the provider or auto-run when live mode is enabled. Keep the shared model decision and independent queue guard.
- No/close precedes queue/preference changes; a dialog opt-out persists only on Yes. Ask each time defaults true when absent; live mode does not persist.
- Validate canonical containment and eligibility again at dispatch. Reject symlink escapes and stale callbacks after scope/reset changes.
- Keep selected-folder Foundation/query observations, provider materialization backlog, published Progress batches, and brctl diagnostic records separate. Never sum overlapping observations or substitute active-record count for the complete Finder backlog. Metadata messages are not app authentication errors or evidence that all transfers failed.
- Keep the main app sandboxed. The embedded same-user reader accepts no arbitrary command/path, returns aggregates plus local memory-only published descriptions, and retains its output cap. Never log or persist those descriptions/raw diagnostics. No admin helper or account-secret collection.
- Processing has no hard elapsed-time timeout. The 60-second notice is soft; Continue preserves the pass and Cancel retains partial observations without stopping iCloud.
- Keep filtering/sorting off the main thread, preserve cancellation/generation guards, and avoid whole-library work in view rendering or empty-selection paths.
- Hover cards must use already observed row/scope data, with no file-content, fresh metadata, or network reads on hover.

Do not imply that app-owned waiting-request controls cancel Finder/macOS existing downloads. That primary capability remains unresolved. Public advertised cancellation is advisory; do not add eviction, global pause, or daemon control as a silent substitute.

## Commits and private artifacts

Use coherent Conventional Commits such as `feat: ...`, `fix: ...`, and `docs: ...`; keep implementation and documentation milestones reviewable. Respect the user's authorization and existing Git signing configuration. A local commit does not authorize a push, release, or deployment.

Review staged paths explicitly. Build output, local `.build` diagnostics, bookmarks, credentials, real file-list captures, and raw status output must stay out of commits. The current public evidence images contain aggregate/Settings views or Icon Composer. Earlier sample UI captures remain local and are excluded from the retained evidence set.

Public distribution has its own signing/notarization, OS/hardware, accessibility, and live-provider gates in the [runbook](runbook.md); a local test pass does not close them.
