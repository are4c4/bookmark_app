# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files. Always verify live GitHub Issues, PRs, CI and the latest `main` before changing shared hotspots.

## Current goal
Continue the transition from a Bookmark-specific application toward a composable Object / Relation / Database knowledge platform while preserving user data and reducing legacy maintenance cost.

Core product direction:
- Object is the durable reusable entity.
- ObjectType = schema/default behavior.
- Database = collection/query context.
- View = presentation/query configuration.
- Built-in code is reserved for irreducible native behavior; domain models such as Bookmark/Paper/Book/Project should normally be user-owned templates/configuration.

## Repository position — 2026-09-08
The generic composition architecture is proven in production code and the project is primarily in daily-use finishing, primitive migration, consolidation and real-machine validation.

Completed architecture/focused milestones include:
- #414 — legacy Bookmark FTS stale-token correctness.
- #481 — universal Object Body across real shared opening surfaces.
- #484 — built-in primitive boundary + user-composable domain architecture.
- #489 — shared native capability direction for Image/File.
- #490 — user-owned ObjectType/Database/View templates.
- #491 — Relation Property authoring + inline target create/import UX.
- #492 — generic Relation-backed Gallery cover source.
- #493 — safe/reversible user-defined schema evolution.
- #494 — canonical unified Object search/indexing.
- #495 — MIME/content-aware Image/File import routing.
- #501 — seven-lane AI development ownership model.
- #877 — focused Search refresh for additional canonical Objects created/reused from Search-opened detail.
- #249 — Bookmark Gallery/List presentation parity with shared generic contracts.

Recent composition proof:
- #856 (`7e103a02…`) defines Bookmark only as a user-owned template/configuration and proves normal Bookmark-like operation through canonical Weblink creation, generic Relations, generic Property values, Databases, Views and View filtering without adding a new Bookmark-only persistence/presentation API.
- #874 (`38c20b67…`) composes the reusable canonical Body editor into Generic Database side peek and closes #481.
- #884 (`f1651ba169240484f3376f6c67f7ce76a810172b`) closes #877 by extending Search-owned focused detail-return refresh to canonical outgoing Relation targets and their label dependents without a workspace rebuild.
- #881 (`47d31345dbaa602e99d00c6199650d9e6b329d32`) moves Bookmark image editing onto canonical Image Relations while retaining compatibility projection for legacy callers.
- #889 (`fcd0eb34c8ed79cbf67a8595f730f6c08cb7e7ff`) routes the legacy Photo Management “add to Bookmark” write through the same canonical Bookmark Image Relation authority using the stable Photo -> Image mapping, with malformed/missing mapping state failing closed.
- #885 (`38494512fc2ba119fecb3f94e6973577aa665f67`) closes #249 by wiring the real Bookmark Stage1 Gallery to the shared fixed/masonry View contract and real-host persistence regression.

## Active architecture/product issues
Live audit after #249 closure shows **7 open Issues**:
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object; remaining rich Weblink/Image presentation and legacy Bookmark URL/media convergence.
- `#218` — macOS installable delivery; repository packaging/CI complete, final user-machine validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault/storage lifecycle; production code complete, final real-macOS validation remains.
- `#245` — legacy Photos -> canonical Image Objects.
- `#888` — Search freshness for nested Daily Notes visited/edited from a Search-opened Object Inspector.

Do not treat #249/#481/#484/#489/#490/#491/#492/#493/#494/#495/#501/#877 as active merely because older Issue bodies or comments contain historical unchecked bullets.

## Seven development lanes
- **A — Object Core & Body** — `docs/AI_PROGRESS_OBJECT.md`
- **B — Relations & Data Integrity** — `docs/AI_PROGRESS_RELATION.md`
- **C — Database, View & Schema UX** — `docs/AI_PROGRESS_DATABASE_VIEW.md`
- **D — Primitive Objects & Media** — `docs/AI_PROGRESS_PRIMITIVES.md`
- **E — Search & Indexing** — `docs/AI_PROGRESS_SEARCH.md`
- **F — Storage, Vault & Delivery** — `docs/AI_PROGRESS_STORAGE.md`
- **G — Refactor & Architecture Health** — `docs/AI_PROGRESS_REFACTOR.md`

Each implementation run/PR has exactly one primary lane. Issues may span lanes, but implementation should split by coherent responsibility rather than temporary file availability.

