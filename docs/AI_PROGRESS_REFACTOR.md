# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

### PR #867 — remove Bookmark Stage1 raw exception exposure
Branch: `refactor/clean-bookmark-stage1-error-privacy-225`

The current focused slice:
- audits `BookmarkUnifiedStage1Page` and confirms its only raw caught-exception interpolation is the external URL-drop failure path;
- changes that path from rendering `$error` to stable `URLを追加できませんでした。` presentation;
- discards the unused caught value rather than converting implementation exception text to UI;
- removes `lib/views/bookmark_unified_stage1_page.dart` from `legacy_allowed_hosts`, ratcheting the temporary legacy error-privacy boundary **5 -> 4 hosts**;
- updates `docs/FEATURE_PRESENTATION_ERROR_PRIVACY.md` and adds `test/bookmark_stage1_error_privacy_test.dart`;
- preserves Bookmark persistence, metadata, Relation, drag/drop routing, media, and View semantics.

The large Stage1 host was reconstructed from the exact current blob and base-diff audited. The production change is limited to the one catch/message pair; no broad Stage1 refactor is included.

At the handoff update point, #867 head `0a88634120a8a98e6d8a12a47a2f603349084fa4` was rebased onto main `2a2a6889af487d124dc6d07e951d0ed8b86e6ec9`. Flutter CI #2631 had passed maintainability guards, feature dependency/privacy guards, Drift generation, and Analyze; the full Test step was still running when this meaningful handoff update superseded that head. Always read the live PR head/run before integration.

## Latest integrated Lane G checkpoints
- **#863 / `84350e59dec76fb7da0096274920ff237f98f98f` — Photo management raw-error cleanup.** Both Photo import failure paths now use stable user-safe messages; the legacy error-privacy allowlist ratcheted **6 -> 5**. CI #2607 and the latest-main refresh CI #2617 both passed before merge.
- **#855 / `1b41a9ce…` — Bookmark detail raw-error cleanup.** Bookmark detail save failures no longer expose raw caught exception text and the allowlist ratcheted smaller.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.** Dead production module/test deleted and canonical feature-presentation direct `AppDatabase` imports ratcheted downward.
- **#823 / `7d4d3077…` — Lane G reload/privacy handoff refresh.**
- **#812 / `f357daa6…` — legacy raw-error presentation spread frozen.** Existing legacy debt became an explicit ratcheting allowlist while new hosts are forbidden.
- **#795 / `ecffd5b2…` — GenericDatabasePage relation-record reload fanout bounded to actually targeted ObjectTypes.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**
- **#707 — People management moved off four temporary Database-presentation shim imports, lowering that import ceiling to 5.**

Earlier caller-zero/dependency narrowing remains valid only as historical context; re-audit current callers before any new deletion.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current `main` baselines before #867 integration:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. temporary Database-presentation legacy shim imports: **5 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: temporarily allowlisted in **5 hosts on main** after #863.

#867 proposes the error-privacy host count **5 -> 4**. Never relax a numeric ceiling or enlarge an allowlist merely to land unrelated work.

## Error-privacy state
#812 originally froze eight legacy raw-error hosts. Focused cleanup has since retired:
- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart` (#863);
- `lib/views/bookmark_unified_stage1_page.dart` (#867 in flight).

After #867, the remaining temporary hosts should be exactly:
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

The current five production legacy-shim imports are concentrated in:
- `GenericDatabasePage`: **3** (`database_create_tiles`, `database_view_tabs`, `resizable_detail_pane`);
- `BookmarkUnifiedStage1Page`: **2** (`database_create_tiles`, `database_view_tabs`).

A fresh audit during #867 confirmed the Stage1 pair can be switched directly to the existing canonical `lib/features/database/presentation/widgets/...` imports as an independent patch-sized behavior-preserving slice. After #867 merges and ownership is rechecked, this is the highest-confidence next Lane G candidate: move the two Stage1 imports, lower the CI/import baseline **5 -> 3**, update maintainability documentation, and **do not delete either shim** because `GenericDatabasePage` still consumes them.

Do not reconstruct `GenericDatabasePage` merely to remove its remaining three imports. Delete a shim only after repository-wide production caller-zero is proven.

## AppDatabase / caller-zero policy
Major responsibility narrowing already integrated includes migration-helper extraction, Bookmark aggregate/read responsibilities, profile path conversion, Saved View/Photo aggregation, engagement mutations, duplicate Tag hierarchy mutation, dead People helpers, dead lifecycle seams, and caller-zero Bookmark/Weblink presentation/search paths.

A post-#829 audit found remaining small `AppDatabase` APIs still have live callers. Do not create speculative Store wrappers solely to reduce a metric. Prefer true responsibility movement or deletion after fresh production caller-zero proof.

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

At the #867 handoff update, open cross-lane PR #866 changes only `generic_database_image_import_service.dart` plus its focused test, and #859 is Relation docs-only; neither owns Stage1. #867 itself owns only the Stage1 error-message hunk. Re-audit live state before the next slice because parallel lanes move quickly.

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

- #863: full Flutter CI #2607 passed; refreshed latest-main run #2617 also passed before merge.
- #867: CI #2631 on pre-handoff head passed maintainability guards, dependency/privacy guards, Drift generation, and Analyze; full Test was running when this handoff documentation update was made. Read the new final-head CI rather than relying on that superseded partial run.
- Use the retained CI diagnostic artifact/log flow from #760 for any Flutter Test failure; do not request pasted logs from the user.

## Exact next actions
1. Read live #867 head, latest `main`, open PR ownership, and final-head Flutter CI.
2. If #867 is green and non-overlapping, squash-merge it and verify the merged error-privacy allowlist is four hosts.
3. Start a separate Lane G PR to move Stage1 `database_create_tiles` and `database_view_tabs` imports to canonical feature paths, then ratchet the legacy-shim import ceiling **5 -> 3** in CI/docs. Keep the re-export shim files while `GenericDatabasePage` still calls them.
4. Re-audit the remaining four raw-error hosts after that slice; prefer a genuinely focused host/error workflow and avoid broad hotspot churn.
5. Continue caller-zero audits only from current production state. Delete code rather than wrapping it when replacement parity and zero callers are proven.
6. Do not redesign Relation, Search, primitive storage/import, Database/View behavior, or Vault lifecycle under #225.
7. Do not destructively remove Bookmark URL/thumbnail/Photo compatibility storage until caller-zero plus migration/import/export/backup parity is proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; branch refreshes must retain intervening main changes. The repository now explicitly forbids artificial/no-op CI-trigger commits, so rerun existing checks when appropriate and use only meaningful code/test/docs changes.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
