# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Object Core owns Object/Body semantics, Relations owns canonical Relation semantics, Database/View owns Database presentation semantics, Primitive Objects & Media owns Weblink/Image/File/etc. behavior, Search owns indexing/query semantics, and Storage/Vault owns storage/delivery behavior. Lane G owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Latest verified `main` at this handoff: **`c2d4bd082e1e88c6781db4f51b2c12998a6ff85f`** — **#654 Retire legacy Bookmark FTS implementation**.

Parallel lanes move `main` quickly. Re-read `AGENTS.md`, Issue #225, open PRs and current `main` before every shared-host edit or merge.

### Most recent Lane G integrated sequence
- **#504** `34a4ac24...` — forbid new `BookmarkItem` / `BookmarkRepository` dependencies under `lib/features/**`.
- **#522** `0254b87e...` — extend presentation/database reach-through measurement to `lib/features/**/presentation`.
- **#561** `5a8be9b3...` — guard direct feature-presentation `AppDatabase` imports; current ceiling 8.
- **#579** `3087a3d7...` — move favorite/status/rating/open-history mutations out of `AppDatabase` into `BookmarkEngagementStore`.
- **#586** `edec7f92...` — remove caller-zero plain-text Body edit path (`ObjectDetailEditService.setPlainTextBody` and `ObjectBodyPlainTextAdapter`).
- **#637** `e47ce709...` — remove dead Bookmark People batch mutations and `_peopleForBookmark` from `AppDatabase` (-22 LOC).
- **#642** `a7918569...` — remove dead Bookmark lifecycle read remnants (`BookmarkLifecycleState`, `states`, `watchStates`, synchronous `genre`) (-46 LOC).
- **#654** `c2d4bd08...` — retire the caller-zero legacy Bookmark-only FTS repository and dedicated tests after Search #629 routed live Global Search through canonical Objects (-369 LOC, +1).

### #654 validation
PR #654 passed:
- Maintainability guardrail tests;
- Maintainability regression ceilings;
- feature legacy dependency guard;
- Drift generation;
- `flutter analyze`;
- full `flutter test`.

Before merge, commits added after the branch base were compared and none touched the removed legacy FTS files or its remaining integrity-test hunk.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. At this checkpoint CI enforces:

1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **8 maximum**;
3. temporary Database-presentation re-export shim imports: **17 maximum**;
4. temporary Database-presentation re-export shim files: **5 maximum**.

Do not copy numeric ceilings into script help text as defaults. Ratchet a ceiling downward only when real debt is removed; never relax one merely to land unrelated feature work.

## Caller-zero / duplicate-path retirement state
The lane has now removed multiple whole modules or obsolete API chains rather than wrapping them in more abstraction. Important completed examples include:
- #417 `saved_view_extensions.dart`;
- #451 Object detail session composition chain;
- #453 drag/drop intent hierarchy;
- #454 `ObjectBodyReferenceIndex`;
- #455 `ObjectBodyBlockValidator`;
- #458 `ObjectGroupMode`;
- #459 `ObjectTypeDefaultsResolver` chain;
- #463 obsolete Object detail Value editor/codec layer;
- #464 abandoned Database record/property presenter layer;
- #466 paragraph-only `ObjectBodySection`;
- #472 `PersonRoleProperties`;
- #586 plain-text Body mutation path;
- #637 dead AppDatabase People batch APIs;
- #642 dead Bookmark lifecycle read model APIs;
- #654 legacy Bookmark-only FTS repository and tests.

Key rule: tests dedicated only to a caller-zero implementation do not make that implementation live. Before deletion, prove production callers are zero and that surviving behavior is covered independently by the canonical path.

## Legacy Bookmark convergence
### Global Search / FTS
Search #629 moved the live `GlobalSearchPage` to `ObjectGlobalSearchPage` / `ObjectGlobalSearchService`. Search correctness is now covered on canonical `object_search_fts`, including focused stale-token removal for title/aliases, Body, typed Properties, Relations, derived text and Weblink metadata.

Therefore #654 removed `FullTextSearchRepository`, its prefix-query test, its Bookmark projection/focused-refresh tests, and only the legacy FTS smoke test/import from `data_integrity_test.dart`. Do **not** reintroduce a Bookmark-only search index or adapter unless a concrete missing product contract is first proven.

### Backlinks / Bookmark detail
`BacklinkRepository` is still live through `BookmarkRelationSection`; do not delete or redesign it merely because canonical Relation infrastructure exists. Retirement requires Object/Relation presentation parity and zero production callers.

### URL / visual compatibility
Legacy `bookmarks.url`, thumbnail, Photo and Bookmark rows remain compatibility/import/export data. Canonical URL/visual presentation has converged substantially, but presentation parity is not permission to delete persisted compatibility storage. Prove production read/write caller-zero plus import/export/backup behavior before storage retirement.

