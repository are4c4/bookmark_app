# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving behavior.

Primary lane: **Refactor**. This lane owns technical-debt reduction rather than product semantics and coordinates with Object / Relation work before touching shared hotspots.

## Current active branch / PR
- `refactor/issue-225-bookmark-read-store` — PR #281 `Move Bookmark aggregation behind read store`.

PR #281 is the first post-migration AppDatabase responsibility-reduction slice:
- adds `BookmarkReadStore.watchItems()` as the owner of screen-ready `BookmarkItem` aggregation;
- moves the former `AppDatabase.watchBookmarkItems()` joins, ordering, cover-photo selection and profile-relative photo path resolution without semantic changes;
- routes `BookmarkRepository` and `ObjectSyncService` through the new read store;
- deletes `AppDatabase.watchBookmarkItems()` after its two production consumers move;
- adds `test/bookmark_read_store_test.dart` covering aggregate ordering, collection data, cover photo and path resolution;
- does not change schema, migration ordering, Object semantics or Relation semantics.

## Completed checkpoints
### P0 guardrails / architecture
Merged through #228:
- `tool/maintainability_report.sh` for non-blocking Dart LOC / largest-file reporting;
- `docs/MAINTAINABILITY.md` with hotspot baseline and no-new-legacy-dependency policy;
- `docs/LEGACY_BOOKMARK_INVENTORY.md` classifying production Bookmark-era consumers;
- `docs/ERROR_POLICY_AUDIT.md` classifying broad catch / fallback behavior;
- `docs/architecture.md` dependency-boundary guidance;
- dedicated Refactor-lane handoff.

The no-new-legacy-dependency rule remains repository policy: new Object/Database/View work should not add new `BookmarkItem` / legacy-table dependencies unless explicitly required for compatibility or migration.

### Failure-policy / observability
Merged behavior-preserving slices:
- #227 — optional PDF author enrichment in `GlobalFileDropLayer` remains non-blocking; debug diagnostics replace an empty catch.
- #229 — profile state / backup metadata fallbacks retain default/best-effort behavior with debug/assert diagnostics.
- #234 — corrupt Database View JSON still fails soft to empty values; unexpected decode failures are debug-visible without logging raw JSON.
- #237 — remote image geometry decode remains best-effort; decode failures are debug-visible while managed import still succeeds.
- #274 — PDF metadata filename fallback remains best-effort; debug diagnostics log exception type + stack only, not path/content.
- #279 — Bookmark metadata URL/host fallback remains best-effort; debug diagnostics log exception type + stack only, not URL/response/exception text.

Do not convert intentional fail-soft product behavior into user-visible failure merely to remove broad catches.

### AppDatabase migration safety / extraction — complete
Issue #225's v2–v14 migration-body extraction target is complete; the resulting helper sequence now covers **v2 through v16**.

Merged extraction PRs include:
- #278 v2
- #276 v3
- #275 v4
- #267 v5
- #262 v6
- #261 v7
- #260 v8
- #258 v9
- #248 v10
- #246 v11
- #241 v12
- #239 v13
- #232 v14
- pre-existing v15 / v16 helpers

`AppDatabase.migration` is now sequencing/wiring rather than the home of historical migration bodies.

