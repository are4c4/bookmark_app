# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

### Tag management raw-error privacy cleanup
Branch: `refactor/clean-tag-management-error-privacy-225`

The preceding AppShell slice passed corrected Flutter CI #2648 and squash-merged as **#872 / `51420bab7818fc3f481b8f98e5ede7ec0f7cc62e`**, ratcheting the legacy raw-error allowlist **3 -> 2 hosts**. Relation #871 then merged as `eaf70d24cbceb2cdd1e9a74a71e220005553bdb7`, followed by Primitive #869 as `36588e0d89e4f95e204d72d7a00194d7c7a2f0ba`. The active Tag slice must be one commit directly on the current main tree before PR creation.

A full `lib/views/tag_management_page.dart` audit found exactly six raw caught-exception presentation surfaces:
- inline tag rename;
- inline tag creation;
- drag/drop tag move;
- Tag Group creation;
- Tag Group rename;
- Tag Group deletion.

The active Tag slice removes raw exception text from all six workflows while preserving useful domain validation:
- tag rename keeps the existing `ArgumentError('同名のタグが存在します')` contract as the stable duplicate-name message and otherwise uses `タグ名を変更できませんでした`;
- Tag Group create/rename catch the existing `TagGroupNameConflictException` explicitly and keep `同じ名前のタググループが既にあります`;
- inline tag creation, drag/drop move, generic Tag Group create/rename failures and Tag Group deletion use operation-specific stable messages without exception interpolation.

The ~1,300-line Tag host was reconstructed from exact source chunks and diff-audited: the production diff is **27 additions / 11 deletions in `TagManagementPage` only**. No Tag hierarchy mutation, move/undo, merge, delete, filtering, selection, keyboard, Relation or persistence semantics changed.

The slice also:
- removes `lib/views/tag_management_page.dart` from `legacy_allowed_hosts`, ratcheting the temporary legacy raw-error boundary **2 -> 1 host**;
- updates `docs/FEATURE_PRESENTATION_ERROR_PRIVACY.md`;
- adds `test/tag_management_error_privacy_test.dart`, locking stable/domain messages and rejecting the former raw `$error` surfaces.

## Latest integrated Lane G checkpoints
- **#872 / `51420bab7818fc3f481b8f98e5ede7ec0f7cc62e` — AppShell raw-error cleanup.** Database creation, Workspace creation and shared data-operation failures now use stable messages; allowlist **3 -> 2**. A stale guard fixture was corrected, then Flutter CI #2648 passed fully before merge.
- **#870 / `a18ce533242e6d60a3e6e11196034e3324ad3c40` — Object Inspector raw-error cleanup.** Ten Object Inspector failure surfaces now use stable messages; allowlist **4 -> 3**. Flutter CI #2641 passed fully before merge.
- **#868 / `c55146f700c07b6038051674e5322aa8d07f1e53` — Bookmark Stage1 Database-presentation shim imports retired.** Stage1 moved its final two Database widget imports to canonical feature paths; accepted legacy-shim import ceiling **5 -> 3**. Flutter CI #2637 passed fully before merge.
- **#867 / `4fb55d3ad6fb19a5a20063fd8e66f730ae990d40` — Bookmark Stage1 raw-error cleanup.** External URL-drop failure uses a stable message; allowlist **5 -> 4**.
- **#863 / `84350e59dec76fb7da0096274920ff237f98f98f` — Photo management raw-error cleanup.** Photo import failures use stable messages; allowlist **6 -> 5**.
- **#855 / `1b41a9ce…` — Bookmark detail raw-error cleanup.** Bookmark detail save failures no longer expose raw caught exception text.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.** Dead production module/test deleted and feature-presentation direct `AppDatabase` imports ratcheted downward.
- **#812 / `f357daa6…` — legacy raw-error presentation spread frozen.** Existing legacy debt became an explicit ratcheting allowlist while new hosts are forbidden.
- **#795 / `ecffd5b2…` — GenericDatabasePage Relation-record reload fanout bounded to ObjectTypes actually targeted by current Relation Properties.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**

Earlier caller-zero/dependency narrowing remains historical context only; re-audit current production callers before any deletion.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current intended baselines with the active Tag slice applied:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. temporary Database-presentation legacy shim imports: **3 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: temporarily allowlisted in **1 host**.

Never relax a numeric ceiling or enlarge an allowlist merely to land unrelated work.

