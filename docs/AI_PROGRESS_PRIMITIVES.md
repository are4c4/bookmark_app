# AI Progress — Primitive Objects & Media Lane

> Lane D durable handoff. Before editing, re-read `AGENTS.md`, `docs/AI_PROGRESS.md`, active Issues, latest `main`, open PR ownership and CI. GitHub is the source of truth.

## Lane goal
Provide Weblink/Image/File/Tag primitives whose irreducible native behavior can be composed by user-defined schemas without parallel persistence systems.

## Current issue status — 2026-09-08
- #484 — built-in primitive boundary / canonical File: **completed/closed**. Canonical File, PDF-as-File capabilities, shared managed-file boundaries, Object Inspector hosting and real File collection create/import affordances are integrated.
- #495 — MIME/content-aware Image/File import: **completed/closed**. The final canonical Images picker gap was closed by #866 after acceptance re-audit. Ambiguous file routing now has one content-aware contract at the real generic Image/File entry points; do not reopen this issue merely to add more router abstraction.
- #245 — Photo -> Image consolidation: **open**. Canonical Image identity/import/edit/media behavior is established. Remaining work is generic presentation parity plus replacement of legacy `PhotoRecord` write/presentation authority before legacy `写真` can be hidden or removed.
- #155 — Weblink Objectization / legacy Bookmark convergence: **open**. Canonical Weblink identity/media/action behavior is established; remaining work is generic presentation polish and safe caller-zero retirement of legacy URL/remote-thumbnail paths.
- #489 — shared native capabilities: **completed/closed**; not an active blocker.

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

Recent relevant merges include #718 (`82e9b912…`), #764 (`45c5bf98…`), #783 (`1b3e029f…`), Refactor #842 (`238f3984…`) and #866 (`51b8e41d8a500b905f2e96d005a559d04d6aa743`).

### #245 position
- Phase 1 canonical Image import/create: established.
- Phase 2 Photo -> Image mirroring/promotion: established through stable `photo_object_links`, exact-file reuse, missing-file safety and native-Image survival.
- Bookmark `Images` / `Cover Image` canonical Relations: established.
- Generic canonical Image Gallery media is established.
- Canonical Images collection picker is content-aware after #866.
- Generic List media is the active #869 slice: real `GenericDatabasePage` List rows reuse `SystemObjectListMedia` instead of a fixed document icon. Latest head is `4369f086c7f24abfb980c5b73c4ac1257e250c65`; Flutter CI #2649 is the current validation run.
- Table parity audit is complete: `_table()` still renders the name cell as `DataCell(Text(record.title))`, so it does not yet host canonical Image/Weblink media. The next patch should reuse the same `SystemObjectListMedia` with `_store.database` / existing `_objectStore`; do not add a Table-specific resolver.
- After generic presentation parity, remaining major #245 work is replacing legacy Bookmark/People `PhotoRecord` write/presentation authority and proving caller-zero parity before legacy `写真` retirement.

Compatibility warning: do not remove `Photos`, `BookmarkPhotos`, `Person.profilePhotoId`, `PhotoManagementPage`, `photo_database_picker.dart` or legacy callers until replacement parity/caller-zero is explicit. `CoreObjectBridge` keeps a special relative-path/no-profile-root compatibility rule and must not be mechanically replaced with ordinary filesystem-existence semantics.

### #866 canonical Images picker routing
#866 (`51b8e41d8a500b905f2e96d005a559d04d6aa743`) closed the last concrete #495 entry-point gap without changing legacy Photo behavior:
- `GenericDatabaseImageImportService.pickAndImport()` uses an unrestricted file picker and classifies every selected source before managed copy/Object mutation;
- classification follows the shared `PrimitiveFileImportClassifier` content-aware contract;
- supported Image bytes import as canonical Image even when the source extension is misleading;
- the managed copy uses a codec-appropriate extension while preserving original filename provenance;
- mixed Image/File selections reject the entire Image-targeted action before mutation;
- missing/non-regular sources fail with a stable path-free error;
- legacy `PhotoStorageService.importImages()` / `PhotoManagementPage` behavior remains unchanged.

