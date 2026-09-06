# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always read live GitHub state before editing; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, caller-zero retirement after proof, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-07
Latest verified `main` for this handoff: **`c481b8b1b05078e14424433bee564a33804b76b7`** after Refactor #451/#453/#454/#455.

The CI presentation/database boundary guard introduced by #443 is now enforced by #448 at a ceiling of **12** `workspaceStore.database` references. The local report remains non-blocking unless a threshold is supplied. Ratchet the CI ceiling downward whenever a Refactor slice actually removes a measured presentation reach-through.

This session completed four behavior-preserving cleanup PRs:
- **#451 merged** — retired the caller-zero Object detail session composition chain (`ObjectDetailRelationContextLoader`, `ObjectDetailSessionLoader`, `ObjectTypeDefaultsService` and dead-only models/tests), **337 deletions / 0 additions**.
- **#453 merged** — retired unused drag/drop intent payload/target hierarchy, **49 deletions / 0 additions**; Flutter CI #1577 green.
- **#454 merged** — retired caller-zero `ObjectBodyReferenceIndex` and its dead-only test, **106 deletions / 0 additions**; Flutter CI #1578 green.
- **#455 merged** — retired caller-zero `ObjectBodyBlockValidator` and removed only validator-specific assertions while preserving live Object Body factory/reference/round-trip coverage, **116 deletions / 1 addition**; Flutter CI #1582 green.

Combined for #451/#453/#454/#455: **608 deletions / 1 addition, net -607 LOC**.

Stale docs-only PR #452 was closed rather than force-merged after main moved.

Shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`) were deliberately not rewritten.

## Live cross-lane ownership at this checkpoint
### Object lane
Open Object PRs at handoff time:
- **#447** — canonical Image preview same-path refresh; owns `object_image_detail_preview.dart` and its focused regression test.
- **#450** — canonical Image detail preview/edit composition; owns `object_image_detail_panel.dart` and its focused regression test.

Refactor must not alter Image edit/restore/file-ownership semantics, Photo mapping, or those active presentation files while this work is in flight.

### Relation lane
No open Relation production PR was present at this checkpoint. Canonical Relation mutation/read/index/backlink/audit/reconcile semantics remain Relation-owned. Refactor must not create alternate Relation writes, indexes, repair paths, or presentation-side mutation.

Re-read live open PRs before every shared-host change because main moves quickly across lanes.

## Recent Refactor convergence
- **#373 merged** — Bookmark visual/lifecycle URL presentation delegates resolver composition to `BookmarkPresentationResolverFactory`.
- **#374 merged** — backup workflow moved out of `SettingsPage` into `DatabaseBackupSettingsSection`.
- **#377 merged** — maintainability reporting exposes presentation `workspaceStore.database` reach-through without failing existing debt.
- **#383 merged** — duplicate Bookmark -> mirrored Object lookup SQL/catch logic centralized in `BookmarkObjectLinkReadStore`.
- **#395 merged** — reverse-lookup resolver composition delegates to the shared factory.
- **#400 merged** — backup section no longer reaches through `BookmarkRepository` to `workspaceStore.database`.
- **#401 merged** — architecture guard prevents new direct Bookmark URL/visual resolver construction in presentation.
- **#404/#406 merged** — optional Image/Weblink diagnostics are privacy-safe while preserving fail-soft behavior.
- **#408 merged** — `BacklinkRepository` delegates focused relation reads through `BookmarkRepository.watchRelationsForBookmark(...)`.
- **#417 merged** — retired caller-zero `saved_view_extensions.dart` and dead-only tests.
- **#422 merged** — deduplicated Bookmark -> FTS projection SQL used by rebuild and focused refresh.
- **#431 merged** — retired caller-zero `DailyNoteDetailService` plus dead-only tests, deleting 94 LOC.
- **#439 merged** — `NotionBookmarkCard` delegates URL resolver composition through `BookmarkPresentationResolverFactory`.
- **#443 merged** — opt-in presentation/database reach-through regression threshold plus fixture regression test.
- **#448 merged** — enforces the accepted repository boundary ceiling of 12 in Flutter CI.
- **#451/#453/#454/#455 merged** — latest caller-zero retirement series described above.

Issue #414 separately tracks possible FTS focused-refresh stale-token correctness. Do not turn that semantic question into behavior-preserving cleanup.

## Major completed checkpoints

### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh` and `docs/MAINTAINABILITY.md`;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- #401 direct Bookmark resolver construction guard;
- #443 opt-in boundary threshold and fixture coverage;
- #448 actual CI enforcement at 12 references.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

