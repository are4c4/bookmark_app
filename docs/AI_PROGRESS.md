# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files. Always verify live GitHub Issues, PRs, CI and the latest `main` before changing shared hotspots.

## Current goal
Continue the transition from a Bookmark-specific application toward a composable Object / Relation / Database knowledge platform while preserving user data and reducing legacy maintenance cost.

Core product direction:
- Object is the durable reusable entity.
- ObjectType = schema/default behavior.
- Database = collection/query context.
- View = presentation/query configuration.
- Object content = typed Properties + one universal versioned/block-oriented Body.
- Built-in code is reserved for irreducible native behavior; Bookmark/Paper/Book/Project/etc. should normally be user-owned templates/configuration.
- Relation mutation/read/index/backlink behavior stays behind the canonical Relation subsystem.

## Repository position — 2026-09-08
The generic composition architecture is now proven in production code. The main work has moved from foundation building to legacy migration/consolidation, focused correctness, maintainability and final real-machine validation.

Completed architecture/product milestones include:
- #414 — legacy Bookmark FTS stale-token correctness.
- #481 — universal Object Body across side/center/full shared opening surfaces.
- #484 — built-in primitive boundary + user-composable domain architecture.
- #489 — shared native capability direction for Image/File.
- #490 — user-owned ObjectType/Database/View templates.
- #491 — Relation Property authoring + inline target create/import UX.
- #492 — generic Relation-backed Gallery cover source.
- #493 — safe/reversible user-defined schema evolution.
- #494 — canonical unified Object search/indexing.
- #495 — MIME/content-aware Image/File import routing.
- #501 — seven-lane AI development ownership model.
- #249 — Bookmark Gallery/List presentation parity; completed after #885.

Key proof points:
- #856 proves Bookmark-like operation as a user-owned template through generic Weblink/Relation/Property/Database/View contracts without a new Bookmark-only persistence API.
- #874 composes the canonical Body editor into Generic Database side peek; #481 is closed.
- #869/#876 give canonical Image/Weblink media to generic List/Table rows.
- #879 makes legacy Photo compatibility sync preserve native canonical Bookmark Image Relations.
- #881 moves Bookmark detail image editing onto canonical `Images` / `Cover Image` Relations while keeping only necessary legacy projection compatibility.
- #885 (`38494512…`) moves the real Bookmark Gallery to shared fixed/masonry View settings/rendering; Flutter CI #2712 is fully green and #249 is closed.

## Active focused/umbrella Issues
Current open product/architecture/correctness work:
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object; remaining presentation + legacy Bookmark URL/media convergence.
- `#218` — macOS installable delivery; repository implementation complete, final user-machine validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault lifecycle; repository implementation complete, final real-macOS validation remains.
- `#245` — legacy Photos -> canonical Image Objects.
- `#888` — Search freshness for nested Daily Notes visited from Search-opened Object detail.

Recently completed Search follow-up:
- #877 closed through #884: Search detail-return refresh now includes canonical outgoing Relation targets and their label dependents.
- #888 is a narrower remaining gap because Daily Note previous/next/today navigation is not Relation-backed.

Do not treat #249/#481/#484/#489/#490/#491/#492/#493/#494/#495/#501/#877 as active merely because older Issue bodies/handoffs mention unfinished work.

## Seven development lanes
- **A — Object Core & Body** — `docs/AI_PROGRESS_OBJECT.md`
- **B — Relations & Data Integrity** — `docs/AI_PROGRESS_RELATION.md`
- **C — Database, View & Schema UX** — `docs/AI_PROGRESS_DATABASE_VIEW.md`
- **D — Primitive Objects & Media** — `docs/AI_PROGRESS_PRIMITIVES.md`
- **E — Search & Indexing** — `docs/AI_PROGRESS_SEARCH.md`
- **F — Storage, Vault & Delivery** — `docs/AI_PROGRESS_STORAGE.md`
- **G — Refactor & Architecture Health** — `docs/AI_PROGRESS_REFACTOR.md`

Every PR has exactly one primary lane. Split work by responsibility, not by temporary file availability.

## Current routing
### A — Object Core & Body
#481 and #249 are completed/closed.

A remains responsible for Object/ObjectType identity, typed Property core semantics, universal Body, Daily Note identity/navigation, and shared Object detail/opening contracts from #56.

Current status: no known independent A-only product acceptance item. Resume for a concrete Object/ObjectType/Body/detail invariant or an explicitly A-owned #56 slice; do not invent work merely to keep the lane busy.

### B — Relations & Data Integrity
Owns canonical Relation mutation/read/index/backlink/audit/reconcile correctness, target/cardinality validation, deletion/detach/retarget/idempotency and fail-closed corruption behavior.

Continue only concrete integrity obligations from live workflows/regressions. New Primitive/Object Relation-producing paths must reuse canonical services; no domain-specific edge store.

### C — Database, View & Schema UX
Focused #490/#491/#492/#493 work and the #481 side-peek composition obligation are complete.

Current status: **idle by design**. Resume only for a concrete Database/View/schema/template obligation. Manual include/exclude collection membership remains deferred until real use demonstrates need.

### D — Primitive Objects & Media
Primary active Issues:
- #155 Weblink/Image presentation and legacy media convergence.
- #245 canonical Image / Photo migration.

Current #245 direction after #879/#881:
- canonical Bookmark Image Relations can now survive legacy compatibility sync;
- Bookmark detail image editing uses canonical Relations;
- remaining write-authority migration includes Bookmark creation, Photo Management attach-to-Bookmark and People profile-photo handling;
- generic Images must reach daily-use parity before legacy `写真` UI/writers are hidden/retired;
- do not drop legacy Photo tables until production callers and migration obligations are proven safe.