## Error-privacy state
#812 originally froze eight legacy raw-error hosts. Focused cleanup has retired:
- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart` (#863);
- `lib/views/bookmark_unified_stage1_page.dart` (#867);
- `lib/views/object_inspector_page.dart` (#870);
- `lib/views/app_shell.dart` (#872);
- `lib/views/tag_management_page.dart` (active slice).

After the active Tag slice, the only remaining temporary host is:
- `lib/views/generic_database_page.dart`.

Primitive #869 has now merged, so the previous Generic hotspot lease is clear at this checkpoint. Re-check open PR ownership immediately before editing Generic, then audit all current failure surfaces before attempting the final **1 -> 0** privacy cleanup.

## Temporary Database-presentation shim state
Three one-line re-export shim files remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

After #868, the remaining production legacy-shim imports are exactly the three in `GenericDatabasePage`: create tiles, view tabs, and resizable detail pane. Repository-wide audits found no other production legacy callers; package-form matches in maintainability fixture code are intentional regression coverage.

A complete **3 -> 0 imports / 3 -> 0 shim files** cleanup is now unblocked by #869, subject to a fresh ownership check. Keep it separate from the final Generic privacy cleanup so each concern remains reviewable.

## AppDatabase / caller-zero policy
Major responsibility narrowing already integrated includes migration-helper extraction, Bookmark aggregate/read responsibilities, profile path conversion, Saved View/Photo aggregation, engagement mutations, duplicate Tag hierarchy mutation, dead People helpers, dead lifecycle seams, and caller-zero Bookmark/Weblink presentation/search paths.

Remaining small `AppDatabase` APIs have live callers unless a fresh audit proves otherwise. Do not create speculative Store wrappers solely to reduce a metric. Prefer true responsibility movement or deletion after current production caller-zero proof.

`BookmarkLifecycleStore.dispose()` remains live despite its empty body because production bootstrap callers exist. Do not remove it solely for line-count cleanup.

## Shared hotspots / ownership
Always re-check open PR changed files immediately before non-trivial edits to:
- `lib/views/generic_database_page.dart`;
- `lib/views/app_shell.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/widgets/bookmark_reorderable_properties.dart`;
- `lib/views/people_management_page.dart`;
- `lib/views/settings_page.dart`;
- `lib/services/profile_manager.dart`;
- `lib/data/app_database.dart`.

Latest ownership check during this slice:
- Primitive **#869 has merged** as `36588e0d…`; its `GenericDatabasePage` lease is clear.
- Relation **#871 has merged** as `eaf70d24…` and did not touch Tag management or shared UI hotspots.
- open PRs **#873** and **#859** are documentation-only at this checkpoint.
- no open PR owns `TagManagementPage` or `GenericDatabasePage` runtime code at the latest check.

Re-read live state before integration because parallel lanes move quickly.

## Cross-lane boundaries
- Lane A owns Object/ObjectType/Body and Object-owned presentation behavior.
- Lane B owns canonical Relation integrity, backlink/index/audit/reconcile and destructive Relation correctness.
- Lane C owns Database/View/schema/template product UX.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and media/import behavior.
- Lane E owns canonical Object search/indexing.
- Lane F owns Vault/filesystem lifecycle and delivery.
- Lane G may delete or narrow legacy paths only after replacement parity/ownership is established; do not hide product changes inside refactor PRs.

## Validation
Local Flutter/Dart execution is unavailable in this connector environment, so GitHub Flutter CI is the validation gate.

- #872: corrected final Flutter CI #2648 passed maintainability guards, privacy guard, Drift generation, Analyze and full Test before squash merge.
- Active Tag slice: exact-base diff confirms the production host changed only the six audited failure workflows. Final guard, Analyze and full Test must pass on a one-commit branch rebased onto current `main` before merge.
- Use retained CI diagnostic artifacts/logs for Flutter Test failures; do not request pasted logs from the user.

## Exact next actions
1. Rebuild the active Tag slice as one commit on latest `main` (`36588e0d…` at this checkpoint) using only the Tag/guard/doc/test/handoff blobs, then verify `main...branch` is ahead 1 and production diff remains limited to `TagManagementPage` +27/-11.
2. Open a focused Lane G Tag privacy PR, require final-head Flutter CI green, then squash-merge and verify the legacy error-privacy allowlist is exactly **1 host**.
3. While CI runs, audit current `GenericDatabasePage` raw-error surface count without editing the active Tag branch.
4. After the Tag PR is independent, take one Generic concern at a time: final **1 -> 0** privacy cleanup first if safely bounded, then separately the **3 -> 0** shim retirement (or reverse the order if current diff/ownership makes that safer). Do not combine them.
5. Continue caller-zero audits only from current production state; delete code rather than wrapping it when replacement parity and zero callers are proven.
6. Do not redesign Relation, Search, primitive storage/import, Database/View behavior, or Vault lifecycle under #225.
7. Do not destructively remove Bookmark URL/thumbnail/Photo compatibility storage until caller-zero plus migration/import/export/backup parity is proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; branch refreshes must retain intervening main changes. Artificial/no-op CI-trigger commits are forbidden; rerun existing checks when appropriate instead.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
