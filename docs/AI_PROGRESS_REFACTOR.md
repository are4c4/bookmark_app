# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always read live GitHub state before editing; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-07
Latest `main` verified in this checkpoint: **`e59e9f7fea65b1f7bbe557a3ed52573633ef309e`** after Refactor #443.

Completed in this run:
- **#443 merged** — `tool/maintainability_report.sh` now accepts opt-in `--max-boundary-refs N` and fails only when presentation `workspaceStore.database` reach-through exceeds the caller-supplied ceiling;
- default maintainability reporting remains non-blocking, so historical debt does not suddenly fail unrelated work;
- `tool/maintainability_report_test.sh` uses an isolated fixture to prove both accepted-ceiling and threshold-breach behavior;
- Flutter CI now runs that fixture before the existing Flutter setup / Analyze / Test steps;
- Flutter CI #1557 passed the maintainability guardrail test, Drift generation, Analyze and the full Flutter test suite;
- `docs/MAINTAINABILITY.md` documents the ratcheting policy and explicit threshold mode.

This P0 guardrail slice changed no product behavior, Relation behavior, persistence schema, legacy storage semantics, or UI behavior. Shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`) were not touched.

## Recent Refactor convergence
- **#373 merged** — Bookmark visual/lifecycle URL presentation delegates low-level resolver composition to `BookmarkPresentationResolverFactory`.
- **#374 merged** — backup workflow moved out of `SettingsPage` into `DatabaseBackupSettingsSection`.
- **#377 merged** — maintainability reporting exposes presentation `workspaceStore.database` reach-through.
- **#383 merged** — duplicate Bookmark -> mirrored Object lookup SQL/catch logic centralized in `BookmarkObjectLinkReadStore`.
- **#395 merged** — reverse-lookup resolver composition delegates to the shared factory.
- **#400 merged** — backup section no longer reaches through `BookmarkRepository` to `workspaceStore.database`.
- **#401 merged** — architecture guard prevents new direct Bookmark URL/visual resolver construction in presentation.
- **#404/#406 merged** — optional Image/Weblink diagnostics are privacy-safe while preserving fail-soft behavior.
- **#408 merged** — `BacklinkRepository` delegates focused relation reads through `BookmarkRepository.watchRelationsForBookmark(...)`.
- **#417 merged** — retired caller-zero `saved_view_extensions.dart` and dead-only tests.
- **#422 merged** — deduplicated Bookmark -> FTS projection SQL used by rebuild and focused refresh.
- **#431 merged** — retired caller-zero `DailyNoteDetailService` plus dead-only tests, deleting 94 LOC.
- **#439 merged** — `NotionBookmarkCard` delegates URL resolver composition through `BookmarkPresentationResolverFactory`, removing another presentation -> database reach-through.
- **#443 merged** — maintainability reach-through metric gained an opt-in regression ceiling with CI-covered fixture semantics.

During FTS validation, a possible focused-refresh stale-token behavior was observed and is tracked separately as **Issue #414**. Do not silently turn that correctness question into a behavior-preserving Refactor semantic change.

## Major completed checkpoints

### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh` and `docs/MAINTAINABILITY.md`;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- #401 direct Bookmark resolver construction guard;
- #443 opt-in regression ceiling plus CI execution of the guardrail fixture.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

A concrete next AppDatabase candidate remains favorite/status/rating/open-count plus batch state updates that are near-passthrough calls from `BookmarkRepository` into the database root. A focused mutation Store is only worthwhile when it removes real responsibility; **do not implement it while the available write path would require reconstructing `app_database.dart` wholesale.**

### Legacy Bookmark presentation / retirement
The originally inventoried direct Bookmark visual duplicates are canonicalized through `BookmarkVisualImage`. Canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and Bookmark List metadata.

#401 prevents new direct URL/visual resolver construction in presentation. #439 removed the remaining known direct Notion-card URL resolver construction.

