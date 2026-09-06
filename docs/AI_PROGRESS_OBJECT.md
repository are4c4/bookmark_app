# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Always re-read live GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for current ownership.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #245 — legacy Photos -> canonical Image Objects and Image product-semantic convergence.
- #249 — Bookmark Gallery/List parity; remaining primary product gap is real Stage1 fixed/masonry Gallery host wiring.
- #242 — Vault folders remain lower priority while media/presentation parity remains actionable.

Completed/closed for current implementation scope: #247 Bookmark opening modes, #149 Property handle implementation, #252 Property-add UX, #156 generic fixed/masonry Gallery foundation, #166 aliases.

## Current merged state — 2026-09-07
Latest verified `main` in this run: `2e50f72548c401663232e3ae2fd7c34e15f7c79d` after Object #479. Refactor #482 is also included on main.

Recent Object checkpoints now merged:
- #416 — canonical Image detail preview using `ImageVisualResolver`, profile-relative paths and persisted geometry.
- #423 — generic Image deletion blocked while legacy Photo compatibility still owns/maps the Image.
- #426 — `ImageObjectService.updateManagedGeometry(...)` for post-edit pixel metadata refresh.
- #432 — `CanonicalImageEditService` with exclusive managed-file ownership, backup/restore, geometry refresh and byte rollback on metadata failure.
- #434 / #436 / #438 — conservative `canEdit(...)` / format support / `canRestoreOriginal(...)` presentation preflights.
- #442 — safe Image edit actions behind `CanonicalImageEditService`.
- #447 — explicit same-path preview refresh and `FileImage` cache eviction.
- #457 — `ObjectImageDetailPanel`, composing preview + safe edit actions and refreshing same-path media after mutation.
- #460 — safe centered crop presets: 1:1, 4:3, 3:4, 16:9 and 9:16.
- #465 — normalized free-crop selector/dialog with draggable frame and corner handles.
- #469 — safe vertical flip action using the same canonical ownership/format recheck as other Image mutations.
- #473 — `ImageVisualResolver` read-only managed-byte geometry fallback only when persisted geometry is missing/partial.
- #475 — free-crop top/bottom/left/right edge handles in addition to corner handles.
- #476 — free-crop `画像を動かす` mode: visible crop frame stays fixed while dragging pans the source image beneath it and mouse-wheel input zooms. The implementation was consolidated into the existing crop selector rather than keeping a duplicate overlay. Flutter CI #1658 passed; merged as `f9564488f52721e6221f4a0bfeaae59427bff184`.
- #480 — reusable `ObjectGalleryModeMenu`, extracted from generic `ObjectViewToolbar`, backed exclusively by `DatabaseViewGalleryAdapter` / `settings['galleryMode']`, preserving unrelated View settings. Flutter CI #1662 passed; merged as `b96e33edab19599dcfd6abd2e7c3ca485e4f1141`.
- #483 — read-only `ObjectWeblinkDetailPreview` using existing `WeblinkVisualResolver` and managed Representative Image geometry; missing representative media is a normal collapsed state. Flutter CI #1665 passed; merged as `254b71f115751a25f56005ea625a81b3d32f7019`.
- #479 — read-only `SystemObjectListMedia` dispatch for canonical Image managed File, Weblink managed Representative Image, and generic fallback. The first DB-backed widget regression timed out while 719 other tests passed; it was replaced with a deterministic resolver seam without changing production resolution. Corrected Flutter CI #1669 passed; merged as `2e50f72548c401663232e3ae2fd7c34e15f7c79d`.

