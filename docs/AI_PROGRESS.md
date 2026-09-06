# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files. Always verify live GitHub PR/CI state before editing shared hotspots.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent daily-use workflow while reducing migration-era maintenance cost: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture/product issues:
- `#56` — generic Object/Database/View daily-use integration
- `#155` — reusable Weblink Object + managed Image presentation/navigation and legacy compatibility retirement
- `#245` — consolidate legacy Photos into canonical Image Objects
- `#249` — Bookmark Gallery/List presentation parity
- `#218` — installable macOS delivery; repository/CI implementation merged, local install/data-preservation validation remains
- `#225` — maintainability, hotspot reduction and legacy-path retirement

`#149`, `#156`, `#166`, `#247`, and `#252` are complete/closed for their current implementation scope.

## Development lanes
- **Object** — `docs/AI_PROGRESS_OBJECT.md`
- **Relation** — `docs/AI_PROGRESS_RELATION.md`
- **Refactor** — `docs/AI_PROGRESS_REFACTOR.md`

Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, and `app_database.dart`. Sequence edits by current PR ownership; do not reconstruct large hosts wholesale.

## Current implementation position — 2026-09-07
Latest production main verified in this Object run: `1d4775530b4c1646cb4a88d719e96f48b6bec39b` after Object #469; Object #473 was merged immediately before it as `a1ea19391f07412c4117d9543f395d79f7f1f8da`.

The generic Object/Relation architecture is live in real Database/Object hosts. Current work is primarily Object-first daily-use parity, canonical Image/Photo convergence, legacy Bookmark presentation/read retirement after replacement parity, and measurable maintainability reduction.