#417 and #431 are whole-module caller-zero retirements: dead modules were deleted instead of retained as speculative compatibility wrappers.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain live compatibility/import/export data until production caller-zero and migration/backup policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Do not reconstruct the large host for a small hunk.

### Failure policy / diagnostic privacy
Broad high-value boundaries are covered across search/settings/bootstrap/profile/attachments/rollback/malformed persisted data and optional Weblink/Image enrichment.

Policy remains:
- intentional fail-soft behavior stays fail-soft;
- rollback cleanup never replaces the primary failure;
- user-visible failures use stable retry/domain messages instead of raw implementation strings;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies and exception text;
- `ProfileManager` corrupt-registry fallback selection remains a product/data-safety decision, not routine cleanup.

Remaining raw user-visible exception interpolation is concentrated in large/shared legacy hosts such as Photo management, Tag management and Stage1. Do not create micro logging PRs merely to chase strings in those files; address them only as part of a safe owned host slice.

## Dependency-composition state
Presentation database reach-through is measured by `tool/maintainability_report.sh`; #443 now allows the accepted ceiling to be explicitly ratcheted when a caller wants regression enforcement. Confirmed reductions include resolver composition (#373/#395/#439), backup composition (#400) and focused Bookmark backlink reads (#408).

Known remaining reach-through is concentrated in large/shared hosts including `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`. Some low-level DB access inside dedicated Store/Service factories is intentional. Prefer a real responsibility move with two or more callers, or an existing focused boundary, over a wrapper created solely to hide one property access.

Photo management remains adjacent to Object-owned #245/Image semantics. People/Collection management are possible future targets, but both are large enough that a patch-sized edit path and a meaningful existing boundary should exist before changing them.

## Cross-lane coordination

### Object lane
Object owns #56/#155/#245/#249 product/presentation convergence. Re-check live PRs before touching Bookmark/generic/media hosts because Object advances quickly. Object #438 has merged canonical Image restore availability; Refactor must not alter Image edit/restore/ownership semantics while reducing unrelated debt.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile remains mature. Refactor may narrow legacy Bookmark callers but must not create alternate serialized-id Relation writes, indexes, repair paths or presentation-side mutation. Relation #440 was documentation-only and is merged.

## Exact next actions
1. Re-read live open PR ownership and latest `main` before the next code slice.
2. Prefer the next measurable responsibility/LOC reduction or caller-zero deletion over another diagnostic micro-PR.
3. Re-audit small compatibility modules for true production caller-zero; delete only when tests/import/export/migration expectations are independently covered.
4. Continue reducing presentation `workspaceStore.database` reach-through only in small/owned hosts with an existing meaningful Store/Service boundary. Do not mass-wrap occurrences.
5. Consider ratcheting `--max-boundary-refs` in CI only after recording the current accepted repository count; do not guess a threshold.
6. Continue GenericDatabasePage P1 only when a safe extraction removes concrete schema/database action, Property workflow or layout-host responsibility.
7. Revisit AppDatabase mutation responsibility only when `app_database.dart` can be patched safely without whole-file reconstruction.
8. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
9. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.
10. Treat Issue #414 as separate search correctness work, not behavior-preserving cleanup.

## Validation expectations
- P0 tooling: focused shell fixture regression plus CI execution; repository Analyze/Test remains the baseline;
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- caller-zero deletion: current production code search plus independent coverage for any still-live behavior;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- failure-policy work: preserve fail-soft/fail-closed semantics and privacy-safe diagnostics;
- legacy storage deletion: prove production caller-zero and import/export/backup handling first.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small diffs on latest main rather than force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- connector file writes replace complete files, so large hosts must not be reconstructed merely for a small hunk;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- test lifecycle hangs must not be solved by changing production semantics or merely raising global timeouts;
- abstractions that add wrappers without removing responsibility should be rejected.

## Stop / continuation state
Refactor remains actionable. #443 is merged and fully validated. Continue with caller-zero or responsibility-reduction slices that avoid active Object ownership and Relation semantics; do not force work into a shared hotspot when no safe patch-sized slice exists.
