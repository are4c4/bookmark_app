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
The generic composition architecture is proven in production code. Remaining work is primarily Photo -> Image / Weblink legacy convergence, integrity hardening around newly-live workflows, caller-zero retirement, focused Object-core correctness and real-machine validation.

Completed focused milestones include #249, #414, #481, #484, #489, #490, #491, #492, #493, #494, #495, #501, #877, #888, #896, #897 and #907.

Recent composition/migration proof:
- #856 (`7e103a02…`) proves Bookmark-like behavior can be expressed through user-owned template/Object/Relation/Database/View configuration rather than a new Bookmark-only persistence model.
- #874 (`38c20b67…`) composes universal Body editing into Generic Database side peek and closes #481.
- #884 (`f1651ba1…`) and #894 (`ac470eec…`) close Search freshness gaps #877/#888 with focused refresh for Relation-linked and nested-Inspector visited Objects rather than workspace rebuilds.
- #881 (`47d31345…`), #889 (`fcd0eb34…`) and #892 (`94b38331…`) move Bookmark image editing, legacy Photo attachment and Bookmark-create Photo selection onto canonical `Images` / `Cover Image` Relations while retaining temporary compatibility projection.
- #885 (`38494512…`) closes #249 by using the shared fixed/masonry Gallery contract in the real Bookmark Stage1 host.
- **#908 (`12994803b043c9da54da8c3175877512119d368b`)** closes #896 by seeding only a zero-View canonical Images collection as ordinary shared `gallery + masonry + directImage` View configuration while preserving every existing user View. Flutter CI #2750 was full green.
- **#915 (`545e07e124e9c0c14da04f44c2c5acd95a2b3641`)** retires caller-zero legacy Bookmark/Photo mutation helpers from `AppDatabase` without deleting compatibility storage.
- **#906 (`b04ebeb1f354156873c51ca0eaaadb32e7cfb63e`)** closes #897 by making legacy Photo physical deletion Vault-safe and fail-closed on external/traversal/symlink/offline/ambiguous paths.
- **#913 (`53fde6f305fb745d31a1faf2597bd105922935fc`)** closes #907 by refreshing canonical Search after live legacy-to-Object mirror completion without a workspace rebuild; #909 remains the Object-owned exact-impact refinement.

## Active architecture/product issues
Live GitHub audit after #913 merge shows **9 open Issues**:
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object; remaining rich Weblink/Image presentation and legacy Bookmark URL/media convergence.
- `#218` — macOS installable delivery; repository packaging/CI complete, final user-machine validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault/storage lifecycle; v1 lifecycle implementation complete, final real-macOS validation remains.
- `#245` — legacy Photos -> canonical Image Objects.
- **`#895` — Relations:** fail closed when Bookmark Image Relation stored values/index/targets/cardinality are inconsistent.
- **`#909` — Object Core:** report exact canonical Object impact from live mirror sync without unchanged-pass false positives.
- **`#910` — Object Core:** prevent generic Daily Note Date edits from desynchronizing one-note-per-date registry identity.

#896/#897/#907 are completed; do not revive them from older handoff or umbrella prose.

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
**Active: #909 and #910.**

#909 owns exact canonical mutation-impact reporting from live Object mirror sync so unchanged broad passes do not produce false-positive downstream work. #910 owns Daily Note Date identity/editability semantics. Neither should be implemented as a Database/View or Search-specific workaround.

### B — Relations & Data Integrity
**Active: #895.**

#881/#889/#892 made canonical Bookmark Image Relations a real production write authority. Lane B must prove those writers obey the same stored-value + normalized-index + target/cardinality integrity contract as canonical Relation reads. Corrupt/index-drift state must fail closed with no partial canonical or `bookmark_photos` compatibility writes.

### C — Database, View & Schema UX
#896 is completed through #908. Canonical Images now receive a useful first-use Gallery through ordinary shared View configuration, and existing user Views remain authoritative.

Lane C is **idle by design** after a fresh post-#908 audit found no independent Database/View/schema/template Issue. Resume only when a new focused generic presentation/configuration obligation is opened or explicitly routed to C.

### D — Primitive Objects & Media
Primary active Issues remain #155 and #245.

Recent Image migration checkpoints include #879/#881/#889/#892 plus C-owned #908 for the generic Images default View. Continue canonical Image read/write/presentation parity and retire Photo-only callers only after replacement parity and safety are demonstrated.

### E — Search & Indexing
#414/#494/#877/#888/#907 are complete. #913 integrated live legacy-mirror Search refresh; exact changed-id refinement now belongs to Object Core #909. Lane E is **idle by design** unless a new Search correctness gap appears.

### F — Storage, Vault & Delivery
#897 is completed through #906. The legacy Photo physical delete boundary is now Vault-safe; #242/#218 remain final real-macOS/user-machine validation rather than known repository implementation work.

