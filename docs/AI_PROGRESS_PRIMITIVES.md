# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Issue status
- #155 — Weblink Objectization / legacy Bookmark convergence: open; core canonical identity/media behavior is established, remaining work is generic presentation and caller-zero compatibility retirement.
- #245 — Photo -> Image consolidation: open; canonical Image import/promotion is established, remaining work is host/write-authority parity and legacy retirement.
- #484 — built-in primitive boundary / canonical File: open; core File/PDF behavior and reusable detail presentation are established, remaining work is final shared-host placement and collection affordance wiring.
- #495 — MIME/content-aware Image/File import: open; content-first routing and production Image/File import paths are established. Only concrete routing/import ambiguities should extend it.
- #489 — shared native capabilities: completed/closed. Do not treat it as an active blocker.

## Architecture contract
- Image and File are distinct ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File: no PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete filesystem boundaries.
- Lane C owns generic Database/View presentation and shared collection hosts.
- Lane B owns Relation lifecycle/integrity for primitive-producing workflows.
- Lane E owns search persistence/reconciliation; Lane D only provides File/PDF-derived capability inputs.
- Never infer physical-delete authority from a Vault-looking path or SHA-256 match.

## Current checkpoint — 2026-09-07

### Weblink
Established on `main`:
- normalized URL identity/reuse and fail-soft metadata enrichment;
- managed Representative Image / Related Images through canonical Relations;
- shared visual resolution;
- native open/copy actions;
- strict durable MIME normalization shared with File/Image.

Relevant merges include #743 (`42d0d04d…`), #751 (`7e3b9d9e…`) and #768 (`dfeee7af…`). Managed Bookmark visual host migration is effectively complete in audited Bookmark detail/List/Table/card paths. #155 remaining work is generic Weblink presentation polish and safe caller-zero retirement of legacy URL/remote-thumbnail compatibility.

### Image / Photo
Canonical Image has managed import/create/reuse, provenance, portable stored-path identity, content-first import, persisted/fallback geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety and Weblink media integration.

Relevant recent merges:
- #718 (`82e9b912…`) — canonical Image metadata enrichment; not active.
- #764 (`45c5bf98…`) — shared strict MIME normalization.
- #783 (`1b3e029f…`) — remote managed extension follows HTTP Content-Type while preserving URL filename provenance.
- #842 (`238f3984…`) — Refactor lane removed three staged Image-detail `AppDatabase` presentation dependencies and tightened the feature-presentation DB-import ceiling from 7 to 4.

#245 position:
- Phase 1 canonical Image import/create: established.
- Phase 2 Photo -> Image mirroring/promotion: established through stable `photo_object_links`, exact-file reuse, missing-file safety and native-Image survival.
- Bookmark `Images` / `Cover Image` canonical Relations: established.
- Remaining major gap is Phase 4+ parity: generic Object detail/List/Table presentation and replacing legacy Bookmark/People `PhotoRecord` write authority before hiding/removing legacy `写真`.

Compatibility warning: `CoreObjectBridge` intentionally keeps its special relative-path/no-profile-root rule. Do not mechanically replace it with normal filesystem-existence semantics. Do not remove `Photos`, `BookmarkPhotos`, `Person.profilePhotoId`, `PhotoManagementPage` or `photo_database_picker.dart` until caller/write parity is explicit.

### Canonical File — core/domain
Canonical File is a production-capable primitive with:
- managed/Vault-relative stored-path identity;
- original filename, MIME/content type, extension/size/import timestamp and optional SHA-256 metadata;
- typed Storage ownership metadata;
- open/reveal/export;
- missing-file-safe resource projection;
- PDF metadata/preview/page-count/text capabilities behind canonical File identity;
- two-phase shared-reference-aware physical deletion.

Key integrated slices:
- #512 (`29cc878f…`) — canonical File + shared managed-file foundation.
- #553 (`4a0c53fc…`) — open/reveal.
- #557 (`702a2278…`) — PDF metadata on File.
- #750 (`fedcceb49463ac05dfa64f338620207f65bdf5b2`) — Lane F arbitrary-file Vault copy + explicit ownership receipt + rollback.
- #771 (`3f3c63c024f6885c32f38fce94253ac368787857`) — Lane F ownership-gated physical delete.
- #778 (`eb2f0e6d…`) — Vault copy -> canonical File creation -> rollback composition.
- #788 (`eea8e52d…`) — typed ownership persistence/projection.
- #794 (`49eb9ffe…`) — shared-reference-aware physical deletion.
- #798 (`fc04b1db…`) — SHA-256 metadata from managed bytes; hash remains metadata, not identity.
- #804 (`58dc3923…`) — safe generic File collection import contract + picker-facing preflight.

File identity remains stored-path based. Reimporting the same external source intentionally creates a distinct managed path and distinct File Object even when SHA-256 matches.

### Canonical File — presentation
The reusable File detail surface is now established on `main` without giving presentation raw filesystem ownership:
- #824 (`f5944785…`) — canonical open/reveal/export action widget with privacy-safe errors.
- #830 (`106a87f4…`) — read-only inline PDF preview seam; non-PDF/missing/unavailable previews render nothing.
- #834 (`97b64325…`) — `ObjectFileDetailPanel` composes preview + actions for one File identity and reserves no PDF-specific whitespace when unavailable.
- #837 (`def7247d…`) — PDF embedded title/authors + page count summary, independently fail-soft, composed into the same File panel.
- #841 (`b954bfc37999e432bb6e79a7ef785a5d22530580`) — `CanonicalFileDetailCapabilities` service-layer composition + system-identity-gated `ObjectFileDetailPanelHost`.

