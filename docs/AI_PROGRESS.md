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
The generic composition architecture is proven in production code. Remaining work is primarily daily-use finishing, Photo -> Image / Weblink legacy convergence, integrity hardening around newly-live workflows, storage safety, refactor/caller-zero retirement and real-machine validation.

Completed focused milestones include #249, #414, #481, #484, #489, #490, #491, #492, #493, #494, #495, #501, #877 and #888.

Recent composition/migration proof:
- #856 (`7e103a02…`) proves Bookmark-like behavior can be expressed through user-owned template/Object/Relation/Database/View configuration rather than a new Bookmark-only persistence model.
- #874 (`38c20b67…`) composes universal Body editing into Generic Database side peek and closes #481.
- #884 (`f1651ba1…`) and #894 (`ac470eec…`) close Search freshness gaps #877/#888 with focused refresh for Relation-linked and nested-Inspector visited Objects rather than workspace rebuilds.
- #881 (`47d31345…`) moves Bookmark image editing onto canonical `Images` / `Cover Image` Relations while retaining temporary legacy Photo projection.
- #889 (`fcd0eb34…`) routes legacy Photo Management “add to Bookmark” through the same canonical Bookmark Image Relation authority.
- **#892 (`94b3833106683745291470732331aef3d28d66d5`)** routes Bookmark creation Photo selection through canonical Image Relations as well; Flutter CI #2730 was green before squash merge.
- #885 (`38494512…`) closes #249 by using the shared fixed/masonry Gallery contract in the real Bookmark Stage1 host.

## Active architecture/product issues
Live GitHub audit after #892 merge shows **9 open Issues**:
- `#56` — generic Object/Database/View daily-use integration umbrella.
- `#155` — reusable Weblink Object; remaining rich Weblink/Image presentation and legacy Bookmark URL/media convergence.
- `#218` — macOS installable delivery; repository packaging/CI complete, final user-machine validation remains.
- `#225` — maintainability, hotspot reduction and legacy-path retirement.
- `#242` — Vault/storage lifecycle; v1 lifecycle implementation complete, final real-macOS validation remains.
- `#245` — legacy Photos -> canonical Image Objects.
- **`#895` — Relation integrity:** fail closed when Bookmark Image Relation stored values/index/targets/cardinality are inconsistent.
- **`#896` — Database/View:** canonical Images should start with a useful shared default Gallery View without resetting user customization.
- **`#897` — Storage:** legacy Photo physical deletion must be Vault-safe and preserve external/ambiguous files.

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
#481/#249 are complete. Lane A is **idle by design** unless #56 or real usage exposes a concrete Object-core/Body/detail correctness obligation. Do not invent abstractions merely to keep the lane active.

### B — Relations & Data Integrity
**Active: #895.**

#881/#889/#892 made canonical Bookmark Image Relations a real production write authority. Lane B must now prove these writers obey the same stored-value + normalized-index + target/cardinality integrity contract as canonical Relation reads. Corrupt/index-drift state must fail closed with no partial canonical or `bookmark_photos` compatibility writes. #892 is merged, so the previous same-service sequencing blocker is cleared.

### C — Database, View & Schema UX
**Active: #896.**

Canonical Images are exposed in generic navigation and already have shared Gallery/direct-Image machinery. Lane C owns first-use/default View provisioning and persistence so Images can replace the legacy dedicated Photo presentation without an Image-specific page or second View authority. Existing user Views/customization must never be reset by reseeding.

Current coordination: open Refactor PR #899 owns the `GenericDatabasePage` import/shim lease. C should prefer View store/provisioning/service/test seams until that lease clears, or wait before broad host edits.

### D — Primitive Objects & Media
Primary active Issues remain #155 and #245.

Recent Image migration checkpoints:
- #879 preserves first-class native Bookmark Image Relations during compatibility sync.
- #881 makes Bookmark detail image edits canonical.
- #889 makes legacy Photo Management attachment canonical.
- #892 makes Bookmark-create Photo selection canonical.

Continue canonical Image write/presentation parity and retire Photo-only callers only after replacement parity and safety are demonstrated.

### E — Search & Indexing
#414/#494/#877/#888 are complete. Lane E is **idle by design** until a concrete Search correctness obligation appears. Preserve focused Search-owned refresh rather than routine full-workspace rebuilds.

### F — Storage, Vault & Delivery
**Active: #897**, in addition to final real-machine validation for #242/#218.

