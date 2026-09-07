# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

### AppShell raw-error privacy cleanup
Branch: `refactor/clean-app-shell-error-privacy-225`

This slice was prepared on top of the Object Inspector privacy head while #870 CI ran. #870 subsequently passed full Flutter CI #2641 and squash-merged to `main` as `a18ce533242e6d60a3e6e11196034e3324ad3c40`. Before opening the AppShell PR, rebuild the branch as one commit on the latest main tree so no stacked Object Inspector diff or intervening cross-lane main changes remain.

A full `lib/views/app_shell.dart` audit found exactly three raw caught-exception user-visible surfaces:
- generic Database creation;
- Workspace creation;
- shared data action failure for Bookmark import/export and Vault backup/restore operations.

Each catch now discards the unused exception value and keeps an operation-specific stable message:
- `データベースを作成できませんでした。`;
- `Workspaceを作成できませんでした。`;
- `データ操作に失敗しました。`.

The AppShell host was reconstructed from the exact stacked-base blob and diff-audited against the Object Inspector head: the production diff is **6 additions / 6 deletions in AppShell only**, corresponding to the three catch/message pairs. No Database creation, Workspace, import/export, Vault backup/restore, routing, or navigation semantics changed.

The slice also:
- removes `lib/views/app_shell.dart` from `legacy_allowed_hosts`, ratcheting the legacy raw-error boundary **3 -> 2 hosts**;
- updates `docs/FEATURE_PRESENTATION_ERROR_PRIVACY.md`;
- adds `test/app_shell_error_privacy_test.dart`, locking all three stable messages and rejecting raw `$error` / `${error...}` presentation.

## Latest integrated Lane G checkpoints
- **#870 / `a18ce533242e6d60a3e6e11196034e3324ad3c40` — Object Inspector raw-error cleanup.** Ten Object Inspector failure surfaces now use stable messages; the legacy error-privacy allowlist ratcheted **4 -> 3**. Full Flutter CI #2641 passed before squash merge.
- **#868 / `c55146f700c07b6038051674e5322aa8d07f1e53` — Bookmark Stage1 Database-presentation shim imports retired.** Stage1 moved its final two Database widget imports to canonical feature paths; the accepted legacy-shim import ceiling ratcheted **5 -> 3**. Flutter CI #2637 passed fully before squash merge.
- **#867 / `4fb55d3ad6fb19a5a20063fd8e66f730ae990d40` — Bookmark Stage1 raw-error cleanup.** External URL-drop failure uses a stable message; the legacy error-privacy allowlist ratcheted **5 -> 4**. Flutter CI #2634 passed fully before merge.
- **#863 / `84350e59dec76fb7da0096274920ff237f98f98f` — Photo management raw-error cleanup.** Photo import failures use stable messages; the allowlist ratcheted **6 -> 5**.
- **#855 / `1b41a9ce…` — Bookmark detail raw-error cleanup.** Bookmark detail save failures no longer expose raw caught exception text.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.** Dead production module/test deleted and feature-presentation direct `AppDatabase` imports ratcheted downward.
- **#812 / `f357daa6…` — legacy raw-error presentation spread frozen.** Existing legacy debt became an explicit ratcheting allowlist while new hosts are forbidden.
- **#795 / `ecffd5b2…` — GenericDatabasePage Relation-record reload fanout bounded to ObjectTypes actually targeted by current Relation Properties.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**

Earlier caller-zero/dependency narrowing remains historical context only; re-audit current production callers before any deletion.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current intended baselines with the active AppShell slice applied:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. temporary Database-presentation legacy shim imports: **3 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: temporarily allowlisted in **2 hosts**.

Never relax a numeric ceiling or enlarge an allowlist merely to land unrelated work.

## Error-privacy state
#812 originally froze eight legacy raw-error hosts. Focused cleanup has since retired:
- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart` (#863);
- `lib/views/bookmark_unified_stage1_page.dart` (#867);
- `lib/views/object_inspector_page.dart` (#870);
- `lib/views/app_shell.dart` (active slice).

After the AppShell slice, the remaining temporary hosts are exactly:
- `lib/views/generic_database_page.dart`;
- `lib/views/tag_management_page.dart`.

`TagManagementPage` has multiple inline rename/create/move/group failure workflows and is a larger privacy slice. `GenericDatabasePage` has many failure surfaces and is also a high-conflict shared host. Do not partially clean either host if it cannot leave the allowlist in the same coherent change.

## Temporary Database-presentation shim state
Three one-line re-export shim files remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

After #868, the remaining production legacy-shim imports are exactly the three in `GenericDatabasePage`: create tiles, view tabs, and resizable detail pane. Repository-wide audits found no other production legacy callers; package-form matches in maintainability fixture code are intentional regression coverage.

A complete **3 -> 0 imports / 3 -> 0 shim files** cleanup remains a high-confidence next Lane G slice once `GenericDatabasePage` is free. Primitive PR #869 owned that host at the latest audit; always re-check live PR ownership before touching it.

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

Latest known ownership during this run:
- Primitive PR **#869** owns `GenericDatabasePage` for canonical List-row media presentation.
- Relation PR **#859** is docs-only.
- no open PR owned `AppShell` during the AppShell audit/implementation.

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

- #870: full Flutter CI #2641 passed before squash merge.
- Active AppShell slice: base-diff audit against the stacked Object Inspector head confirms production changes are only the three catch/message pairs. Final guard, Analyze and full Test must pass on the final one-commit branch before merge.
- Use the retained CI diagnostic artifact/log flow for Flutter Test failures; do not request pasted logs from the user.

## Exact next actions
1. Read latest `main` and open PR ownership after #870 merge.
2. Rebuild the AppShell slice as one commit using the latest-main tree as the base and only the AppShell/guard/doc/test/handoff blobs from this branch; verify `main...branch` is ahead 1 and contains no stacked Object Inspector diff.
3. Open a focused Lane G AppShell privacy PR, require final-head Flutter CI green, then squash-merge and verify the allowlist is exactly two hosts.
4. While CI runs, re-audit `TagManagementPage` fully and current caller-zero candidates away from active hotspot leases.
5. After #869 clears `GenericDatabasePage`, re-audit its latest exact blob before either the final shim retirement or a separately scoped privacy cleanup. Do not combine those two concerns.
6. Continue caller-zero audits only from current production state; delete code rather than wrapping it when replacement parity and zero callers are proven.
7. Do not redesign Relation, Search, primitive storage/import, Database/View behavior, or Vault lifecycle under #225.
8. Do not destructively remove Bookmark URL/thumbnail/Photo compatibility storage until caller-zero plus migration/import/export/backup parity is proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; branch refreshes must retain intervening main changes. Artificial/no-op CI-trigger commits are forbidden; rerun existing checks when appropriate instead.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