Lane F is **idle by design** unless validation exposes a defect or another lane identifies a concrete Storage contract gap.

### G — Refactor & Architecture Health
#225 remains active. #899 Database-presentation shim cleanup and #915 caller-zero `AppDatabase` Photo mutation retirement are merged. Continue deletion/extraction only where replacement parity or caller-zero evidence is concrete; do not hide product semantics inside Refactor work.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database selects Objects; View controls filter/sort/group/layout/presentation; Objects are not owned by a View.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- universal Object Body is available through shared side/center/full opening surfaces.
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature and production paths increasingly share one integrity contract.
- template-derived schemas are user-owned/editable and are not silently reset by later template versions.
- Bookmark-like domain creation/operation is proven through generic template/Object/Relation/Database/View contracts.
- Weblink is a reusable canonical Object with normalized URL identity, enrichment and managed Image Relations.
- Bookmark detail, Photo Management attachment and Bookmark creation write image selection through canonical Image Relations (#881/#889/#892), while temporary Photo projection remains for legacy readers.
- canonical Images now open first-use as a shared masonry Gallery with direct-Image covers through ordinary View persistence (#908), without resetting user customization.
- legacy Photo physical deletion is gated by proven active-Vault ownership and fails closed on unsafe paths (#906).
- caller-zero Bookmark/Photo mutation helpers have been removed from both `BookmarkRepository` (#903) and `AppDatabase` (#915) while compatibility reads/storage remain where still required.
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- PDF remains File + capabilities/enrichment/search; there is no separate PDF persistence model.
- Global Search is canonical Object search; focused detail-return and live legacy-mirror freshness avoid routine workspace rebuilds (#884/#894/#902/#913).
- macOS release/DMG CI has succeeded; final local install/Vault preservation checks remain outside repository automation.

## Remaining product edge
Highest-value live work:
1. **#245 Photo -> Image** — finish canonical Image presentation/read/write parity, migrate remaining Bookmark/People/Photo consumers, then hide/retire legacy `写真` only after caller parity.
2. **#895 Relation integrity** — harden the newly-live Bookmark Image canonical write workflows against stored/index/target corruption.
3. **#909 Object sync impact** — make live mirror completion report only canonical Objects actually changed, eliminating unchanged-pass false positives while remaining Search-agnostic.
4. **#910 Daily Note identity** — make canonical Date identity-managed so generic edits cannot separate registry date from persisted Date.
5. **#155 Weblink convergence** — finish generic rich Weblink/Image presentation and retire remaining Bookmark URL/thumbnail compatibility only after caller-zero proof.
6. **#225 Refactor** — delete superseded shims/legacy paths after replacement parity.
7. **#242/#218 validation** — final real-macOS Vault and packaged-app preservation checks.
8. **#56 usage-driven finishing** — create focused follow-ups only for demonstrated daily-use gaps.

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

The #899 Generic Database import/shim lease is finished. Lane C currently holds no shared-hotspot lease; always re-audit live PRs rather than carrying this checkpoint forward as a lease guarantee.

## Cross-lane boundaries
- Database/View owns generic presentation/configuration; Primitive owns Weblink/Image/File-specific product semantics.
- Primitive owns Object/file identity, metadata and content routing; Storage owns Vault/filesystem byte placement, portable paths, ownership, rollback and physical delete safety.
- Relation/Data Integrity owns Relation mutation/read/index correctness and integrity-sensitive schema changes.
- Object Core owns Body persistence/edit contracts, Daily Note identity and generic canonical mutation-impact contracts.
- Search owns canonical FTS projection/refresh planning; Object/primitive producers expose only Search-agnostic mutation impact.
- Refactor deletes legacy code only after the owning product lane proves replacement parity.

## Development hygiene
- Follow `AGENTS.md` autonomous-loop, lane ownership and stopping criteria.
- Do not manufacture no-op/whitespace/temp commits to trigger CI; use workflow rerun controls or the next meaningful change.
- Always re-read live GitHub state before implementation; handoff files are durable checkpoints, not substitutes for current Issues/PRs/CI.
- Idle is correct when no concrete work exists. Current focused repository obligations include #895 in Lane B and #909/#910 in Lane A; C and F are idle after #896/#897 completion unless new focused gaps appear.

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility data remains live while old callers still consume it;
- Photo -> Image migration must not delete or rewrite user data before parity and ownership are proven;
- malformed Relation state must fail closed rather than be silently projected/repaired by presentation workflows;
- Object sync impact must avoid false-positive broad invalidation while remaining independent of Search semantics;
- Search freshness fixes must not reintroduce full-workspace rebuilds or Search dependencies into Object presentation;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- physical file deletion must remain ownership-gated rather than infer authority from an arbitrary legacy path;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases, not concurrent broad edits.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.