#897 is a concrete repository implementation obligation discovered during #245 migration: `PhotoStorageService.deleteManagedPhoto(...)` previously trusted an arbitrary legacy path for physical deletion. Active branch `feature/storage-vault-safe-legacy-photo-delete-897` now hardens this boundary to the configured active `photos/` root, resolves portable paths through `ProfilePathResolver`, fails closed on external/traversal/symlink/offline/ambiguous state, and protects unsafe `.bookmark_original` backups. Repository and focused Storage regressions are present; PR/CI/integration remain.

### G — Refactor & Architecture Health
#225 remains active. Open PR #899 retires the final Database-presentation re-export shims and temporarily owns the `GenericDatabasePage` import region. Keep product behavior changes out of Refactor work.

## Major integrated state
- Object/ObjectType/Database/View foundations are live in real hosts.
- Database selects Objects; View controls filter/sort/group/layout/presentation; Objects are not owned by a View.
- Table/List/Gallery/Board, multiple Views, persisted opening modes and generic schema editing are integrated.
- universal Object Body is available through shared side/center/full opening surfaces.
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature and production paths increasingly share one integrity contract.
- template-derived schemas are user-owned/editable and are not silently reset by later template versions.
- Bookmark-like domain creation/operation is proven through generic template/Object/Relation/Database/View contracts.
- Weblink is a reusable canonical Object with normalized URL identity, enrichment and managed Image Relations.
- Bookmark detail, Photo Management attachment and Bookmark creation now write image selection through canonical Image Relations (#881/#889/#892), while temporary Photo projection remains for legacy readers.
- Image and File remain distinct built-in primitives while sharing managed-file/Vault infrastructure.
- PDF remains File + capabilities/enrichment/search; there is no separate PDF persistence model.
- Global Search is canonical Object search; focused detail-return freshness covers root, trustworthy Relation-linked, and nested-visited Objects without routine workspace rebuilds.
- Storage-managed File attachments use explicit ownership; legacy Photo deletion is being brought to the same fail-closed filesystem safety standard in #897.
- macOS release/DMG CI has succeeded; final local install/Vault preservation checks remain outside repository automation.

## Remaining product edge
Highest-value live work:
1. **#245 Photo -> Image** — finish canonical Image presentation/write parity, migrate remaining Bookmark/People/Photo consumers, then hide/retire legacy `写真` only after caller parity.
2. **#895 Relation integrity** — harden the newly-live Bookmark Image canonical write workflows against stored/index/target corruption.
3. **#896 Images View UX** — make canonical Images practical as a first-class generic Gallery collection while preserving user View configuration.
4. **#897 Storage safety** — finish CI/integration of Vault-safe legacy Photo deletion.
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

Current live lease note: PR #899 (Lane G) owns the final Database presentation shim/import cleanup in `GenericDatabasePage`; Lane C #896 should not race a broad edit there.

## Cross-lane boundaries
- Database/View owns generic presentation/configuration; Primitive owns Weblink/Image/File-specific product semantics.
- Primitive owns Object/file identity, metadata and content routing; Storage owns Vault/filesystem byte placement, portable paths, ownership, rollback and physical delete safety.
- Relation/Data Integrity owns Relation mutation/read/index correctness and integrity-sensitive schema changes.
- Object Core owns Body persistence/edit contracts and reusable opening/detail seams.
- Search owns canonical FTS projection/refresh planning; presentation exposes only generic navigation-impact seams.
- Refactor deletes legacy code only after the owning product lane proves replacement parity.

## Development hygiene
- Follow `AGENTS.md` autonomous-loop, lane ownership and stopping criteria.
- Do not manufacture no-op/whitespace/temp commits to trigger CI; use workflow rerun controls or the next meaningful change.
- Always re-read live GitHub state before implementation; handoff files are durable checkpoints, not substitutes for current Issues/PRs/CI.
- Idle is correct when no concrete work exists, but #895/#896/#897 are now real obligations and B/C/F must no longer be described as idle while they remain open/actionable.

## Known risks
- legacy Bookmark URL/thumbnail/Photo compatibility data remains live while old callers still consume it;
- Photo -> Image migration must not delete or rewrite user data before parity and ownership are proven;
- malformed Relation state must fail closed rather than be silently projected/repaired by presentation workflows;
- Search freshness fixes must not reintroduce full-workspace rebuilds or Search dependencies into Object presentation;
- Vault changes must not silently replace inaccessible storage with a new empty database;
- physical file deletion must not derive authority from an arbitrary legacy path;
- large shared hosts remain conflict magnets; throughput comes from lane ownership + hotspot leases, not concurrent broad edits.

## Handoff rule
Each lane normally updates only its own progress file. Update this repository-wide file when issue routing, architecture decisions, cross-lane dependencies or global priorities materially change.
