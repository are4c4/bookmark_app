# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always read live GitHub state before editing; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-06
Latest `main` verified in this checkpoint: **`ea73825855756cf26dc50e0ad97861ac204d5656`** after Refactor #427.

Recent Refactor convergence:
- **#373 merged** — Bookmark visual/lifecycle URL presentation delegates low-level resolver composition to `BookmarkPresentationResolverFactory`.
- **#374 merged** — backup workflow moved out of `SettingsPage` into `DatabaseBackupSettingsSection`.
- **#377 merged** — maintainability reporting exposes presentation `workspaceStore.database` reach-through without failing on existing debt.
- **#383 merged** — duplicate Bookmark -> mirrored Object lookup SQL/catch logic centralized in `BookmarkObjectLinkReadStore`.
- **#395 merged** — reverse-lookup resolver composition delegates to the shared factory.
- **#400 merged** — backup section no longer reaches through `BookmarkRepository` to `workspaceStore.database`.
- **#401 merged** — architecture guard prevents new direct Bookmark URL/visual resolver construction in presentation.
- **#404 merged** — optional remote-image dimension diagnostics omit raw exception objects while preserving fail-soft import.
- **#406 merged** — optional generic Weblink enrichment diagnostics are privacy-safe; canonical creation remains fail-soft.
- **#408 merged** — `BacklinkRepository` delegates focused relation reads through `BookmarkRepository.watchRelationsForBookmark(...)` instead of reaching through to `AppDatabase` and watching the whole legacy relation table.
- **#417 merged** — retired caller-zero `saved_view_extensions.dart` and its dead-API-only regression: 25 production LOC + 59 test LOC removed, no replacement wrapper added.
- **#422 merged** — deduplicated complete Bookmark -> FTS projection SQL behind one private insert implementation shared by rebuild and focused refresh. Flutter CI #1503 Analyze/Test green.
- **#427 merged** — retired caller-zero Database collection View projector after current-source audit; no replacement abstraction.

During #410/#422 validation, a possible pre-existing focused-refresh stale-token behavior was observed. It was deliberately kept out of behavior-preserving Refactor work and is tracked separately as **Issue #414**. Do not silently turn that correctness question into a Refactor semantic change.

Current work in progress:
- **Refactor #429 became stale/non-mergeable after #427** despite Flutter CI #1519 green. Do not force merge it.
- **Current replacement branch `refactor/issue-225-retire-unused-daily-note-detail-service-v3`** is rebuilt directly from `ea738258...` and deletes caller-zero `DailyNoteDetailService` plus its dead-only test: 36 production LOC + 58 test LOC, 94 total, with no replacement abstraction.
- current-source search before rebuilding found `DailyNoteDetailService` only in its own production file and dedicated test; active Daily Note navigation remains on `DailyNoteDetailNavigationService` / shared Object detail paths.

Current parallel ownership at this checkpoint:
- **Object #428 open** — handoff-only refresh after Image deletion work; no production overlap with the Daily Note caller-zero deletion.
- **Relation #420 open** — handoff-only and stale/non-mergeable; Refactor must not redesign canonical Relation semantics.
- avoid shared Object/Image deletion paths while Object work advances.

## Major completed checkpoints

### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh` and `docs/MAINTAINABILITY.md`;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- #401 direct Bookmark resolver construction guard.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

A concrete next AppDatabase candidate remains: favorite/status/rating/open-count plus three batch state updates are near-passthrough calls from `BookmarkRepository` into the database root. A focused `BookmarkStateMutationStore` would remove real mutation responsibility. **Do not implement this while the available write path requires reconstructing `app_database.dart` wholesale.**

### Legacy Bookmark presentation / retirement
All four originally inventoried direct Bookmark visual duplicates are canonicalized through `BookmarkVisualImage` (Notion card, reverse lookup, lifecycle rows, Stage1 List/Table). Canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and Bookmark List metadata.

#401 still prevents new direct URL/visual resolver construction in presentation. Remaining allowlisted direct construction must be re-audited from current source before editing; do not relax the guard for new callers.

#417 is a recent whole-module caller-zero retirement: `saved_view_extensions.dart` is deleted instead of retained as a speculative compatibility wrapper. #427 continues the same deletion-first pattern for an unused Database collection View projector.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain live compatibility/import/export data until production caller-zero and migration/backup policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. The Property-create dialog extraction remains a good target only when a safe patch-sized edit path exists and Object does not own the host.

