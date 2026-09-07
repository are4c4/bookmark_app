# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

### Object Inspector raw-error privacy cleanup
Branch: `refactor/clean-object-inspector-error-privacy-225`

Current focused slice starts from main `c55146f700c07b6038051674e5322aa8d07f1e53` (#868) and cleans the remaining raw caught-exception interpolation in `lib/views/object_inspector_page.dart` without changing Object/Relation/Body/File/Weblink behavior.

The audited host contains ten user-visible failure surfaces in this policy category:
- alias add/remove;
- Daily Note navigation;
- shared Body mutation and Body duplication;
- Object reference insertion;
- Database/View reference insertion;
- Object title edit;
- generic Property value edit;
- Weblink promotion.

Each catch now discards the unused exception value and keeps the existing operation-specific failure wording as a stable user-safe message. The dynamic Property name in the Property-edit failure is retained; only raw implementation exception text is removed.

The production diff was reconstructed from the exact current Object Inspector blob and base-diff audited: **20 additions / 20 deletions**, all limited to the ten catch/message pairs. No persistence, mutation ordering, Relation, Body, Daily Note, File, Weblink, or navigation semantics changed.

The slice also:
- removes `lib/views/object_inspector_page.dart` from `legacy_allowed_hosts`, ratcheting the temporary legacy raw-error boundary **4 -> 3 hosts**;
- updates `docs/FEATURE_PRESENTATION_ERROR_PRIVACY.md`;
- adds `test/object_inspector_error_privacy_test.dart`, locking the stable messages and rejecting raw `$error` / `${error...}` presentation in this host.

## Latest integrated Lane G checkpoints
- **#868 / `c55146f700c07b6038051674e5322aa8d07f1e53` — Bookmark Stage1 Database-presentation shim imports retired.** Stage1 moved its final two Database widget imports to canonical feature paths; the accepted legacy-shim import ceiling ratcheted **5 -> 3**. Flutter CI #2637 passed fully before squash merge.
- **#867 / `4fb55d3ad6fb19a5a20063fd8e66f730ae990d40` — Bookmark Stage1 raw-error cleanup.** External URL-drop failure now uses a stable user-safe message; the legacy error-privacy allowlist ratcheted **5 -> 4**. Flutter CI #2634 passed fully before merge.
- **#863 / `84350e59dec76fb7da0096274920ff237f98f98f` — Photo management raw-error cleanup.** Both Photo import failure paths use stable user-safe messages; the allowlist ratcheted **6 -> 5**.
- **#855 / `1b41a9ce…` — Bookmark detail raw-error cleanup.** Bookmark detail save failures no longer expose raw caught exception text.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.** Dead production module/test deleted and feature-presentation direct `AppDatabase` imports ratcheted downward.
- **#812 / `f357daa6…` — legacy raw-error presentation spread frozen.** Existing legacy debt became an explicit ratcheting allowlist while new hosts are forbidden.
- **#795 / `ecffd5b2…` — GenericDatabasePage Relation-record reload fanout bounded to ObjectTypes actually targeted by current Relation Properties.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**

Earlier caller-zero/dependency narrowing remains historical context only; re-audit current production callers before any deletion.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current intended baselines with this active slice applied:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. temporary Database-presentation legacy shim imports: **3 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: temporarily allowlisted in **3 hosts**.

Never relax a numeric ceiling or enlarge an allowlist merely to land unrelated work.

## Error-privacy state
#812 originally froze eight legacy raw-error hosts. Focused cleanup has since retired:
- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart` (#863);
- `lib/views/bookmark_unified_stage1_page.dart` (#867);
- `lib/views/object_inspector_page.dart` (active slice).

After this slice, the remaining temporary hosts are exactly:
- `lib/views/app_shell.dart`;
- `lib/views/generic_database_page.dart`;
- `lib/views/tag_management_page.dart`.

These are not equally patch-sized. `GenericDatabasePage` and `AppShell` are broad composition/product hotspots; `TagManagementPage` has multiple failure workflows. Re-audit all surfaces and current ownership before selecting another cleanup.

## Temporary Database-presentation shim state
Three one-line re-export shim files remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

After #868, the remaining production legacy-shim imports are exactly the three in `GenericDatabasePage`: create tiles, view tabs, and resizable detail pane. Repository-wide audits found no other production legacy callers; the package-form match in maintainability fixture code is intentional regression coverage.

Do not delete these shims while `GenericDatabasePage` still imports them. A complete **3 -> 0 imports / 3 -> 0 shim files** cleanup is technically straightforward once that host is free, but current open Primitive PR #869 owns `GenericDatabasePage`; Lane G must not take that hotspot lease concurrently.

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

At the latest ownership check:
- Primitive PR **#869** owns `GenericDatabasePage` for canonical List-row media presentation; do not edit Generic in Lane G until that lease clears.
- Relation PR **#859** is docs-only and does not overlap Object Inspector.
- no open PR owns `ObjectInspectorPage`, so the active Object Inspector privacy slice is non-overlapping.

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

- #868: full Flutter CI #2637 passed before squash merge.
- Active Object Inspector slice: base diff confirms only the ten catch/message pairs changed in production; final guard, Analyze and full Test must pass before merge.
- Use the retained CI diagnostic artifact/log flow for Flutter Test failures; do not request pasted logs from the user.

## Exact next actions
1. Verify the active branch contains only Object Inspector privacy changes plus guard/doc/test/handoff updates; squash to one coherent commit on latest `main`.
2. Open a focused Lane G PR, require final-head Flutter CI green, then squash-merge and verify the legacy error-privacy allowlist is exactly three hosts.
3. While CI runs, re-audit the remaining three raw-error hosts and caller-zero/dependency candidates that do not overlap open hotspot leases.
4. After #869 clears `GenericDatabasePage`, re-audit its exact current blob and legacy shim callers before attempting the final **3 -> 0** shim-import/shim-file retirement.
5. Prefer a focused `TagManagementPage` or `AppShell` privacy cleanup only if the whole host can leave the allowlist without changing product semantics.
6. Continue caller-zero audits only from current production state; delete code rather than wrapping it when replacement parity and zero callers are proven.
7. Do not redesign Relation, Search, primitive storage/import, Database/View behavior, or Vault lifecycle under #225.
8. Do not destructively remove Bookmark URL/thumbnail/Photo compatibility storage until caller-zero plus migration/import/export/backup parity is proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; branch refreshes must retain intervening main changes. Artificial/no-op CI-trigger commits are forbidden; rerun existing checks when appropriate instead.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