## Current routing
### A — Object Core & Body
#481 and #249 are completed/closed. Universal Body and the focused Bookmark presentation parity Issue no longer provide open Lane A work.

Lane A continues to own Object/ObjectType identity, Property/Body core semantics, Daily Note identity and reusable Object opening/detail contracts. Current status is **idle by design** unless #56 or real usage exposes a concrete Object-core/detail correctness obligation. Do not invent schema types, Body abstractions or Bookmark presentation work merely to keep A active.

### B — Relations & Data Integrity
Owns canonical Relation mutation/read/index/backlink/audit/reconcile correctness and fail-closed corruption behavior.

Continue only concrete integrity obligations created by live workflows or regressions. Primitive flows such as #881/#889/#245 must continue using canonical Relation contracts rather than domain-specific edge stores.

### C — Database, View & Schema UX
Focused #490/#491/#492/#493 work and the cross-lane #481 composition obligation are complete.

Current status: **idle by design**. Resume only for a concrete generic Database/View/schema/template Issue or a specific #56 acceptance gap routed to C. Do not invent manual include/exclude membership or speculative View abstractions.

### D — Primitive Objects & Media
Primary active Issues:
- #155 — Weblink/Image presentation and legacy media convergence.
- #245 — canonical Image / Photo migration.

Recent checkpoints:
- #869 — canonical Image/Weblink media in generic List rows.
- #876 (`3506974e…`) — canonical media in generic Table rows.
- #879 (`3be71f12…`) — legacy Photo compatibility sync preserves first-class native Bookmark Image Relations.
- #881 (`47d31345…`) — Bookmark detail image editing writes canonical `Images` / `Cover Image` Relations while legacy mapped-photo projection remains compatibility-only.
- #889 (`fcd0eb34…`) — legacy Photo Management Bookmark attachment now resolves the stable Photo -> Image mapping and delegates to the same canonical Bookmark Image Relation service; missing/malformed mappings fail closed instead of reviving Photo as a second write authority.

Continue canonical Image write/presentation parity and Photo -> Image migration before retiring legacy Photo UI/storage callers. Do not delete compatibility storage before caller parity and migration safety are proven.

### E — Search & Indexing
#414/#494/#877 are completed/closed. #884 (`f1651ba1…`) is the completed #877 implementation.

Primary active Issue is now **#888**: nested Daily Note navigation from a Search-opened Inspector can mutate an Object that is not reachable through the source Object's Relation-based refresh plan. Preserve focused refresh, keep Search orchestration Search-owned, and do not add Search dependencies to Object presentation.

### F — Storage, Vault & Delivery
- #242 Vault: repository implementation complete; real-macOS Create/Open/Switch/Move/Recovery validation remains.
- #218 packaging/install: repository implementation complete; user-machine install/launch/data-preservation validation remains.
- shared managed-file copy/ownership/rollback/delete filesystem contracts are delivered for Primitive consumers.

No speculative Storage implementation is required while the remaining acceptance depends on real-machine validation.

### G — Refactor & Architecture Health
#225 remains active.

