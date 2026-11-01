# DPIA-lite

## Project overview

A local macOS app helps a person inspect the iCloud synchronization metadata for a chosen folder, view provider backlog, published transfer batches and separate diagnostic records, and request local downloads. Cancellation of Finder’s pre-existing queue remains unresolved. Every launch starts in dry-run; live actions require explicit Settings selection and the configured confirmation. The app has no vendor backend, telemetry, advertising, user registration, or document-content processing.

This is a design assessment for the implemented data flows. An organization deploying the app must assess its own purposes, legal role, users, and document categories before relying on it.

## Data subjects and categories

The user and people identified in their file names or directory structure may be data subjects. Metadata includes file names, relative paths, file sizes, modification dates, transfer state, and error descriptions. Lists, the inspector, and transient hover cards display already observed values locally; hovering adds no metadata/network collection. A folder bookmark is an opaque local access capability. The app does not read file bodies, although a user-requested download can cause macOS to store the document locally.

File names can reveal health, employment, financial, or other sensitive subjects. No assumption that metadata is harmless should be made.

## Purposes and lawful basis

The processing purpose is local inspection and user-directed download management. The user deliberately chooses a folder and invokes a request. This interaction supplies operational authorization; it does not by itself establish a GDPR lawful basis for every organizational deployment.

For a personal user's purely personal or household activity, the GDPR household exemption may be relevant. A business or other controller must determine and document its own applicable lawful basis and any additional conditions for special-category data. The design does not select a universal lawful basis or make a compliance claim. See the [GDPR text](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng), particularly Articles 2, 5, 6, 9, 25, 32, and 35.

## Data flow

1. A macOS folder picker receives the user's selected root.
2. A security-scoped bookmark is persisted locally to remember that access.
3. Opening a selected-folder browser starts Foundation metadata discovery for that scope. System downloads is the default view and does not automatically initiate per-file resource probes.
4. The embedded unprivileged XPC service reads fixed local brctl status and provider-filtered fileproviderctl dump output, which can include private names and account metadata, in bounded memory. Only diagnostic aggregates return from these raw reads. Public Progress observation separately returns macOS localized descriptions, public kinds, byte counts when file-kind, and advertised capabilities. Descriptions can include private names and cross XPC for local memory-only display. Neither descriptions nor raw output are logged, persisted, or sent to an external service. The published-description reply is local IPC, distinct from a user export or remote disclosure feature. No hard elapsed-time deadline applies; each raw output is capped at 128 MiB.
5. Dry-run records an intended request as a plan. An explicit eligible live download request, after the configured Yes/No decision, is passed to macOS. Apple manages transport and the resulting local document copy.
6. Quitting removes in-memory observations and queue history. Disconnect removes the app's remembered folder record. The local Ask each time preference remains until changed; live mode never persists.

The app has no export, remote analytics, crash upload, or external sharing feature. Apple's existing iCloud processing is a separate service relationship controlled by the user's account and settings.

## Risks and mitigations

| Risk to a person | Design response | Remaining assessment |
|---|---|---|
| Sensitive names appear to someone viewing the screen | Local display only; system account permissions; no automatic exports | Shared-screen and unattended-device procedures belong to the user/deployer |
| An unintended download increases local availability of sensitive material | Default dry-run, explicit live setting and confirmation policy; scope/eligibility revalidation; no automatic job replay | Device encryption and local backup behavior require deployment review |
| Stale metadata leads to mistaken assumptions about availability | Distinguish current, stale, unknown, error, and incomplete query coverage | Real-account acceptance remains required |
| A bookmark or diagnostic exposes access details | Bookmark mode `0600`; bounded raw diagnostic memory in same-user helper; raw-output-free diagnostic replies, memory-only published descriptions; no bookmark/path logging or remote telemetry | Source review and actual embedded-client response passed; distribution security still requires qualification; device compromise is outside the app's control |

## Retention and deletion

Snapshots and request history stay in process memory only. The selected folder bookmark remains until replaced or disconnected. Its versioned record is `Application Support/iCloudDriveManager/connection.json`, inside the sandbox container for the bundled app.

Disconnect removes app access state, not user documents. Removing a bookmark does not cancel a request already submitted to macOS, remove a downloaded file, remove iCloud copies, or erase backups. Those operations remain under normal macOS and account controls.

Access and portability of app state are limited to the displayed metadata and the user's own filesystem; this MVP has no export function. Rectification of document names or content happens through Finder or the owning app. There is no remote vendor record to delete in this architecture.

## Is a full DPIA required?

A general conclusion cannot be drawn for every deployment. This local, user-directed design does not itself include large-scale profiling, automated decisions, or a central metadata collection service. A controller must still assess Article 35 criteria and applicable supervisory-authority lists against its actual use, scale, and data sensitivity. A change adding telemetry, shared administration, or remote indexing requires a renewed assessment.
