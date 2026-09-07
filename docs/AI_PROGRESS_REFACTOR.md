# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G checkpoint before the active branch is #707, which moved People management off four temporary Database-presentation shim imports and ratcheted the legacy-shim-import ceiling to **5**. Earlier relevant integrated checkpoints include #705 (duplicate AppDatabase Tag hierarchy mutation retired), #701 (Database Property-add raw exception exposure removed), #695 (Photo management shim imports retired), #687 (Collection management shim imports retired), #672 (caller-zero DetailPropertyRow shim retired), #654 (caller-zero Bookmark-only FTS retired), #642/#637 (dead Bookmark/AppDatabase seams removed), and #579 (engagement writes moved out of AppDatabase).

### Active slice — caller-zero Database toolbar shim retirement
Branch: `refactor/retire-database-toolbar-shim-225-v3`, recreated from current main `ae07efe41f8cff98eb9499fd7fef586f81f14756` because #719 again became stale/non-mergeable after parallel lane merges.

Completed on the active branch:
- `2dbc52065ae622b6feb7ceafb5543f40e52da906` — ratchet `.github/workflows/flutter_ci.yml` Database-presentation re-export shim ceiling **4 → 3**;
- `40d9fdbd1ff2869a92ea992aae885b2175af4d53` — delete caller-zero `lib/widgets/database_page_toolbar.dart`.

Current-main repository search confirms the historical toolbar shim itself has no production import caller. Real hosts use the canonical `lib/features/database/presentation/widgets/database_page_toolbar.dart` path. The deletion changes no widget implementation or UI behavior.

No `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`, Relation code, primitive storage, Search, or Vault code is touched in this slice.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. On the active branch:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **8 maximum**;
3. temporary Database-presentation legacy shim imports: **5 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum** after the toolbar shim deletion.

Ratchet downward only when real debt is removed; never relax a ceiling for unrelated work.

## Remaining temporary Database-presentation shims
After this branch, three re-export shims remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

Remaining legacy shim imports are concentrated in larger/shared hosts. Do not reconstruct a large hotspot merely to lower a metric. Switch callers only through naturally patch-sized safe edits, then delete a shim only after production caller-zero is proven.

## AppDatabase / Bookmark responsibility state
Major narrowing already integrated includes Bookmark aggregate reads, profile path conversion, Saved View aggregation, Photo aggregation/path reads, historical migration bodies, engagement mutations, dead People helpers, dead lifecycle remnants, and duplicate Tag hierarchy mutation.

Known deferred seams that must be re-audited before touching:
- `AppDatabase.updateBookmarkFields(... personNames ...)` has a live caller that currently passes `personNames: null`;
- `BookmarkLifecycleStore.remove()` is empty but still has a permanent-delete caller;
- `BookmarkRepository.setBookmarkPeopleFromDatabase(...)` appears production caller-zero but lives in the large `bookmark_repository.dart` host.

Preserve attachment cleanup/deletion ordering; do not rebuild a large repository host for a one-line metric win.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include `GenericDatabasePageStateLoader` (#310) and `GenericDatabasePageServices.fromWorkspaceStore(...)` (#323). Remaining high-value responsibilities include schema/database actions, Property workflows, and layout-specific host code. Continue only with focused regression-backed slices and an available hotspot lease.

Before non-trivial edits, inspect open PR ownership for `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, `app_database.dart`, and other active shared hosts.

## Legacy Bookmark / Photo convergence
Legacy Bookmark URL/thumbnail/Photo rows remain compatibility/import/export data. Presentation convergence is not storage-retirement proof. Do not remove persisted compatibility fields until production read/write callers and portability/migration contracts are proven zero/replaced. `BacklinkRepository`, Bookmark presentation resolvers, transfer/backup services, attachment paths, and canonical Object search remain live unless independently proven otherwise.

## Failure-policy state
#701 removed one canonical Database Property-add raw-exception boundary. Raw user-visible exception interpolation remains in larger/shared legacy hosts and some other-lane product surfaces. Take failure-policy cleanup only in safely owned, regression-testable slices; do not cross into Primitive/Relation/Storage semantics merely to remove one string. Vault recovery semantics remain Storage-owned.

## Validation / CI
Merged Lane G checkpoints were integrated only after relevant Flutter CI passed. For the active v3 toolbar-shim branch, static caller audit is complete; normal PR CI is still required before merge. Always verify current head SHA, mergeability, changed files, and CI before integration.

## Exact next actions
1. Open a fresh PR from `refactor/retire-database-toolbar-shim-225-v3` to `main` and mark #719 superseded by it.
2. Verify changed files are only the shim deletion, CI ceiling ratchet, and this handoff.
3. Wait for required CI; merge only if current head remains unchanged, mergeable, and green.
4. While CI runs, continue caller-zero/dependency-boundary audits that do not touch leased hotspots.
5. Re-audit the remaining five shim imports and three remaining shim files; lower ceilings only through real debt removal.
6. Keep large Bookmark dead seams deferred until a naturally safe patch opportunity exists.
7. Continue GenericDatabasePage extraction only with regression coverage and ownership clearance.
8. Do not redesign Relation semantics, Object search, primitive storage, or Vault lifecycle under Refactor.
9. Do not destructively remove Bookmark URL/thumbnail/Photo storage before proven parity.

## Risks / stop condition
Parallel lanes move `main` quickly. Open PR ownership always overrides this handoff. If all remaining candidates are confined to actively leased hotspots, another lane's product territory, or large-host edits with no safe patch-sized mechanism, idling is preferable to manufacturing abstraction or broad churn.
