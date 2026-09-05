# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

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

Before editing shared hotspots, inspect open PR ownership. In particular, sequence non-trivial edits to `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and `app_database.dart`.

## Current implementation position
The generic Object/Relation architecture is live in real Database/Object hosts. Work is now mostly Object-first daily-use parity plus targeted retirement of legacy Bookmark presentation/read responsibilities and measurable hotspot reduction.

Important `main` state through 2026-09-06:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed previews become Image Objects and canonical Representative-image Relations;
- Weblinks / Images / Daily Notes are exposed through generic sidebar/Database hosts;
- canonical Weblink URL-entry and managed Image import are live in the generic host (#286/#291);
- fixed/masonry Gallery modes and managed Weblink/Image media are integrated (#223/#284/#288);
- Weblink/Image defaults, generated titles and site/favicon metadata are daily-use oriented (#293/#298/#302/#309);
- direct Weblink creation performs best-effort metadata/preview enrichment (#303), with Relation lifecycle coverage in #307;
- managed Image source URL identity is normalized (#308);
- shared URL Properties are safely clickable;
- all four direct Bookmark visual duplicates from the original #225 inventory now route through canonical `BookmarkVisualImage`: Notion card #294, reverse lookup #299, lifecycle rows Object #296, and Stage1 List/Table #324;
- canonical Bookmark URL presentation is moving host by host through `BookmarkUrlResolver`: lifecycle #317 and reverse lookup #320 are merged; Notion card #322 is the current open Object slice;
- AppDatabase historical migration bodies v2-v16 are extracted and historical migration regressions extend to v1;
- Bookmark/SavedView/Photo composite reads and profile-path concerns moved out of AppDatabase (#281/#282/#283/#289);
- GenericDatabasePage decomposition now includes read/projection loading #310 and low-level dependency composition #323;
- recent #225 diagnostics/privacy work #321/#325/#326/#327/#328/#329 preserves fail-soft behavior while reducing silent failures and user-content leakage in debug logs;
- canonical Relation mutation/read/index/backlink/audit/reconcile remains mature;
- macOS app/DMG packaging from #220 is integrated and CI-built successfully.

## Object lane — current state
Object owns #56/#155 product replacement surfaces and daily-use presentation.

Recent Object-first legacy URL migration:
- **#317 merged** — Bookmark lifecycle prefers one healthy canonical Bookmark -> Weblink URL and retains legacy Bookmark URL fallback;
- **#320 merged** — reverse lookup uses the same canonical URL preference;
- **#322 open** — Notion bookmark-card URL display/open behavior is the current focused Object PR.

The canonical URL resolver is read-only and fails closed on missing/ambiguous/malformed Relation state; presentation must not repair Relation data. Legacy Bookmark URL storage remains compatibility/import/export data until all production dependencies and migration policy are proven replaceable.

See `docs/AI_PROGRESS_OBJECT.md` for lane details, but verify actual GitHub PR state before relying on older active-PR numbers in that handoff.

## Relation lane — current state
Canonical Relation behavior is mature. Focused composition coverage includes #307 for direct generic Weblink creation/enrichment -> managed Representative Image Relation.

Relation resumes for a genuinely new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression. Presentation-only Object/Refactor work should not create parallel Relation implementations.

## Refactor lane — #225 current state
Major completed work:
- P0 maintainability/no-new-legacy-dependency/error-policy/architecture guardrails;
- complete v2-v16 migration-body extraction plus historical compatibility fixes/regressions;
- `BookmarkReadStore`, `ProfilePathResolver`, `SavedViewReadStore`, `PhotoReadStore` responsibility moves (#281/#282/#283/#289);
- original direct legacy Bookmark visual duplication fully retired through #294/#299/Object #296/#324;
- GenericDatabasePage read/projection extraction #310;
- GenericDatabasePage low-level dependency composition extraction #323;
- privacy-safe failure observability for PDF enrichment, tag-tree state, computed projection, optional remote preview ingestion, Database View JSON and generic Object/Property JSON through #321/#325/#326/#327/#328/#329.

The former Stage1 blocker is resolved. The heavyweight full-page regression, not production code, caused the ~12-minute CI Test hang. #324 replaced it with a deterministic source-level architecture guard and full Test returned to the normal ~3-minute range before merge.

There is no open Refactor PR at this checkpoint. The next Refactor priority is another **safe, patch-sized responsibility extraction** from a real hotspot—especially GenericDatabasePage schema/property/layout responsibilities—or a focused stable-error boundary. Do not create wrapper-only abstractions or hand-reconstruct huge shared files to work around tooling.

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
- Presentation should not reach through application dependencies to construct low-level Store/Service graphs when a focused boundary already exists.

## Delivery priorities
1. **Object:** continue #155/#56 daily-use parity and canonical legacy replacement surfaces; finish #322 or its latest replacement branch if main moves.
2. **Refactor:** continue GenericDatabasePage P1 decomposition through a safe, behavior-preserving responsibility move with focused coverage; prioritize real responsibility/LOC reduction.
3. **Object + Refactor in sequence:** narrow legacy Bookmark URL reads only after each Object-first replacement is proven; do not delete compatibility storage/import/export early.
4. **Refactor:** replace raw user-visible implementation exceptions with focused stable error states where retry/failure behavior can be tested; `GlobalSearchPage` is a known candidate.
5. **User/product:** validate #220 `Bookmark.app` locally and #205 visual alignment in the actual app/theme.
6. Prefer usage-discovered friction and measurable maintenance reduction over speculative abstraction.

## Validation status
- Relation #307 is full-CI green and merged.
- Refactor #310 and #323 responsibility/composition slices are full Analyze/Test green and merged.
- Stage1 canonical visual #324 is full Analyze/Test green and merged with the deterministic guard; Test completed in the normal range.
- Refactor failure/privacy #321/#325/#326/#327/#328/#329 are merged after green Analyze/Test; #329 includes focused persisted-JSON corruption coverage.
- migration/read-store/path-resolver refactor slices listed above were integrated with focused regressions and full/focused CI as appropriate.
- macOS release workflow for #220 previously built and uploaded the release package successfully.

## Known risks / sequencing constraints
- do not introduce direct serialized-id Relation writes from new system-collection/import UX;
- ambiguous Relation damage is not automatically repaired;
- future Object merge/dedup requires explicit Relation policy before edge/value rewrites;
- legacy Bookmark URL/thumbnail remains compatibility data while old production/import/export paths need it;
- rich media must reuse managed Image/Weblink identity, canonical Relation reads and persisted geometry;
- large shared hosts must be edited in sequenced, patch-sized slices; rebuild intended diffs on latest main rather than force-merging stale branches;
- test-only lifecycle/hang failures must not be “fixed” by changing production semantics or merely raising global timeouts without evidence;
- `ProfileManager` corrupt-registry fallback affects data-location recovery and requires explicit policy before behavior changes;
- debug diagnostics must not leak raw persisted/request user content merely to improve observability.

## Current lane status
- **Object:** active on #155/#56; #317/#320 URL host migrations merged and #322 is open at this checkpoint.
- **Relation:** stable/idle until a new Relation-producing workflow or concrete regression appears.
- **Refactor:** active on #225; #310/#323 hotspot decomposition and #324 visual consolidation are merged; #321/#325–#329 failure/privacy sequence is merged. Next work should be a safe measurable hotspot extraction or focused stable-error boundary.