Important merged state:
- canonical Bookmark -> Weblink and Weblink -> managed Image production flows are live;
- managed previews become Image Objects and canonical Representative-image Relations;
- Weblinks / Images / Daily Notes are exposed through generic sidebar/Database hosts;
- canonical Weblink URL entry and managed Image import are live;
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated;
- canonical Image source/file identity and byte-identical reimport are deterministic;
- legacy Photo promotion reuses canonical Images without taking ownership of pre-existing native Images;
- Bookmark legacy photo attachments mirror through canonical `Images` multi-Relation;
- Bookmark explicit cover mirrors through canonical `Cover Image` single Relation;
- Bookmark presentation reads canonical `Cover Image` before legacy explicit-cover fallback;
- Relation regression covers Cover Image attach/idempotency/retarget/backlink/cardinality/delete lifecycle;
- native canonical Image title + `Note` editing is live while legacy-owned mirrors remain read-only;
- canonical Image detail has reusable managed-media preview and edit components with profile-relative path support;
- safe canonical Image edit coordinator enforces exclusive managed-file ownership, format support, backup/restore, geometry refresh and byte rollback;
- canonical Image actions now cover rotate left/right, horizontal/vertical flip, restore, crop presets and normalized free crop;
- same-path managed byte edits explicitly refresh `FileImage` presentation cache;
- missing/partial persisted Image geometry can be resolved read-only from managed bytes while complete persisted geometry remains the no-decode fast path (#473);
- canonical Image backlinks cover the legacy Photo -> Bookmark reverse-lookup concept;
- legacy Photo deletion preserves managed files still owned/shared by canonical Images;
- generic Image deletion removes only unambiguously sole-owned managed files and preserves shared/external/symlinked media;
- generic Images block deletion while an Image still participates in legacy Photo compatibility sync, preventing delete-then-recreate/re-promote loops;
- Bookmark opening modes, Property rows/add flows, URL presentation and List metadata hierarchy are converged;
- canonical Relation mutation/read/index/backlink/audit/reconcile remains mature;
- AppDatabase responsibility reduction, caller-zero cleanup and Bookmark read-boundary cleanup continue under #225;
- macOS app/DMG packaging is integrated and CI-built successfully.

## Object lane — current state
Object owns #56/#155/#245/#249 product replacement surfaces and daily-use presentation.

#245 Phase 1 canonical Image import/create and Phase 2 legacy Photo -> Image mirroring are functionally implemented. Phase 3 Bookmark `Images` / `Cover Image` canonical Relation semantics and lifecycle are also implemented, while some user-facing Bookmark/People write paths still use legacy Photo authority.

The reusable canonical Image panel is now feature-rich enough to replace most legacy Photo editor affordances: preview, rotate, horizontal/vertical flip, restore, crop presets and free crop all remain behind `CanonicalImageEditService`. Older/native Images without complete persisted geometry can still present/crop using #473 read-only geometry fallback.

The highest-value remaining Image work is **real host integration and legacy UI retirement**, not another Image persistence/editor subsystem. `ObjectImageDetailPanel` still needs a genuinely patch-sized wiring change in `ObjectInspectorPage`. Current connector writes replace complete files, so the shared large host must not be reconstructed merely to add a small hunk.

Generic Images List still uses a generic document icon rather than Image thumbnails; media parity likewise requires a patch-sized generic host seam. #249 still has Stage1 List row padding/min-height/title/trailing alignment and Bookmark fixed/masonry wiring remaining; those also touch a large shared host.

Person profile image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object product contract exists. Legacy `photo_database_picker.dart` still has real Bookmark create/detail and People callers tied to legacy write authority.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain compatibility/import/export/live-host data until production caller-zero and migration policy are proven. Presentation convergence alone is not permission to delete storage.

## Relation lane — current state
Canonical Relation behavior is mature. Bookmark `Images` and `Cover Image` production semantics use canonical Relation APIs and focused lifecycle regression is integrated.

Recent Image edit/crop/geometry work is Relation-neutral and does not create alternate Relation writes. Resume Relation implementation only for a genuinely new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression. Person -> Image or new direct Bookmark Image editor/attachment writes become Relation-lane triggers when they become real production write paths.

## Refactor lane — #225 current state
Major completed work includes migration-body extraction, read-store responsibility moves, canonical Bookmark visual consolidation, GenericDatabasePage decomposition, caller-zero cleanup, Bookmark resolver/read-boundary cleanup and FTS projection deduplication.

Refactor #467 added privacy-safe observability to optional Image file existence probing without changing fail-soft behavior. Refactor #472 retired a caller-zero Person role-properties widget. Recheck live PR ownership before touching shared resolver/host files; Object product-semantic migration must establish replacement behavior before Refactor deletes legacy Photo/Bookmark paths.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicates.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = presentation/query over a Database collection.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Tags/Weblinks/Images are reusable Objects; lightweight local choices remain Values.
- Daily Note is an Object keyed by unique local date.
- Weblink stores shared resource facts; Bookmark stores user-specific context and relates to Weblink.
- Relation writes/deletions use canonical Relation APIs.
- Aliases are search/presentation metadata; references persist canonical Object ids.
- Identity-sensitive system collections must not fall back to raw title-only Object creation.
- New Object-first feature work must not deepen legacy `BookmarkItem`/legacy-table dependencies unless explicitly required for compatibility/migration.
- Presentation should not reach through high-level application dependencies to build low-level Store/Service graphs when a focused boundary already exists.

## Delivery priorities
1. **Object / #245/#56:** wire `ObjectImageDetailPanel` into canonical Image detail once a patch-sized `ObjectInspectorPage` edit path is available; retain canonical edit ownership checks and same-path preview refresh.
2. **Object / #245:** finish generic Images List/Table media parity through existing `ImageVisualResolver`/generic media contracts; do not build another Image-specific database page.
3. **Object / #245:** retire legacy Photo user-facing navigation/write paths only after Bookmark/People write parity is proven. Do not swap `photo_database_picker.dart` to canonical-only writes while compatibility sync can overwrite them.
4. **Object / #249:** finish Bookmark List row polish and fixed/masonry Gallery parity when patch-sized Stage1 editing is available; reuse generic View `galleryMode` persistence rather than fork settings.
5. **Object / #155:** continue canonical Weblink/Image presentation migration only where replacement semantics are already proven; do not remove legacy edit/import/export compatibility prematurely.
6. **Refactor / #225:** continue measurable responsibility reduction and legacy deletion only after Object replacement parity; sequence shared-host/resolver work with current PR ownership.
7. **Relation:** remain stable unless a new Relation-producing workflow or concrete regression appears.
8. **User/product:** validate installable macOS delivery and prioritize usage-discovered friction over speculative abstractions.
9. Defer broad #242 Vault work unless it becomes a direct dependency of a chosen Image path/storage slice.

## Validation status
- Object #460 Flutter CI #1604 green; merged as `3ead07fba966261aafaab1bc825d1d98a881623d`.
- Object #465 Flutter CI #1613 green; merged as `2b25c55bd621ad438290923995c24756827beb53`.
- Object #469 Flutter CI #1620 green; merged as `1d4775530b4c1646cb4a88d719e96f48b6bec39b`.
- Object #473 Flutter CI #1631 green; merged as `a1ea19391f07412c4117d9543f395d79f7f1f8da` immediately before #469.
- #473 validates complete persisted geometry no-decode behavior, read-only fallback for missing geometry, coherent replacement of partial invalid metadata, profile-relative path handling and missing-file fail-closed behavior.
- Relation remains on the mature canonical lifecycle baseline; recent Object filesystem/edit/presentation work does not alter Relation representation.

## Known risks / sequencing constraints
- do not introduce direct serialized-id Relation writes from new system-collection/import UX;
- ambiguous Relation damage is not automatically repaired;
- future Object merge/dedup requires explicit Relation policy before edge/value rewrites;
- legacy Bookmark URL/thumbnail/Photo remains compatibility data while live/import/export/backup paths need it;
- rich media must reuse managed Image/Weblink identity, canonical Relation reads and persisted geometry;
- large shared hosts must be edited in sequenced, patch-sized slices; rebuild intended diffs on latest main rather than force-merging stale branches;
- current connector writes replace complete existing files, so do not reconstruct a large shared host merely to make a small UI hunk change;
- global legacy Photo copy/reuse semantics must not change while legacy Photo workflows still rely on independent managed paths;
- generic Image deletion must remain compatibility-aware while `photo_object_links` is authoritative;
- canonical Image editing must not mutate shared managed files in place and must retain immediate ownership recheck, geometry refresh and rollback;
- test-only lifecycle/hang failures must not be “fixed” by changing production semantics or merely raising global timeouts without evidence;
- debug diagnostics must not leak raw persisted/request user content merely to improve observability.

## Current lane status
- **Object:** active on #56/#155/#245/#249. Image import/bridge/edit foundations are integrated; shared-host Image panel/List/Stage1 parity is the main remaining product gap.
- **Relation:** stable; current handoff work is documentation-only unless a new Relation-producing Image workflow lands.
- **Refactor:** recent observability/caller-zero work is integrated; recheck live ownership before overlapping edits.
