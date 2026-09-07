# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, `docs/AI_PROGRESS.md`, active issues, and current open PR/CI state before editing. Recheck Object/Relation/Database/Storage/Refactor ownership before touching shared hotspots.

## Lane goal
Provide built-in Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined domain schemas without parallel persistence systems.

## Primary active issues
- #155 — reusable Weblink identity/metadata/media and legacy Bookmark convergence.
- #245 — legacy Photo -> canonical Image migration.
- #484 — primitive boundary and canonical File.
- #489 — capability-oriented shared native behavior.
- #495 — MIME/content-aware Image/File import routing.

## Product contract / lane boundary
Image and File remain distinct ObjectTypes while sharing managed-file/native capability infrastructure. PDF remains a File Object with optional preview/metadata/page-count/text behavior; no PDF-specific storage model is allowed.

Lane C owns generic Database/View settings/hosts. Lane B owns Relation lifecycle integrity. Lane F owns Vault/filesystem lifecycle, managed-copy ownership, backup/restore and storage switching. Lane E owns search indexing; Lane D only supplies derived File/PDF capability.

Do not infer File byte ownership from path location. Generic File physical deletion remains blocked until Storage supplies an explicit ownership grant.

## Current checkpoint — 2026-09-07

### Weblink
`WeblinkObjectService` owns canonical URL normalization/reuse and missing-only metadata enrichment. Merged #634 resolves relative OpenGraph/favicon resources against the final redirected response URL while preserving requested-URL identity. Enrichment remains fail-soft.

Merged #693 (`335a9c49fcbe4cba875aa31d3b84e59f92a00430`) keeps `WeblinkVisualResolver` responsible only for fail-closed, read-only Representative Image Relation selection and delegates the target Image's managed path/existence/persisted geometry read to the existing `ImageVisualResolver`. It uses `probeMissingGeometry: false`, preserving Weblink cards' previous persisted-metadata-only behavior without introducing image-byte decoding. Flutter CI #2169 passed guardrails, Drift generation, Analyze and the full test suite before merge.

### Image / Photo migration
Canonical Image import/provenance/geometry/editing/deletion safety is established. Merged #652 canonicalized legacy Photo paths through the active profile/Vault resolver. Merged #675 (`08d46d599c717b57f608159c5b106e836034e911`) aligned native Image creation/reimport with the same portable stored-path identity while preserving historical non-empty absolute values and external absolute references.

Merged #692 (`91824121156fbfebfa260b09d80e604d5923d8ab`) adopted the shared `ProfilePathResolver.canonicalStoredPath(...)` operation inside `ImageObjectService`, removing its remaining duplicate `resolveStoredPath -> toStoredPath` composition while preserving Image-specific empty-path validation, managed absolute/relative convergence, external absolute references, source provenance and concrete Image identity. Flutter CI #2159 passed maintainability guardrails, legacy dependency guard, Drift generation, Analyze and the full test suite before merge.

Legacy Photo migration remains compatibility-sensitive. `CoreObjectBridge` intentionally retains its special relative-path/no-profile-root gate; replacing it mechanically with `ManagedFileResolver.resolveExisting(...)` would change migration semantics. Refactor PR #695 currently touches legacy `PhotoManagementPage` imports, so Lane D should not edit that hotspot without a fresh ownership check. Do not hide/remove legacy Photo persistence or navigation until Bookmark/People authority and write parity are proven.

### Canonical File / shared managed-file capability
Canonical File identity/metadata, open/reveal/export and deterministic path-based reimport are established. Merged #671 (`26600dbafb119b35f5e33ceb48217a8535603714`) proves File Object deletion preserves physical bytes without an explicit Storage ownership grant.

Merged #679 (`f2782dd860ded896cd8d6eb5ddb6bc66015a1a30`) centralized portable stored-path identity as `ProfilePathResolver.canonicalStoredPath(...)` and exposed the operation through `ManagedFileResolver`.

Merged #682 (`7cee922adf82d7daf15c4b44657b6b77d266d0f2`) added `CanonicalFileManagedResourceResolver`, preventing native File/PDF capability from activating on arbitrary custom ObjectTypes that merely contain a File-shaped Property.

Merged #688 (`792fb4d58701785dba2f4d9768c6f2cf1fe363a6`) adopted the shared `canonicalStoredPath(...)` operation inside `FileObjectService`, removing duplicate path composition while preserving File-specific validation and identity. Flutter CI #2147 passed maintainability guardrails, legacy dependency guard, Drift generation, Analyze and the full test suite before merge.

