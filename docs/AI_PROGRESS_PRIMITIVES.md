# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` first. Recheck current Object/Storage/Refactor PR ownership before editing shared media/storage code.

## Lane goal
Provide a small set of built-in primitive ObjectTypes whose irreducible native behavior can be composed by user-defined domain schemas.

## Primary active issues
- #155 — Weblink reusable Object and legacy Bookmark URL/media convergence.
- #245 — legacy Photos -> canonical Image Objects.
- #484 — built-in primitive boundary and canonical File/Tag semantics.
- #489 — capability-oriented shared native behavior.
- #495 — MIME/content-aware import routing to Image or File.

## Product contract
Built-in primitives are Weblink, Image, File and Tag. Image and File remain distinct ObjectTypes while sharing managed-file/native capability infrastructure. PDF remains a File Object with optional type-specific capabilities; do not add a PDF ObjectType or separate storage model.

## Lane boundaries
- Lane D owns primitive identity/product semantics, content routing and native capabilities.
- Lane C owns generic Database/View/schema presentation settings.
- Lane B owns Relation lifecycle integrity; Lane D may use canonical Relation APIs for primitive semantics but does not redesign them.
- Lane F owns Vault/Profile/filesystem lifecycle, storage location changes, backup/restore and canonical managed-copy roots.
- Do not create a second generic managed-file root while Lane F owns that seam.

## Integrated foundation
- PR #512 — canonical File primitive, shared file-backed resolver, content-first classifier.
- PR #528 — exclusive Image/File primitive import router; one user-selected source delegates to exactly one primitive and failures never fall through to the alternate primitive.
- PR #557 — PDF metadata capability layered on canonical File.
- PR #569 — canonical Image import honors content-first routing even when filename extension is misleading.

Canonical Image remains the long-term image identity. Legacy Photo data is compatibility-only until host parity allows safe retirement.

## Active PDF capability PRs
### PR #609 — extracted text
Branch: `feature/primitives-pdf-text-489`
Head after refresh onto newer main: `c24eb77a78c6e497a83f8d99dc197cc89f164212`.

Adds optional canonical File PDF text extraction:
- resolves the managed File first;
- verifies PDF through the shared content-first classifier;
- exposes trimmed derived text without writing a search index;
- production macOS reader uses Spotlight metadata;
- conflicting non-PDF content does not invoke the PDF reader;
- diagnostics avoid raw local file paths/exception text.

CI run #1945 was still in progress at the latest check.

### PR #614 — transient preview
Branch: `feature/primitives-pdf-preview-bytes-489`
Head: `fb324e85bafa564d13bbe88ac518d0736b558187`.

Adds optional canonical File PDF visual preview:
- verifies PDF content before rendering;
- uses macOS Quick Look for a transient first-page preview;
- returns PNG bytes rather than persisting another derived-file identity;
- uses only OS temporary output and removes it in `finally`;
- unsupported/failing/empty rendering fails soft as unavailable;
- no generic UI hotspot, Vault lifecycle, Relation mutation, or PDF persistence model changes.

CI run #1950 was still in progress at the latest check; maintainability/legacy guards had passed before Flutter analysis/tests began.

## 2026-09-07 — Tag built-in schema contract slice
Active branch: `feature/primitives-tag-schema-contract-484`
Latest implementation commit: `c0232f765b738761fff3fcac69dd59eeb72c5222`.

This slice does not add another Tag persistence or edge model. It strengthens tests around the existing canonical contract:
- Tag is a system ObjectType backed by ordinary canonical Object storage;
- `Parent` is a single self-Relation targeting the canonical Tag ObjectType;
- legacy Tag id/group compatibility Properties remain hidden system metadata;
- an incompatible pre-existing `Parent` Property fails closed rather than being silently accepted or duplicated.

The existing Tag hierarchy mirror continues to write parent relationships through the canonical Relation mutation service; Relation lifecycle semantics remain Lane B-owned and unchanged.

Hotspot status:
- this slice changes only `test/tag_object_bridge_test.dart` plus this handoff;
- no shared UI hotspot lease is taken;
- latest main inspected before branching was `73cd358e4c308c166bd75e94098010710725831f`.

Validation:
- connector environment cannot execute local Flutter tests directly;
- focused test additions are intended to run through Flutter CI after PR creation.

## Exact next actions
1. Open the focused Tag schema-contract PR and inspect CI; fix only failures caused by this slice.
2. Recheck #609/#614 CI and merge when green and mergeable; refresh onto latest main if needed.
3. When Lane F exposes the canonical managed-copy seam, compose File import with the already-merged exclusive primitive router and add duplicate/reimport/rollback coverage.
4. Continue safe #245 Image/Photo retirement or #155 Weblink compatibility retirement only through service/domain/test slices while shared hosts are leased elsewhere.
5. For Tag quick-create, preserve the rule that Tag remains canonical Object + Relation; do not invent a Tag-specific edge engine.

## Stop reason
This checkpoint stops only at the current connector execution boundary after completing another independent Lane D slice and updating the durable handoff. CI pending by itself is not treated as a blocker; future runs should continue from the next safe slice above.
