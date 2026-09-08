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
The generic composition architecture is proven in production code. Current highest-value work is Photo -> Image caller-zero consolidation/final preservation, Weblink convergence, maintainability, and usage-driven finishing.

Recent completion checkpoints:
- #895 hardens Bookmark Image Relation writers with strict fail-closed integrity preflight and rollback-safe compatibility projection.
- #896 gives canonical Images a shared first-use masonry/direct-Image Gallery without resetting user Views.
- #897 constrains legacy Photo physical deletion to proven active-Vault ownership.
- #909 provides exact Search-agnostic canonical Object sync impact.
- #920 gives canonical Weblinks a shared first-use List View.
- #941 / PR #1002 (`a74abec4cc231af91acbee956b4aaf131be87608`) composes canonical Image preview/editing into the shared Object Inspector.
- #948 moves People/profile imagery to canonical Person -> Image Relations; subsequent refactor work retired the legacy picker/mutation APIs.
- #949 is **completed/closed**. PR #997 (`8d52f75f683851cecc8a65955bd8c509183b4a14`) adds generic Database command-palette navigation and PR #1015 (`5f03dccc55e9333c51ce3db2a2e8d8f6f2216f0f`) removes normal legacy `写真` AppShell navigation. Canonical `画像` is now the single normal user-facing image collection.
- #218 is completed after real-Mac release launch/data-preservation validation.

## Active architecture/product issues
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object; remaining rich Weblink/Image presentation and legacy Bookmark URL/media convergence.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault/storage lifecycle; implementation complete, final real-macOS Create/Open/Switch/Move/Recovery validation remains.
- `#245` — legacy Photos -> canonical Image Objects umbrella.
- `#950` — Lane G caller-zero legacy Photo compatibility retirement; destructive schema removal is explicitly separate.
- `#951` — Lane F final real-macOS Vault/data-preservation validation for Photo -> Image consolidation.

Open PR and hotspot ownership are time-sensitive and must be rechecked live before editing.

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
#909 is completed/closed. Lane A is idle by design unless #56 or real usage exposes another concrete Object-core/Body/detail/sync correctness obligation.

### B — Relations & Data Integrity
#895 is completed/closed. Lane B is idle by design unless new production work introduces a Relation writer/reader/delete/compatibility projection or a concrete corruption regression.

### C — Database, View & Schema UX
#949 is completed/closed. Canonical `画像` is the single normal user-facing image collection through generic Database/View navigation, including ⌘K; legacy `写真` AppShell navigation is gone while compatibility data remains intact. Lane C should remain idle unless another concrete generic Database/View/schema UX gap appears.

### D — Primitive Objects & Media
#941 and #948 are completed. Lane D retains #155/#245 primitive product work only where a concrete Weblink/Image/File identity, metadata, preview/editing or migration gap remains. Do not reintroduce a Photo-specific product surface.

### E — Search & Indexing
No open Search-owned Issue is present in the current live audit. Preserve focused refresh rather than routine workspace rebuilds.

### F — Storage, Vault & Delivery
#242 production implementation is complete. #951 is the active Photo -> Image preservation gate.

With #949 complete, Lane F has added a focused read-only preservation-manifest helper on `feature/storage-vault-preservation-manifest-951` so the final real-Mac pass can mechanically verify SQLite integrity plus exact `photos/` / `attachments/` bytes before/after Move/Duplicate/restore. It does not alter production Storage semantics and still requires the real app semantic checks. See `docs/AI_PROGRESS_STORAGE.md` and `docs/vault_preservation_validation.md`.

The final real-machine pass should follow the applicable #950 caller-zero cleanup so it validates the intended end state.

