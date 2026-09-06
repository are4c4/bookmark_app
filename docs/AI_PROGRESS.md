# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files. Always verify live GitHub PR/CI state before editing shared hotspots.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent daily-use workflow while reducing migration-era maintenance cost: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture/product issues:
- `#56` — generic Object/Database/View daily-use integration
- `#155` — reusable Weblink Object + managed Image presentation/navigation and legacy compatibility retirement
- `#149` — Property-row visual validation
- `#218` — installable macOS delivery; repository/CI implementation merged, local install/data-preservation validation remains
- `#225` — maintainability, hotspot reduction and legacy-path retirement

`#156` fixed/masonry Gallery and `#166` alias-aware Object identity are complete/closed.

## Development lanes
- **Object** — `docs/AI_PROGRESS_OBJECT.md`
- **Relation** — `docs/AI_PROGRESS_RELATION.md`
- **Refactor** — `docs/AI_PROGRESS_REFACTOR.md`

Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, and `app_database.dart`. Sequence edits by current PR ownership; do not reconstruct large hosts wholesale.

## Current implementation position — 2026-09-06
Latest `main` observed at this handoff: `a5968bc5d259731097f31ba60b5bf540aaaf664b` after Refactor #368.

The generic Object/Relation architecture is live in real Database/Object hosts. Current work is primarily Object-first daily-use parity, legacy Bookmark presentation/read retirement after replacement parity, and measurable maintainability reduction.