Broader merged product state:
- canonical Bookmark -> Weblink -> managed Representative Image flow is live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live;
- Image import uses app-managed storage, persists geometry where available, and reuses byte-identical managed files deterministically on reimport;
- Image creation remains identity-sensitive and never falls back to title-only creation;
- legacy Photo rows mirror idempotently to canonical Images with stable mapping/provenance; native Images are not owned/deleted by legacy cleanup;
- Bookmark legacy photo attachments mirror through canonical Bookmark `Images` multi-Relation and explicit cover through canonical `Cover Image` single Relation;
- Bookmark cover/list/table/card presentation has canonical visual routing with compatibility fallback where still required;
- canonical Image deletion/backlinks are Relation-safe, and legacy Photo deletion preserves shared canonical Image files;
- canonical Image managed-file cleanup/editing is ownership-aware and fail-closed for shared/external/ambiguous files;
- native canonical Image title/Note editing is enabled; legacy-owned mirrors remain read-only while Photo is authoritative;
- Image reverse lookup is available through canonical Object/Relation backlinks;
- generic Gallery has real fixed/masonry View persistence/rendering and managed Weblink/Image media geometry;
- Bookmark opening modes and one-Person-per-chip presentation already converge on shared contracts.

## Current product position
#245 Phase 1 (canonical Image import/create), Phase 2 (legacy Photo -> Image bridge), and Phase 3 Bookmark `Images` / `Cover Image` canonical Relation semantics/lifecycle are functionally implemented. Legacy Bookmark and People photo write paths still remain compatibility authority for some user-facing flows.

The reusable Image detail/edit panel now covers preview, rotate, horizontal/vertical flip, restore, crop presets, free crop, edge resizing, fixed-frame panning and zooming while remaining behind `CanonicalImageEditService` ownership/rollback rules. Generic List also has a reusable Image/Weblink media dispatcher after #479. The major remaining Image gap is **shared-host integration**, not another editor or persistence subsystem.

#155 Weblink work is likewise in presentation/consolidation: canonical URL identity, metadata, managed Representative Image, Gallery media, creation and Relation lifecycle already exist. Generic Property rows provide Page title / Domain / Description / URL, and #483 now supplies the reusable managed visual for shared detail.

## Exact next actions
1. Re-read live open PR ownership and latest main before any shared-host edit. Refactor/Relation run in parallel.
2. Highest-value shared-detail step when a genuinely patch-sized edit path is available: wire `ObjectImageDetailPanel` into canonical Image detail in `ObjectInspectorPage`. Route `onError` to the existing SnackBar affordance and `onChanged` to `_load()` or equivalent persisted-detail refresh. Do not reconstruct the whole Inspector merely to insert the panel.
3. In the same shared-detail convergence phase, mount `ObjectWeblinkDetailPreview` only for the canonical Weblink system type; continue using generic Property rows for Page title / Domain / Description / URL.
4. Keep all Image byte edits behind `CanonicalImageEditService`; never pass a raw file path from presentation into `ImageEditService`.
5. Complete #245 Phase 4 generic List media through a patch-sized `GenericDatabasePage` edit: replace the fixed document leading icon with merged `SystemObjectListMedia`. Do not add an Image- or Weblink-specific page.
6. Complete #249 Bookmark Gallery parity only through patch-sized Stage1 wiring:
   - mount merged `ObjectGalleryModeMenu` when the active Bookmark View is Gallery;
   - persist its returned `DatabaseViewConfig` through the existing View store;
   - decode the same `settings['galleryMode']` with `DatabaseViewGalleryAdapter`;
   - route existing Bookmark itemBuilder/card semantics into `ObjectGalleryView` for fixed vs masonry geometry;
   - do not add a Bookmark-only Gallery mode setting.
7. Do not hide/remove legacy `写真` until Bookmark/People write authority parity is proven. Current `photo_database_picker.dart` callers remain tied to legacy write semantics.
8. Legacy Photo tags remain compatibility `Legacy Tags`. Converting them into canonical Tag Relations would be a new Relation-producing product decision; do not do that from Object lane alone.
9. Defer Person profile Image migration until a first-class Person Object/image relationship contract exists; current People UX still depends on legacy `profilePhotoId`.
10. Continue #155 legacy retirement only where canonical replacement is live and caller-zero is proven. Do not remove query/import/export compatibility reads merely for caller-count reduction.

