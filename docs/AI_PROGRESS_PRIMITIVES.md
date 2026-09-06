# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, `docs/AI_PROGRESS.md`, the active issues, and current open PR/CI state before editing. Recheck Object/Relation/Database/Storage/Refactor ownership before touching shared hotspots.

## Lane goal
Provide a small set of built-in primitive ObjectTypes whose irreducible native behavior can be composed by user-defined domain schemas without introducing parallel persistence systems.

## Primary active issues
- #155 — Weblink reusable Object, URL identity/normalization and legacy Bookmark URL/media convergence.
- #245 — legacy Photos -> canonical Image Objects.
- #484 — built-in primitive boundary and canonical File Object.
- #489 — capability-oriented shared native behavior.
- #495 — MIME/content-aware import routing to Image or File.

## Product contract / lane boundary
Built-in primitive targets are Weblink, Image, File and Tag. Image and File remain distinct ObjectTypes while sharing managed-file/native capability infrastructure. PDF is a File Object with optional MIME/content-derived preview/metadata/page-count/text capabilities, never a separate persistence or storage model.

Lane D owns Weblink identity/enrichment, Image identity/provenance/import/editing and Photo compatibility migration, canonical File product semantics, primitive-native capability services, MIME/content routing and PDF/File preview/metadata/text extraction behavior. Lane C owns generic Database/View settings and host UX. Lane B owns Relation lifecycle integrity. Lane F owns Vault/profile filesystem lifecycle, managed-copy ownership, backup/restore and storage-location switching. Lane E owns search indexing; Lane D only supplies File/PDF derived text capability.

Do not create a second generic managed-file root. Do not infer File byte ownership from a path such as `attachments/`; a Storage-owned explicit managed-copy/ownership contract is required before generic File deletion can remove physical bytes.

## Current implementation checkpoint — 2026-09-07

### Weblink
Canonical `WeblinkObjectService` owns URL normalization/reuse and missing-only metadata enrichment. Normalization remains intentionally conservative: scheme/host case, default HTTP(S) ports, dot path segments and empty HTTP(S) root paths are canonicalized while query and fragment content remain identity-significant.

Merged #634 resolves relative OpenGraph/favicon resources against the final redirected response URL while keeping Weblink/Bookmark creation identity anchored to the normalized requested URL. Metadata fetch failures remain best-effort/fail-soft.

### Image / Photo migration
Canonical Image import, source provenance, geometry, Gallery/detail presentation, edit/restore ownership checks and managed-file delete safety are established. Legacy Photo mirroring remains compatibility-only and continues to use the canonical Image ObjectType.

Merged #652 canonicalizes legacy Photo paths through the active profile/Vault path resolver during Photo -> Image promotion. Managed absolute legacy paths therefore converge with relative canonical Image identity while external absolute paths remain external.

Merged #675 (`08d46d599c717b57f608159c5b106e836034e911`) extends the same contract to native Image creation/reimport:
- new profile-managed Images persist portable profile-relative File paths;
- absolute and relative representations of the same managed file reuse one Image Object;
- older non-empty absolute Image File values are not opportunistically rewritten but still match relative reimports;
- external absolute references remain absolute;
- Image Object identity, Source URL identity, editing/deletion ownership and Relation behavior remain unchanged.

#675 CI #2114 passed maintainability guardrails, Drift generation, `flutter analyze` and full `flutter test` before squash merge.

### Canonical File / shared file-backed foundation
Canonical system File Object identity and metadata are implemented through `FileObjectService`; title-only generic creation is rejected and managed-path reimport is deterministic. `FileManagedResourceResolver` exposes existing-file metadata through the shared path resolver. `CanonicalFileActionService` provides open/reveal behavior and merged #641 adds export/copy-out behavior without rewriting canonical File identity.

Merged #671 (`26600dbafb119b35f5e33ceb48217a8535603714`) fixes the current destructive-safety boundary with production-path regressions: deleting a canonical File Object removes the Object but preserves physical bytes, including paths under the historical `attachments/` directory, until Storage supplies an explicit ownership grant. External File references are also preserved. CI #2105 passed guardrails, Drift generation, analyze and full tests.

Active #679 (`feature/primitives-canonical-stored-path-capability-489`, head `5dddb2704a06091d63112fd1f31ee86f40aa2768`) centralizes portable path identity:
- `ProfilePathResolver.canonicalStoredPath(...)` composes stored-path resolution and portable re-storage once;
- absolute/relative profile-managed paths converge;
- external absolute paths remain absolute;
- `ManagedFileResolver.canonicalStoredPath(...)` exposes the contract through the shared file-backed capability facade;
- existing `toStoredPath(...)` remains for callers already holding a resolved path.

#679 is infrastructure-only and does not move/copy/delete bytes or change Object identity. CI #2126 is running at this handoff.

### MIME/content import routing
`PrimitiveObjectImportService` validates each source, classifies it once and invokes exactly one canonical Image or File importer; selected-importer failure never falls through to the other primitive.