Important merged state:
- canonical Bookmark -> Weblink and Weblink -> managed Image production flows are live;
- managed previews become Image Objects and canonical Representative-image Relations;
- Weblinks / Images / Daily Notes are exposed through generic sidebar/Database hosts;
- canonical Weblink URL entry and managed Image import are live (#286/#291);
- fixed/masonry Gallery and managed Weblink/Image media are integrated;
- Weblink/Image defaults, enriched titles, favicon/content-type/published-date metadata and clickable URL Properties are integrated;
- direct Weblink creation performs best-effort metadata/preview enrichment (#303), with Relation lifecycle coverage #307;
- managed Image source URL identity is normalized (#308);
- all four direct Bookmark visual duplicates from the original #225 inventory use canonical `BookmarkVisualImage` (#294/#299/Object #296/#324);
- canonical Bookmark URL presentation covers lifecycle #317, reverse lookup #320, Notion card #322, Stage1 #341, and Bookmark List metadata #360;
- AppDatabase historical migration bodies v2-v16 are extracted and historical migration regressions extend to v1;
- Bookmark/SavedView/Photo composite reads and profile-path concerns moved out of AppDatabase (#281/#282/#283/#289);
- GenericDatabasePage decomposition includes state/projection loading #310 and low-level dependency composition #323;
- canonical Relation mutation/read/index/backlink/audit/reconcile remains mature;
- macOS app/DMG packaging from #220 is integrated and CI-built successfully.

## Object lane — current state
Object owns #56/#155 product replacement surfaces and daily-use presentation.

Recent convergence includes:
- Bookmark opening mode through shared presentation host #344;
- shared Property add popover #346;
- Bookmark Property handle convergence #348;
- generic Table/detail Property add adoption #349;
- `PersonRoleProperties` shared add flow #350;
- Bookmark List metadata hierarchy #352 and bounded semantic chips #354;
- Bookmark List URL metadata no longer reads legacy URL directly #360.

At this checkpoint **Object PR #366** owns the remaining `BookmarkReorderableProperties` person-role add-flow convergence. Its full Flutter CI #1364 is green, but the PR became non-mergeable after main advanced. Object lane should refresh/rebuild it on current main rather than force-merge. Refactor should not edit that host while the slice is active.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain compatibility/import/export/live-host data until production caller-zero and migration policy are proven. Presentation convergence alone is not permission to delete storage.

## Relation lane — current state
Canonical Relation behavior is mature. Direct generic Weblink creation/enrichment -> managed Representative Image Relation has focused lifecycle coverage (#307).

Relation handoff was refreshed from current architecture in #367. Resume Relation implementation only for a genuinely new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression. Presentation-only Object/Refactor work must not create parallel Relation implementations.

## Refactor lane — #225 current state
Major completed work:
- P0 maintainability/no-new-legacy-dependency/error-policy/architecture guardrails;
- complete v2-v16 migration-body extraction plus historical compatibility fixes/regressions;
- `BookmarkReadStore`, `ProfilePathResolver`, `SavedViewReadStore`, `PhotoReadStore` responsibility moves (#281/#282/#283/#289);
- original direct legacy Bookmark visual duplication retirement (#294/#299/Object #296/#324);
- GenericDatabasePage state/projection extraction #310 and dependency composition #323;
- broad privacy-safe failure observability/rollback protection sequence including #321/#325–#329/#331–#335;
- Board/Image/Profile rollback cleanup convergence #351/#358/#362;
- ProfileManager diagnostic privacy #363;
- attachment stable failure boundary #364;
- bootstrap/Profile-switch stable fail-closed boundary #368.

The old #336 attachment Widget/Drift regression repeatedly hit the workflow timeout. #364 superseded it with the same narrow production policy but no public test-only constructor seams and a deterministic guard; full CI returned to normal completion. Stale branches #336/#355/#357/#365 were closed instead of force-merged.

There is **no open Refactor production PR** at this checkpoint. The next Refactor priority should be a measurable, patch-sized responsibility extraction or a genuinely unsafe remaining boundary—not another speculative wrapper or micro logging PR.

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
1. **Object:** refresh/integrate #366 on current main, then continue #56/#155/#249/#252 daily-use parity with patch-sized slices.
2. **Refactor:** after rechecking open ownership, choose a measurable responsibility/LOC extraction from a real hotspot; GenericDatabasePage schema/database/Property/layout responsibilities remain candidates.
3. **Object + Refactor in sequence:** continue legacy Bookmark URL/thumbnail/Photo retirement only after each canonical replacement is proven; preserve import/export/backup compatibility until caller-zero.
4. **Relation:** remain stable unless a new Relation-producing workflow or concrete regression appears.
5. **User/product:** validate #220 `Bookmark.app` locally and #205/#149 visual behavior in the actual app/theme.
6. Prefer usage-discovered friction and measurable maintenance reduction over speculative abstraction.

## Validation status
- Refactor #363 full CI #1356 green and merged.
- Refactor #364 full Analyze/Test green and merged.
- Refactor #368 full Flutter CI #1367 green and merged as `a5968bc5d259731097f31ba60b5bf540aaaf664b`.
- Object #366 full Flutter CI #1364 green but stale/non-mergeable after main advanced; refresh before integration.
- Relation #367 was handoff-only and merged before #368.

## Known risks / sequencing constraints
- do not introduce direct serialized-id Relation writes from new system-collection/import UX;
- ambiguous Relation damage is not automatically repaired;
- future Object merge/dedup requires explicit Relation policy before edge/value rewrites;
- legacy Bookmark URL/thumbnail/Photo remains compatibility data while live/import/export/backup paths need it;
- rich media must reuse managed Image/Weblink identity, canonical Relation reads and persisted geometry;
- large shared hosts must be edited in sequenced, patch-sized slices; rebuild intended diffs on latest main rather than force-merging stale branches;
- test-only lifecycle/hang failures must not be “fixed” by changing production semantics or merely raising global timeouts without evidence;
- `ProfileManager` corrupt-registry fallback selection affects data-location recovery and requires explicit product/data-safety policy before behavior changes;
- debug diagnostics must not leak raw persisted/request user content merely to improve observability.

## Current lane status
- **Object:** active; #366 is the current focused slice but needs refresh after main advanced.
- **Relation:** stable; #367 refreshed handoff, no new Relation implementation currently required.
- **Refactor:** recent failure-policy backlog converged through #368; next work should prioritize measurable hotspot responsibility reduction after checking Object ownership.