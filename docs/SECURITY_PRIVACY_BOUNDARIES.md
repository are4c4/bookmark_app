# Security and privacy boundaries

This document records the repository's current security/privacy trust model for the local-first desktop application. It is a review checklist and implementation contract, not a penetration-test certification or a replacement for focused subsystem tests.

Related: #1363, #225, #1358.

## Trust model

The application is a single-user, local-first desktop application. Local ownership does not make every input trusted.

### User-authored local state

Object titles, Bodies, Properties, Relations, Database/View configuration and other values intentionally authored inside the active Vault are trusted as user data for normal application semantics. They are still private and must not be copied into logs, support output, external requests or unrelated presentation by default.

### Remote Web content and URLs

Captured URLs, redirects, HTML metadata, favicons, thumbnails and other network-derived values are untrusted remote input.

Canonical Weblink/network code must own URL normalization, supported-scheme policy, redirect handling and metadata parsing. Presentation code must not create a second fetch path merely to render a URL. Remote input must not be allowed to turn a network operation into arbitrary local-file access or silently expose private request material.

### Imported files

Imported files and their filenames, MIME declarations, metadata and embedded content are untrusted input even when the user selected them intentionally.

Canonical Image/File and managed-storage boundaries own classification, path normalization and managed/external ownership. A filename or metadata field is display/input data, not authority to escape the managed root or overwrite an unrelated path.

### Repository fixtures

Repository-owned tests, synthetic benchmark fixtures and deterministic UI-audit fixtures are non-production data. They may contain paths/URLs designed to exercise contracts, but production code must not rely on their trust level.

## Boundary checklist

### Network

- Use the canonical Weblink/native-capability network boundary; do not add presentation-owned HTTP clients for convenience.
- Accept only schemes explicitly supported by the owning Weblink/opening contract. `file:` or other local-resource schemes must not become remote metadata-fetch inputs accidentally.
- Treat redirects as untrusted URL transitions and re-apply the owning boundary's validation when authority/scheme can change.
- Do not persist or display secret-bearing request headers, cookies, authorization material or raw client state as diagnostic metadata.
- Remote metadata remains data. It does not grant ObjectType, filesystem or execution authority.

### Files and paths

- Managed-file operations must normalize and resolve paths through the canonical storage boundary.
- Relative managed paths must remain contained by the active managed root after normalization; `..`, absolute-path injection, alternate separators or symlink-sensitive behavior must not silently escape ownership checks.
- An external file path is not proof that the application owns the bytes or may delete them.
- Normal UI should prefer user-meaningful names/status rather than host absolute paths.
- Support/diagnostic output should use stable categories, ids and counts where sufficient; include a raw path only when an explicit diagnostic/export contract requires it.

### Errors and diagnostics

- Presentation must map failures to stable operation-oriented messages rather than interpolating raw exceptions. `docs/FEATURE_PRESENTATION_ERROR_PRIVACY.md` and its CI guard remain authoritative for that boundary.
- Logs/support data must not include tokens, cookies, authorization headers or private request payloads by default.
- Diagnostic records should minimize user-authored Body/Property text and filesystem paths. Prefer subsystem/category, internal identifier, count and remediation guidance.
- Best-effort failures may remain non-blocking only when the behavior is explicit and tested; swallowing an error is not a privacy mechanism.

### Clipboard, export and external opening

- Clipboard/export intentionally crosses the local application boundary and therefore requires an explicit user action or product contract.
- Open export/portability is distinct from backup/restore and must follow its owning contract rather than leaking implementation files opportunistically.
- Opening external URLs/files should pass canonical validated identities/paths to the platform boundary; remote/imported text must not be interpreted as a command.

## Review and routing rule

Lane G owns this cross-cutting checklist and narrow deterministic guardrails. Product-specific defects remain with the owning subsystem:

- A — Object/ObjectType/Body identity and lifecycle;
- B — Relation integrity;
- C — Database/View/schema UX;
- D — Weblink/Image/File native network/import behavior;
- E — Search/indexing;
- F — Vault/filesystem/export/managed-byte lifecycle.

G must not create duplicate network, Relation, File or storage authorities under a security label. When an audit finds a concrete product defect, create/refine one focused owning-lane Issue and fix it through the canonical boundary.

## Evidence expected before #1363 closes

This checklist is only the documentation slice. #1363 remains open until current canonical boundaries have focused, high-confidence regressions for the applicable risks, including network scheme/redirect handling where supported, managed-path containment, and privacy-safe diagnostic presentation. The initial implementation must remain non-destructive and require no external telemetry/security service.