Flutter CI #2632 was fully green before squash merge.

### #869 List-host validation lesson
The first #869 real-host regression used an actual PNG all the way through `SystemObjectListMedia` -> `Image.file`. In full-suite CI #2640, maintainability/Analyze passed but the new widget test remained alive until its 10-minute timeout. The production behavior was not failing an assertion; the host-level test had crossed into platform image decoding.

A first stabilization still retained too much real-page/file lifecycle and again exceeded the normal full-suite duration. The current regression therefore uses layered ownership:
- the real `GenericDatabasePage` Images List test creates a canonical Image Object without a File value, waits for the production `SystemObjectListMedia` resolver to classify it as Image media, and verifies canonical host identity/database wiring without starting `Image.file`;
- `image_visual_resolver_test.dart` already covers real managed path/PNG resolution, including the `probeMissingGeometry: false` path-only contract used by List media;
- `system_object_list_media_test.dart` covers resolved-file presentation through the injected image builder.

Do not re-expand a real-host regression into platform decode work when focused resolver/presentation tests already own those lower-level contracts.

## Canonical File — integrated state
Canonical File is production-capable with:
- managed/Vault-relative stored-path identity;
- original filename, strict MIME/content type, extension/size/import timestamp and optional SHA-256 metadata;
- typed Storage ownership metadata;
- open/reveal/export;
- missing-file-safe resource projection;
- PDF metadata/preview/page-count/text capabilities behind the same File identity;
- shared-reference-aware, ownership-gated physical deletion;
- real generic File collection import;
- shared Object Inspector native File/PDF detail presentation.

Key slices include #512 (`29cc878f…`), #528 (`735c8be7…`), #553 (`4a0c53fc…`), #557 (`702a2278…`), #750 (`fedcceb49463ac05dfa64f338620207f65bdf5b2`), #771 (`3f3c63c024f6885c32f38fce94253ac368787857`), #778 (`eb2f0e6d…`), #788 (`eea8e52d…`), #794 (`49eb9ffe…`), #798 (`fc04b1db…`), #804 (`58dc3923…`), #824 (`f5944785…`), #830 (`106a87f4…`), #834 (`97b64325…`), #837 (`def7247d…`), #841 (`b954bfc37999e432bb6e79a7ef785a5d22530580`), #862 (`b65f41113888ac82bbe0ed498957abf4bd48f62a`) and #853 (`bd39bd8944451a54d41e8b114cfa7081af02a9b2`).

File identity remains stored-path based. Reimporting the same external source intentionally creates a distinct managed path/File Object when the import contract says a new managed copy is owned; SHA-256 is metadata, not implicit dedup/delete authority.

## MIME/content routing — completed #495 contract
`PrimitiveObjectImportService` remains the canonical ambiguous-file decision boundary:
1. validate a real regular-file source;
2. classify once with `strong content signature > meaningful declared MIME > extension fallback`;
3. invoke exactly one Image/File importer;
4. never fall through after selected-importer failure.

Important behavior:
- unknown/unsupported content fails conservatively to File where safe;
- content-classified Image import uses a codec-appropriate managed extension while preserving source filename provenance;
- malformed MIME cannot suppress stronger valid evidence;
- canonical File picker preflights selected sources before mutation and rejects supported Image content from an explicitly File-targeted action with zero Vault/Object mutation;
- canonical Images picker #866 classifies every selected source before mutation and rejects any mixed/non-Image selection as one atomic target action;
- Relation target quick-create uses `PrimitiveObjectImportService` and fails closed when selected content resolves to the wrong primitive for the Relation target;
- no raw user path belongs in ordinary diagnostics.