Current PR #697: `fix/primitives-file-imported-at-enrichment-484`
Current production+test commit on top of merged #693: `6cebaa583bce4415335ac0ce6a489923973e40a0`

#697 closes one missing-only File metadata gap: a canonical File reused by equivalent stored-path identity already filled missing filename/MIME/extension/size metadata but left a missing `Imported at` empty forever. Reimport now fills only a missing timestamp from the provided/current import time, while the existing regression continues to prove a non-empty earlier timestamp is preserved. The focused regression seeds a path-only canonical File, reimports through an equivalent absolute path and proves Object identity reuse plus timestamp enrichment. No filesystem ownership or byte lifecycle changes are involved.

### MIME/content import routing
`PrimitiveObjectImportService` validates a real regular-file source, classifies it content-first and delegates exactly once to Image or File; selected-importer failures never fall through.

Merged #665 expanded strong signatures for common non-Image/unsupported-Image formats. Merged #684 (`aa0eefe5be1da730a7af94f0b26c7a6cdd58659f`) closes the existing-path extension-only gap: if real source bytes do not identify a supported Image and routing evidence falls back only to filename extension, production path import fails closed to generic File. Direct classifier extension fallback remains available when content is genuinely unavailable. #684 CI #2134 passed before merge.

A fresh #495 audit found no additional concrete classifier defect worth widening the routing surface. End-to-end generic File import remains intentionally blocked on a Lane F-owned managed-copy + explicit ownership seam for arbitrary source files. Lane F PR #691 currently changes only Vault move/reopen migration behavior and does not add that seam. Lane D must not duplicate attachment/Vault copy/delete lifecycle or create a second managed-file root.

### PDF-on-File
PDF remains canonical File. Available capability services cover content-verified metadata, transient Quick Look preview bytes, Spotlight text extraction, page count, Search-derived text projection, and File open/reveal/export. The current PDF services already consume canonical File managed-resource resolution plus content-first classification. No separate PDF persistence/search/storage route is needed.

### Tag
`TagObjectBridge` keeps built-in Tag on canonical Object storage; parent hierarchy is a normal self-Relation through canonical Relation APIs. Native Tag name uniqueness/identity remains intentionally undefined until product semantics are explicit.

## Validation / CI
Recent Lane D merges #665, #671, #675, #679, #682, #684, #688, #692 and #693 passed normal Flutter CI before integration. #688 CI #2147, #692 CI #2159 and #693 CI #2169 passed guardrails, Drift generation, Analyze and full tests.

Local Flutter/Dart execution is unavailable in the connector-only runtime. PR #697 has been cleanly restacked onto merged #693/current main with its focused File regression; require normal Flutter CI on the resulting current head before merge. Any CI from its pre-restack head is obsolete.

## Hotspot / concurrency state
No shared hotspot lease is required for #697. Current work stays in primitive data/service/test/docs. Avoid `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `people_management_page.dart`, `photo_management_page.dart`, Relation internals and Vault lifecycle code while other lanes own or actively touch those boundaries.

Open-PR audit at this checkpoint found no competing Lane D owner for `FileObjectService`. Lane F PR #691 is confined to Vault move/reopen and legacy storage migration; Refactor PR #695 is confined to legacy Photo presentation imports. Neither overlaps #697.

## Exact next actions
1. Require green Flutter CI on the current #697 head and merge only that verified head.
2. After #697, audit #489 managed-file/native capability consumers only for another concrete duplication or fail-open boundary; do not add speculative abstractions.
3. Continue #495 only for concrete classification ambiguities. End-to-end File import waits for the Lane F managed-copy/ownership contract.
4. Coordinate with Lane F on File managed-copy + explicit ownership before generic File import/delete lifecycle.
5. Coordinate with Lane C for generic File import/create UX and File/Image presentation hosts rather than editing Database/View hotspots from Lane D.
6. Continue #245 Photo retirement and #155 legacy Weblink retirement only where replacement parity is proven and hotspot ownership is clear.
7. Keep Tag hierarchy on canonical Relation APIs; defer native Tag uniqueness semantics until explicitly defined.

## Cross-lane dependencies / blockers
- Lane F: managed-copy location, ownership grant, delete/move semantics, Vault portability/recovery.
- Lane C: generic Database/View File import/create and presentation UX.
- Lane B: Relation lifecycle correctness for primitive-producing Relation workflows.
- Lane E: Search owns index persistence/reconciliation.

Pending CI alone is not a stop condition; independent primitive service/domain/test work should continue when available.