Historical regression coverage was added before risky extractions, including real schemaVersion 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 and 13-era upgrade paths where appropriate. Relation-lane regressions also replay canonical Relation bootstrap across old Bookmark-era migrations (#264, #266, #271, #273, #280).

### Historical migration compatibility bugs found and fixed
The historical fixtures exposed real installed-user upgrade defects rather than test-only problems:
- #257 — v5 -> current could create `photos.tags` early and then v7 attempted to add the column again. v7 now adds it only when absent.
- #259 — v4 -> current could create `people.profile_photo_id` early and then v9 attempted to add it again. v9 now guards the column addition.
- #269 — v3 SavedView migration used the current Drift row mapper against a historical physical table missing later required columns. Legacy `tag_id` migration now uses historical/raw SQL instead.
- #270 — v2 Bookmark/tag normalization used current table definitions/mappers against historical physical schema. v3 now recreates its historical DDL and reads only historical Bookmark columns through raw SQL.

These fixes preserve old migration intent while removing dependence on today's generated row shape.

### AppDatabase responsibility reduction
- v2–v16 migration bodies are extracted.
- PR #281 moves `watchBookmarkItems()` composite loading out of the database root into `BookmarkReadStore` and removes the old database-root aggregation API once both production consumers move.

Continue narrowing AppDatabase only when the move deletes a real responsibility rather than adding wrapper-only indirection.

## Cross-lane coordination
### Object lane
Current open Object PR:
- #223 — real `GenericDatabasePage` masonry Gallery integration.

#223 directly owns `generic_database_page.dart`. Therefore:
- do not begin broad GenericDatabasePage controller/state/layout extraction while #223 is open;
- do not reconstruct that file for unrelated refactors;
- re-check ownership after #223 merges/closes before starting P1 page decomposition.

Recent Object work has moved canonical Weblink/Image creation and managed-media behavior forward (#250/#263/#265/#272 and related work). Legacy presentation retirement should follow proven Object-first replacements rather than creating parallel adapters.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Relation has added cross-lane migration/composition regressions through #280. Refactor must preserve canonical Relation APIs and must not redesign Relation storage/index semantics.

Do not add Relation regressions mechanically for every refactor; add them only when a changed boundary can affect canonical Relation persistence, bootstrap, lifecycle or composition.

## Hotspot ownership / edit policy
Before non-trivial edits, inspect open PRs for:
- `generic_database_page.dart`
- `app_shell.dart`
- `object_inspector_page.dart`
- `bookmark_unified_stage1_page.dart`
- `app_database.dart`

Prefer patch-sized extractions and compare-audited diffs. Do not use whole-file reconstruction merely to change a small responsibility.

## Exact next actions
1. Finish PR #281 validation and merge only if focused read-store regression + full Analyze/Test remain green.
2. Re-run `tool/maintainability_report.sh` / hotspot inventory after #281 to record the actual AppDatabase reduction.
3. Audit remaining AppDatabase responsibilities. Next candidates must remove a real persistence-root responsibility (for example reusable profile/path concerns or coherent legacy read operations) and keep behavior covered; avoid abstraction for its own sake.
4. Re-run `docs/LEGACY_BOOKMARK_INVENTORY.md` after Object #223 and subsequent #155 work. Track production references removed and deleted LOC, not adapters added.
5. Once #223 releases `generic_database_page.dart`, start P1 decomposition as small focused slices with pre-existing/focused regressions; no monolithic rewrite.
6. Continue failure-policy work only for genuinely silent broad catches where behavior-preserving diagnostics/tests add value.
7. Update repository-wide `docs/AI_PROGRESS.md` only when sequencing/ownership materially changes and after checking concurrent lane ownership.

## Validation expectations
For responsibility-moving refactors:
- preserve public behavior and ordering/path semantics;
- add focused regression coverage for the moved responsibility when practical;
- run `flutter analyze` and full tests before merge;
- verify production callers no longer use the old responsibility before deleting it.

For migration refactors/fixes:
- historical migration regression must pass;
- schema version, statement order/defaults and intended compatibility behavior must remain unchanged unless the regression proves the old implementation was broken.

For failure-policy refactors:
- fail-soft/user-visible behavior remains unchanged unless a separate product issue says otherwise;
- debug diagnostics must not log raw user content, file paths, URLs, image bytes, credentials or secrets when avoidable.

## Risks / blockers
- broad GenericDatabasePage refactor remains blocked by active Object PR #223 ownership.
- legacy Bookmark storage/UI cannot be deleted before Object-first read/write/presentation parity is proven.
- parallel lanes can make PR bases and shared docs stale quickly; rebase by reconstructing the intended small diff on latest main rather than force-merging stale state.
- refactors that only add wrappers without deleting duplication or reducing responsibility should be reconsidered.

## Current validation / stop state
- v2–v16 migration extraction: complete and merged.
- v1→current historical migration regression: green and merged (#277), with canonical Relation v1 bootstrap coverage merged in #280.
- Bookmark/PDF metadata observability: merged (#279/#274).
- PR #281: active; code Analyze passed on the focused-read-store head and full Test is being validated after adding `bookmark_read_store_test.dart`.

Refactor work remains actionable. The current execution should continue through #281; the only major blocked P1 item is broad `GenericDatabasePage` decomposition while #223 owns that hotspot.
