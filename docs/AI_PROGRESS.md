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
The generic composition architecture is now proven in production code, not only in design documents.

Completed architecture milestones include:
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

Key composition proof:
- #856 (`7e103a02…`) defines Bookmark only as a user-owned template/configuration and proves normal Bookmark-like operation through canonical Weblink creation, generic Relations, generic Property values, Databases, Views and View filtering without adding a new Bookmark-only persistence/presentation API.
- Template visible/order/filter/sort/group/Gallery-cover references resolve symbolically to stable created Property ids.
- Generic Relation target quick-create/import supports custom types plus canonical Tag/Weblink/Image/File behavior.
- Generic Gallery cover selection resolves Relation-backed Image/Weblink media in the real Database host.
- #874 (`38c20b67…`) closes universal Body opening parity by composing the reusable canonical Body editor into Generic Database side peek; #481 is completed/closed.

The architecture-construction phase is therefore largely complete. The primary remaining work is presentation parity, legacy migration/consolidation, focused correctness follow-ups, and final real-machine validation.

## Active architecture/product issues
There are currently eight open focused/umbrella issues:
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object; remaining Weblink/Image presentation and legacy Bookmark URL/media convergence.
- `#218` — macOS installable delivery; repository packaging/CI complete, final user-machine validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault/storage lifecycle; production code complete, final real-macOS validation remains.
- `#245` — legacy Photos -> canonical Image Objects.
- `#249` — Bookmark presentation parity.
- `#877` — Search freshness when Object detail creates/reuses additional canonical Objects.

Do not treat #481/#484/#489/#490/#491/#492/#493/#494/#495/#501 as active merely because older issue bodies or historical comments mention unfinished work.

## Seven development lanes
- **A — Object Core & Body** — `docs/AI_PROGRESS_OBJECT.md`
- **B — Relations & Data Integrity** — `docs/AI_PROGRESS_RELATION.md`
- **C — Database, View & Schema UX** — `docs/AI_PROGRESS_DATABASE_VIEW.md`
- **D — Primitive Objects & Media** — `docs/AI_PROGRESS_PRIMITIVES.md`
- **E — Search & Indexing** — `docs/AI_PROGRESS_SEARCH.md`
- **F — Storage, Vault & Delivery** — `docs/AI_PROGRESS_STORAGE.md`
- **G — Refactor & Architecture Health** — `docs/AI_PROGRESS_REFACTOR.md`

Each implementation run/PR has exactly one primary lane. Issues may span lanes, but work should be split by coherent responsibility rather than temporary file availability.

## Current routing
### A — Object Core & Body
#481 is completed/closed. Universal Body persistence/editing now uses the same canonical contract across system/custom Objects, Daily Note, Bookmark detail and generic side/center/full openings.

A continues to own Object/ObjectType identity, shared Object opening/detail semantics and future Object-core obligations from #56. #249 Bookmark real-host presentation remains Object-owned unless GitHub explicitly reassigns it.

### B — Relations & Data Integrity
Owns canonical Relation mutation/read/index/backlink/audit/reconcile correctness and fail-closed corruption behavior.

#493 is complete/closed; continue only concrete integrity obligations created by live workflows or regressions. New Relation-producing Primitive/Object flows must continue using canonical mutation/read contracts rather than domain-specific edge stores.

### C — Database, View & Schema UX
Focused #490/#491/#492/#493 work is complete. The final cross-lane #481 Database/View obligation also completed in #874.

Current status: **idle by design**.

Resume only when:
1. a focused Database/View/schema/template Issue is opened or assigned to C;
2. #56 gains a concrete generic Database/View acceptance gap not routed elsewhere;
3. another lane lands a capability that creates a specific generic View/schema composition obligation;
4. presentation ownership is explicitly reassigned to C.

Do not invent manual include/exclude membership or speculative abstractions while no concrete product need exists.

### D — Primitive Objects & Media
Primary active issues:
- #155 Weblink/Image presentation and legacy media convergence.
- #245 canonical Image / Photo migration.

