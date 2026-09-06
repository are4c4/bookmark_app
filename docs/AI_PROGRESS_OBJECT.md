# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Always re-read live GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for current ownership.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #245 — legacy Photos -> canonical Image Objects and Image product-semantic convergence.
- #249 — Bookmark Gallery/List parity; Stage1 List density/alignment and fixed/masonry host wiring remain.
- #242 — Vault folders remain lower priority while Image/presentation parity remains actionable.

Completed/closed for current implementation scope: #247 Bookmark opening modes, #149 Property handle, #252 Property-add UX, #156 generic fixed/masonry Gallery, #166 aliases.

## Current merged state — 2026-09-07
Latest verified `main` in this run: `2b25c55bd621ad438290923995c24756827beb53` after Object #465.

Recent Image/Object checkpoints now merged:
- #416 — canonical Image detail preview using `ImageVisualResolver`, profile-relative paths and persisted geometry.
- #423 — generic Image deletion blocked while legacy Photo compatibility still owns/maps the Image.
- #426 — `ImageObjectService.updateManagedGeometry(...)` for post-edit pixel metadata refresh.
- #432 — `CanonicalImageEditService` with exclusive managed-file ownership, backup/restore, geometry refresh and byte rollback on metadata failure.
- #434 / #436 / #438 — conservative `canEdit(...)` / format support / `canRestoreOriginal(...)` presentation preflights.
- #442 — safe Image edit actions: rotate left/right, horizontal flip and restore-original.
- #447 — explicit same-path preview refresh and `FileImage` cache eviction.
- #457 — `ObjectImageDetailPanel`, composing preview + safe edit actions and refreshing same-path media after mutation.
- #460 — safe centered crop presets: 1:1, 4:3, 3:4, 16:9 and 9:16.
- #465 — normalized free-crop selector/dialog with draggable frame and corner handles; selected `Rect` is routed through `CanonicalImageEditService.edit(normalizedCropRect: ...)` without exposing raw file paths to mutation UI. Crop requests are validated before target/ownership resolution.

Broader merged product state:
- canonical Bookmark -> Weblink -> managed Representative Image flow is live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live;
- Image import uses app-managed storage, persists geometry where available, and reuses byte-identical managed files deterministically on reimport;
- Image creation remains identity-sensitive and never falls back to title-only creation;
- legacy Photo rows mirror idempotently to canonical Images with stable mapping/provenance; native Images are not owned/deleted by legacy cleanup;
- Bookmark legacy photo attachments mirror through canonical Bookmark `Images` multi-Relation and explicit cover through canonical `Cover Image` single Relation;
- Bookmark cover presentation reads canonical `Cover Image` before legacy explicit-cover fallback;
- canonical Image deletion/backlinks are Relation-safe, and legacy Photo deletion preserves shared canonical Image files;
- canonical Image managed-file cleanup is ownership-aware and fail-closed for shared/external/ambiguous files;
- native canonical Image title/Note editing is enabled; legacy-owned mirrors remain read-only while Photo is authoritative;
- Image reverse lookup is available through canonical Object/Relation backlinks.

## Current product position
#245 Phase 1 (canonical Image import/create) and Phase 2 (legacy Photo -> Image bridge) are functionally implemented in production. Phase 3 Bookmark `Images` / `Cover Image` canonical Relation semantics and lifecycle are also implemented, while legacy Bookmark write paths still remain compatibility authority for some user-facing flows.

The reusable Image detail/edit panel is now feature-rich enough to replace most legacy Photo editor affordances: preview, rotate, flip, restore, crop presets, and free crop all remain behind `CanonicalImageEditService` ownership/rollback rules.

The major remaining gap is **host integration and legacy UI retirement**, not another Image persistence subsystem.

