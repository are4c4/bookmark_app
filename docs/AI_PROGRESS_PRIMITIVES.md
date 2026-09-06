# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` first. Recheck current Object/Storage/Refactor PR ownership before editing shared media/storage code.

## Lane goal
Provide built-in primitive ObjectTypes whose irreducible native behavior can be composed by user-defined domain schemas.

## Primary active issues
- #155 — Weblink reusable Object and legacy Bookmark URL/media convergence.
- #245 — legacy Photos -> canonical Image Objects.
- #484 — built-in primitive boundary and canonical File Object.
- #489 — capability-oriented shared native behavior.
- #495 — MIME/content-aware import routing to Image or File.

## Product contract / lane boundary
Built-in primitive targets are Weblink, Image, File and Tag. Image and File remain distinct ObjectTypes while sharing managed-file/native capability infrastructure. PDF is a File Object with optional MIME/content-derived capabilities, never a separate persistence/storage model.

Lane D owns Weblink identity/enrichment, Image identity/provenance/import/editing and Photo compatibility migration, canonical File product semantics, primitive-native capability services, MIME/content routing and PDF/File preview/metadata/text extraction behavior. Lane C owns generic Database/View configuration; Lane B owns Relation lifecycle integrity; Lane F owns Vault/profile filesystem lifecycle, portability, backup/restore and storage-location switching.

Do not create a second generic managed-file root. Existing profile attachment storage and Storage-owned Vault lifecycle are the coordination boundary for future canonical File managed copying.

## Current implementation checkpoint — 2026-09-07

### Canonical File / shared file-backed foundation
Merged PR #512 (`29cc878f8b13b4795506ca6a3d28fd192780b618`) established:
- canonical system File ObjectType identity and metadata;
- portable stored-path normalization through `ProfilePathResolver`;
- deterministic managed File reimport reuse;
- shared read-only `ManagedFileResolver` used by File and Image presentation;
- `FileManagedResourceResolver` for canonical File file-backed capability;
- `PrimitiveFileImportClassifier` with precedence `content signature > meaningful MIME > extension fallback`;
- content-aware routing of supported JPEG/PNG/GIF/WebP/HEIC/HEIF to Image and PDF/ZIP/unknown content to File;
- diagnostics that do not log raw user paths.

PR #528 (`Add exclusive Image/File primitive import router`) is merged. `PrimitiveObjectImportService` now validates/classifies each source and delegates exactly once to one injected canonical Image or File importer; selected-importer failure never falls through to the other primitive. Mixed multi-file actions preserve source order and one-delegation-per-source semantics.

The canonical Image path has also gained content-first classified import support, so image bytes with misleading filename extensions can still enter the canonical Image identity/provenance path without creating both Image and File Objects.

### PDF-on-File optional capabilities
Merged PR #557 (`Add PDF metadata capability on canonical File`) exposes content-verified PDF metadata through `CanonicalFilePdfMetadataService`; it reuses the existing PDF metadata reader while preserving canonical File identity.

PR #609 (`Expose canonical File PDF extracted-text capability`) is open on `feature/primitives-pdf-text-489`. It was rebased onto the latest main as commit `c24eb77a78c6e497a83f8d99dc197cc89f164212`; refreshed Flutter CI is running. The service:
- resolves the canonical managed File first;
- reclassifies with the content-first classifier before enabling PDF behavior;
- returns trimmed derived text keyed by canonical File Object id;
- treats blank/unsupported extraction as unavailable;
- uses macOS Spotlight `kMDItemTextContent` as the production reader;
- does not write a search index or introduce PDF persistence.

### Current run — transient PDF preview capability
Active branch: `feature/primitives-pdf-preview-bytes-489`
Latest code/test commit before this handoff update: `a4758d10bb47808d5a84ea3f276941e4e2108203`.

Implemented `CanonicalFilePdfPreviewService`:
- resolves a canonical managed File through `FileManagedResourceResolver`;
- verifies `application/pdf` with the shared content-first classifier before native preview work;
- derives a transient PNG preview on macOS through `/usr/bin/qlmanage`;
- returns immutable PNG bytes instead of persisting a preview file or creating a PDF Object/storage model;
- creates only an OS-temp output directory and removes it in `finally` on success/failure;
- treats unsupported platform, renderer failure, empty output and ambiguous Quick Look output as unavailable;
- does not log raw user file paths or exception text.

Focused tests added in `test/canonical_file_pdf_preview_service_test.dart` cover:
- disguised PDF bytes exposing preview despite generic stored MIME;
- conflicting PNG content with stored PDF MIME never invoking the PDF renderer;
- empty native preview being treated as unavailable.

This slice touches only a primitive capability service, its focused test and this handoff. It does not touch shared UI hotspots, Relation internals, Vault switching/storage roots, `app_database.dart`, or generic Database/View UX.

## Validation / CI
- #512 and merged predecessor slices passed maintainability guardrails, Drift generation, `flutter analyze`, and full `flutter test` before merge.
- #609 refreshed-head Flutter CI is currently running.
- The PDF preview branch requires Flutter CI after PR creation; local Flutter/Dart execution is unavailable in the connector-only environment used for this run.

## Hotspot / concurrency state
No shared hotspot lease is required for the active PDF capability slices. Open Lane A/C/F/G PRs own their respective service/UI/schema/storage work; this run intentionally stayed in primitive service/domain/test files. File managed-copy composition remains sequenced behind the Storage-owned managed-copy/Vault boundary rather than inventing duplicate filesystem infrastructure.

## Exact next actions
1. Open the PDF preview PR and require green Flutter CI; fix only failures caused by this slice.
2. Merge #609 after refreshed CI is green and mergeability is restored; do not block independent primitive work on its CI.
3. After preview/text capabilities are stable, compose them into a File presentation host only when a patch-sized host lease is available; generic View configuration remains Lane C.
4. Coordinate the Storage-owned canonical managed-copy callback for generic File imports, reusing/evolving the existing profile/Vault attachment boundary rather than adding another generic file root.
5. Compose `PrimitiveObjectImportService` with the canonical Image importer and Storage-backed File managed-copy/create callback; add duplicate/reimport/rollback coverage proving one user action creates exactly one primitive.
6. Continue #245 Image real-host parity / legacy Photo retirement and #155 Weblink legacy retirement only where replacement parity is proven and hotspot ownership is clear.
7. Evaluate Tag built-in quick-create/default semantics as an independent Lane D slice if File work is blocked; keep hierarchy edges on canonical Relation APIs.

## Cross-lane dependencies / blockers
- Lane F must own canonical managed-copy/Vault filesystem lifecycle before Lane D wires generic File import copying end-to-end.
- Lane E owns indexing of File/PDF derived text; Lane D only exposes the extraction capability.
- Lane C owns generic Database/View presentation settings and host UX; Lane D may supply primitive-specific preview/open/reveal behavior through capability services.
- Lane B owns Relation integrity for any new primitive-producing Relation workflows.

## Stop reason
This run should stop only if execution/tool limits are reached or no independent safe Lane D slice remains. CI pending by itself is not a stop condition.

## Handoff checklist
Record active Issue, branch/PR/commit, tests, native capability/storage dependencies, hotspot ownership, exact next actions, and the actual stop reason.