A possible future AppDatabase target remains favorite/status/rating/open-count plus batch state updates that are near-passthrough calls from `BookmarkRepository` into the database root. Only move them when the change deletes real database-root responsibility and `app_database.dart` can be patched safely; do not reconstruct the file wholesale.

### Legacy Bookmark presentation / retirement
The originally inventoried direct Bookmark visual duplicates are canonicalized through `BookmarkVisualImage`. Canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and Bookmark List metadata.

#401 prevents new direct URL/visual resolver construction in presentation. #439 removed the remaining known direct Notion-card URL resolver construction.

Whole-module caller-zero retirement is preferred to speculative compatibility wrappers. Current examples include #417, #431, #451, #453, #454 and #455.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain live compatibility/import/export data until production caller-zero and migration/backup policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Do not reconstruct the large host for a small hunk.

### Failure policy / diagnostic privacy
Intentional fail-soft behavior stays fail-soft; rollback cleanup never replaces the primary failure; user-visible errors use stable messages; debug diagnostics avoid raw persisted/request user content. Remaining raw exception interpolation is concentrated in large/shared legacy hosts and should not trigger isolated logging churn.

## Dependency-composition state
Presentation database reach-through is measured by `tool/maintainability_report.sh` and enforced in CI at **12**. Confirmed reductions include resolver composition (#373/#395/#439), backup composition (#400) and focused Bookmark backlink reads (#408).

Known remaining reach-through is concentrated in `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`. Photo management remains adjacent to Object-owned Image semantics.

`CollectionManagementPage` was re-audited in this session: collection create/delete/membership already use `BookmarkRepository`, while rename and note persistence still update `database.collections` directly. There is no existing semantic update API. Do **not** add a one-caller wrapper merely to hide the access, and do not reconstruct `app_database.dart`/a large repository file through connector writes. Revisit only when a patch-sized existing boundary can own those mutations. Until then the CI ceiling remains 12.

## Caller-zero audit notes from this checkpoint
Confirmed live and therefore **not** deletion candidates:
- `ObjectDetailContent` and its loader/editor/presentation path;
- `ObjectBodyBlockIdAllocator` / `ObjectBodyBlockDuplicator`;
- `ObjectBodyEditor`;
- `DailyNoteDetailNavigationService`;
- `DatabaseCollectionResolver` and collection loading path.

Confirmed dead and removed in this checkpoint:
- Object detail session composition chain (#451);
- drag/drop intent type hierarchy (#453);
- `ObjectBodyReferenceIndex` (#454);
- `ObjectBodyBlockValidator` (#455).

Future caller-zero searches must re-run current-source and filename/import searches against latest main before deletion; stale GitHub search-index hits are not sufficient proof by themselves.

## Exact next actions
1. Re-read live open PR ownership and latest main before any code edit.
2. Continue current-source caller-zero auditing outside active Image/Relation ownership; delete only when production callers are zero and any still-live behavior has independent coverage.
3. Prefer a real responsibility/LOC reduction over wrappers added solely to hide property access.
4. If a presentation `workspaceStore.database` reference is removed, lower the CI ceiling from 12 in the same focused PR or an immediately following focused guardrail PR.
5. Revisit Collection management rename/note persistence only when an existing meaningful Store/Repository boundary can absorb it through a patch-sized edit.
6. Continue GenericDatabasePage P1 only when a safe extraction removes concrete schema/database action, Property workflow or layout-host responsibility.
7. Revisit AppDatabase mutation responsibility only when `app_database.dart` can be patched safely without whole-file reconstruction.
8. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
9. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.
10. Treat Issue #414 as separate search correctness work.

## Validation expectations
- P0 tooling: focused shell fixture regression, actual repository report with CI ceiling, plus Flutter Analyze/Test baseline;
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- caller-zero deletion: current production-code search plus import/file-name audit and independent coverage for still-live behavior;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- legacy storage deletion: prove production caller-zero and import/export/backup handling first.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small diffs on latest main rather than force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- connector file writes replace complete files, so do not reconstruct a large host merely for a small hunk;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- abstractions that add wrappers without removing responsibility should be rejected;
- stale search-index results can lag main, so verify candidate files and callers against current-source content before deletion.

## Stop / continuation state
Refactor remains actionable, but the obvious caller-zero Object Body/detail modules found in this pass have now been retired. The next safe work should either prove another true caller-zero module or perform a patch-sized responsibility move through an already meaningful boundary. Avoid active Image files (#447/#450), Relation semantics, and large-host reconstruction.
