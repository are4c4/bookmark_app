# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G production checkpoints:
- **`2bde122bd9a3c07e976a476f3ac3ba48e2380554` — #731 Retire dead Bookmark People and lifecycle seams**;
- **`6f27c85577a429c1b1abd5980573cb5105c9863a` — #728 Remove dead Bookmark people update seam**;
- **#707** — move People management off four temporary Database-presentation shim imports and ratchet the legacy-shim-import ceiling to **5**.

Earlier relevant integrated checkpoints include #705 (duplicate AppDatabase Tag hierarchy mutation retired), #701 (Database Property-add raw exception exposure removed), #695 (Photo management shim imports retired), #687 (Collection management shim imports retired), #672 (caller-zero DetailPropertyRow shim retired), #654 (caller-zero Bookmark-only FTS retired), #642/#637 (dead Bookmark/AppDatabase seams removed), #586 (plain-text Object Body mutation chain retired), and #579 (engagement writes moved out of AppDatabase).

### #728 — unreachable Bookmark People update seam
- removed the unused `personNames` parameter from `AppDatabase.updateBookmarkFields(...)`;
- removed the unreachable conditional `setBookmarkPeople(...)` branch;
- removed the Repository caller's always-null named argument;
- live Person edits remain on the role-aware `setPeopleForRole(..., '出演者', ...)` path;
- final diff was 2 files, 3 deletions, 0 additions;
- full Flutter CI passed before squash merge.

### #731 — dead Repository/Lifecycle seams
- removed caller-zero `BookmarkRepository.setBookmarkPeopleFromDatabase(...)`;
- removed empty `BookmarkLifecycleStore.remove(...)` and its sole no-op permanent-delete call;
- attachment cleanup still runs before `_database.deleteBookmark(...)`;
- `data_integrity_test.dart` independently verifies managed attachment bytes, attachment rows, and the Bookmark row are removed;
- final diff was 2 files, 5 deletions, 0 additions;
- full Flutter CI passed before squash merge.

### Active slice — caller-zero Database toolbar shim retirement
Branch: `refactor/retire-database-toolbar-shim-225-v4`, recreated from current main `2bde122bd9a3c07e976a476f3ac3ba48e2380554` because earlier #710/#719/#723 branches accumulated stale handoff/history while parallel lanes moved main.

Completed on the active branch:
- `f13729b203584f3de3f77cc0a895487df08e4072` — ratchet `.github/workflows/flutter_ci.yml` Database-presentation re-export shim ceiling **4 → 3**;
- `9069e8e576a16225d0ff235adbe0f3149ef8cbfa` — delete caller-zero `lib/widgets/database_page_toolbar.dart`.

Repository-wide exact import search found no legacy import of `../widgets/database_page_toolbar.dart` or the package equivalent. Real hosts already use `lib/features/database/presentation/widgets/database_page_toolbar.dart`. This slice changes no widget implementation or UI behavior.

No `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, Relation code, primitive storage, Search, or Vault behavior is changed by this slice.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. On the active v4 branch:

1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **8 maximum**;
3. temporary Database-presentation legacy shim imports: **5 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**.

Ratchet downward only when real debt is removed; never relax a ceiling merely to land unrelated work.

## Remaining temporary Database-presentation shims
After the active branch, three re-export shims remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

The remaining five production shim imports are concentrated in two large/shared hosts:
- `GenericDatabasePage`: 3 imports (`database_create_tiles`, `database_view_tabs`, `resizable_detail_pane`);
- `BookmarkUnifiedStage1Page`: 2 imports (`database_create_tiles`, `database_view_tabs`).

Do not reconstruct either large host merely to lower a metric. Switch callers only through a naturally patch-sized safe edit, then delete a shim only after production caller-zero is proven.

## AppDatabase / Bookmark responsibility state
Major narrowing already integrated includes Bookmark aggregate reads, profile path conversion, Saved View aggregation, Photo aggregation/path reads, versioned migration helpers, engagement mutations, dead People helpers, dead lifecycle remnants, duplicate Tag hierarchy mutation, the unreachable `updateBookmarkFields.personNames` branch (#728), the caller-zero Repository People wrapper (#731), and the empty lifecycle remove seam (#731).

The three Bookmark seams previously listed as deferred are therefore closed. Re-audit current production callers before identifying any next deletion candidate; do not assume historical caller-zero status remains valid.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include `GenericDatabasePageStateLoader` (#310) and `GenericDatabasePageServices.fromWorkspaceStore(...)` (#323).

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows, and layout-specific host code. Continue only as small regression-backed slices coordinated with Database/View ownership.

Before non-trivial edits, inspect open PR ownership for `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, `app_database.dart`, and other active shared hosts.

## Legacy Bookmark / Photo convergence
Legacy Bookmark URL/thumbnail/Photo rows remain compatibility/import/export data. Presentation convergence is not storage-retirement proof. Do not remove persisted compatibility fields until production read/write callers and portability/migration contracts are proven zero/replaced.

`BacklinkRepository`, Bookmark presentation resolvers, transfer/backup services, attachment paths, and canonical Object search remain live unless independently proven otherwise.

## Failure-policy state
#701 removed one canonical Database Property-add raw-exception boundary. Raw user-visible exception interpolation remains in larger/shared legacy hosts and some other-lane product surfaces. Take failure-policy cleanup only in safely owned, regression-testable slices; do not cross into Primitive/Relation/Storage semantics merely to remove one string. Vault recovery semantics remain Storage-owned.

## Validation / CI
Merged Lane G checkpoints are integrated only after relevant Flutter CI passes. For the active v4 toolbar-shim branch, static caller audit and exact-current-main reconstruction are complete; normal PR CI is still required before merge.

Always verify current head SHA, mergeability, changed files, and CI before integration. Expected-head SHA checks are preferred for merge.

## Exact next actions
1. Verify the active v4 diff is only the toolbar shim deletion, CI file-ceiling ratchet, and this handoff.
2. Open the v4 PR and mark #723 superseded; do not merge stale #710/#719/#723 branches.
3. Merge v4 only if current-head CI is green and latest main has no overlapping change.
4. While CI runs, continue caller-zero/dependency-boundary audits that do not touch leased hotspots.
5. Re-audit the remaining five shim imports and three remaining shim files; lower ceilings only through real debt removal.
6. Continue `GenericDatabasePage` extraction only with regression coverage and ownership clearance.
7. Lower presentation/database or feature-presentation `AppDatabase` ceilings only after a real responsibility/boundary move removes references.
8. Take additional raw-error/privacy cleanup only in small independently owned hosts.
9. Do not redesign Relation semantics, canonical Object search, primitive storage, or Vault lifecycle under Refactor.
10. Do not destructively remove Bookmark URL/thumbnail/Photo storage before proven caller-zero and portability/migration parity.

## Risks / stop condition
Parallel lanes move `main` quickly. Complete-file connector writes require exact-current-source preservation and base-diff verification. Open PR ownership always overrides this handoff. If all remaining candidates are confined to actively leased hotspots, another lane's product territory, or broad high-risk edits, idling is preferable to manufacturing abstraction or broad churn.
