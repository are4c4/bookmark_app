# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files. Always verify live GitHub Issue/PR/CI state before editing shared hotspots.

## Current goal
Continue the transition from a Bookmark-specific application toward a composable Object / Relation / Database knowledge platform while preserving user data and reducing legacy maintenance cost.

Core product direction:
- Object is the durable reusable entity.
- ObjectType = schema/default behavior.
- Database = collection/query context.
- View = presentation/query configuration.
- Built-in code is reserved for irreducible primitives/behaviors; domain models such as Bookmark/Paper/Book/Project should normally be user-owned templates/configuration.

## Current repository position — 2026-09-08
The generic composition architecture is now substantially proven in production code, not only design prose.

Completed architecture milestones:
- #484 — built-in primitive boundary + user-composable domain architecture — closed.
- #489 — shared native capability direction for Image/File — closed.
- #490 — user-owned ObjectType/Database/View templates — closed.
- #491 — Relation Property authoring + inline target create/import UX — closed.
- #492 — generic Relation-backed Gallery cover source — closed.
- #493 — safe/reversible user-defined schema evolution UX — closed.
- #494 — canonical unified Object search/indexing — closed.
- #414 — legacy Bookmark FTS stale-token correctness — closed.

Key composition proof:
- #856 (`7e103a02…`) adds Bookmark only as a user-owned template/configuration and proves normal Bookmark-like operation through canonical Weblink creation, generic Relations, generic Property values, Database Views and View filtering without adding a new Bookmark-only persistence/presentation API.
- #851 (`0ca36410…`) adds symbolic template Group defaults resolved to canonical created Property ids.
- #845 (`a320a5b8…`) exposes safe Property schema management in the real `GenericDatabasePage`; #493 is closed.
- #819 (`dfc07176…`) wires custom/Tag/Weblink/Image/File Relation target quick-create/import through the real generic Relation picker; #491 is closed.
- #792 (`9e35afa2…`) wires configurable Relation-backed Gallery covers into the real generic Database host; #492 is closed.

Lane C therefore has no independent actionable implementation issue at this checkpoint. Idle is intentional until a concrete Database/View/schema/template gap appears.

## Active architecture/product issues
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object + remaining Weblink/Image presentation and legacy Bookmark URL/media convergence.
- `#218` — macOS installable delivery; repository packaging/CI complete, final user-machine validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault/storage lifecycle; production code complete, final real-macOS validation remains.
- `#245` — legacy Photos -> canonical Image Objects.
- `#249` — Bookmark Gallery/List presentation parity; currently Object-lane owned.
- `#481` — universal Body/note surface for every ObjectType; Object-lane owned.
- `#495` — MIME/content-aware Image/File import routing; Primitive-lane owned.
- `#501` — seven-lane AI development ownership model.

Do not reopen or treat #484/#490/#491/#492/#493/#494 as active merely because older umbrella prose still mentions them.

## Seven development lanes
- **A — Object Core & Body** — `docs/AI_PROGRESS_OBJECT.md`
- **B — Relations & Data Integrity** — `docs/AI_PROGRESS_RELATION.md`
- **C — Database, View & Schema UX** — `docs/AI_PROGRESS_DATABASE_VIEW.md`
- **D — Primitive Objects & Media** — `docs/AI_PROGRESS_PRIMITIVES.md`
- **E — Search & Indexing** — `docs/AI_PROGRESS_SEARCH.md`
- **F — Storage, Vault & Delivery** — `docs/AI_PROGRESS_STORAGE.md`
- **G — Refactor & Architecture Health** — `docs/AI_PROGRESS_REFACTOR.md`

Each implementation run/PR has exactly one primary lane. Issues may span lanes, but work should be split by coherent ownership rather than file availability.

## Current routing
### A — Object Core & Body
- #481 universal Body.
- Object/ObjectType/core identity/default/detail/opening work from #56.
- #249 Bookmark presentation remains currently routed to Object unless GitHub explicitly changes ownership.

### B — Relations & Data Integrity
- Canonical Relation mutation/read/index/backlink/audit/reconcile lifecycle.
- Integrity regressions from new Relation-producing workflows.
- Fail-closed corrupted Relation reads and destructive target/cardinality correctness.
- Current open Relation work should be read from `docs/AI_PROGRESS_RELATION.md`; do not infer it from old #493 prose because #493 is closed.

### C — Database, View & Schema UX
Focused #490/#491/#492/#493 work is complete.

