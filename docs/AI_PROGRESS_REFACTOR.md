# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

### Retire the final Database-presentation compatibility shims
Branch: `refactor/retire-database-presentation-shims-225`

Latest integrated Lane G checkpoint is **#886 / `4469a5496a18b7fd5a81be17f41fb30298042cb6`**, which completed the legacy raw-error privacy track. Flutter CI #2720 passed maintainability guards, zero-allowlist privacy guard, Drift generation, Analyze and full Test on the final head before squash merge.

The active shim-retirement slice is behavior-preserving:
- `GenericDatabasePage` moves its final three legacy imports (`database_create_tiles`, `database_view_tabs`, `resizable_detail_pane`) directly to `lib/features/database/presentation/widgets/`;
- the three one-line `lib/widgets/` re-export shims are deleted after a fresh repository-wide caller audit found no other production legacy imports;
- Flutter CI ceilings ratchet legacy shim imports **3 -> 0** and shim files **3 -> 0**;
- `tool/maintainability_report_test.sh` proves a zero-import/zero-shim fixture passes while existing failure cases still fail;
- `test/generic_database_page_database_shim_import_test.dart` locks the canonical imports and rejects the three old Generic import paths;
- `docs/MAINTAINABILITY.md` records the completed shim retirement.

The Generic host was reconstructed through the connector from current source chunks. The intended runtime change is import-only; a diff audit found the import migration plus two non-semantic source-format artifacts (Backlinks `TextStyle` closing formatting and EOF newline state). Do not add any product behavior to this slice. If a safer exact patch mechanism becomes available, normalize those incidental formatting differences before merge; otherwise require full CI green and keep them explicitly classified as non-semantic.

## Latest integrated Lane G checkpoints
- **#886 / `4469a549…` — Generic Database raw-error privacy cleanup.** Final legacy host stabilized; raw-error allowlist **1 -> 0**. CI #2720 full green.
- **#882 / `7ff4e273…` — caller-zero BookmarkRepository wrappers retired.** Five dead Workspace/Tag forwarding APIs removed; CI #2688 full green.
- **#875 / `f2d54ad…` — Tag management raw-error cleanup.** Six failure paths stabilized while duplicate-name domain messages were preserved; allowlist **2 -> 1**.
- **#872 / `51420bab…` — AppShell raw-error cleanup.** Stable user-safe failure messages; allowlist **3 -> 2**.
- **#870 / `a18ce533…` — Object Inspector raw-error cleanup.** Ten failure surfaces stabilized; allowlist **4 -> 3**.
- **#868 / `c55146f…` — Bookmark Stage1 Database-presentation shim imports retired.** Legacy shim imports **5 -> 3**.
- **#867 / `4fb55d3…` — Bookmark Stage1 raw-error cleanup.** Allowlist **5 -> 4**.
- **#863 / `84350e59…` — Photo management raw-error cleanup.** Allowlist **6 -> 5**.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.**
- **#812 / `f357daa6…` — raw-error presentation spread frozen behind the ratcheting guard.**
- **#795 / `ecffd5b2…` — Generic Database Relation-record reload fanout bounded.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**

Re-audit current production callers before every deletion; historical caller-zero conclusions are not permanent assumptions.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Intended baselines with the active shim slice applied:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. Database-presentation legacy shim imports: **0 maximum**;
4. Database-presentation re-export shim files: **0 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: **forbidden; allowlist size 0**.

Never relax a numeric ceiling, recreate a compatibility shim under a new filename, or reintroduce an error-privacy allowlist entry merely to land unrelated work.

## Error-privacy state — complete
#812 originally froze eight legacy raw-error hosts. Focused cleanup retired all eight from the allowlist:
- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart`;
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/app_shell.dart`;
- `lib/views/tag_management_page.dart`;
- `lib/views/generic_database_page.dart`.

#886 completed the track at **8 -> 0 hosts**. Future work should enforce the zero boundary rather than create more isolated privacy cleanup PRs unless a genuinely new defect appears.

## Database-presentation shim state
Before the active slice, the final three one-line re-export shims were:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

A fresh default-branch code audit found the only production legacy imports in `GenericDatabasePage`. Stage1 had already moved its final two imports in #868. The active slice therefore moves Generic directly to canonical feature imports and deletes all three shims. After merge the intended state is **0 legacy shim imports / 0 Database-presentation re-export shim files**. Historical shim names remain in the scanner so reintroduction is detected.

## AppDatabase / caller-zero policy
Major responsibility narrowing already integrated includes migration-helper extraction, Bookmark aggregate/read responsibilities, profile path conversion, Saved View/Photo aggregation, engagement mutations, duplicate Tag hierarchy mutation, dead People helpers, dead lifecycle seams, and caller-zero Bookmark/Weblink presentation/search paths.

#882 reconfirmed that small root-repository forwarding APIs should be deleted only after fresh caller-zero proof. `BookmarkRepository.createTag(...)` remains live. `BookmarkLifecycleStore.dispose()` remains a live bootstrap/lifecycle contract despite its empty body because production callers exist.

Prefer true responsibility removal or deletion over pass-through wrappers added solely to improve a metric.

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

Latest ownership check after #886 merge:
- open Primitive **#892** touches Bookmark creation/Image Relation code, not Generic;
- open docs-only **#893** does not own runtime hotspots;
- open Search **#894** touches `ObjectInspectorPage` and Search files, not Generic;
- no current open PR owns `GenericDatabasePage` runtime code at this checkpoint.

Parallel lanes move quickly; re-check immediately before final branch rebuild/merge.

## Cross-lane boundaries
- Lane A owns Object/ObjectType/Body and Object-owned presentation behavior.
- Lane B owns canonical Relation integrity, backlink/index/audit/reconcile and destructive Relation correctness.
- Lane C owns Database/View/schema/template product UX.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and media/import behavior.
- Lane E owns canonical Object search/indexing.
- Lane F owns Vault/filesystem lifecycle and delivery.
- Lane G may delete or narrow legacy paths only after replacement parity/ownership is established; do not hide product changes inside refactor PRs.

## Validation
Local Flutter/Dart execution is unavailable in this connector environment, so GitHub Flutter CI is the merge gate.

- #886: final Flutter CI #2720 passed all guardrails, Drift generation, Analyze and full Test before merge.
- Active shim slice: verify final comparison is one commit directly on latest `main`; runtime change must remain limited to Generic import routing plus explicitly classified non-semantic formatting if it cannot be safely normalized.
- Final-head CI must pass maintainability report fixture at shim ceilings 0/0, legacy dependency/privacy guards, Drift generation, Analyze and full Test.
- Use retained CI diagnostic logs/artifacts for failures; do not ask the user to paste logs.

## Exact next actions
1. Finish the shim branch documentation/test state and rebuild it as **one commit directly on latest main**, carrying only shim-retirement files.
2. Verify repository-wide production legacy-shim imports are zero and the three `lib/widgets` re-export files are absent.
3. Verify branch is ahead 1 / behind 0 and no open PR has acquired Generic ownership.
4. Open a focused Lane G PR, require final-head Flutter CI green, then squash-merge.
5. After merge, update Issue #225 checkpoint and re-audit caller-zero modules / presentation-database reach-through for the next independent behavior-preserving slice.
6. Do not destructively remove Bookmark URL/thumbnail/Photo compatibility storage until caller-zero plus migration/import/export/backup parity is proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; final branch rebuilds must retain intervening main changes. Artificial/no-op CI-trigger commits are forbidden; rerun existing checks when appropriate instead.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
