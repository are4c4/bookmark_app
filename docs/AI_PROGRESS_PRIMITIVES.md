# AI Progress — Primitive Objects & Media Lane

> Lane D durable handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Current issue status — 2026-09-08
- #484 — built-in primitive boundary / canonical File: **completed/closed**. The canonical File primitive, PDF-as-File capability model, shared managed-file boundaries, Object Inspector host and real File collection create affordance are now represented in product architecture.
- #495 — MIME/content-aware Image/File import: open. Core classifier/router, content-first Image import, Vault-managed File import, File picker preflight and Relation quick-create router reuse are established. Continue only for concrete remaining import-entry inconsistencies.
- #245 — Photo -> Image consolidation: open. Canonical Image is established; remaining work is legacy Photo presentation/write-authority migration and eventual caller-zero retirement.
- #155 — Weblink Objectization / legacy Bookmark convergence: open. Canonical Weblink identity/media/action behavior is established; remaining work is generic presentation polish and safe caller-zero legacy URL/remote-thumbnail retirement.
- #489 — shared native capabilities: completed/closed; not an active blocker.

## Architecture contract
- Image and File are distinct system ObjectTypes but reuse shared file-backed/native infrastructure.
- PDF is a capability of canonical File. Do not add a PDF ObjectType/table/storage/search persistence path.
- Lane D owns primitive identity, metadata, MIME/content routing and primitive-native behavior.
- Lane F owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical-delete filesystem boundaries.
- Lane C owns generic Database/View/schema presentation; Lane B owns Relation lifecycle/integrity; Lane E owns search persistence/reconciliation.
- Never infer physical-delete authority merely from a Vault-looking path or content hash.

## Weblink
Established on `main`:
- normalized URL identity/reuse and fail-soft metadata enrichment;
- managed Representative Image / Related Images through canonical Relations;
- shared visual resolution;
- native open/copy actions;
- strict durable MIME normalization shared with File/Image.

Relevant merges include #743 (`42d0d04d…`), #751 (`7e3b9d9e…`) and #768 (`dfeee7af…`). Managed Bookmark visual host migration is effectively complete in audited Bookmark detail/List/Table/card paths. #155 remaining work should be generic Weblink presentation polish or safe removal of caller-zero compatibility paths, not another Weblink persistence layer.

## Image / legacy Photo
Canonical Image has managed import/create/reuse, provenance, portable stored-path identity, content-first classified import, persisted/fallback geometry, preview/edit/rotate/flip/restore/crop behavior, shared-file safety and Weblink media integration.

Recent relevant merges include #718 (`82e9b912…`), #764 (`45c5bf98…`), #783 (`1b3e029f…`) and Refactor #842 (`238f3984…`).

#245 position:
- Phase 1 canonical Image import/create: established.
- Phase 2 Photo -> Image mirroring/promotion: established through stable `photo_object_links`, exact-file reuse, missing-file safety and native-Image survival.
- Bookmark `Images` / `Cover Image` canonical Relations: established.
- Remaining major gap is Phase 4+: generic Images parity and replacing legacy Bookmark/People `PhotoRecord` write authority before hiding/removing legacy `写真`.

Compatibility warning: do not remove `Photos`, `BookmarkPhotos`, `Person.profilePhotoId`, `PhotoManagementPage`, `photo_database_picker.dart` or legacy callers until replacement parity/caller-zero is explicit. `CoreObjectBridge` keeps a special relative-path/no-profile-root compatibility rule and must not be mechanically replaced with ordinary filesystem-existence semantics.

## Canonical File — integrated state
Canonical File is now a production-capable primitive with:
- managed/Vault-relative stored-path identity;
- original filename, strict MIME/content type, extension/size/import timestamp and optional SHA-256 metadata;
- typed Storage ownership metadata;
- open/reveal/export;
- missing-file-safe resource projection;
- PDF metadata/preview/page-count/text capabilities behind the same File identity;
- shared-reference-aware, ownership-gated physical deletion;
- real generic File collection import;
- shared Object Inspector native File/PDF detail presentation.

Key slices:
- #512 (`29cc878f…`) — canonical File + shared managed-file foundation.
- #528 (`735c8be7…`) — exclusive Image/File primitive router.
- #553 (`4a0c53fc…`) — open/reveal.
- #557 (`702a2278…`) — PDF metadata on File.
- #750 (`fedcceb49463ac05dfa64f338620207f65bdf5b2`) — Lane F arbitrary-file Vault copy + explicit ownership receipt + rollback.
- #771 (`3f3c63c024f6885c32f38fce94253ac368787857`) — Lane F ownership-gated persistent delete.
- #778 (`eb2f0e6d…`) — Vault copy -> canonical File creation -> rollback composition.
- #788 (`eea8e52d…`) — typed ownership persistence/projection.
- #794 (`49eb9ffe…`) — shared-reference-aware physical deletion.
- #798 (`fc04b1db…`) — SHA-256 metadata from managed bytes; hash remains metadata, not identity.
- #804 (`58dc3923…`) — safe generic File collection import contract + picker-facing preflight.
- #824 (`f5944785…`) — canonical open/reveal/export action widget.
- #830 (`106a87f4…`) — read-only inline PDF preview seam.
- #834 (`97b64325…`) — `ObjectFileDetailPanel` composition.
- #837 (`def7247d…`) — PDF metadata/page-count summary in the same File panel.
- #841 (`b954bfc37999e432bb6e79a7ef785a5d22530580`) — service-layer `CanonicalFileDetailCapabilities` + system-identity-gated `ObjectFileDetailPanelHost`.
- #862 (`b65f41113888ac82bbe0ed498957abf4bd48f62a`) — canonical File collection create mode/label/icon and real `GenericDatabaseFileImportService.pickAndImport(...)` host wiring.
- #853 (`bd39bd8944451a54d41e8b114cfa7081af02a9b2`) — shared `ObjectInspectorPage` now places `ObjectFileDetailPanelHost` after Properties and before Body.

