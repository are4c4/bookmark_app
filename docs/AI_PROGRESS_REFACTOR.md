# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving behavior.

Primary lane: **Refactor**. This lane coordinates with Object and Relation lanes, owns technical-debt reduction rather than product semantics, and must avoid broad edits to files currently owned by active feature PRs.

## Current active branch / PR
- `refactor/issue-225-migration-v13-extraction` — PR #238 `Extract AppDatabase v13 migration step`.

PR #238 is intentionally narrow:
- protected by the v12 -> current migration regression merged in #235;
- moves only the `from < 13` Tag Groups / `tags.group_id` / Bookmark Attachments / PDF Annotations migration body into `migrateToV13(Migrator)`;
- keeps migration sequencing/order and compatibility guards unchanged;
- leaves v2-v12 and v14-v16 behavior untouched;
- final production compare is limited to `app_database.dart` + `app_database_migrations.dart`.

## Completed checkpoints
### P0 guardrails / architecture
Merged through #228:
- `tool/maintainability_report.sh` for non-blocking Dart LOC/largest-file reporting;
- `docs/MAINTAINABILITY.md` with hotspot baseline and no-new-legacy-dependency policy;
- `docs/LEGACY_BOOKMARK_INVENTORY.md` classifying production Bookmark-era consumers;
- `docs/ERROR_POLICY_AUDIT.md` classifying broad catch/fallback behavior;
- `docs/architecture.md` dependency-boundary guidance;
- dedicated Refactor-lane handoff.

The no-new-legacy-dependency rule is now repository policy: new Object/Database/View work should not add new `BookmarkItem` / legacy-table dependencies unless explicitly required for compatibility or migration.

### Failure-policy / observability slices
Merged behavior-preserving changes:
- #227 — PDF author enrichment in `GlobalFileDropLayer`: empty catch replaced with debug/assert visibility while keeping import success non-blocking.
- #229 — profile state / backup metadata fallbacks: retain default/best-effort behavior but expose causes in debug/assert execution.
- #234 — corrupt persisted Database View filters/sorts/settings still fail soft to empty values, but unexpected decode exceptions are visible in debug without logging raw user JSON.
- #237 — remote image dimension decode remains optional/best-effort; decode exceptions are visible in debug while managed import still succeeds with null geometry.

Do not convert intentional fail-soft product behavior into user-visible failure merely to remove broad catches.

### AppDatabase migration safety / extraction
Merged:
- #230 — v13 -> current migration regression around v14 `saved_views` column additions.
- #232 — extracted only v14 migration body into `migrateToV14(Migrator)`.
- #235 — v12 -> current migration regression covering v13 Tag Groups, `tags.group_id`, Bookmark Attachments, PDF Annotations and indexes.
- #236 — v11 -> current workspace migration regression, including compatibility with a pre-existing workspace table lacking newer columns.

Active:
- #238 — v13 migration-body extraction, protected by #235.

Historical versions with row/data transforms (notably v3/v4/v10/v11) remain higher risk and must not be extracted/reworked until dedicated compatibility fixtures protect their semantics.

## Cross-lane coordination
### Object lane
Active Object PRs:
- #221 — managed Weblink Gallery media geometry widget.
- #223 — real `GenericDatabasePage` masonry Gallery integration, stacked on #221.

#223 directly owns `generic_database_page.dart`. Therefore:
- do not start broad `GenericDatabasePage` controller/state/layout extraction yet;
- do not reconstruct that file to make unrelated refactor changes;
- re-check ownership after #221/#223 merge/rebase before beginning P1 hotspot decomposition.

Legacy visual retirement also requires sequencing with Object-first replacements:
- `NotionBookmarkCard` still needs a focused canonical visual migration through the real Stage1 caller;
- reverse lookup still needs canonical visual resolution threaded through Tag/Photo/People management callers;
- Refactor should delete duplicate legacy presentation only after the Object lane has proven the replacement path and tests exist.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature through exposed Weblink/Image host coverage (#222). Refactor must preserve these APIs and must not redesign Relation storage/index semantics.

If a legacy-deletion refactor affects Relation-bearing Objects, use existing Relation-safe deletion APIs and coordinate with Relation only when a concrete lifecycle semantic changes.

## Hotspot ownership / edit policy
Before non-trivial edits, inspect open PRs for:
- `generic_database_page.dart`
- `app_shell.dart`
- `object_inspector_page.dart`
- `bookmark_unified_stage1_page.dart`
- `app_database.dart`

Prefer patch-sized extractions and compare-audited diffs. Do not use whole-file reconstruction merely to change a small responsibility.

## Exact next actions
1. Finish PR #238 validation; merge only if focused migration regression + full Analyze/Test remain green.
2. Continue the **test-before-extraction** pattern for the next historical migration boundary:
   - identify the exact historical schema shape from Git history;
   - add a regression preserving real compatibility data;
   - only then extract the migration body without semantic/style rewrites.
3. Prioritize low-risk structural migration bodies before versions that transform existing rows.
4. Continue error-policy audit with small behavior-preserving slices where broad catches are still genuinely silent and under-covered.
5. Re-run the Bookmark legacy inventory after Object #221/#223 and later #155 work lands; track production references removed and deleted LOC rather than adapters added.
6. Once `generic_database_page.dart` is free of active Object ownership, begin P1 decomposition as small extractions (loader/controller/actions/layout hosts) with focused regressions; do not perform a monolithic rewrite.
7. Keep `docs/AI_PROGRESS.md` updated when hotspot ownership or repository-wide sequencing changes.

## Validation expectations
For migration refactors:
- focused historical migration regression must pass;
- `flutter analyze` and full tests should pass before merge;
- schema version, statement order, defaults and compatibility behavior must remain unchanged.

For failure-policy refactors:
- user-visible/fail-soft behavior must remain unchanged unless a separate product Issue says otherwise;
- debug diagnostics must not log raw user content, image bytes, credentials or secrets.

## Risks / blockers
- broad GenericDatabasePage refactor is currently blocked by active Object PR #223 ownership.
- historical migration semantics are installed-user compatibility contracts; do not rewrite them for style.
- legacy Bookmark storage/UI cannot be deleted before Object-first read/write/presentation parity is proven.
- parallel agents can create stale-base documentation and migration PRs quickly; refresh from latest main before integration rather than force-merging old branch state.
- refactoring that only adds wrappers without deleting duplication or reducing responsibility should be reconsidered.

## Stop reason
This documentation refresh records current state only. Refactor work remains actionable through #238 and subsequent protected migration/error-policy slices. The major `GenericDatabasePage` decomposition remains intentionally deferred until Object PR #223 releases that hotspot.
