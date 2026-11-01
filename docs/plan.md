# Delivery plan

Updated: 2026-11-01. **Main user goal remains unresolved:** cancel downloads already queued by Finder/macOS, rather than merely manage requests created inside this app.

- [x] Establish the native Xcode app, shared Swift modules, scoped access, default dry-run policy, Tidal identity, and actual Icon Composer source.
- [x] Remove the production sample-data/Demo path; validate real-folder discovery, read-only diagnostics, responsive large-library rendering, and Settings.
- [x] Create signed local C1 `cd1afcf094cfc7bfcb5049f44451d58b3f0eebd4` — `feat: add native iCloud Drive monitoring app`.
- [x] Add passive row hover cards; source/build checks passed, user confirmed actual card appearance; create signed local C2 `da80b9bc6e2c1e2401e26a47fc8e166dad0afe52` — `feat(ui): add passive hover cards to app rows`.
- [x] Identify the material contract gap: diagnostic downloading records are not the full Finder backlog, and app-request controls cannot cancel pre-existing system requests.
- [x] Create signed local C3 `94ddafbccb8463a1759ff4c35a4ce6484c23034e` — `fix(sync): separate system backlog from diagnostic records`, preserving the unresolved main use case and red persistence gate.
- [ ] **Active:** Verify a supported mechanism for observing and cancelling the user's actual Finder-queued operation. In parallel, validate the read-only display correction and diagnose its reproduced protected-bookmark round-trip failure without weakening protection or test expectations.
- [ ] Implement and independently validate any agreed cancellation path, or report the specific platform limitation and obtain direction; never substitute eviction, upload pause, daemon control, or local row removal.
- [x] Refresh and verify the C3 universal app/archive; preserve a truthful documentation progress milestone with current failed gates stated.
- [ ] Resolve the current functional/test gates and refresh their acceptance before claiming overall delivery.
- [ ] Handoff with unresolved platform/action and distribution qualifications stated explicitly.

The actual queued file/folder target question remains unanswered. Read-only candidate inspection has not established current queue membership or a valid cancellation target; no transfer action has been attempted.

## Phase ownership

| Owner | Responsibility |
|---|---|
| Integration | Model/client lifecycle, native build/test/runtime, exact app identity, artifacts, and exclusive staging/committing |
| Backend research | Public API contract, provider diagnostic grammar, typed snapshots, and focused parser tests |
| Native service | Same-app authorization, fixed read-only command allowlist, public progress registry, session/run loop, privacy |
| Native UI | System downloads as primary view; separate backlog, batches, diagnostics, app requests, and on-demand file browser |
| Agents Orchestrator / Project Shepherd | Independent material review, source/actual-evidence distinction, concise canonical documentation and quality gates |

## Required contracts

The primary system view must not present dozens of explicit downloading records as a complete list of queued files or compare that count directly with Finder's byte total. Provider backlog, published batches, and brctl records remain separate and may overlap. Logical size is not remaining network traffic. Unknown direction/capabilities remain unknown; no English-description inference or unverified cancellation control is permitted.

The new service methods remain read-only and argument-free. Diagnostic subprocesses are internally allowlisted, have a 128 MiB output cap, serialize without duplicate same-kind reads, and have no hard elapsed-time deadline. Localized published descriptions may contain names and must remain local, memory-only, and unlogged. The main app stays sandboxed; the helper is unprivileged, same-user, and validates its enclosing app.

Detailed resource metadata starts only on opening the file browser. Its 60-second notice is soft; Continue preserves the scan, Cancel stops only app discovery with partial results. Existing live app-request actions keep default dry-run, explicit mode selection, shared Yes/No policy, and an independent queue guard. No real cloud mutation is used for validation without explicit authorization.

## Evidence and completion boundary

C1/C2 checks and artifacts remain preserved evidence for those milestones, not proof that the clarified primary use case is satisfied. Public Progress documentation and the installed SDK expose cooperative published-operation cancellation, not a general complete Finder queue API. The observed aggregate advertised cancellation and pause unavailable. Per-item pause on macOS 26 also affects uploads, persists, and is not queue cancellation. Eviction changes local data and is not a substitute.

Current read-only source review, exact-command parser acceptance and actual primary-panel observation passed. An earlier 42-test run passed; the latest full check and a narrow recheck reproduce one protected-bookmark round-trip reopening failure at two assertions (Cocoa 257/POSIX EPERM). All 36 core and 3 hosted app tests pass, including compilation of the final error/stale-label adjustment. A standalone Foundation probe reproduced class-B `.completeUnlessOpen` reopening failure in both temp and workspace while ordinary/class-C writes read back. Current exact-app inspection also shows bookmark restoration failure despite successful process launch. Preserve the record; selecting the same folder is not an established fix. The underlying cause remains unestablished; no protection or test contract is weakened. Final Debug build/exact-path launch and universal Release build succeeded separately; current C3 binary/signature/archive checks passed for both universal binaries and the extracted archive. ZIP SHA256 is `266cd63cbb1d00f564264f68d68f9474ebd37561fcf6a2497fe1984cfe6625c0`. These successes do not close the failed persistence gate. The observed app panel showed 84,632 items / 256.91 GB logical size and file sections Not scanned, with no Finder cancellation control. Documentation records a progress milestone with these open gates; no main-goal completion or final handoff is claimed. No push, publication, release, account change, data deletion, helper installation, daemon restart, or index repair is authorized. Cross-OS/Intel runtime, full accessibility, affirmative live requests, actual No/close and discovery Cancel, Developer ID/notarization, and complete provider coverage remain qualifications.
