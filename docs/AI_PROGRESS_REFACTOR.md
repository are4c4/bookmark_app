# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Read live GitHub state before acting; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-06
Latest `main` observed before this slice: `92b58a9457f5efc7e754bd4b32bfef5b25b748e8` after current Object/Photo handoff convergence.

Recent Refactor convergence:
- **#383 merged** — duplicate legacy Bookmark -> mirrored Object lookup is centralized in `BookmarkObjectLinkReadStore` and reused by Bookmark URL/visual resolvers.
- **#395 merged** — reverse-lookup URL resolver composition delegates to the existing `BookmarkPresentationResolverFactory`, removing one presentation `workspaceStore.database` reach-through.
- **#397 open** — tests-only architecture guard prevents new direct `BookmarkUrlResolver` / `BookmarkVisualResolver` construction in presentation while allowing only the two known legacy hosts to shrink.
- **#400 open (this checkpoint)** — `DatabaseBackupSettingsSection` no longer reaches through `BookmarkRepository` to `workspaceStore.database`; `DatabaseBackupService.fromRepository(...)` owns that composition and the focused boundary regression requires presentation caller-zero for this path.

#400 removes **2 direct `workspaceStore.database` references from 1 presentation file** without changing backup format, restore semantics, dialogs, test injection seams, failure policy, schema, migrations, Relation behavior, or UI behavior.

Current parallel ownership observed before editing:
- Relation #398 owns Bookmark Cover Image Relation lifecycle tests only;
- Object #394 owns destructive legacy Photo managed-file deletion safety;
- Refactor #397 owns the presentation resolver-construction guard test;
- no current open PR owns `database_backup_settings_section.dart` or `database_backup_service.dart`.

## Major completed checkpoints

### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase migration extraction / responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

Only add another abstraction when it removes a real database-root/Widget responsibility or duplicate caller logic. Reject wrapper-only indirection.

### Legacy Bookmark visual / URL presentation retirement
Direct visual duplicates are canonicalized through `BookmarkVisualImage` in Notion card, reverse lookup, lifecycle rows, and Stage1 List/Table. Canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion card, Stage1, and Bookmark List metadata.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain compatibility/import/export/live-host data until production caller-zero and migration policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Do not reconstruct the large host wholesale.

### Failure policy / diagnostic privacy
Merged work covers broad best-effort/fail-closed boundaries, rollback cleanup, attachment/profile/bootstrap flows, Settings operations and malformed compatibility reads.

Policy:
- intentional fail-soft behavior stays fail-soft;
- rollback cleanup never replaces the primary failure;
- user-visible failures use stable retry/domain messages instead of raw implementation strings;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies, and exception text;
- changing `ProfileManager` corrupt-registry fallback selection remains a product/data-safety decision, not routine cleanup.

## Cross-lane coordination

### Object lane
Object owns #56/#155/#245/#249 product/presentation convergence and currently #394 Photo deletion safety. Re-check live PRs before touching Bookmark/generic/media hosts because Object advances quickly.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile remains mature. #398 is focused lifecycle coverage for the new Bookmark Cover Image production Relation. Refactor must not create alternate serialized-id Relation writes, indexes, repair paths, or presentation-side mutation.

## Exact next actions
1. Re-check #397/#400 CI and mergeability against latest `main`; never force-merge a stale branch.
2. If #397 lands, use its shrinking allowlist to migrate `NotionBookmarkCard` to `BookmarkPresentationResolverFactory.urlFor(repository)` when that file is unowned; this should remove another presentation database reach-through without adding abstraction.
3. Re-run production `workspaceStore.database` search / maintainability report after #400; prefer small hosts with an existing composition boundary before touching `app_shell.dart`, Stage1, People, Photo, or GenericDatabasePage.
4. Continue GenericDatabasePage P1 only when a safe patch-sized extraction removes a concrete schema/database action, Property workflow, or layout-host responsibility.
5. Follow Object-first legacy retirement: prove caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
6. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.

## Validation expectations
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- failure-policy work: preserve fail-soft/fail-closed semantics and privacy-safe diagnostics;
- legacy deletion: prove production caller-zero and import/export/backup handling first.

For #400 specifically, the focused source-boundary regression is updated on the branch; full Analyze/Test is expected from Flutter CI before merge.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small intended diffs on latest main instead of force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- test lifecycle hangs must not be solved by changing production semantics or merely raising global timeouts;
- abstractions that add wrappers without removing responsibility should be rejected.

## Stop / continuation state
Refactor remains actionable. #400 is a small measurable dependency-composition slice with CI pending; independent next work should target another existing-boundary presentation reach-through only after live ownership is rechecked. Large shared hotspots remain intentionally untouched in this checkpoint.
