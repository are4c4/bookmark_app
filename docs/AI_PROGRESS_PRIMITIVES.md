# AI Progress — Primitive Objects & Media Lane

> Lane D handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Issue status
- #155 — Weblink Objectization / legacy Bookmark convergence: open; core identity/media path is established, remaining work is generic presentation and caller-zero compatibility retirement.
- #245 — Photo -> Image consolidation: open; canonical Image import and Photo mirroring are established, remaining work is host/write-authority parity and legacy retirement.
- #484 — built-in primitive boundary / canonical File: open; core File/PDF product behavior is established, remaining work is composability/presentation across lanes.
- #495 — MIME/content-aware Image/File import: open; content-first routing and production Image/File import paths are established.
- #489 — shared native capabilities: **completed/closed**. Do not treat it as an active blocker.

## Architecture contract
- Image and File are distinct ObjectTypes but reuse file-backed/native capability infrastructure.
- PDF is a File Object with optional preview/metadata/page-count/text behavior; no PDF-specific persistence model.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and filesystem delete safety.
- Lane C owns generic Database/View presentation and shared hosts.
- Lane B owns Relation lifecycle/integrity for primitive-producing workflows.
- Lane E owns search index persistence/reconciliation; Lane D only provides derived File/PDF capability.
- Never infer physical delete authority from a Vault-looking path.

## Current checkpoint — 2026-09-07

### Weblink
Established on `main`:
- normalized URL identity/reuse and fail-soft metadata enrichment;
- managed Representative Image / Related Images through canonical Relations;
- shared Weblink visual resolution;
- native open/copy actions;
- strict durable MIME normalization shared with File/Image.

Recent relevant merges include #743 (`42d0d04d…`) for canonical open/copy, #751 (`7e3b9d9e…`) for shared `MimeTypeNormalizer`, and #768 (`dfeee7af…`) for Weblink adoption.

The managed Bookmark visual host migration is effectively complete in the currently audited Bookmark detail/List/Table/card paths. #155 remaining work is generic Weblink collection/detail polish and safe retirement of legacy `bookmarks.url` / remote-thumbnail compatibility only after caller parity.

### Image / Photo
Canonical Image now has managed import/create/reuse, provenance, portable stored-path identity, content-first import, persisted/fallback geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety and Weblink media integration.

Recent relevant merges:
- #718 merged as `82e9b91294ee39b7105d4b84c01ff50d92521515`; it is not active.
- #764 (`45c5bf98…`) moved Image MIME metadata to the shared strict normalizer.
- #783 (`1b3e029f…`) makes remote managed extension follow HTTP `Content-Type` while preserving URL filename provenance.

#245 position:
- Phase 1 canonical Image import/create: established.
- Phase 2 Photo -> Image mirroring/promotion: established through stable `photo_object_links`, exact-file reuse, missing-file safety and native-Image survival.
- Bookmark `Images` / `Cover Image` canonical Relations: established.
- Remaining major gap is Phase 4+ parity: generic Object detail/List/Table presentation and replacing legacy Bookmark/People `PhotoRecord` write authority before hiding/removing legacy `写真`.

Compatibility warning: `CoreObjectBridge` intentionally keeps its special relative-path/no-profile-root rule. Do not mechanically replace it with normal filesystem-existence semantics. Do not remove `Photos`, `BookmarkPhotos`, `Person.profilePhotoId`, `PhotoManagementPage` or `photo_database_picker.dart` until caller/write parity is explicit.

### Canonical File
Canonical File is a production-capable primitive with:
- managed/Vault-relative stored-path identity;
- original filename, MIME/content type, extension/size/import timestamp and optional SHA-256 metadata;
- open/reveal/export;
- missing-file-safe resource projection;
- PDF metadata/preview/page-count/text capability behind canonical File identity;
- typed Storage ownership metadata;
- two-phase shared-reference-aware physical deletion.

Key integrated slices:
- #512 (`29cc878f…`) — canonical File + shared managed-file foundation.
- #553 (`4a0c53fc…`) — File open/reveal.
- #557 (`702a2278…`) — PDF metadata on File.
- #750 (`fedcceb49463ac05dfa64f338620207f65bdf5b2`) — Lane F arbitrary-file Vault copy + explicit `vault-managed-copy-v1` receipt + rollback.
- #771 (`3f3c63c024f6885c32f38fce94253ac368787857`) — Lane F ownership-gated physical delete.
- #778 (`eb2f0e6d1ca06feefb2664e20407e21622d5f0a4`) — Vault copy -> canonical File creation -> rollback composition.
- #788 (`eea8e52ddb014f5e0c444ca605ee3db75000cf6e`) — typed ownership persistence/projection.
- #794 (`49eb9ffeec19be163b32a079d2882bc7e7799968`) — shared-reference-aware physical deletion.
- #798 (`fc04b1db72491b10d729327b97f6764c5d81e685`) — SHA-256 metadata from managed bytes; hash remains metadata, not identity.
- #804 (`58dc3923d19489ec030a83ef83bffcc88fd90970`) — safe generic File collection import contract + picker-facing preflight.