## Exact next actions
1. Re-read live open PR ownership and latest main before any shared-host edit. Refactor #467 currently owns `ImageVisualResolver` observability only; do not overlap that file while open.
2. Highest-value Object step: wire `ObjectImageDetailPanel` into canonical Image detail in `ObjectInspectorPage` using a genuinely patch-sized edit. Route `onError` to the existing SnackBar/error affordance and `onChanged` to `_load()` or an equivalent persisted-detail refresh. Do not reconstruct the whole Inspector merely to insert the panel.
3. Keep all byte edits behind `CanonicalImageEditService`; never pass raw file paths from presentation into `ImageEditService`.
4. Continue #245 Phase 4 generic Images parity:
   - generic Images List still uses a generic document icon rather than Image thumbnails;
   - Image Table/List daily-use media parity should reuse existing `ImageVisualResolver`/generic media contracts rather than an Image-specific page;
   - canonical backlinks already replace legacy Bookmark reverse lookup;
   - do not hide/remove legacy `写真` until remaining Bookmark/People/write-path parity is proven.
5. Continue #245 Bookmark image write/edit UX only after legacy `bookmark_photos` authority/write-through semantics are explicit; canonical-only writes can still be overwritten by compatibility sync.
6. Legacy Photo tags currently mirror as compatibility `Legacy Tags`. Converting them into canonical Tag Relations would be a new Relation-producing product decision; do not do that from Object lane alone.
7. Continue #249 Stage1 List polish only through a patch-sized host change: stable row padding/minimum height, bounded title lines with ellipsis, stable trailing-action alignment.
8. Continue #249 Bookmark Gallery parity by reusing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` and persisted `settings['galleryMode']`; do not create Bookmark-only Gallery settings.
9. Continue #155 legacy presentation convergence only where canonical replacement is already proven. Do not remove query/import/export compatibility reads merely for caller-count reduction.
10. Defer Person profile Image migration until a first-class Person Object/image relationship contract exists; current People UX still depends on legacy `profilePhotoId`.

## Cross-lane coordination
### Relation
Canonical Relation behavior is mature. Bookmark `Images` / `Cover Image` lifecycle is covered. Resume Relation implementation only if a new production workflow creates/retargets Relations or a concrete lifecycle regression appears.

### Refactor
Refactor may retire legacy code only after Object replacement behavior is live and caller-zero is proven. Current open Refactor #467 touches `ImageVisualResolver`; avoid overlap until it resolves. Shared hotspots remain `generic_database_page.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `people_management_page.dart`, `app_database.dart`.

## Validation in this run
- Re-read current main/open PR ownership before each Image slice.
- #460: Flutter CI #1604 green; merged as `3ead07fba966261aafaab1bc825d1d98a881623d`.
- #465: Flutter CI #1613 green (maintainability, Analyze, full Test); merged as `2b25c55bd621ad438290923995c24756827beb53`.
- #465 tests cover normalized crop geometry, drag/resize interaction, dialog availability/fail-closed behavior, action routing, and canonical-service validation of invalid crop requests before mutation.
- Audited managed Image reimport: `GenericDatabaseImageImportService` already uses `PhotoStorageService.importImages/importPaths(reuseIdentical: true)` and returns canonical Object ids without uncontrolled duplicate managed copies.
- Audited Photo tags: bridge already preserves them as `Legacy Tags`; no new Tag Relation semantics introduced.
- Audited Object opening: `GenericDatabasePage` still constructs `ObjectInspectorPage` directly, so panel integration still requires a small shared-host edit; no smaller route factory currently exists.

## Risks / blockers
- The current connector replaces complete existing files; there is no hunk-sized write. Do not reconstruct large shared hosts solely to add a few lines.
- `object_inspector_page.dart` and `bookmark_unified_stage1_page.dart` remain conflict-prone hotspots.
- Byte edits preserve managed file paths; any host integration must retain #447/#457 explicit refresh behavior.
- Generic Images List media parity still requires either a safe small dispatch seam or a patch-sized generic host edit.
- Legacy Bookmark photo writes and People `profilePhotoId` remain production compatibility dependencies.
- Ambiguous Relation/file ownership must fail closed; cleanup/edit code must not repair or guess ownership.
- Destructive filesystem cleanup must prefer leaking an orphan file over deleting a shared/external user file.

## Stop / continuation condition
The reusable canonical Image panel itself is no longer the blocker. The next highest-value product work is its patch-sized `ObjectInspectorPage` integration, followed by #249 Stage1 and generic Images List media parity. If only whole-file reconstruction is available for those large hosts, do not manufacture a broad rewrite or parallel persistence abstraction merely to keep a run busy; continue only with independent, product-relevant Object slices or durable handoff/verification work.