## AppDatabase responsibility state
Major completed narrowing:
- #281 screen-ready Bookmark aggregation -> `BookmarkReadStore`;
- #282 profile-relative path conversion -> `ProfilePathResolver`;
- #283 Saved View aggregation -> `SavedViewReadStore`;
- #289 Photo aggregate/path reads -> `PhotoReadStore`;
- migration bodies v2-v16 extracted behind migration helpers; `AppDatabase.migration` is sequencing/wiring;
- #579 engagement writes -> `BookmarkEngagementStore`;
- #637 dead People batch/read helpers removed.

`AppDatabase` still contains legitimate CRUD/compatibility operations. Continue narrowing only when a real responsibility can be deleted/moved without introducing a pass-through wrapper.

### Audited near-term AppDatabase candidate
At the #637 checkpoint, `AppDatabase.updateBookmarkFields(... personNames ...)` had one production caller (`BookmarkRepository.update`) and that caller always passed `personNames: null`; live Person updates already use role-aware `setPeopleForRole(...)`. This makes the optional parameter/branch a likely behavior-preserving dead API seam.

**Re-audit on latest main before editing.** Do not assume the earlier caller count is still current.

## BookmarkLifecycleStore state
Live mutations such as inbox/archive/trash/restore and `watchGenre()` remain in use. #642 removed caller-zero aggregate state readers and synchronous `genre()`.

`BookmarkLifecycleStore.remove()` was observed as a no-op called from permanent deletion. It may be removable together with its caller, but re-audit current source and open PR ownership first. `dispose()` is also a no-op but has broad test/host call sites; removing it purely for a metric is low priority.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include:
- #310 `GenericDatabasePageStateLoader`;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows and layout-specific host code. Keep changes patch-sized and avoid reconstructing `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, or `bookmark_unified_stage1_page.dart` merely to change an import or constructor.

Database/View lane is actively landing Property authoring and Gallery/View composition slices. Always inspect open PRs before touching those hosts.

## Temporary Database-presentation re-export shims
Five legacy shim files remain guarded. Their canonical implementations live under `lib/features/database/presentation/widgets/`.

The shim-import ceiling is currently **17**. Migrate imports opportunistically when a real host is already safely modified; do not open large-file rewrites solely to decrease this count. Delete a shim only after all production/test callers have naturally moved.

## Failure-policy state
High-value user-visible raw-error boundaries have largely been stabilized. Intentional compatibility/best-effort failures may stay fail-soft, but unexpected failures should be observable through privacy-safe debug/test diagnostics where useful.

Do not change recovery/data-selection policy under Refactor merely because a catch is broad; Profile/Vault fallback changes can affect data safety and belong with Storage/Vault ownership.

## Current-source non-candidates
Recent audits confirmed these still have production callers and are **not** caller-zero deletion targets:
- `AutoOrganizeService`;
- `BookmarkTransferService`;
- `DatabaseBackupService`;
- `BookmarkPresentationResolverFactory` and canonical/legacy URL/visual resolvers;
- `GenericDatabaseImageImportService`;
- `DatabaseViewQueryAdapter` / `DatabaseViewManagementService`;
- `GenericDatabaseCollectionPageData`;
- `ObjectBodyBlockActionController`;
- `ObjectBoardMoveService`;
- `ObjectDetailPropertyPresentation`;
- `ObjectValuePromotion`;
- `BacklinkRepository`;
- canonical Object search repositories/services.

`tool/performance_probe.dart` is an intentional standalone CLI and must not be classified caller-zero merely because production Dart does not import it.

## Exact next actions
1. Re-read current `main` and open PRs after this docs slice lands.
2. Re-audit `AppDatabase.updateBookmarkFields.personNames`; if the only caller still always passes null, remove the parameter and dead branch in a small PR with focused CRUD regressions/full CI.
3. Re-audit `BookmarkLifecycleStore.remove()`; if it remains a no-op with only the permanent-delete call, remove both without changing deletion ordering/attachment cleanup.
4. Continue true production caller-zero audits; prefer deletion over wrapper creation.
5. Opportunistically ratchet temporary shim imports below 17 only when a real host can switch safely to canonical imports.
6. Lower presentation/database or feature-presentation AppDatabase ceilings only after a real boundary move removes references.
7. Continue GenericDatabasePage responsibility extraction only in small slices coordinated with Database/View ownership.
8. Do not touch Relation semantics, canonical Object search semantics, primitive storage semantics, or Vault lifecycle under Refactor.
9. Do not destructively remove Bookmark URL/thumbnail/Photo storage until production caller-zero and portability/migration contracts are proven.

## Risks / sequencing
- parallel lanes move `main` quickly;
- connector file writes replace complete files, so avoid one-line edits in huge shared hosts unless the complete current file can be safely preserved;
- open PR ownership takes precedence over an old handoff;
- behavior-preserving cleanup must not silently become migration, schema redesign, Relation redesign, Search redesign or storage-policy work;
- a falling reference/LOC metric is useful only when real responsibility disappears.

## Stop / continuation state
As of `c2d4bd08...`, no known Search duplicate remains after #654. The next useful Lane G work is narrow caller/API cleanup or an opportunistic boundary/shim ratchet, not a fabricated abstraction. If the two explicitly audited API seams above have gained callers or become concurrently owned, re-run the caller-zero audit and choose another small deletion rather than forcing a hotspot edit.