### E — Search & Indexing
#414/#494/#877 are complete. #888 is active.

#888 must keep focused Search refresh architecture while tracking canonical Object ids visited through nested Inspector navigation (notably Daily Note previous/next/today), then refresh those visited Objects and relevant Relation-label dependents when returning to Search. Do not add Search dependencies to Object Inspector domain logic and do not replace focused refresh with routine workspace rebuilds.

### F — Storage, Vault & Delivery
- #242 Vault: code/automated regressions complete; real-macOS Create/Open/Switch/Move/Recovery validation remains.
- #218 packaging/install: repository packaging/CI complete; user-machine install/launch/data-preservation validation remains.
- shared managed-file copy/ownership/rollback/delete filesystem contracts are delivered for Primitive consumers.

Do not invent speculative Storage implementation while these are waiting on real-machine validation.

### G — Refactor & Architecture Health
#225 remains active.

Current focus:
- verified caller-zero legacy retirement;
- large-host responsibility reduction;
- dependency/shim ratchets;
- stable user-facing failure policy/privacy;
- AppDatabase narrowing only where real responsibility disappears.

PR #886 is the current final legacy raw-caught-error presentation cleanup in `GenericDatabasePage`; its CI must be read live before merge. Completing that privacy subtrack does **not** by itself complete #225.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database = target ObjectType + collection filter; View filter/sort/group/layout are a separate presentation/query layer.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- Bookmark Gallery now uses the same persisted fixed/masonry View contract as generic Gallery.
- universal Object Body is available through real side/center/full opening surfaces.
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature and increasingly used for reads as well as writes.
- template-derived schemas are user-owned/editable and are not silently reset by template evolution.
- Weblink is a reusable canonical Object with normalized URL identity, enrichment and managed Image Relations.
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- PDF remains File + PDF capabilities/enrichment/search; there is no parallel PDF storage model.
- Global Search is canonical Object search; old Bookmark-only FTS is retired.
- managed files use one Vault filesystem contract with explicit ownership and fail-closed delete safety.
- macOS release/DMG CI has succeeded; final local validation remains outside repository automation.

## Highest-value remaining work
1. **#245 Photo -> Image** — migrate remaining legacy Bookmark/Photo/People write/read authority to canonical Image Objects/Relations, prove parity, then retire legacy `写真` UI/writers safely.
2. **#155 Weblink consolidation** — finish rich generic Weblink/Image presentation and retire legacy Bookmark URL/thumbnail compatibility only after caller-zero/parity evidence.
3. **#888 Search nested-detail freshness** — keep visited Daily Note edits immediately searchable without a whole-workspace rebuild.
4. **#225 Refactor** — delete superseded Bookmark/Photo/shim paths and keep reducing large-host responsibility after product parity is proven.
5. **#242/#218 real-macOS validation** — run the final Vault lifecycle and packaged-app preservation checks with the user.
6. **#56 real-use umbrella** — after focused migrations close, use real app usage to identify remaining generic platform polish instead of speculatively expanding architecture.

## Repository-wide design contract
- Objects are global and are not owned/duplicated by Databases or Views.
- ObjectType defines schema/defaults; Database selects Objects; View controls presentation/query.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + versioned Body.
- Weblink/Image/File/Tag are built-in only for irreducible native identity/capability/default semantics.
- Domain concepts such as Bookmark/Paper/Book/Project/Recipe should normally be user-owned/template ObjectTypes.
- Relation writes/deletes use canonical Relation APIs; no domain-specific edge stores.
- New domains participate in canonical Object search instead of adding long-term domain-specific indexes.
- New Object-first work must not deepen legacy Bookmark/Photo dependencies except explicit compatibility/migration bridges.
- Legacy schema/storage is not deleted merely because a replacement UI exists; retirement requires caller-zero/parity/migration-safety evidence.

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

Before non-trivial edits, inspect current open PR changed files. One lane at a time may hold a broad hotspot lease. Patch-sized non-overlapping changes still require a fresh overlap audit.

## Cross-lane boundaries
- Database/View owns generic presentation/configuration contracts; Primitive owns Weblink/Image/File-specific product semantics.
- Primitive owns Object/file identity, metadata and content routing; Storage owns Vault/filesystem byte placement, portable paths, ownership, rollback and physical delete safety.
- Relation/Data Integrity owns Relation mutation/read integrity and integrity-sensitive schema changes.
- Object Core owns Body persistence/edit/detail contracts; other hosts may compose shared seams without creating another Body model.
- Search owns canonical FTS projection/refresh planning/freshness orchestration.
- Primitive owns PDF/File extraction; Search owns derived-text persistence/index/reconciliation.
- Refactor deletes legacy code only after the product owner proves replacement parity.

## Development hygiene
- Follow `AGENTS.md` for autonomous loops, lane ownership and stopping criteria.
- Do not create `noop`, temporary, whitespace-only or create/delete commits merely to trigger CI.
- Prefer workflow rerun controls when an unchanged failed job simply needs another attempt.
- Always re-read live GitHub state before implementation; these handoffs are durable checkpoints, not source-of-truth replacements.

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility remains live while callers still depend on it;
- Photo -> Image migration must not delete/rewrite user data before production parity is proven;
- canonical Image writes must not be erased by compatibility sync;
- malformed Relation state must fail closed rather than be partially projected/repaired by presentation;
- Search freshness fixes must not regress to whole-workspace rebuilds on routine detail return;
- Vault changes must not silently replace inaccessible storage with an empty database;
- physical file deletion requires explicit Storage ownership, not path-shape inference;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases;
- idle lanes are preferable to speculative abstractions.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.
