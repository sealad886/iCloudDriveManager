# Compliance design mapping

This document maps technical design decisions to relevant privacy and assurance themes. It is not a certification, independent audit, legal opinion, or claim of conformance. The application has no remote service, centralized identity, or payment processing.

## GDPR themes

The [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng) is the primary reference. The controller and applicable obligations depend on actual deployment; see [DPIA-lite](dpia-lite.md).

| Theme | App design | Evidence or remaining obligation |
|---|---|---|
| Lawful basis | User selects a scope and requests operations | Operational permission is not a universal legal basis; organizational controller documents its own basis |
| Data minimization and purpose limitation | On-demand selected-folder metadata, separate provider/account aggregates, and public progress descriptions; no file-body reads or vendor collection | Raw CLI output stays in bounded helper memory; published descriptions may contain names and remain local/unlogged; review real-account behavior and undocumented format support |
| Transparency | Default dry-run, explicit live-action Settings/Yes/No, selected-folder versus whole-account scope, queue and coverage limitations | Current real-data UI acceptance and accessibility review remain required |
| Access and portability | Metadata shown locally; original files remain under user control | No built-in export; a deployer must provide any applicable rights workflow |
| Rectification | The app does not edit document names or contents | Use Finder or the owning app; controller handles requests where applicable |
| Erasure and retention | In-memory snapshots/queue; disconnect removes remembered bookmark | Does not delete iCloud files, local document copies, or external backups |
| Restriction and objection | User can disconnect and stop app-owned waiting submissions | Already submitted system requests can continue; no vendor processing service to disable |
| Security of processing | Scoped access, containment checks, local file permissions, no secret collection | Device encryption, account security, release signing, and physical acceptance remain deployment responsibilities |
| Cross-border transfers | App creates no vendor data transfer | Apple iCloud and organizational usage require their own account/service assessment |

## OWASP ASVS themes

[OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) is primarily an application verification standard. The following is a thematic mapping for a native local app, not a claim against a specific ASVS version or level. Web-specific requirements such as cookies, CSRF tokens, browser security headers, and server sessions do not apply to this architecture.

| Theme | Native equivalent | Evidence |
|---|---|---|
| Architecture and threat modeling | Explicit process, filesystem, and platform boundaries | [Architecture](architecture.md), [threat model](security.md) |
| Authentication | macOS user session and Apple-managed account authentication | No app credentials or JWT implementation |
| Session management | Scoped folder access and process-lifetime queue | Latest protected-bookmark round-trip test and actual restoration fail; preserve record and investigate without weakening protection |
| Access control | Canonical root containment plus per-request validation; same-user signed enclosing-app XPC client | Path/requester tests and actual nested-service authorization acceptance |
| Validation and encoding | URLs and resource values validated; names treated as display strings | Classifier and containment tests; no shell interpolation of names |
| Error handling and logging | Local recoverable errors, no sensitive application logging | Source review and diagnostic acceptance |
| Data protection | In-memory metadata; minimal protected bookmark store | Persistence tests; macOS device configuration controls at-rest encryption |
| Communications | No app network client; iCloud transport belongs to macOS | No server TLS or HTTP headers to configure |
| Malicious code and dependencies | Apple system frameworks, no third-party runtime packages | CI/source review; signed/notarized distribution still pending |

## SOC 2-style themes

These are engineering themes, not a SOC 2 report or assertion about an operating organization.

| Theme | Design support | Remaining operational work |
|---|---|---|
| Security | Least folder privilege, no privileged helper or account secrets | Signing, notarization, vulnerability response ownership |
| Availability | Local operation; unavailable metadata/diagnostics remain visible | Provider outages, diagnostic format changes, and network availability remain external dependencies |
| Confidentiality | No vendor backend/analytics, no file-body access | Device encryption and user-session protection |
| Processing integrity | Deduplication, explicit queue states, metadata-confirmed completion | Real-provider acceptance and large-library profiling |
| Privacy | Minimal retention and user-controlled disconnect | Deployment-specific notices, rights handling, and DPIA decision |

MFA belongs to the user's Apple Account and organizational device policy. The app neither configures nor verifies MFA. It provides no central audit trail, backup service, or availability SLA.

## Frameworks outside this MVP

HIPAA, PCI DSS, ISO 27001 certification, and EU MDR are not assumed. The app has no clinical purpose, payment flow, or organizational ISMS. Metadata can still be sensitive; a regulated organization must assess its own deployment and controls before use. No specialized compliance status is implied.
