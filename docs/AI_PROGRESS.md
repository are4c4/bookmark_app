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
The generic composition architecture is proven in production code. Remaining work is primarily Photo -> Image / Weblink convergence, maintainability/caller-zero retirement, final Vault real-machine validation, and usage-driven daily-use finishing.

Completed focused milestones now include #249, #414, #481, #484, #489, #490, #491, #492, #493, #494, #495, #501, #877, #888, #895, #896, #897, #909, #920 and #218.

Recent integration proof:
- #856 (`7e103a02…`) proves Bookmark-like behavior can be expressed through user-owned template/Object/Relation/Database/View configuration rather than a new Bookmark-only persistence model.
- #874 (`38c20b67…`) composes universal Body editing into Generic Database side peek and closes #481.
- #884 (`f1651ba1…`) and #894 (`ac470eec…`) close Search freshness gaps #877/#888 with focused refresh rather than workspace rebuilds.
- #881 (`47d31345…`) moves Bookmark image editing onto canonical `Images` / `Cover Image` Relations while retaining temporary legacy Photo projection.
- #889 (`fcd0eb34…`) routes legacy Photo Management “add to Bookmark” through the same canonical Bookmark Image Relation authority.
- #892 (`94b3833106683745291470732331aef3d28d66d5`) routes Bookmark creation Photo selection through canonical Image Relations.
- #895 / PR #922 (`bc09381b9eb77dee6b4ef12a94e7b9c06bc86c36`) hardens those Bookmark Image Relation writers with strict stored-value/index/target/cardinality mutation preflight and rollback-safe compatibility projection; Flutter CI #2793 Analyze + full Test green.
- #896 / PR #908 (`12994803b043c9da54da8c3175877512119d368b`) makes canonical Images seed a shared masonry/direct-Image Gallery only when zero Views exist and never resets user customization; Flutter CI #2750 full green.
- #897 is completed: legacy Photo physical deletion is constrained to proven active-Vault managed ownership and fails closed on external/ambiguous paths.
- #909 / PR #923 (`03acb81633031cb833975196b29f66947d9de747`) provides exact Search-agnostic canonical Object impact from live mirror sync while preserving initial non-notifying bootstrap and callback failure isolation; Flutter CI #2795 full green.
- #920 / PR #925 (`b8646d370035940222921d49ba1812a78d056523`) makes canonical Weblinks seed a shared first-run List View only when zero Views exist, preserving later user rename/layout/settings across reopen; Flutter CI #2789 full green.
- #218 is completed after real-Mac release launch/data-preservation validation.

## Active architecture/product issues
Live GitHub audit at this handoff shows **5 open Issues**:
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object; remaining rich Weblink/Image presentation and legacy Bookmark URL/media convergence.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault/storage lifecycle; production implementation complete, final real-macOS Create/Open/Switch/Move/Recovery validation remains.
- `#245` — legacy Photos -> canonical Image Objects.

There are no open PRs at the latest audit. Re-check live PR state before starting new work rather than relying on this snapshot.

Do not treat completed architecture Issues as active merely because older umbrella bodies/comments still contain unchecked historical bullets.

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
#909 is **completed/closed**. Lane A is currently **idle by design** unless #56 or real usage exposes another concrete Object-core/Body/detail/sync correctness obligation.

The integrated #909 contract reports only canonical Object ids whose semantic persisted state changed during one successful live mirror pass. It excludes timestamps and legacy/user payload, preserves initial bootstrap as non-notifying, and keeps downstream callback failure outside the canonical persistence transaction.

### B — Relations & Data Integrity
#895 is **completed/closed**. Lane B is currently **idle by design** unless new #245/#56 production work introduces a Relation writer/reader/delete/compatibility projection or a concrete corruption regression.

The #895 completion contract is now part of the canonical Relation boundary: integrity-sensitive Bookmark Image mutations re-read fresh state using shared strict preflight, reject malformed/duplicate/missing/wrong-type/cardinality/index drift without repair, and keep canonical Relation writes plus `bookmark_photos` compatibility projection atomic. See `docs/AI_PROGRESS_RELATION.md`.

### C — Database, View & Schema UX
#896 and #920 are **completed/closed**.

Canonical system collections now use ordinary persisted View configuration for first-use defaults:
- Images -> shared masonry Gallery + direct Image cover only when zero Views exist;
- Weblinks -> shared List only when zero Views exist;
- any existing View wins unchanged, preserving user rename/layout/settings;
- ordinary custom ObjectTypes retain normal Database definition/default behavior.

Lane C is **idle by design** until live #56/#155/#245 usage exposes a new concrete Database/View/schema/template UX defect. Do not invent speculative View abstractions merely to keep the lane active.

### D — Primitive Objects & Media
Primary active Issues remain **#155 and #245**.