Current focus remains behavior-preserving caller-zero deletion, hotspot responsibility reduction, dependency/shim ratchets, stable user-facing error/privacy policy, and `AppDatabase` narrowing only when a real responsibility disappears. Do not hide product behavior changes inside Refactor work.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database = target ObjectType + collection filter; View filter/sort/group/layout remain separate presentation/query configuration.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- universal Object Body is available through shared side/center/full real opening surfaces without type-specific note storage/editor paths.
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature and production paths increasingly share the same integrity contract.
- template-derived schemas are user-owned/editable and are not silently reset by later template versions.
- Bookmark-like domain creation/normal operation is proven through generic template/Object/Relation/Database/View contracts.
- Bookmark Stage1 Gallery now uses the same fixed/masonry View setting/renderer contract as generic Database Gallery (#885); #249 is completed.
- Weblink is a reusable canonical Object with normalized URL identity, enrichment and managed Image Relations.
- Bookmark detail image editing and the legacy Photo Management Bookmark-attach flow now write through canonical Image Relations (#881/#889), while compatibility projection remains for old Photo-based readers during #245 migration.
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- PDF remains File + PDF capabilities/enrichment/search; there is no separate PDF persistence model.
- Global Search is canonical Object search; detail-return freshness uses focused refresh planning rather than routine full-workspace rebuilds.
- Storage-managed files use one Vault filesystem contract with explicit ownership and fail-closed delete safety.
- macOS release/DMG CI has succeeded; final local install/Vault preservation validation remains outside repository automation.

## Remaining product edge
Highest-value remaining work from live Issues:
1. **#245 Photo -> Image** — continue canonical Image presentation/write parity, migrate remaining Bookmark/People/Photo consumers, then hide/retire legacy `写真` only after caller parity.
2. **#155 Weblink consolidation** — finish rich generic Weblink/Image presentation and retire legacy Bookmark URL/thumbnail compatibility only after callers reach zero.
3. **#888 Search freshness** — refresh nested Daily Notes visited/edited from Search-opened detail while preserving the focused-refresh architecture.
4. **#225 Refactor** — delete superseded Bookmark/Photo/shim paths after replacement parity and continue reducing hotspot responsibility.
5. **#242/#218 validation** — final real-macOS Vault and packaged-app preservation checks with the user.
6. **#56 usage-driven finishing** — create focused follow-up Issues only for concrete real-use gaps; do not reopen completed architecture Issues merely because historical umbrella text is stale.

## Repository-wide design contract
- Objects are global and are not owned/duplicated by Databases or Views.
- ObjectType defines schema/defaults; Database selects Objects; View controls presentation/query.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + versioned block-oriented Body.
- Weblink/Image/File/Tag are built-in only for irreducible native identity/capability/default semantics.
- Bookmark/Note/Paper/Book/Project/Recipe/etc. should normally be user-owned/template ObjectTypes.
- Relation writes/deletes use canonical Relation APIs; no domain-specific edge stores.
- New domains participate in canonical Object search instead of adding long-term domain-specific search indexes.
- New Object-first work must not deepen legacy Bookmark/Photo dependencies except explicit compatibility/migration bridges.
- Legacy storage/schema is not deleted merely because replacement UI exists; retirement requires caller-zero/parity evidence and migration safety.

## Concurrency / hotspot rule
Shared hotspots include:
- `lib/views/generic_database_page.dart`
- `lib/views/app_shell.dart`
- `lib/views/object_inspector_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/widgets/bookmark_reorderable_properties.dart`
- `lib/views/people_management_page.dart`
- `lib/views/settings_page.dart`
- `lib/services/profile_manager.dart`
- `lib/data/app_database.dart`

Before non-trivial edits, inspect current open PR ownership. One lane at a time may hold a broad hotspot lease. Patch-sized non-overlapping changes still require a fresh overlap audit.

## Cross-lane boundaries
- Database/View owns generic presentation/configuration contracts; Primitive owns Weblink/Image/File-specific product semantics.
- Primitive owns Object/file identity, metadata and content routing; Storage owns Vault/filesystem byte placement, portable paths, explicit ownership, rollback and physical delete safety.
- Relation/Data Integrity owns correctness of Relation mutations/reads and integrity-sensitive schema changes.
- Object Core owns Body persistence/edit contracts and reusable Body composition seams; Database/View may compose those seams into its own hosts without taking over Body semantics.
- Search owns canonical FTS projection, refresh planning and freshness orchestration.
- Primitive owns PDF/File extraction behavior; Search owns derived-text persistence/index/reconciliation.
- Refactor deletes legacy code only after the owning product lane proves replacement parity.

## Development hygiene
- Follow `AGENTS.md` for autonomous-loop, lane ownership and stopping criteria.
- Do not create `noop`, `tmp`, `oops`, whitespace-only or create/delete commits merely to trigger CI.
- Prefer workflow rerun controls when available; otherwise make only meaningful changes.
- Always re-read live GitHub state before implementation; handoff files are durable checkpoints, not substitutes for current Issues/PRs/CI.
- Idle lanes are preferable to speculative abstractions once concrete obligations are exhausted.

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility data remains live while old callers still consume it;
- Photo -> Image migration must not delete or rewrite user data before production parity is proven;
- Image/File shared infrastructure must not weaken Image ownership/delete/edit guarantees;
- malformed Relation state must fail closed rather than be silently partially projected/repaired by presentation code;
- Search freshness fixes must not reintroduce full-workspace rebuilds on every detail return or couple Object presentation to Search services;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- physical file deletion requires explicit Storage ownership and must not infer authority from path shape alone;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases, not concurrent broad edits.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.