Merged #665 (`7b34fbd9be85b5586626b36103339b5b45ec8da0`) hardens the content-first classifier so misleading image filenames do not redirect known non-Image or unsupported-Image content into Image. Strong signatures now cover common audio/video/archive containers (WAV/AVI/Ogg/FLAC/MP3, MP4/QuickTime/M4V/M4A/3GPP, ZIP/gzip/7z/RAR) plus unsupported AVIF/BMP/TIFF/ICO, all routing to File. Supported JPEG/PNG/WebP/GIF/HEIC/HEIF remain Image. A router regression proves a `.png`-named MP4 calls File exactly once and never Image. CI #2097 passed guardrails, Drift generation, analyze and full tests.

Known follow-up under #495: when content probing succeeds but no known signature is recognized, the current classifier may still use a supported image extension as fallback. All currently supported Image formats have positive signatures, so a future small hardening slice should treat non-empty unknown probe bytes conservatively as File rather than trusting `.jpg/.png/...`.

### PDF-on-File optional capabilities
PDF remains canonical File throughout. Current production-capable services include:
- `CanonicalFilePdfMetadataService` for content-verified metadata;
- `CanonicalFilePdfPreviewService` for transient macOS Quick Look PNG preview bytes;
- `CanonicalFilePdfTextService` for optional macOS Spotlight text extraction;
- `CanonicalFilePdfPageCountService`, merged in #645, for optional positive page count;
- `CanonicalFilePdfSearchIndexer`, which projects extracted text into Search-owned derived text/FTS without creating PDF persistence;
- canonical File open/reveal/export behavior.

All PDF services resolve the managed File and reclassify content before enabling PDF-specific behavior. Preview/text/page count fail soft when unavailable and do not persist a separate PDF model.

### Tag
`TagObjectBridge` keeps the built-in `tag` system ObjectType on canonical Object storage. Parent hierarchy is a normal self-Relation written through `RelationMutationService`; there is no parallel tag-edge engine. Legacy Tag ids/groups remain compatibility metadata. Do not invent native Tag name-based identity/uniqueness until the product rule is explicit.

## Validation / CI
Recent Lane D verification:
- #634 Weblink redirect metadata: merged after green full CI.
- #641 File export: merged after green full CI.
- #645 PDF page count: merged after green full CI.
- #652 Photo path canonicalization: merged after green full CI.
- #665 import signature routing: CI #2097 green, merged as `7b34fbd9...`.
- #671 File byte-preservation deletion boundary: CI #2105 green, merged as `26600dba...`.
- #675 Image stored-path identity: CI #2114 green, merged as `08d46d59...`.
- #679 shared canonical stored-path capability: CI #2126 running at this handoff.

## Hotspot / concurrency state
No shared hotspot lease was used for the Lane D work above. Changes stayed in primitive data/service/test files and this handoff. `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `main.dart` and Relation internals were deliberately avoided while other lanes are active.

Do not add a File `managedFile` generic create-mode by itself: `GenericDatabaseCreateMode` is consumed by `generic_database_page.dart` presentation switches, so end-to-end generic File import UX must coordinate with Lane C and the Storage-owned managed-copy boundary rather than partially changing the UI contract.

## Exact next actions
1. Finish #679: require green guardrails/Drift/analyze/full tests; merge only the verified head.
2. Adopt `ProfilePathResolver.canonicalStoredPath(...)` in `FileObjectService` and `ImageObjectService` in patch-sized follow-ups, removing their duplicate `resolveStoredPath -> toStoredPath` composition while preserving concrete primitive identity.
3. Harden #495 unknown-probed-content routing: if non-empty bytes have no recognized supported Image signature, route conservatively to File instead of trusting an image extension; keep no-content/MIME fallback behavior for unavailable probes.
4. Strengthen `FileManagedResourceResolver` so native File/PDF capabilities fail closed unless the ObjectType is the canonical system File type; today its low-level resolver expects callers to verify this boundary.
5. Coordinate with Lane F on a canonical File managed-copy + explicit ownership seam. Only after that, compose `PrimitiveObjectImportService` with the Storage-backed File importer and enable end-to-end generic File import/delete lifecycle.
6. Coordinate with Lane C for the generic File import/create affordance and File presentation host; avoid unilateral edits to `generic_database_page.dart`.
7. Continue #245 real-host Image parity / legacy Photo retirement and #155 legacy Weblink retirement only where replacement parity is proven and hotspot ownership is clear.
8. Keep Tag hierarchy on canonical Relation APIs; defer native Tag uniqueness/quick-create semantics until explicitly defined.

## Cross-lane dependencies / blockers
- Lane F: canonical File managed-copy location, ownership grant, delete/move semantics, Vault portability and recovery.
- Lane C: generic Database/View presentation and File import/create host UX.
- Lane B: Relation lifecycle correctness for any primitive-producing Relation workflow.
- Lane E: Search owns index persistence/reconciliation; Lane D owns PDF text extraction only.

These dependencies block only their specific integration surfaces. Independent primitive service/domain/test slices remain available.

## Stop reason
Stop only for an actual execution/tool limit, unresolved safety/ownership ambiguity, or when no independent safe Lane D slice remains. Pending CI alone is not a stop condition.

## Handoff checklist
Record active Issue, branch/PR/commit, tests/CI, native capability/storage dependencies, hotspot ownership, exact next actions and actual stop reason.