Recent Image migration checkpoints include canonical Bookmark detail/photo-management/create Image Relation writes (#881/#889/#892), #895 integrity hardening, #896 default Images Gallery UX, and #897 Vault-safe legacy Photo deletion. Continue canonical Image write/presentation parity and retire Photo-only callers only after replacement parity and safety are demonstrated. #920 gives Weblinks a useful shared default List without moving Weblink identity/metadata/media semantics into Lane C.

### E — Search & Indexing
No open Search-owned Issue is present in the current live Issue audit. Preserve focused Search-owned refresh rather than routine full-workspace rebuilds. The #909 canonical Object-sync impact contract is now available as a Search-agnostic invalidation input when future live-mirror Search work needs it.

### F — Storage, Vault & Delivery
#897 and #218 are **completed/closed**. #242 remains open only for final real-macOS Vault preservation validation; repository implementation and automated regression coverage are otherwise complete. Do not invent additional Vault code solely because #242 is open for manual validation.

### G — Refactor & Architecture Health
#225 remains active. Keep product behavior changes out of Refactor work and retire legacy/shim paths only after the owning product lane proves replacement parity.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database selects Objects; View controls filter/sort/group/layout/presentation; Objects are not owned by a View.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- Universal Object Body is available through shared side/center/full opening surfaces.
- Canonical Relation mutation/read/index/backlink/audit/reconcile is mature and production paths increasingly share one integrity contract.
- Integrity-sensitive Relation editor writes can use shared strict preflight rather than treating serialized/index corruption as user edits.
- Template-derived schemas are user-owned/editable and are not silently reset by later template versions.
- Bookmark-like domain creation/operation is proven through generic template/Object/Relation/Database/View contracts.
- Weblink is a reusable canonical Object with normalized URL identity, enrichment and managed Image Relations.
- Bookmark detail, Photo Management attachment and Bookmark creation write image selection through canonical Image Relations (#881/#889/#892); #895 prevents corrupt canonical state or compatibility sync from silently overwriting those Relations.
- Canonical Images have shared default Gallery configuration (#896) while retaining normal View customization.
- Canonical Weblinks have a shared default List configuration (#920) while retaining normal View customization and shared `SystemObjectListMedia` rendering.
- Legacy Photo physical deletion is Vault-safe (#897); external/ambiguous files are preserved.
- Live Object mirror sync can report exact semantic canonical Object impact without Search dependencies (#909).
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- PDF remains File + capabilities/enrichment/search; there is no separate PDF persistence model.
- Global Search is canonical Object search; focused detail-return freshness covers root, trustworthy Relation-linked, and nested-visited Objects without routine workspace rebuilds.
- macOS release/DMG packaging and real-Mac launch/data-preservation validation are complete (#218).
- Vault v1 repository implementation is complete; #242 remains for final real-machine preservation exercises.

## Remaining product edge
Highest-value live work:
1. **#245 Photo -> Image** — finish canonical Image presentation/write parity, migrate remaining Bookmark/People/Photo consumers, then hide/retire legacy `写真` only after caller parity.
2. **#155 Weblink convergence** — finish generic rich Weblink/Image presentation and retire remaining Bookmark URL/thumbnail compatibility only after caller-zero proof.
3. **#225 Refactor** — delete superseded shims/legacy paths after replacement parity.
4. **#242 validation** — final real-macOS Vault Create/Open/Switch/Move/Recovery preservation checks.
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

At the latest audit there is no open PR, so no repository-wide hotspot lease is recorded here. This is only a snapshot; always verify again immediately before editing.

## Cross-lane boundaries
- Database/View owns generic presentation/configuration; Primitive owns Weblink/Image/File-specific product semantics.
- Primitive owns Object/file identity, metadata and content routing; Storage owns Vault/filesystem byte placement, portable paths, ownership, rollback and physical delete safety.
- Relation/Data Integrity owns Relation mutation/read/index correctness and integrity-sensitive schema changes.
- Object Core owns Body persistence/edit contracts, reusable opening/detail seams, and Search-agnostic canonical Object sync impact.
- Search owns canonical FTS projection/refresh planning; presentation/Object sync exposes only generic navigation/mutation-impact seams.
- Refactor deletes legacy code only after the owning product lane proves replacement parity.

## Development hygiene
- Follow `AGENTS.md` autonomous-loop, lane ownership and stopping criteria.
- Do not manufacture no-op/whitespace/temp commits to trigger CI; use workflow rerun controls or the next meaningful change.
- Always re-read live GitHub state before implementation; handoff files are durable checkpoints, not substitutes for current Issues/PRs/CI.
- Idle is correct when no concrete work exists. Lanes A/B/C are currently idle after #909/#895/#896/#920 until new concrete triggers appear; D and G retain active repository implementation work, while F #242 is manual-validation gated.

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility data remains live while old callers still consume it;
- Photo -> Image migration must not delete or rewrite user data before parity and ownership are proven;
- malformed Relation state must fail closed rather than be silently projected/repaired by presentation or compatibility workflows;
- Search freshness fixes must not reintroduce full-workspace rebuilds or Search dependencies into Object presentation/core contracts;
- consumers of Object-sync impact must keep it as canonical ids/semantic impact rather than rebuilding broad timestamp-driven invalidation;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- physical file deletion must not derive authority from an arbitrary legacy path;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases, not concurrent broad edits.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.