Important #841 architecture lesson: its first head put `AppDatabase` composition under feature presentation and correctly failed the maintainability ceiling. The merged version moved composition into `lib/services` rather than relaxing the ceiling. `ObjectFileDetailPanelHost` now consumes a typed capability bundle and custom ObjectTypes with merely File-shaped Properties fail closed to no native File panel.

`ObjectInspectorPage` does **not yet place** `ObjectFileDetailPanelHost`. The adapter deliberately reduces the eventual shared-host patch to construction of `CanonicalFileDetailCapabilities.fromDatabase(database: store.database, objectStore: objectStore)` plus one host widget placement. Re-audit open PR ownership immediately before touching that large file.

### MIME/content routing
`PrimitiveObjectImportService` remains the canonical decision boundary:
1. validate a real regular-file source;
2. classify once with `strong content signature > meaningful declared MIME > extension fallback`;
3. invoke exactly one Image/File importer;
4. never fall through after selected-importer failure.

Relevant hardening:
- #528 (`735c8be7…`) — exclusive router.
- #569 — content-classified Image import no longer trusts misleading source extension for managed copy.
- #739 (`c9a56245…`) — malformed MIME such as `image/`, `/png`, `image/png/extra`, `image / png` is not evidence.
- #751 (`7e3b9d9e…`) — shared strict MIME normalization.
- #764 / #768 — Image/Weblink durable metadata use the same MIME contract as File.
- #804 — File picker preflights all selected sources before mutation; any supported Image rejects the whole File action with zero Vault/Object mutation, while content-classified File inputs continue normally.

The old “generic File import is blocked on Lane F managed-copy/ownership” statement is obsolete. #750/#771 delivered that dependency and Lane D consumes it on `main`.

### PDF / Tag
- PDF remains canonical File; existing services provide content-verified metadata, preview, page count, text extraction, search-derived text input and normal File actions. No PDF ObjectType/table/search route exists.
- Tag remains canonical Object storage with hierarchy through canonical self-Relation. Do not invent native Tag uniqueness semantics without an explicit product decision.

## Validation
- #824, #830, #834, #837 and #841 were integrated after normal Flutter CI passed their relevant maintainability guardrails, Drift generation, Analyze and full Flutter tests.
- #841 specifically preserves the stricter presentation/database boundary by moving composition to `lib/services`; do not reintroduce presentation-owned `AppDatabase` composition.
- Local Flutter/Dart execution is unavailable in this connector runtime; GitHub CI is the executable validation source.

## Current hotspot / concurrency state
- Lane C PR #832 (`feature/database-view-real-host-schema-management-493`) currently owns `GenericDatabasePage` and explicitly plans/contains shared-host schema-management wiring. Do **not** overlap that file for File collection import UI until its lease clears.
- No open PR was found claiming `object_inspector_page.dart` at the #841 merge checkpoint, but it remains a large shared hotspot. Re-audit immediately before any edit.
- Bookmark/People/Photo hosts, `app_shell.dart` and `app_database.dart` remain shared hotspots and require a fresh open-PR audit before non-trivial edits.

## Exact next actions
1. Re-audit `object_inspector_page.dart` ownership. If clear and a patch-sized edit path is available, place `ObjectFileDetailPanelHost` after the title/navigation area and before generic Properties for the canonical File system ObjectType; add a real-host regression proving custom File-shaped ObjectTypes do not receive native File UI.
2. Wait for Lane C #832 to clear `GenericDatabasePage`, then connect #804 `requiresManagedFileImport()` + `GenericDatabaseFileImportService.importPickedFiles(...)` to the real File collection create affordance if no equivalent wiring landed meanwhile.
3. Re-audit #484 acceptance after those two host placements. Core File/PDF identity, metadata, ownership, import, actions, derived PDF capability and delete safety are implemented.
4. Continue #245 only where replacement parity is explicit: canonical Image detail/List/Table parity and Bookmark/People write-authority migration are higher value than speculative new Image abstractions.
5. Continue #155 only for generic Weblink collection/detail polish or caller-zero legacy URL/remote-thumbnail retirement.
6. Keep #495 limited to concrete routing/import ambiguities; core routing/import behavior is established.
7. Keep Tag hierarchy on canonical Relation APIs and defer native uniqueness semantics.

## Cross-lane dependencies / blockers
- Lane C: #832 currently blocks Lane D edits to `GenericDatabasePage`; no generic File core blocker remains.
- Lane F: no current generic File blocker; #750/#771 provide copy/ownership/rollback/delete filesystem boundaries.
- Lane B: owns Relation integrity for primitive-producing workflows.
- Lane E: owns search persistence/reconciliation; Lane D owns only File/PDF extraction/capability behavior.
- Refactor: #842 tightened the feature-presentation DB-import ceiling to 4. Preserve or lower it; never raise it to accommodate File detail composition.

## Run checkpoint
Latest Lane D merge: #841, squash merge `b954bfc37999e432bb6e79a7ef785a5d22530580`, full Flutter CI green before merge.

Recent File presentation sequence: #824 -> #830 -> #834 -> #837 -> #841.

Current stop/coordination reason for shared-host work: `GenericDatabasePage` is leased by Lane C #832; `ObjectInspectorPage` is clear at the latest audit but requires a true patch-sized edit rather than whole-file replacement through the connector. Independent File core/presentation composition work is complete enough that the next value is real-host placement, not another parallel abstraction.
