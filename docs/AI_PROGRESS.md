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
Latest production main observed in this Object run: `cd5aae6f726028363306c4a9449bc1a3a6f10bdb` after Object #382, followed by handoff documentation refresh commits.

The generic Object/Relation architecture is live in real Database/Object hosts. Current work is primarily Object-first daily-use parity, canonical Image/Photo convergence, legacy Bookmark presentation/read retirement after replacement parity, and measurable maintainability reduction.

Important merged state:
- canonical Bookmark -> Weblink and Weblink -> managed Image production flows are live;
- managed previews become Image Objects and canonical Representative-image Relations;
- Weblinks / Images / Daily Notes are exposed through generic sidebar/Database hosts;
- canonical Weblink URL entry and managed Image import are live (#286/#291);
- fixed/masonry Gallery and managed Weblink/Image media are integrated;
- Weblink/Image defaults, enriched titles, favicon/content-type/published-date metadata and clickable URL Properties are integrated;
- direct Weblink creation performs best-effort metadata/preview enrichment (#303), with Relation lifecycle coverage #307;
- managed Image source URL identity is normalized and stable file identity prevents duplicate Image Objects across provenance changes (#308/#379);
- legacy Photo promotion reuses canonical Images while preserving native Image ownership (#378/#380);
- Weblink preview ingestion now reuses canonical-equivalent Image source identity before downloading/copying media (#381);
- canonical Image reimport deterministically reuses byte-identical managed files while legacy/default Photo imports preserve independent-copy behavior (#382);
- all four direct Bookmark visual duplicates from the original #225 inventory use canonical `BookmarkVisualImage` (#294/#299/Object #296/#324);
- canonical Bookmark URL presentation covers lifecycle #317, reverse lookup #320, Notion card #322, Stage1 #341, Bookmark List metadata #360 and reverse-lookup flash prevention #371;
- Bookmark opening modes use the shared presentation host (#344);
- Bookmark Property handle and Property-add flows are converged (#348/#346/#349/#350/#366);
- Bookmark List metadata hierarchy and bounded semantic chips are integrated (#352/#354/#370);
- AppDatabase historical migration bodies v2-v16 are extracted and historical migration regressions extend to v1;
- Bookmark/SavedView/Photo composite reads and profile-path concerns moved out of AppDatabase (#281/#282/#283/#289);
- GenericDatabasePage decomposition includes state/projection loading #310 and low-level dependency composition #323;
- canonical Relation mutation/read/index/backlink/audit/reconcile remains mature;
- macOS app/DMG packaging from #220 is integrated and CI-built successfully.

## Object lane — current state
Object owns #56/#155/#245/#249 product replacement surfaces and daily-use presentation.

Recent convergence includes:
- #379 stable managed Image file identity;
- #380 canonical Image reuse during legacy Photo promotion;
- #381 canonical Image source lookup before Weblink preview download, merged as `25c9618c8a957aff771fd3c864be15a57e6ba339` after Flutter CI #1403 green;
- #382 deterministic byte-identical canonical Image reimport, merged as `cd5aae6f726028363306c4a9449bc1a3a6f10bdb` after Flutter CI #1404 green.

#245 Phase 1 duplicate/reimport behavior is now deterministic for canonical Image import, and Phase 2 Photo promotion has stronger canonical file reuse. Remaining work is product-semantic convergence: Bookmark cover/multi-image semantics, useful generic Images parity, Person profile image migration, Vault/path coordination where needed, and eventual legacy Photo caller retirement.

#249 remains the highest-value presentation parity work: finish Stage1 List row spacing/title/action alignment, then wire Bookmark Gallery to the existing shared persisted fixed/masonry contract. These changes must remain patch-sized because `bookmark_unified_stage1_page.dart` is a large shared hotspot.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain compatibility/import/export/live-host data until production caller-zero and migration policy are proven. Presentation convergence alone is not permission to delete storage.

## Relation lane — current state
Canonical Relation behavior is mature. Direct generic Weblink creation/enrichment -> managed Representative Image Relation has focused lifecycle coverage (#307).

#381/#382 introduce no new Relation writes. Resume Relation implementation only for a genuinely new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression. Bookmark -> Image or Person -> Image migration becomes a Relation-lane lifecycle trigger once a real production write path is introduced. Presentation-only Object/Refactor work must not create parallel Relation implementations.

## Refactor lane — #225 current state
Major completed work includes migration-body extraction, read-store responsibility moves, canonical Bookmark visual consolidation, GenericDatabasePage decomposition, and broad rollback/failure-observability guardrails.

Live Refactor work observed during the latest Object run includes:
- #383 — centralize legacy Bookmark -> mirrored Object link lookup behind `BookmarkObjectLinkReadStore`;
- #385 — delegate reverse-lookup resolver composition through the existing presentation resolver factory.

These are behavior-preserving resolver/dependency-boundary changes. Recheck their live state before touching overlapping #155 presentation/resolver paths.

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
1. **Object / #249:** finish Bookmark List row polish in a patch-sized Stage1 slice, then reuse the generic `DatabaseViewGalleryAdapter` / `ObjectGalleryView` fixed/masonry contract with per-View persistence and real-host/widget regression.
2. **Object / #155:** continue canonical Weblink/Image presentation migration where replacement semantics are already proven; do not remove legacy edit/import/export compatibility prematurely.
3. **Object / #245:** move from identity/dedupe work toward product-semantic Image convergence; any new Bookmark/Person Image Relations must use canonical Relation APIs and receive Relation-lane lifecycle coverage.
4. **Refactor / #225:** continue measurable responsibility reduction and legacy deletion only after Object replacement parity; sequence resolver work with current open PR ownership.
5. **Relation:** remain stable unless a new Relation-producing workflow or concrete regression appears.
6. **User/product:** validate installable macOS delivery and prioritize usage-discovered friction over speculative abstractions.
7. Defer broad #242 Vault work unless it becomes a direct dependency of a chosen Image path/storage slice.

## Validation status
- Object #381 Flutter CI #1403 green; squash merged as `25c9618c8a957aff771fd3c864be15a57e6ba339`.
- Object #382 Analyze/Test green in Flutter CI #1404; squash merged as `cd5aae6f726028363306c4a9449bc1a3a6f10bdb`.
- Object #149/#247 were real-host validated by the user and closed; #252 is closed after #366.
- Earlier Object #378/#379/#380 Image identity/promotion slices are integrated on main.
- Relation remains on the mature canonical lifecycle baseline; #381/#382 did not change Relation behavior.

## Known risks / sequencing constraints
- do not introduce direct serialized-id Relation writes from new system-collection/import UX;
- ambiguous Relation damage is not automatically repaired;
- future Object merge/dedup requires explicit Relation policy before edge/value rewrites;
- legacy Bookmark URL/thumbnail/Photo remains compatibility data while live/import/export/backup paths need it;
- rich media must reuse managed Image/Weblink identity, canonical Relation reads and persisted geometry;
- large shared hosts must be edited in sequenced, patch-sized slices; rebuild intended diffs on latest main rather than force-merging stale branches;
- current connector writes replace complete existing files, so do not reconstruct a large shared host merely to make a small UI hunk change;
- global legacy Photo copy/reuse semantics must not change while legacy Photo workflows still rely on independent managed paths; #382 intentionally opts only canonical Image imports into reuse;
- test-only lifecycle/hang failures must not be “fixed” by changing production semantics or merely raising global timeouts without evidence;
- debug diagnostics must not leak raw persisted/request user content merely to improve observability.

## Current lane status
- **Object:** active on #56/#155/#245/#249. Image identity/reimport convergence through #382 is merged; next safe product target is #249 Stage1 List/Gallery parity when patch-sized editing is available.
- **Relation:** stable; no new Relation implementation required until a real new Relation-producing Image workflow lands.
- **Refactor:** active around resolver/read-boundary cleanup (#383/#385 observed); recheck live PR ownership before overlapping edits.
