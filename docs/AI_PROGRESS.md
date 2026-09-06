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

## Current implementation position — 2026-09-06
Latest production main observed in this Object run: `a8c39f6941a9959791b7d36305e921b4e5d0784f` after Object #423.

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
- Relation-lane regression covers Cover Image attach/idempotency/retarget/backlink/cardinality/delete lifecycle;
- native canonical Image title + `Note` editing is live while legacy-owned mirrors remain read-only;
- canonical Image detail has a reusable managed-media preview component with profile-relative path and persisted geometry support;
- canonical Image backlinks cover the legacy Photo -> Bookmark reverse-lookup concept;
- legacy Photo deletion preserves managed files still owned/shared by canonical Images;
- generic Image deletion removes only unambiguously sole-owned managed files and preserves shared/external/symlinked media;
- generic Images now block deletion while an Image still participates in legacy Photo compatibility sync, preventing delete-then-recreate/re-promote loops (#423);
- Bookmark opening modes, Property rows/add flows, URL presentation and List metadata hierarchy are converged;
- canonical Relation mutation/read/index/backlink/audit/reconcile remains mature;
- AppDatabase responsibility reduction and Bookmark FTS/read-boundary cleanup continue under #225;
- macOS app/DMG packaging is integrated and CI-built successfully.

## Object lane — current state
Object owns #56/#155/#245/#249 product replacement surfaces and daily-use presentation.

#245 has moved well beyond initial identity/dedupe work. Canonical Image import/reimport, Photo promotion, Bookmark `Images`/`Cover Image` semantics, cover presentation, reverse lookup, metadata editing, managed-file deletion safety and legacy-sync deletion guards are now integrated.

Current WIP is #426: a focused `ImageObjectService.updateManagedGeometry(...)` mutation so future canonical Image editing can replace stale `Pixel width` / `Pixel height` after crop/rotate while preserving identity, File and provenance. Direct Image editor exposure is intentionally not enabled yet because an in-place file edit may affect another canonical Image, another workspace, or a legacy Photo consumer. Reuse existing ownership auditing; do not introduce a second file-ownership model.

The reusable Image detail preview from #416 still needs a patch-sized wiring change in `ObjectInspectorPage`. Current connector writes replace complete files, so this shared large host must not be reconstructed merely to add a small hunk.

#249 still has actionable presentation parity: Stage1 List row padding/min-height/title/trailing alignment and Bookmark fixed/masonry wiring. These also touch a large shared host and should wait for a patch-sized/hunk-capable edit path rather than force whole-file replacement.

Person profile image migration remains deferred because People UX is still legacy `profilePhotoId`/Photo-oriented and no first-class Person Object product contract exists.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain compatibility/import/export/live-host data until production caller-zero and migration policy are proven. Presentation convergence alone is not permission to delete storage.

## Relation lane — current state
Canonical Relation behavior is mature. Bookmark `Images` and `Cover Image` production semantics use canonical Relation APIs and focused lifecycle regression is integrated.

Recent Object Image deletion/file-cleanup work does not introduce alternate Relation writes. Allowed generic Image deletion still delegates to `RelationMutationService.deleteObject(...)`; #423 only adds an Object-owned pre-delete compatibility guard while legacy Photo remains authoritative.

Resume Relation implementation only for a genuinely new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression. Person -> Image or new direct Bookmark Image editor/attachment writes become Relation-lane triggers when they become real production write paths. Presentation-only work must not create parallel Relation implementations.

## Refactor lane — #225 current state
Major completed work includes migration-body extraction, read-store responsibility moves, canonical Bookmark visual consolidation, GenericDatabasePage decomposition, caller-zero cleanup, Bookmark resolver/read-boundary cleanup and FTS projection deduplication.

Recent Refactor #422/#424 are integrated. Recheck live PR ownership before touching shared resolver/host files; Object product-semantic migration must establish replacement behavior before Refactor deletes legacy Photo/Bookmark paths.

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
1. **Object / #245:** finish #426 geometry-refresh validation/merge, then define a safe canonical Image editor workflow that reuses existing managed-file ownership auditing, fails closed or copy-on-edits shared media, and re-probes persisted geometry after successful edits.
2. **Object / #245/#56:** wire the existing canonical Image detail preview into `ObjectInspectorPage` once a patch-sized edit path is available; do not reconstruct the shared host wholesale.
3. **Object / #249:** finish Bookmark List row polish and fixed/masonry Gallery parity when patch-sized Stage1 editing is available; reuse generic View `galleryMode` persistence rather than fork settings.
4. **Object / #155:** continue canonical Weblink/Image presentation migration only where replacement semantics are already proven; do not remove legacy edit/import/export compatibility prematurely.
5. **Refactor / #225:** continue measurable responsibility reduction and legacy deletion only after Object replacement parity; sequence shared-host/resolver work with current PR ownership.
6. **Relation:** remain stable unless a new Relation-producing workflow or concrete regression appears.
7. **User/product:** validate installable macOS delivery and prioritize usage-discovered friction over speculative abstractions.
8. Defer broad #242 Vault work unless it becomes a direct dependency of a chosen Image path/storage slice.

## Validation status
- Object #416 Flutter CI #1498 green; merged as `442804c8c15c65fd66ed95ccbfde9d20172c48bf`.
- Object #423 initially exposed a profile-relative test-fixture identity mismatch; production semantics were unchanged. The fixture was corrected to use `ProfilePathResolver.toStoredPath(...)`.
- Object #423 Flutter CI #1512 then passed Analyze and all 708 tests; merged as `a8c39f6941a9959791b7d36305e921b4e5d0784f`.
- Object #426 is the current geometry-refresh WIP; recheck live CI/mergeability before integration.
- Relation remains on the mature canonical lifecycle baseline; recent Object filesystem/compatibility guards do not alter Relation representation.

## Known risks / sequencing constraints
- do not introduce direct serialized-id Relation writes from new system-collection/import UX;
- ambiguous Relation damage is not automatically repaired;
- future Object merge/dedup requires explicit Relation policy before edge/value rewrites;
- legacy Bookmark URL/thumbnail/Photo remains compatibility data while live/import/export/backup paths need it;
- rich media must reuse managed Image/Weblink identity, canonical Relation reads and persisted geometry;
- large shared hosts must be edited in sequenced, patch-sized slices; rebuild intended diffs on latest main rather than force-merging stale branches;
- current connector writes replace complete existing files, so do not reconstruct a large shared host merely to make a small UI hunk change;
- global legacy Photo copy/reuse semantics must not change while legacy Photo workflows still rely on independent managed paths;
- generic Image deletion must remain compatibility-aware while `photo_object_links` is authoritative; a reused native Image can have null `Legacy Photo ID` and still be an active legacy Photo mapping target;
- Image editor integration must not mutate a shared managed file in place without an explicit ownership/copy-on-edit policy, and must refresh persisted dimensions after byte edits;
- test-only lifecycle/hang failures must not be “fixed” by changing production semantics or merely raising global timeouts without evidence;
- debug diagnostics must not leak raw persisted/request user content merely to improve observability.

## Current lane status
- **Object:** active on #56/#155/#245/#249. #423 is merged; #426 is current safe WIP. Shared-host Image preview and Stage1 parity remain tooling-constrained.
- **Relation:** stable; current handoff work is documentation-only unless a new Relation-producing Image workflow lands.
- **Refactor:** recent FTS/caller-zero handoff work is integrated; recheck live ownership before overlapping edits.