File identity remains stored-path based. Reimporting the same external source intentionally creates a distinct managed path/File Object when the import contract says a new managed copy is owned; SHA-256 is metadata, not implicit dedup/delete authority.

### #853 validation lesson
The first Inspector regression instantiated the entire asynchronous File/PDF panel and kept a Flutter widget test alive until its 10-minute timeout. Production File capability widgets already cache their Futures and dedicated host/panel tests cover canonical identity/native behavior. The final #853 regression therefore verifies the Inspector wiring contract deterministically, while `object_file_detail_panel_host_test` and focused File action/PDF widget tests remain responsible for lower-level behavior. #853 refreshed CI passed guardrails, Drift generation, Analyze and the full Flutter test suite before merge.

## MIME/content routing
`PrimitiveObjectImportService` remains the canonical ambiguous-file decision boundary:
1. validate a real regular-file source;
2. classify once with `strong content signature > meaningful declared MIME > extension fallback`;
3. invoke exactly one Image/File importer;
4. never fall through after selected-importer failure.

Important behavior:
- unknown/unsupported content fails conservatively to File where safe;
- content-classified Image import uses a codec-appropriate managed extension while preserving source filename provenance;
- malformed MIME cannot suppress stronger valid evidence;
- File picker preflights selected sources before mutation and rejects supported Image content from an explicitly File-targeted action with zero Vault/Object mutation;
- Relation target quick-create uses `PrimitiveObjectImportService` and fails closed when selected content resolves to the wrong primitive for the Relation target;
- no raw user path belongs in ordinary diagnostics.

Relevant routing hardening includes #528, #569, #739 (`c9a56245…`), #751, #764/#768 and #804. The old “generic File import is blocked on Lane F” note is obsolete.

## PDF / Tag
- PDF remains canonical File; metadata, preview, page count and text extraction/search-derived inputs are optional capabilities. No PDF persistence type exists.
- Tag remains canonical Object storage with hierarchy through canonical self-Relation. Do not invent parallel tag-edge storage or native uniqueness semantics without an explicit product decision.

## Validation / environment
- #862 full Flutter CI green before squash merge `b65f41113888ac82bbe0ed498957abf4bd48f62a`.
- #853 refreshed full Flutter CI run #2608 green before squash merge `bd39bd8944451a54d41e8b114cfa7081af02a9b2`.
- Earlier File presentation/core slices listed above were integrated after their relevant guardrails, Drift generation, Analyze and Flutter tests passed.
- Local Flutter/Dart execution is unavailable in this connector runtime; GitHub Actions is the executable validation source.

## Current hotspot / concurrency state
Latest audited `main` after Lane D File host completion: `bd39bd8944451a54d41e8b114cfa7081af02a9b2`.

Open PR audit immediately after that merge:
- Refactor #863 touches `photo_management_page.dart` plus privacy guard/docs. Do not concurrently edit `PhotoManagementPage` while it is open.
- Relation #859 is docs-only (`docs/AI_PROGRESS_RELATION.md`).
- No remaining Lane D PR claims `object_inspector_page.dart` or `generic_database_page.dart` after #853/#862 merged, but both are large shared hotspots and require a fresh audit before another edit.
- `app_shell.dart`, `app_database.dart`, Bookmark/People/Photo hosts remain shared hotspots.

## Exact next actions
1. #495: audit concrete user-selected import entry points. Relation quick-create already reuses `PrimitiveObjectImportService`; File collection preflight is content-aware. The Images collection still enters through `PhotoStorageService.importImages()` / extension-filtered `importPaths()`, so decide from actual picker semantics/tests whether content-first classification should replace that extension-only boundary before closing #495. Do not add another router abstraction.
2. #245: after Refactor #863 clears `PhotoManagementPage`, continue only patch-sized parity/caller migration work. Prefer generic Images detail/List/Table and canonical Object/Relation reads/writes over adding more Photo adapters.
3. #155: continue only generic Weblink collection/detail polish or caller-zero legacy URL/remote-thumbnail retirement.
4. Re-audit #495 close condition after the Images picker audit. If all real ambiguous file-import entry points use the central content-aware contract and explicit target pickers fail closed correctly, update/close the issue rather than extending the architecture speculatively.
5. Keep Tag hierarchy on canonical Relation APIs and defer native uniqueness semantics.

## Cross-lane dependencies / blockers
- Lane F: no current generic File blocker; Vault copy/ownership/rollback/delete boundaries are on main.
- Lane C: no current File collection blocker; #862 is integrated. Generic Database remains a shared hotspot.
- Lane B: Relation quick-create/import already uses the central primitive router and canonical Relation attach; B owns integrity around those writes.
- Lane E: owns search persistence/reconciliation; Lane D owns only File/PDF extraction/capability behavior.
- Refactor: #863 currently owns `photo_management_page.dart`; avoid overlap until it merges/closes.

## Run checkpoint
Latest Lane D production merge: #853, squash merge `bd39bd8944451a54d41e8b114cfa7081af02a9b2`, full Flutter CI #2608 green.

Immediately preceding Lane D merge: #862, squash merge `b65f41113888ac82bbe0ed498957abf4bd48f62a`, full Flutter CI green.

#484 is complete. The next meaningful Lane D work is no longer more File-core abstraction; it is a concrete #495 import-entry audit and #245/#155 caller/presentation convergence while respecting active hotspot leases.
