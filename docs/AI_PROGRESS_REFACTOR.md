# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics; this lane deletes duplication, narrows responsibilities, improves failure observability/privacy, and decomposes hotspots only after checking parallel PR ownership.

## Current checkpoint — 2026-09-06
Latest `main` inspected at `2c3fcd7ba352e85487bdcd46ba23cee77e32301b`.

Open PR ownership at this checkpoint is Refactor-only:
- **#336** `Stabilize attachment failure handling`
- **#340** `Sanitize ProfileManager fallback diagnostics`
- **#342** `Preserve profile restore failure during cleanup` — Flutter CI run #1304 is green
- **#343** `Preserve Image import failure during rollback cleanup` — current run

No Object/Relation PR currently owns the shared hotspots, but #343 intentionally avoids them anyway. It touches only `GenericDatabaseImageImportService`, its focused test, and failure-policy documentation.

### Current run — #343
A rollback boundary in managed Image import could mask the primary canonical Image Object-creation failure: `_createImported()` caught the creation error, awaited `deleteManagedPhoto()`, then rethrew. If file deletion itself failed, the cleanup exception replaced the original failure.

#343 changes only that rollback boundary:
- rollback deletion is explicitly best-effort;
- the original Image-creation failure is always rethrown;
- secondary cleanup failure is debug/assert-visible through a fixed message + stack trace only;
- no path or exception text is logged;
- focused regression uses a `PhotoStorageService` test double whose delete fails and proves the original `UnsupportedError` remains the observed failure.

No Image identity, import acceptance, storage format, Object/Relation semantics, schema, or presentation behavior changes.

## Completed checkpoints
### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- dedicated Refactor handoff.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase migration extraction — complete
All historical migration bodies **v2 through v16** live behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Historical fixtures cover real schemaVersion checkpoints down to v1 and exposed installed-user defects fixed before extraction, including duplicate `photos.tags`, duplicate `people.profile_photo_id`, and historical mapper/schema incompatibilities.

### AppDatabase responsibility reduction — completed slices
Merged responsibility moves:
- **#281 `BookmarkReadStore`** — removed `AppDatabase.watchBookmarkItems()`;
- **#282 `ProfilePathResolver`** — removed AppDatabase profile-path conversion responsibility;
- **#283 `SavedViewReadStore`** — removed screen-ready saved-view aggregation;
- **#289 `PhotoReadStore`** — removed `AppDatabase.watchAllPhotos()` and centralized Photo path resolution.

Continue shrinking AppDatabase only when a slice removes a real responsibility; reject wrapper-only indirection.

### Legacy Bookmark visual duplication — original inventory complete
Canonical `BookmarkVisualImage` migration is merged for all four direct visual duplicates originally identified:
- lifecycle rows — Object #296;
- Notion card — Refactor #294;
- reverse lookup — Refactor #299;
- Stage1 List/Table — Refactor #324.

Whole Bookmark hosts are not automatically deletable; only the duplicate visual-resolution logic is retired. Legacy fallback remains while compatibility callers remain.

### GenericDatabasePage decomposition
Merged focused slices:
- **#310** — read/projection loading, all-ObjectType aggregation, create-mode resolution and computed evaluation moved into `GenericDatabasePageStateLoader`;
- **#323** — low-level Store/Service graph construction moved out of the Widget into `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Next useful P1 candidates remain schema/database actions, Property workflow extraction, or layout-specific host extraction, but only through patch-sized edits that measurably remove responsibility/LOC.

### Failure-policy / privacy sequence
Merged slices include #227/#229/#234/#237/#274/#279/#321/#325–#335/#338, covering best-effort metadata/media enrichment, malformed persisted JSON, computed projection, search/settings error states, file-drop failures, and diagnostic privacy.

Current open follow-ups are #336/#340/#342/#343. Intentional fail-soft behavior must remain fail-soft. Debug diagnostics use fixed messages + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies, and exception text when those may echo user content.

## Cross-lane coordination
### Object lane
Object-first Weblink/Bookmark parity has advanced beyond the older handoff: lifecycle, reverse lookup, Notion card, and Stage1 URL/visual paths have been migrating toward canonical Weblink state. Legacy `bookmarks.url` remains compatibility/import/export data until all live callers and migration policy are proven replaceable.

Before touching `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart`, `app_shell.dart`, or `app_database.dart`, re-check open PR ownership.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Refactor must preserve canonical Relation APIs and must not create alternate serialized-id/index/repair paths.

## Exact next actions
1. Let #336/#340/#342/#343 complete CI/integration; do not stack overlapping failure-boundary edits onto the same files while they are open.
2. Re-scan for rollback catches where secondary cleanup can replace the primary failure. `ObjectBoardCreateService` is worth verifying, but preserve its invariant rollback and avoid changing Relation/Object semantics.
3. Continue GenericDatabasePage P1 decomposition only when a safe patch-sized responsibility move is available; prefer measurable responsibility/LOC reduction over aliases/wrappers.
4. Continue caller-zero legacy retirement only after Object-first replacement is already merged and production references can actually be removed.
5. Keep ProfileManager recovery selection policy deferred; changing corrupt-registry fallback semantics is a data-safety/product decision, not routine cleanup.
6. Re-run `tool/maintainability_report.sh` after another meaningful hotspot slice in an environment that can execute the repo.

## Validation expectations
For responsibility-moving refactors:
- preserve ordering/path/public behavior;
- add focused regression coverage when practical;
- run `flutter analyze` and full tests before merge;
- verify old production callers are gone before deleting old responsibility.

For failure-policy work:
- fail-soft/user-visible behavior stays unchanged unless a separate product issue says otherwise;
- rollback cleanup must not mask the original operation failure;
- avoid logging raw user content, paths, URLs, JSON, bytes, credentials, secrets, or exception text that may contain them.

## Risks / blockers
- `main` moves quickly; rebuild small intended diffs on current main instead of force-merging stale branches;
- large shared hosts should not be reconstructed wholesale for small edits;
- legacy Bookmark storage/UI cannot be deleted before Object-first parity and caller-zero proof;
- ProfileManager recovery behavior is a data-safety decision;
- multiple currently open Refactor PRs mean follow-up work should avoid their exact files until integrated.

## Current validation / stop state
- #342: Flutter CI run #1304 passed; PR is mergeable/open.
- #343: focused code/test/docs are pushed; CI is pending after PR creation/update.
- No shared hotspot or Relation semantics were touched in this run.

Refactor work remains actionable. The next safe work should be another non-overlapping rollback/failure-boundary verification or a measurable hotspot extraction after current PR ownership clears.
