# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` first. Recheck current Object/Storage/Refactor PR ownership before editing shared media/storage code.

## Lane goal
Provide a small set of built-in primitive ObjectTypes whose irreducible native behavior can be composed by user-defined domain schemas.

## Primary active issues
- #155 — Weblink reusable Object and legacy Bookmark URL/media convergence.
- #245 — legacy Photos -> canonical Image Objects.
- #484 — built-in primitive boundary and canonical File Object.
- #489 — capability-oriented shared native behavior.
- #495 — MIME/content-aware import routing to Image or File.
- #481 only where primitive detail composition must expose the universal Body owned by Object Core.

## Product contract
Built-in primitives currently target:
- Weblink
- Image
- File
- Tag

Daily Note is a special workflow, not a general media primitive. Bookmark/Paper/Book/Project/etc. should normally be user-owned/template domain types.

## Owns
- Weblink URL identity/normalization/enrichment.
- Image identity/provenance/import/editing and Photo compatibility migration.
- Canonical File Object identity/import/open/reveal/export behavior.
- Shared managed-file/native capability services where domain-semantic.
- MIME/content classification and PDF/File enrichment behavior.
- Tag built-in defaults/quick-create semantics where not Relation-integrity work.

## Boundary with Storage lane
- Primitive lane owns Object identity/product semantics and capability contracts.
- Storage lane owns Vault/Profile directory lifecycle, filesystem portability, backup/restore, and storage-location switching.
- Shared managed-file path/ownership helpers require explicit coordination; do not create duplicate filesystem abstractions.
- Existing profile storage already manages generic legacy attachment copies under `<profile>/attachments`; future canonical File copy/delete lifecycle should reuse or deliberately evolve that boundary with Storage/Vault ownership rather than introduce a second generic file root.

## Current implementation checkpoint
Canonical Image is already advanced: managed import/reuse, legacy Photo mirroring, Bookmark Images/Cover Image Relations, safe preview/edit ownership, rotate/flip/restore/crop and geometry fallback are integrated. Remaining Image work should focus on shared-host parity and legacy Photo write/navigation retirement, not another Image persistence model.

### 2026-09-07 — canonical File / shared file-backed foundation
Active implementation: #484, #489, #495.

Merged foundation:
- PR #512 — `Add canonical File primitive and shared file-backed capability`, merged as `29cc878f8b13b4795506ca6a3d28fd192780b618`.

Implemented in #512:
- canonical system `File` ObjectType service with managed File identity, original filename, normalized content type, extension, byte size, and imported timestamp;
- profile/Vault-relative stored-path normalization through the existing `ProfilePathResolver` contract;
- deterministic File reimport reuse by canonical stored path while preserving existing non-empty metadata;
- generic Object creation facade boundary `createFileFromManagedFile(...)`, with title-only generic/Board creation fail-closed for the File system type;
- reusable read-only `ManagedFileResolver` for stored-path resolution, existence/type probe, current byte size, modified time, and portable stored-path conversion;
- canonical Image visual resolution now reuses the shared managed-file resolver without changing Image identity, editing, deletion, geometry, or ownership semantics;
- read-only `FileManagedResourceResolver` adopts the same file-backed capability for canonical File presentation/open/reveal/export hosts;
- one `PrimitiveFileImportClassifier` implements #495 routing precedence `content signature > meaningful MIME > extension fallback`, routing supported JPEG/PNG/GIF/WebP/HEIC/HEIF to Image and PDF/ZIP/unsupported/unknown content to File;
- diagnostics for new file capability/classification code do not log raw user file paths or exception text.

Validation for #512:
- maintainability guardrails, Drift generation, `flutter analyze`, and full `flutter test` passed before merge.

### 2026-09-07 — exclusive primitive import orchestration
Active branch / PR:
- `feature/primitives-import-router-495`
- PR #528 — `Add exclusive Image/File primitive import router`

Implemented in #528:
- adds `PrimitiveObjectImportService` as the single Image-vs-File orchestration boundary after classification;
- each source path is first required to be an available regular file, then classified through the canonical `PrimitiveFileImportClassifier`;
- delegates to exactly one injected canonical Image or File importer and forwards classifier-derived content type;
- selected-importer failure propagates and never falls through to the other primitive, preventing one user action from creating both Image and File Objects after a partial failure;
- non-positive Object ids returned by a delegate are rejected fail-closed without alternate-target retry;
- multi-file imports preserve source order, validate/classify each source independently, and perform exactly one delegation per source;
- no new filesystem-copy abstraction is introduced: managed File copying remains a Storage/Vault coordination dependency.

Focused tests in #528:
- disguised PDF named as an image routes only to File using content evidence;
- disguised PNG named as a document routes only to Image using content evidence;
- selected Image importer failure never falls through to File;
- missing source fails before either importer runs;
- invalid/non-positive delegate Object id fails without alternate primitive retry;
- mixed multi-file input routes each source exactly once and preserves source order.

Concurrency notes:
- a second overlapping PR #534 was detected during the latest concurrency audit and closed unmerged as a duplicate of #528;
- its two useful stricter checks were folded into #528 instead of keeping parallel router services;
- #528 edits only a primitive service, its focused test, and this handoff; it does not touch `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, Relation internals, Vault switching, or legacy Bookmark hosts.

Validation:
- the earlier #528 head passed maintainability guardrails, Drift generation, `flutter analyze`, and the full test suite;
- #528 was refreshed onto latest main and strengthened with missing-source/Object-id fail-closed checks, so the refreshed head requires CI again before merge;
- local Flutter/Dart validation is unavailable in this connector execution environment.

Exact next actions:
1. Fix/merge refreshed PR #528 only after CI is green.
2. Coordinate a Storage-owned canonical managed-copy callback for generic File imports, reusing/evolving the existing `<profile>/attachments` boundary rather than creating another generic file root.
3. Compose `PrimitiveObjectImportService` with the existing canonical Image import path plus that File managed-copy/create callback; add end-to-end duplicate/reimport/rollback coverage proving one user action creates only one primitive.
4. Once the import composition exists, expose File creation/import in the generic Database host with a patch-sized hotspot lease and add open/reveal/export behavior through the shared file-backed capability.
5. Add PDF-on-File enrichment/preview in optional capability services; do not create a PDF ObjectType or persistence model.
6. Continue #245 Image real-host parity / legacy Photo retirement and #155 Weblink legacy retirement only where replacement paths are already proven and concurrent hotspot ownership is clear.

## Stop reason
Current implementation checkpoint is refreshed PR #528. Independent File-copy composition is intentionally blocked on the Storage-owned managed-copy seam; do not invent a duplicate filesystem abstraction merely to continue.

## Handoff checklist
Record active Issue, branch/PR/commit, tests, native capability/storage dependencies, hotspot ownership, exact next actions, and stop reason.