Current status: **idle by design**.
Resume only when:
1. a focused Database/View/schema/template Issue is opened or assigned to C;
2. #56 gains a concrete generic Database/View acceptance gap not routed elsewhere;
3. another lane lands a capability that creates a specific generic View/schema composition obligation;
4. ownership of #249 or another presentation slice is explicitly reassigned to C.

Do not invent manual include/exclude Database membership; #56 explicitly defers it until real usage demonstrates need.

### D — Primitive Objects & Media
- #155 Weblink/Image presentation and legacy media convergence.
- #245 canonical Image / Photo migration.
- #495 content-aware Image/File import routing.
- Weblink/Image/File/Tag primitive product semantics, import/media behavior and File/PDF capabilities.

Recent Primitive work has already landed canonical File collection import and canonical Image media composition in generic Database hosts. Future patches in those shared hosts remain D-owned when the behavior is primitive-specific; always re-check live open PR ownership before editing.

### E — Search & Indexing
- #414/#494 are complete/closed.
- Canonical Object search now covers title/aliases, selected Properties, Body, Relation labels, Weblink metadata and derived File/PDF text.
- Stay idle unless a concrete Search/Indexing regression or cross-lane indexing obligation appears.

### F — Storage, Vault & Delivery
- #242 Vault: repository implementation complete; real-macOS Create/Open/Switch/Move/Recovery validation remains.
- #218 packaging/install: repository implementation complete; user-machine install/launch/data-preservation validation remains.
- Shared managed-file copy/ownership/rollback/delete filesystem contracts are delivered for Primitive consumers.

### G — Refactor & Architecture Health
- #225 behavior-preserving hotspot reduction, dependency narrowing, caller-zero legacy retirement and error/privacy cleanup.
- Do not hide product behavior changes inside Refactor work.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database = target ObjectType + collection filter; View filter/sort/group/layout remain a separate presentation/query layer.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- Canonical Relation mutation/read/index/backlink/audit/reconcile is mature and production paths use it.
- Template-derived schemas are user-owned, editable and not silently reset by later template versions.
- Template visible/order/filter/sort/group/Gallery-cover references resolve symbolically to stable created Property ids.
- Bookmark-like domain creation/normal operation is proven through generic template/Object/Relation/Database/View contracts.
- Weblink is a reusable canonical Object with normalized URL identity and managed Image Relations.
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- PDF remains File + PDF capabilities/enrichment/search; there is no separate PDF persistence model.
- Global Search is canonical Object search; the old Bookmark-only FTS path is retired.
- Storage-managed files use one Vault filesystem contract with explicit ownership and fail-closed delete safety.
- macOS release/DMG CI has succeeded; final local validation remains outside repository automation.

## Remaining product edge
The largest remaining work is no longer generic schema composition. It is **daily-use presentation + migration/consolidation**:
- finish Weblink/Image generic presentation and remaining Bookmark visual convergence (#155);
- make Images fully replace legacy Photo UX safely (#245);
- complete content-aware import routing across remaining user-facing entry points (#495);
- finish Bookmark presentation parity (#249, Object-owned);
- enable universal Body everywhere (#481, Object-owned);
- retire legacy callers and reduce large-host responsibility only after replacement parity (#225).

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

## Current cross-lane dependency notes
- Database/View owns generic presentation/configuration contracts; Primitive owns Weblink/Image/File-specific product semantics.
- Primitive owns Object/file identity, metadata and MIME/content routing; Storage owns Vault/filesystem byte placement, portable paths, ownership, rollback and physical delete safety.
- Database/View owns schema authoring UX; Relation/Data Integrity owns correctness of integrity-sensitive Relation evolution/mutation/read behavior.
- Object Core owns Body persistence/edit contracts; Search owns Body indexing.
- Primitive owns PDF/File extraction behavior; Search owns derived-text persistence/index/reconciliation.
- Refactor deletes legacy code only after the owning product lane proves replacement parity.

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility data remains live while old hosts still consume it;
- Photo -> Image migration must not delete or rewrite user data before production parity is proven;
- Image/File shared infrastructure must not weaken Image ownership/delete/edit guarantees;
- malformed Relation state must fail closed rather than be silently partially projected/repaired by presentation code;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- physical file deletion requires explicit Storage ownership and must not infer authority from path shape alone;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases, not concurrent broad edits;
- idle lanes are preferable to speculative abstractions.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.

Always re-read live GitHub state before implementation. This file is a durable checkpoint, not a substitute for current Issues/PRs/CI.