### Failure policy / diagnostic privacy
Broad high-value boundaries are covered across search/settings/bootstrap/profile/attachments/rollback/malformed persisted data and optional Weblink/Image enrichment.

Policy remains:
- intentional fail-soft behavior stays fail-soft;
- rollback cleanup never replaces the primary failure;
- user-visible failures use stable retry/domain messages instead of raw implementation strings;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies and exception text;
- `ProfileManager` corrupt-registry fallback selection remains a product/data-safety decision, not routine cleanup.

Remaining raw user-visible exception interpolation is concentrated in large/shared legacy hosts such as Photo management, Tag management and Stage1. Do not create micro logging PRs merely to chase strings in those files; address them only as part of a safe owned host slice.

### Search/index responsibility
#422 centralizes the duplicated Bookmark -> FTS projection used by full rebuild and focused refresh. FTS schema, ranking, prefix-query semantics, trash filtering and transaction boundaries remain unchanged.

**Issue #414 is separate correctness work.** Reproduce and fix stale focused-refresh tokens there if confirmed; do not conflate it with #225 cleanup.

## Dependency-composition state
#377 makes presentation database reach-through visible. Confirmed reductions include resolver composition (#373/#395), backup composition (#400) and focused Bookmark backlink reads (#408).

Known remaining reach-through is concentrated in large/shared hosts including `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`. Some low-level DB access inside dedicated Store/Service factories is intentional. Prefer a real responsibility move with two or more callers, or an existing focused boundary, over a wrapper created solely to hide one property access.

Attachment presentation still constructs `BookmarkAttachmentStore` in multiple hosts. Do not solve this by making `BookmarkRepository` a broader service locator; only change it when an existing focused boundary removes actual responsibility.

## Cross-lane coordination

### Object lane
Object owns #56/#155/#245/#249 product/presentation convergence. Re-check live PRs before touching Bookmark/generic/media hosts because Object advances quickly. Current Object work is Image/product convergence; avoid overlapping deletion/media paths.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile remains mature. Refactor may narrow legacy Bookmark callers (as #408 did) but must not create alternate serialized-id Relation writes, indexes, repair paths or presentation-side mutation.

## Exact next actions
1. Open/validate the latest-main replacement PR for the Daily Note caller-zero deletion; merge only after current-head CI is green and mergeable.
2. Re-read live open PR ownership before every shared-host change.
3. Prefer the next **measurable responsibility/LOC reduction or caller-zero deletion** over another diagnostic micro-PR.
4. Re-audit small compatibility modules for true production caller-zero; delete only when tests/import/export/migration expectations are independently covered.
5. Continue reducing presentation `workspaceStore.database` reach-through only in small/owned hosts with an existing meaningful Store/Service boundary. Do not mass-wrap occurrences.
6. Continue GenericDatabasePage P1 only when a safe extraction removes concrete schema/database action, Property workflow or layout-host responsibility.
7. Revisit `BookmarkStateMutationStore` only when `app_database.dart` can be patched safely without whole-file reconstruction.
8. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
9. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.
10. Treat Issue #414 as separate search correctness work, not behavior-preserving cleanup.
11. Issue #225 checklist is historically stale. Update it only in a dedicated admin pass that preserves concurrent issue edits; do not replace the large body opportunistically from a feature branch.

## Validation expectations
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- caller-zero deletion: current production code search plus independent coverage for any still-live behavior;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- failure-policy work: preserve fail-soft/fail-closed semantics and privacy-safe diagnostics;
- legacy storage deletion: prove production caller-zero and import/export/backup handling first.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small diffs on latest main rather than force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- current connector file writes replace complete files, so do not hand-reconstruct a large shared host for a small hunk;
- local/container git cannot be relied on for GitHub access here, so do not invent maintainability-report numbers that were not actually measured;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- test lifecycle hangs must not be solved by changing production semantics or merely raising global timeouts;
- abstractions that add wrappers without removing responsibility should be rejected.

## Stop / continuation state
Refactor remains actionable. Current safe slice is the latest-main Daily Note caller-zero retirement. After its CI/mergeability settles, continue auditing small compatibility modules for deletion-first reductions while avoiding Object-owned media/deletion paths and canonical Relation redesign.