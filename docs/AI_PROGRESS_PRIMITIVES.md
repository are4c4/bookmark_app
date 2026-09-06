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

Branch / PR:
- `feature/primitives-file-capability-484`
- PR #512 — `Add canonical File primitive and shared file-backed capability`

Implemented in PR #512:
- canonical system `File` ObjectType service with managed File identity, original filename, normalized content type, extension, byte size, and imported timestamp;
- profile/Vault-relative stored-path normalization through the existing `ProfilePathResolver` contract;
- deterministic File reimport reuse by canonical stored path while preserving existing non-empty metadata;
- generic Object creation facade boundary `createFileFromManagedFile(...)`, with title-only generic/Board creation fail-closed for the File system type;
- reusable read-only `ManagedFileResolver` for stored-path resolution, existence/type probe, current byte size, modified time, and portable stored-path conversion;
- canonical Image visual resolution now reuses the shared managed-file resolver without changing Image identity, editing, deletion, geometry, or ownership semantics;
- read-only `FileManagedResourceResolver` adopts the same file-backed capability for canonical File presentation/open/reveal/export hosts;
- one `PrimitiveFileImportClassifier` implements #495 routing precedence `content signature > meaningful MIME > extension fallback`, routing supported JPEG/PNG/GIF/WebP/HEIC/HEIF to Image and PDF/ZIP/unsupported/unknown content to File;
- diagnostics for new file capability/classification code do not log raw user file paths or exception text.

Tests added:
- `test/managed_file_resolver_test.dart`
- `test/file_object_service_test.dart`
- `test/generic_database_file_create_service_test.dart`
- `test/primitive_file_import_classifier_test.dart`
- `test/file_managed_resource_resolver_test.dart`
- existing `test/image_visual_resolver_test.dart` remains the Image regression boundary after shared resolver adoption.

Validation:
- repository maintainability guardrail tests pass on PR #512;
- maintainability regression ceilings pass;
- Drift generation passes;
- the first CI analyze run exposed only two invalid `const` constructors introduced around runtime resolver composition; both were corrected without behavior changes;
- latest full analyze/test CI must be green before merge; local Flutter validation is unavailable in this execution environment.

Hotspot / concurrency notes:
- PR #512 deliberately does not edit `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, or Relation internals;
- File UI create-mode wiring is intentionally deferred until a canonical managed-copy/import boundary is composed, avoiding a visible but unusable system collection;
- open Image editing work was checked before this slice; the shared Image change is limited to read-only path/existence resolution.

Exact next actions after PR #512:
1. Compose a single managed import orchestration boundary for #495 that classifies one user action and delegates to exactly one canonical Image or File identity path.
2. Coordinate generic File copying/ownership/safe deletion with the Storage/Vault lane, reusing the existing profile attachment boundary where appropriate rather than inventing another filesystem subsystem.
3. Once that import boundary exists, expose File creation in the generic Database host with a patch-sized hotspot lease and add open/reveal/export behavior through the shared file-backed capability.
4. Add PDF-on-File enrichment/preview in optional capability services; do not create a PDF ObjectType or persistence model.
5. Continue #245 Image real-host parity / legacy Photo retirement and #155 Weblink legacy retirement only where replacement paths are already proven and concurrent hotspot ownership is clear.

## Handoff checklist
Record active Issue, branch/PR/commit, tests, native capability/storage dependencies, hotspot ownership, exact next actions, and stop reason.
