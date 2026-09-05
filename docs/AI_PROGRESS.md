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
The generic Object/Relation architecture is live in real Database/Object hosts. Work is now mostly Object-first daily-use parity plus targeted retirement of legacy Bookmark presentation/read responsibilities.

Important `main` state through 2026-09-06:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed previews become Image Objects and canonical Representative-image Relations;
- Weblinks / Images / Daily Notes are exposed through generic sidebar/Database hosts;
- canonical Weblink URL-entry and managed Image import are live in the generic host (#286/#291);
- fixed/masonry Gallery modes and managed Weblink/Image media are integrated (#223/#284/#288);
- Weblink/Image defaults, generated titles and site/favicon metadata are daily-use oriented (#293/#298/#302/#309);
- direct Weblink creation performs best-effort metadata/preview enrichment (#303), with Relation lifecycle coverage in #307;
- managed Image source URL identity is normalized (#308);
- shared URL Properties are safely clickable on current main;
- canonical Bookmark visual rendering covers lifecycle rows (#296), Notion cards (#294), and reverse lookup (#299); Stage1 List/Table is the final original duplicate under Refactor #304;
- AppDatabase historical migration bodies v2-v16 are extracted and historical migration regressions extend to v1;
- Bookmark/SavedView/Photo composite reads and profile-path concerns moved out of AppDatabase (#281/#282/#283/#289);
- GenericDatabasePage P1 decomposition has started: #310 moves read/projection loading into `GenericDatabasePageStateLoader`;
- canonical Relation mutation/read/index/backlink/audit/reconcile remains mature;
- macOS app/DMG packaging from #220 is integrated and CI-built successfully.

## Object lane — current state
Object owns #56/#155 product replacement surfaces and daily-use presentation.

Recent merged work includes canonical URL-entry, managed Image import/media, Weblink/Image defaults, direct enrichment, source identity normalization, Site name/Favicon metadata and clickable URL values. See `docs/AI_PROGRESS_OBJECT.md` for exact current details.

Current open Object work includes **#312 `Prefer canonical Weblink URLs in Bookmark lifecycle`**:
- read-only resolver prefers one healthy canonical Bookmark -> Weblink Relation and Weblink URL Property;
- legacy Bookmark URL remains compatibility fallback;
- ambiguous/malformed/cross-type Relation state fails closed rather than repairing data;
- #312 explicitly avoids Stage1 while Refactor #304 owns that host.

Object-first replacement must precede deletion of legacy URL/thumbnail storage or import/export compatibility.

## Relation lane — current state
Canonical Relation behavior is mature. Latest focused composition coverage includes #307 for direct generic Weblink creation/enrichment -> managed Representative Image Relation.

Relation resumes for a genuinely new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression. Presentation-only Object/Refactor work should not create parallel Relation implementations.

## Refactor lane — #225 current state
Major completed work:
- P0 maintainability/no-new-legacy-dependency/error-policy/architecture guardrails;
- behavior-preserving diagnostics for several intentional fail-soft paths;
- complete v2-v16 migration-body extraction plus historical compatibility fixes/regressions;
- `BookmarkReadStore`, `ProfilePathResolver`, `SavedViewReadStore`, `PhotoReadStore` responsibility moves (#281/#282/#283/#289);
- legacy visual consolidation for Notion and reverse lookup (#294/#299), coordinated with Object lifecycle visual #296;
- first GenericDatabasePage P1 decomposition slice #310, full Analyze/Test green and merged.

Current Refactor PR **#304** removes Stage1 List/Table direct cover/thumbnail rendering in favor of `BookmarkVisualImage`. Production change is small. Its focused full-page widget regression has been hanging a `flutter_tester` worker under the full suite and hitting the CI Test step timeout; latest branch work explicitly unmounts the Stage1 widget before database close. Treat this as a test-lifecycle issue until evidence shows a production defect.

Next Refactor priority after #304 is another small GenericDatabasePage responsibility extraction, not a monolithic rewrite.

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

## Delivery priorities
1. Object: continue #155/#56 daily-use parity and canonical legacy replacement surfaces, including #312.
2. Refactor: finish #304 test lifecycle and merge the final original Stage1 visual duplicate migration if green.
3. Refactor: continue GenericDatabasePage P1 decomposition as focused behavior-preserving responsibility moves.
4. Object + Refactor in sequence: narrow legacy Bookmark URL/thumbnail reads only after each Object-first replacement is proven.
5. User/product: validate #220 `Bookmark.app` locally and #205 visual alignment in the actual app/theme.
6. Prefer usage-discovered friction and measurable maintenance reduction over speculative abstraction.

## Validation status
- Relation #307 is full-CI green and merged.
- Refactor #310 is full Analyze/Test green and merged.
- migration/read-store/path-resolver refactor slices listed above were integrated with focused regressions and full/focused CI as appropriate.
- #304 production Analyze is green; current unresolved validation is the hanging focused widget-test worker under full-suite execution.
- macOS release workflow for #220 previously built and uploaded the release package successfully.

## Known risks / sequencing constraints
- do not introduce direct serialized-id Relation writes from new system-collection/import UX;
- ambiguous Relation damage is not automatically repaired;
- future Object merge/dedup requires explicit Relation policy before edge/value rewrites;
- legacy Bookmark URL/thumbnail remains compatibility data while old production/import paths need it;
- rich media must reuse managed Image/Weblink identity, canonical Relation reads and persisted geometry;
- large shared hosts must be edited in sequenced, patch-sized slices; rebuild intended diffs on latest main rather than force-merging stale branches;
- test-only lifecycle/hang failures must not be “fixed” by changing production semantics or simply raising global timeouts without evidence.

## Current lane status
- **Object:** active on #155/#56 daily-use parity; #312 currently owns Bookmark lifecycle URL presentation/opening.
- **Relation:** stable/idle until a new Relation-producing workflow or concrete regression appears.
- **Refactor:** active on #225; #310 P1 state-loader is merged, #304 Stage1 visual test lifecycle is being resolved, then GenericDatabasePage decomposition continues.
