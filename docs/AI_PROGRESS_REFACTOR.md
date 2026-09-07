# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

### Stage1 Database-presentation shim retirement
Branch: `refactor/retire-bookmark-stage1-database-shim-imports-225`

Current focused slice:
- starts from merged #867 / `4fb55d3ad6fb19a5a20063fd8e66f730ae990d40`;
- changes only the two `BookmarkUnifiedStage1Page` imports for `database_create_tiles.dart` and `database_view_tabs.dart` from legacy `lib/widgets/...` re-export paths to the existing canonical `lib/features/database/presentation/widgets/...` paths;
- preserves the exact widget implementations and all Bookmark/View behavior;
- ratchets the legacy Database-presentation shim-import ceiling **5 -> 3** in Flutter CI;
- updates `docs/MAINTAINABILITY.md` and adds a focused source regression locking the canonical Stage1 imports;
- leaves all three re-export shim files in place because `GenericDatabasePage` still has the remaining three production imports.

The 56 KB Stage1 host was reconstructed from the exact merged blob and base-diff audited immediately after the write: **2 additions / 2 deletions only**, corresponding exactly to the two import-path replacements. No other Stage1 code changed.

## Latest integrated Lane G checkpoints
- **#867 / `4fb55d3ad6fb19a5a20063fd8e66f730ae990d40` — Bookmark Stage1 raw-error cleanup.** External URL-drop failure now uses a stable user-safe message; the legacy error-privacy allowlist ratcheted **5 -> 4**. Final Flutter CI #2634 passed maintainability guards, dependency/privacy guards, Drift generation, Analyze, and full Test before squash merge.
- **#863 / `84350e59dec76fb7da0096274920ff237f98f98f` — Photo management raw-error cleanup.** Both Photo import failure paths use stable user-safe messages; the legacy error-privacy allowlist ratcheted **6 -> 5**.
- **#855 / `1b41a9ce…` — Bookmark detail raw-error cleanup.** Bookmark detail save failures no longer expose raw caught exception text.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.** Dead production module/test deleted and feature-presentation direct `AppDatabase` imports ratcheted downward.
- **#812 / `f357daa6…` — legacy raw-error presentation spread frozen.** Existing legacy debt became an explicit ratcheting allowlist while new hosts are forbidden.
- **#795 / `ecffd5b2…` — GenericDatabasePage relation-record reload fanout bounded to actually targeted ObjectTypes.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**
- **#707 — People management moved off four temporary Database-presentation shim imports, lowering that import ceiling to 5.**

Earlier caller-zero/dependency narrowing remains valid only as historical context; re-audit current callers before any new deletion.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

With the active Stage1 shim slice applied, intended baselines are:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. temporary Database-presentation legacy shim imports: **3 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: temporarily allowlisted in **4 hosts** after #867.

Never relax a numeric ceiling or enlarge an allowlist merely to land unrelated work.

## Error-privacy state
#812 originally froze eight legacy raw-error hosts. Focused cleanup has since retired:
- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart` (#863);
- `lib/views/bookmark_unified_stage1_page.dart` (#867).

The remaining temporary hosts are:
- `lib/views/app_shell.dart`;
- `lib/views/generic_database_page.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/tag_management_page.dart`.

Do not assume they are equally patch-sized. `TagManagementPage` has multiple raw-error surfaces, and `AppShell` / `GenericDatabasePage` are broad shared hotspots. Re-audit count, typed/domain error requirements, tests, and current PR ownership before choosing another host.

## Temporary Database-presentation shim state
Three re-export shim files remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

After the active Stage1 import switch, the remaining production legacy-shim imports are exactly the three in `GenericDatabasePage`:
- `database_create_tiles`;
- `database_view_tabs`;
- `resizable_detail_pane`.

Do not reconstruct `GenericDatabasePage` merely to remove them. Re-audit current Database/View ownership and edit them only through a naturally patch-sized safe slice. Delete a shim only after repository-wide production caller-zero is proven.

## AppDatabase / caller-zero policy
Major responsibility narrowing already integrated includes migration-helper extraction, Bookmark aggregate/read responsibilities, profile path conversion, Saved View/Photo aggregation, engagement mutations, duplicate Tag hierarchy mutation, dead People helpers, dead lifecycle seams, and caller-zero Bookmark/Weblink presentation/search paths.

Remaining small `AppDatabase` APIs have live callers unless a fresh audit proves otherwise. Do not create speculative Store wrappers solely to reduce a metric. Prefer true responsibility movement or deletion after current production caller-zero proof.

`BookmarkLifecycleStore.dispose()` remains live despite its empty body because production bootstrap callers exist. Do not remove it solely for line-count cleanup.

## Shared hotspots / ownership
Always re-check open PR changed files immediately before a non-trivial edit to:
- `lib/views/generic_database_page.dart`;
- `lib/views/app_shell.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/widgets/bookmark_reorderable_properties.dart`;
- `lib/views/people_management_page.dart`;
- `lib/views/settings_page.dart`;
- `lib/services/profile_manager.dart`;
- `lib/data/app_database.dart`.

At the active-slice ownership check, the only other open PR was Relation docs-only #859; no parallel PR owned Stage1, Flutter CI, or maintainability documentation. Re-audit live state before any follow-up because parallel lanes move quickly.

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

- #867: final Flutter CI #2634 passed maintainability guards, feature dependency/privacy guards, Drift generation, Analyze, and full Test before merge.
- Active Stage1 shim slice: base-diff audit confirms the production host changed only two import paths. Final branch CI must pass before merge.
- Use the retained CI diagnostic artifact/log flow for any Flutter Test failure; do not request pasted logs from the user.

## Exact next actions
1. Squash the active Stage1 shim branch to one coherent commit on latest `main`, verify diff contains only the two Stage1 import replacements plus CI/docs/test/handoff updates, and open a focused Lane G PR.
2. Require final-head Flutter CI green, then squash-merge and verify the accepted shim-import ceiling is **3**.
3. Re-audit `GenericDatabasePage` ownership before considering its remaining three shim imports; do not edit that hotspot merely to lower a metric.
4. Re-audit the remaining four raw-error hosts. Prefer a genuinely focused workflow; avoid broad `AppShell` / `GenericDatabasePage` churn.
5. Continue caller-zero audits only from current production state. Delete code rather than wrapping it when replacement parity and zero callers are proven.
6. Do not redesign Relation, Search, primitive storage/import, Database/View behavior, or Vault lifecycle under #225.
7. Do not destructively remove Bookmark URL/thumbnail/Photo compatibility storage until caller-zero plus migration/import/export/backup parity is proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; branch refreshes must retain intervening main changes. The repository explicitly forbids artificial/no-op CI-trigger commits, so rerun existing checks when appropriate and use only meaningful code/test/docs changes.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