### G — Refactor & Architecture Health
#225 and #950 remain active. Current #950 work may delete caller-zero presentation/API code only after parity is proven and must preserve Photo schema/data, Vault files, backup/import/export, migration behavior and Storage policy. Destructive legacy schema retirement is a separate explicit migration decision.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database selects Objects; View controls filter/sort/group/layout/presentation; Objects are not owned by a View.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- Universal Object Body is available through shared side/center/full opening surfaces.
- Canonical Relation mutation/read/index/backlink/audit/reconcile is mature and production paths increasingly share one integrity contract.
- Bookmark-like domain creation/operation is proven through generic template/Object/Relation/Database/View contracts.
- Weblink is a reusable canonical Object with normalized URL identity, enrichment and managed Image Relations.
- Bookmark image editing/creation paths use canonical Image Relations with strict integrity preflight while temporary compatibility projection remains where required.
- Canonical Images use ordinary persisted Database/View configuration, generic navigation, shared media rendering and shared Inspector preview/edit behavior.
- People profile imagery is canonical Image/Relation-based.
- Legacy Photo physical deletion is Vault-safe; external/ambiguous files are preserved.
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- Global Search is canonical Object search with focused freshness behavior.
- macOS release/DMG packaging and real-Mac launch/data-preservation validation are complete.
- Vault v1 repository implementation is complete; only final real-machine preservation exercises remain.

## Remaining product edge
Highest-value live work:
1. **#245 Photo -> Image** — finish safe applicable #950 caller-zero cleanup, then run Lane F #951 real-macOS preservation validation before closing the umbrella.
2. **#155 Weblink convergence** — finish generic rich Weblink/Image presentation and retire remaining Bookmark URL/thumbnail compatibility only after caller-zero proof.
3. **#225 / #950 Refactor** — delete superseded shims/legacy paths only after replacement parity; keep destructive schema retirement separate.
4. **#242 / #951 validation** — final real-macOS Vault Create/Open/Switch/Move/Recovery plus Photo -> Image preservation checks.
5. **#56 usage-driven finishing** — create focused follow-ups only for demonstrated daily-use gaps.

## Repository-wide design contract
- Objects are global and are not owned/duplicated by Databases or Views.
- ObjectType defines schema/defaults; Database selects Objects; View controls presentation/query.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + versioned block-oriented Body.
- Weblink/Image/File/Tag are built-in only for irreducible native identity/capability/default semantics.
- Bookmark/Note/Paper/Book/Project/Recipe/etc. should normally be user-owned/template ObjectTypes.
- Relation writes/deletes use canonical Relation APIs; no domain-specific edge stores.
- New domains participate in canonical Object search instead of adding long-term domain-specific indexes.
- New Object-first work must not deepen legacy Bookmark/Photo dependencies except explicit compatibility/migration bridges.
- Legacy storage/schema is not deleted merely because replacement UI exists; retirement requires caller-zero/parity evidence and migration safety.

## Concurrency / hotspot rule
Shared hotspots include `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, and `app_database.dart`.

Before non-trivial edits, inspect current open PR ownership. One lane at a time may hold a broad hotspot lease. Patch-sized non-overlapping changes still require a fresh overlap audit.

## Cross-lane boundaries
- Database/View owns generic presentation/configuration; Primitive owns Weblink/Image/File-specific product semantics.
- Primitive owns Object/file identity, metadata and content routing; Storage owns Vault/filesystem byte placement, portable paths, ownership, rollback and physical delete safety.
- Relation/Data Integrity owns Relation mutation/read/index correctness and integrity-sensitive schema changes.
- Object Core owns Body persistence/edit contracts, reusable opening/detail seams, and Search-agnostic canonical Object sync impact.
- Search owns canonical FTS projection/refresh planning.
- Refactor deletes legacy code only after owning product lanes prove replacement parity.
- Lane F #951 validates preservation but does not own Image identity/navigation/caller-zero deletion; concrete defects must be routed to the owning lane.

## Development hygiene
- Follow `AGENTS.md` autonomous-loop, lane ownership and stopping criteria.
- Do not manufacture no-op/whitespace/temp commits to trigger CI.
- Always re-read live GitHub state before implementation; handoffs are durable checkpoints, not substitutes for current Issues/PRs/CI.
- Idle is correct when no concrete work exists. A/B/C/E may currently be idle; D retains #155/#245 product work, G retains #225/#950 work, and F is preparing/running #951/#242 final preservation validation.

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility data remains live where old callers still require it;
- Photo -> Image migration must not delete or rewrite user data before parity and ownership are proven;
- malformed Relation state must fail closed rather than be silently repaired by presentation/compatibility workflows;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- physical file deletion must not derive authority from an arbitrary legacy path;
- #951 must validate the final product state without deleting legacy schema/data or inventing new Storage semantics;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases, not concurrent broad edits.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.
