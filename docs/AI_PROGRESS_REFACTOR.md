# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always read live GitHub state before editing; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-07
Latest `main` verified for this slice: **`f87b463b0991c8e2b4a3aa7e41db68a677b28aa3`** after Object #442/#446. Relation #445 is documentation-only and does not own Refactor files.

Previous docs-only Refactor PR #444 became stale/non-mergeable after main moved and was closed rather than force-merged.

Current Refactor WIP: `refactor/issue-225-ci-boundary-ceiling-447`.
- #443 already added `--max-boundary-refs N` plus isolated fixture coverage to `tool/maintainability_report.sh`;
- this slice wires the real repository metric into Flutter CI with the accepted ceiling of **12** presentation `workspaceStore.database` references;
- the default local report remains non-blocking unless a threshold is explicitly supplied;
- `docs/MAINTAINABILITY.md` now records that CI owns the current accepted ceiling and that the ceiling should ratchet downward when Refactor removes reach-through references;
- no product, persistence, Relation, Image-edit, or UI behavior changes are included.

Shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`) were deliberately not touched.

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
- #443 opt-in regression ceiling and fixture coverage.

Current WIP makes the boundary ceiling an actual CI repository regression guard at 12 references while preserving non-blocking default local reporting.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

A concrete next AppDatabase candidate remains favorite/status/rating/open-count plus batch state updates that are near-passthrough calls from `BookmarkRepository` into the database root. Only move them when the change deletes real database-root responsibility and `app_database.dart` can be patched safely; do not reconstruct the file wholesale.

### Legacy Bookmark presentation / retirement
The originally inventoried direct Bookmark visual duplicates are canonicalized through `BookmarkVisualImage`. Canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and Bookmark List metadata.

#401 prevents new direct URL/visual resolver construction in presentation. #439 removed the remaining known direct Notion-card URL resolver construction.

#417 and #431 are whole-module caller-zero retirements: dead modules were deleted rather than retained as speculative compatibility wrappers.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain live compatibility/import/export data until production caller-zero and migration/backup policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Do not reconstruct the large host for a small hunk.

### Failure policy / diagnostic privacy
Intentional fail-soft behavior stays fail-soft; rollback cleanup never replaces the primary failure; user-visible errors use stable messages; debug diagnostics avoid raw persisted/request user content. Remaining raw exception interpolation is concentrated in large/shared legacy hosts and should not trigger isolated logging churn.

## Dependency-composition state
Presentation database reach-through is measured by `tool/maintainability_report.sh`. Confirmed reductions include resolver composition (#373/#395/#439), backup composition (#400) and focused Bookmark backlink reads (#408).

Known remaining reach-through is concentrated in `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`. Photo management remains adjacent to Object-owned Image semantics. Prefer a real responsibility move with an existing meaningful boundary over wrappers created solely to hide property access.

The CI ceiling is currently 12. Any future Refactor PR that reduces the measured count should lower the CI ceiling at the same time or in an immediately following focused PR.

## Cross-lane coordination
### Object lane
Object owns #56/#155/#245/#249 product/presentation convergence. Object #442 added safe canonical Image detail edit actions and #446 refreshed its handoff. Refactor must not alter Image edit/restore/ownership semantics while reducing unrelated debt.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile remains mature. Relation #445 is documentation-only. Refactor must not create alternate Relation writes, indexes, repair paths or presentation-side mutation.

## Exact next actions
1. Validate the current CI-ceiling branch through PR CI; merge only when the maintainability ceiling, Analyze and full tests pass and the PR remains mergeable.
2. Re-read live open PR ownership before every shared-host change.
3. Prefer the next measurable responsibility/LOC reduction or true caller-zero deletion over another diagnostic micro-PR.
4. Re-audit small compatibility modules for production caller-zero; delete only when tests/import/export/migration expectations are independently covered.
5. Reduce presentation `workspaceStore.database` reach-through only in small/owned hosts with an existing meaningful Store/Service boundary, and ratchet the CI ceiling downward with each reduction.
6. Continue GenericDatabasePage P1 only when a safe extraction removes concrete schema/database action, Property workflow or layout-host responsibility.
7. Revisit AppDatabase mutation responsibility only when `app_database.dart` can be patched safely without whole-file reconstruction.
8. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
9. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.
10. Treat Issue #414 as separate search correctness work.

## Validation expectations
- P0 tooling: focused shell fixture regression, actual repository report with CI ceiling, plus Flutter Analyze/Test baseline;
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- caller-zero deletion: current production code search plus independent coverage for still-live behavior;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- legacy storage deletion: prove production caller-zero and import/export/backup handling first.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small diffs on latest main rather than force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- connector file writes replace complete files, so do not reconstruct a large host merely for a small hunk;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- abstractions that add wrappers without removing responsibility should be rejected.

## Stop / continuation state
Refactor remains actionable. Current WIP converts the existing opt-in P0 boundary metric into a real CI regression ceiling without touching product semantics. After CI/merge, continue with caller-zero or responsibility-reduction slices that avoid active Object ownership and Relation semantics.