Relevant routing hardening includes #528, #569, #739 (`c9a56245…`), #751, #764/#768, #804 and #866. #495 is closed; future routing work needs a new concrete bug/entry-point inconsistency rather than speculative extension of this architecture.

## PDF / Tag
- PDF remains canonical File; metadata, preview, page count and text extraction/search-derived inputs are optional capabilities. No PDF persistence type exists.
- Tag remains canonical Object storage with hierarchy through canonical self-Relation. Do not invent parallel tag-edge storage or native uniqueness semantics without an explicit product decision.

## Validation / environment
- #866: Flutter CI #2632 full green; squash merge `51b8e41d8a500b905f2e96d005a559d04d6aa743`.
- #869: latest head `4369f086c7f24abfb980c5b73c4ac1257e250c65`; Flutter CI #2649 is pending/in progress at this checkpoint after deterministic host-test stabilization.
- #862 full Flutter CI green before squash merge `b65f41113888ac82bbe0ed498957abf4bd48f62a`.
- #853 refreshed full Flutter CI #2608 green before squash merge `bd39bd8944451a54d41e8b114cfa7081af02a9b2`.
- Local Flutter/Dart execution is unavailable in this connector runtime; GitHub Actions is the executable validation source.

## Current hotspot / concurrency state
Latest audited `main` while #869 is open: `a18ce533242e6d60a3e6e11196034e3324ad3c40` (#870 merged).

Open PR audit at this checkpoint:
- Primitive #869 owns the `generic_database_page.dart` List-media hotspot until it merges/closes.
- Refactor #872 owns `app_shell.dart`, not `generic_database_page.dart`.
- Relation #871 changes Relation read/graph services with no shared UI hotspot edit.
- Relation #859 is docs-only.

Do not start the Table production edit until #869 releases the `generic_database_page.dart` lease. Re-audit open PRs immediately before the next shared-host edit.

## Exact next actions
1. Finish #869 validation. If Flutter CI #2649 is full green, squash merge it and record the merge SHA/run in this handoff.
2. #245 Table media parity: on fresh latest `main`, replace the text-only Table name cell with the existing `SystemObjectListMedia` + title composition. Reuse `_store.database`, `_objectStore`, workspace/object type/object identity already available in the host. Preserve DataRow opening/property edit behavior and custom/unsupported fallback.
3. Add a deterministic real Table-host regression. Keep platform image decoding in focused media/resolver tests rather than duplicating it inside a full `GenericDatabasePage` host test.
4. Re-audit canonical Image generic detail/daily-use parity and remaining legacy Photo write/presentation callers before any `写真` hiding/removal.
5. #155: continue only generic Weblink collection/detail polish or caller-zero legacy URL/remote-thumbnail retirement.
6. Keep Tag hierarchy on canonical Relation APIs and defer native uniqueness semantics.

## Cross-lane dependencies / blockers
- Lane F: no current generic File blocker; Vault copy/ownership/rollback/delete boundaries are on `main`.
- Lane C: generic Database/View owns generic layout contracts, while this Lane D slice only supplies primitive media semantics. Coordinate if Table layout behavior itself must change beyond hosting existing media.
- Lane B: Relation quick-create/import already uses the central primitive router and canonical Relation attach; B owns integrity around those writes.
- Lane E: owns search persistence/reconciliation; Lane D owns only File/PDF extraction/capability behavior.
- Refactor #872 owns `app_shell.dart`; no current overlap with #869.

## Run checkpoint
Current Lane D production checkpoint: #866 merged as `51b8e41d8a500b905f2e96d005a559d04d6aa743`, Flutter CI #2632 green, and #495 is completed/closed.

Active Lane D PR: #869, head `4369f086c7f24abfb980c5b73c4ac1257e250c65`, Flutter CI #2649 pending/in progress. Table parity has been audited and is the next production slice once #869 releases the shared host.

This run must not stop merely because #869 CI is pending; continue only work that does not violate the active `generic_database_page.dart` hotspot lease until its result is known.