#495 import routing is complete/closed.

Recent Image migration checkpoints:
- #869 — canonical Image/Weblink media in generic List rows.
- #876 (`3506974e…`) — canonical media in generic Table rows.
- #879 (`3be71f12…`) — legacy Photo compatibility sync preserves first-class native Bookmark Image Relations instead of erasing them.

Continue toward canonical Image presentation/write parity, then retire legacy Photo read/write/UI paths only after caller parity and migration safety are proven.

### E — Search & Indexing
#414/#494 are complete/closed, but #877 is now active.

#877 owns focused Search freshness after an Object opened from Search creates/reuses an additional canonical Object (for example Weblink promotion). Preserve the focused-refresh architecture; do not rebuild the whole workspace on every detail return or import Search dependencies into Object presentation.

### F — Storage, Vault & Delivery
- #242 Vault: repository implementation complete; real-macOS Create/Open/Switch/Move/Recovery validation remains.
- #218 packaging/install: repository implementation complete; user-machine install/launch/data-preservation validation remains.
- shared managed-file copy/ownership/rollback/delete filesystem contracts are delivered for Primitive consumers.

No speculative Storage implementation is needed while these are waiting on real-machine validation.

### G — Refactor & Architecture Health
#225 remains active.

Current focus:
- verified caller-zero legacy retirement;
- large-host responsibility reduction;
- dependency/shim ratchets;
- stable user-facing failure policy and raw-exception privacy cleanup;
- AppDatabase narrowing only when real responsibility disappears.

Do not hide product behavior changes inside Refactor work.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database = target ObjectType + collection filter; View filter/sort/group/layout remain a separate presentation/query layer.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- universal Object Body is available through shared real opening surfaces without type-specific note storage/editor paths.
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature and production paths increasingly route reads through the same integrity contract.
- template-derived schemas are user-owned, editable and are not silently reset by later template versions.
- Bookmark-like domain creation/normal operation is proven through generic template/Object/Relation/Database/View contracts.
- Weblink is a reusable canonical Object with normalized URL identity, enrichment and managed Image Relations.
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- PDF remains File + PDF capabilities/enrichment/search; there is no separate PDF persistence model.
- Global Search is canonical Object search; the old Bookmark-only FTS path is retired.
- Storage-managed files use one Vault filesystem contract with explicit ownership and fail-closed delete safety.
- macOS release/DMG CI has succeeded; final local validation remains outside repository automation.

## Remaining product edge
The highest-value remaining work is:
1. **#245 Photo -> Image** — continue canonical Image presentation/write parity, migrate remaining Bookmark/People Photo consumers, then hide/retire the legacy `写真` UI only after caller parity is proven.
2. **#249 Bookmark presentation** — finish remaining real-host presentation convergence such as fixed/masonry Gallery parity.
3. **#155 Weblink consolidation** — finish rich generic Weblink/Image presentation and retire legacy Bookmark URL/thumbnail compatibility only after callers reach zero.
4. **#877 Search freshness** — refresh additional Objects created/reused from Search-opened detail without regressing focused-refresh boundaries.
5. **#225 Refactor** — delete superseded Bookmark/Photo/shim paths after replacement parity and continue reducing hotspot responsibility.
6. **#242/#218 validation** — perform final real-macOS Vault and packaged-app preservation checks with the user.

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
- Legacy storage/schema is not deleted merely because a replacement UI exists; retirement requires caller-zero/parity evidence and migration safety.

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

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility data remains live while old hosts still consume it;
- Photo -> Image migration must not delete or rewrite user data before production parity is proven;
- Image/File shared infrastructure must not weaken Image ownership/delete/edit guarantees;
- malformed Relation state must fail closed rather than be silently partially projected/repaired by presentation code;
- Search freshness must not be "fixed" by reintroducing full-workspace rebuilds on every detail return;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- physical file deletion requires explicit Storage ownership and must not infer authority from path shape alone;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases, not concurrent broad edits;
- idle lanes are preferable to speculative abstractions once concrete cross-lane obligations are exhausted.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.