## Cross-lane coordination
### Relation
Canonical Relation behavior is mature. Bookmark `Images` / `Cover Image` and Weblink `Representative image` / `Related images` lifecycle are covered. #475/#476/#479/#480/#483 do not add Relation mutation behavior. Resume Relation implementation only if a new production workflow creates/retargets Relations or a concrete lifecycle regression appears.

### Refactor
Refactor may retire legacy code only after Object replacement behavior is live and caller-zero is proven. Refactor #482 now guards the count of temporary Database presentation shims in addition to legacy shim imports/reach-through. Shared hotspots remain `generic_database_page.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `people_management_page.dart`, and `app_database.dart`.

## Validation / audits in this run
- #475: free-crop edge-handle slice merged after green CI.
- #476: Flutter CI #1658 green; merged as `f9564488f52721e6221f4a0bfeaae59427bff184`.
- #480: Flutter CI #1662 green; merged as `b96e33edab19599dcfd6abd2e7c3ca485e4f1141`.
- #483: Flutter CI #1665 green; merged as `254b71f115751a25f56005ea625a81b3d32f7019`.
- #479 first CI #1659: maintainability + Analyze green; 719 tests passed and only the new DB-backed List-media widget regression timed out after 10 minutes. Production resolver code was not implicated. Corrected CI #1669 passed the full suite; merged as `2e50f72548c401663232e3ae2fd7c34e15f7c79d`.
- Audited Stage1: `_saveActiveDatabaseView()` preserves unrelated settings, so `galleryMode` can use the existing View setting without a new persistence path. Current `_gallery()` is still hard-wired to `MasonryGridView.count`, which is the remaining real-host geometry gap.
- Audited managed Image reimport: `GenericDatabaseImageImportService` already uses `PhotoStorageService.importImages/importPaths(reuseIdentical: true)` and returns canonical Object ids without uncontrolled duplicate managed copies.
- Audited Object opening: `GenericDatabasePage` still constructs `ObjectInspectorPage` directly; no smaller shared-detail route factory currently removes the need for a small Inspector edit.
- Audited existing Weblink detail semantics: generic Property rows already render resource facts; #483 supplies the previously missing reusable managed Representative Image visual.
- Audited generic List: the live row still uses a fixed `Icons.description_outlined`; #479 now provides the reusable replacement component, leaving only host wiring.
- Audited legacy `photo_database_picker.dart`: production callers remain Bookmark create/detail and People profile-photo workflows, all still bound to legacy write authority; no unsafe canonical-only picker swap was made.

## Risks / blockers
- The current GitHub connector replaces complete existing files; there is no hunk-sized write. Do not reconstruct large shared hosts solely to add a few lines.
- `generic_database_page.dart`, `object_inspector_page.dart`, and `bookmark_unified_stage1_page.dart` remain conflict-prone hotspots.
- Byte edits preserve managed file paths; any Image host integration must retain explicit preview refresh/cache eviction behavior from #447/#457.
- Legacy Bookmark photo writes and People `profilePhotoId` remain production compatibility dependencies.
- Ambiguous Relation/file ownership must fail closed; cleanup/edit code must not repair or guess ownership.
- Destructive filesystem cleanup must prefer leaking an orphan file over deleting a shared/external user file.

## Stop / continuation condition
Reusable Image/Weblink presentation pieces are no longer the architectural blocker. Highest-value remaining work is patch-sized host integration: generic List media, Image/Weblink shared detail, and Bookmark fixed/masonry Gallery. If only whole-file reconstruction is available for those large hosts, do not manufacture a broad rewrite or parallel persistence abstraction merely to keep a run busy. Continue with independent, product-relevant Object slices, verification, or durable handoff work until a safe host edit path is available.