File identity remains stored-path based. Reimporting the same external source intentionally creates a distinct managed path and distinct File Object even when SHA-256 matches.

### MIME/content routing
`PrimitiveObjectImportService` is the canonical decision boundary:
1. validate a real regular-file source;
2. classify once with `strong content signature > meaningful declared MIME > extension fallback`;
3. invoke exactly one Image/File importer;
4. never fall through after selected-importer failure.

Relevant hardening:
- #528 (`735c8be7…`) — exclusive router.
- #569 — content-classified Image import no longer trusts misleading source extension for managed copy.
- #739 (`c9a56245…`) — malformed MIME such as `image/`, `/png`, `image/png/extra`, `image / png` is not evidence.
- #751 (`7e3b9d9e…`) — shared strict MIME normalization.
- #764 / #768 — Image/Weblink use the same durable MIME contract as File.
- #804 — File picker preflights **all** selected sources before mutation; any supported Image causes the entire File action to fail with zero Vault/Object mutation, while PDF bytes disguised with an image extension still route to File.

The old “generic File import is blocked on Lane F managed-copy/ownership” statement is obsolete. #750/#771 delivered that dependency and Lane D consumes it on `main`.

### PDF / Tag
- PDF remains canonical File; existing services provide content-verified metadata, preview, page count, text extraction, Search-derived text input and normal File actions. No PDF ObjectType/table/search route exists.
- Tag remains canonical Object storage with hierarchy through canonical self-Relation. Do not invent native Tag uniqueness semantics without an explicit product decision.

## Validation
- #804 final head passed maintainability guardrails, Drift generation, Analyze and the full Flutter test suite before merge.
- Earlier implementation PRs listed above were integrated after their relevant normal Flutter CI passed.
- Local Flutter/Dart execution is unavailable in this connector-only runtime; GitHub CI is the executable validation source.

## Current hotspot / concurrency state
Current Lane C host lease is **PR #819** (`feature/database-view-relation-value-quick-create-491-v2`), the current-main successor to #808. It owns `GenericDatabasePage` / `GenericDatabasePageServices` and is wiring Relation quick-create for custom/Tag/Weblink/Image/File targets using Lane D content-first primitive import contracts and Lane F Vault copy.

Do **not** concurrently edit those host regions from Lane D. #804 deliberately provides lower-level File affordance/import contracts without touching the large host.

`object_inspector_page.dart`, Bookmark/People/Photo hosts, `app_shell.dart` and `app_database.dart` remain shared hotspots and require a fresh open-PR audit before non-trivial edits.

## Exact next actions
1. Let Lane C #819 finish/merge its `GenericDatabasePage` / `GenericDatabasePageServices` lease; re-audit before any File collection host wiring.
2. After #819, connect `requiresManagedFileImport()` + `GenericDatabaseFileImportService.importPickedFiles(...)` to the generic File collection host only if #819 has not already provided equivalent composition; keep the host patch-sized.
3. Re-audit #484 acceptance after File host wiring. Core File/PDF identity, metadata, ownership, import, actions and delete safety are already implemented.
4. Continue #245 only where replacement parity is explicit: highest-value remaining work is canonical Image detail/List/Table host parity and Bookmark/People write-authority migration. Do not hide `写真` prematurely.
5. Continue #155 only for generic Weblink collection/detail polish or caller-zero legacy URL/remote-thumbnail retirement. Do not add a Weblink-specific parallel page/storage path.
6. Keep #495 changes limited to concrete routing/import ambiguities; its core routing/import contract is established.
7. Keep Tag hierarchy on canonical Relation APIs and defer native uniqueness semantics.

## Cross-lane dependencies / blockers
- **Lane C:** #819 currently blocks Lane D edits to `GenericDatabasePage` / `GenericDatabasePageServices`.
- **Lane F:** no current generic File blocker; #750/#771 provide copy/ownership/rollback/delete filesystem boundaries.
- **Lane B:** owns Relation integrity for primitive-producing workflows including #819.
- **Lane E:** owns search persistence/reconciliation; Lane D owns only File/PDF extraction behavior.

## Run checkpoint
Latest Lane D implementation merged in this run: #804, squash merge `58dc3923d19489ec030a83ef83bffcc88fd90970`, full Flutter CI green.

Handoff PR: #821, branch `docs/primitives-handoff-2026-09-07-v2`.

Stop reason for this checkpoint: the next high-value generic File host change overlaps Lane C #819's active shared-hotspot lease. Independent core File/MIME/ownership/import work for #484/#495 is already implemented; further safe work should target #245/#155 only after a fresh caller/hotspot audit rather than adding speculative abstractions.
