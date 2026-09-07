# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

### Final Generic Database raw-error privacy cleanup
Branch: `refactor/clean-generic-database-error-privacy-225`

Latest integrated `main` at the start of this slice is **#882 / `7ff4e273eef6ca04939cf27b660ac5bff9c24282`**. #882 retired five caller-zero `BookmarkRepository` forwarding APIs (`renameWorkspace`, `setActiveWorkspace`, `renameTag`, `setTagParent`, `deleteTag`) with **0 additions / 16 deletions** after Flutter CI #2688 passed fully.

The preceding privacy slices are integrated:
- #863 Photo management: allowlist 6 -> 5;
- #867 Bookmark Stage1: 5 -> 4;
- #870 Object Inspector: 4 -> 3;
- #872 AppShell: 3 -> 2;
- #875 Tag management: 2 -> 1.

A fresh audit of current `lib/views/generic_database_page.dart` after #876 Table media and #874 side-peek Body found exactly **11** remaining raw caught-exception presentation surfaces:
- Database identity update;
- Database schema duplicate;
- collection settings save;
- Database delete;
- quick Property creation;
- normal Object creation;
- full Property creation;
- Board card move;
- Board Object creation;
- Relation edit/save;
- side-peek Object delete.

The active slice changes only those catches from `catch (error)` to `catch (_)` and removes `: $error` from the corresponding user messages. Operation behavior, Relation/Object mutation semantics, #874 Body composition, #876 Table media, view state and persistence are unchanged.

Regression coverage:
- `test/generic_database_page_error_privacy_test.dart` locks nine stable operation messages and rejects former raw interpolation;
- `test/generic_database_page_relation_stale_picker_test.dart` keeps the real fail-closed stale-target regression while expecting the stable `Relationを更新できませんでした。` message;
- `tool/feature_presentation_error_privacy_guard_test.sh` is being ratcheted to prove that even the former Generic host is rejected once the allowlist reaches zero.

The guard's `legacy_allowed_hosts` is now intentionally **empty**. After this slice, raw caught-error interpolation is forbidden across canonical feature presentation and legacy `lib/views` / `lib/widgets` presentation.

## Latest integrated Lane G checkpoints
- **#882 / `7ff4e273…` — caller-zero BookmarkRepository wrappers retired.** Five dead Workspace/Tag forwarding APIs removed; CI #2688 full green.
- **#875 / `f2d54ad…` — Tag management raw-error cleanup.** Six failure paths stabilized while duplicate-name domain messages were preserved; allowlist 2 -> 1.
- **#872 / `51420bab…` — AppShell raw-error cleanup.** Database creation, Workspace creation and shared data-operation failures stabilized; allowlist 3 -> 2.
- **#870 / `a18ce533…` — Object Inspector raw-error cleanup.** Ten failure surfaces stabilized; allowlist 4 -> 3.
- **#868 / `c55146f…` — Bookmark Stage1 Database-presentation shim imports retired.** Legacy Database shim imports 5 -> 3.
- **#867 / `4fb55d3…` — Bookmark Stage1 raw-error cleanup.** Allowlist 5 -> 4.
- **#863 / `84350e59…` — Photo management raw-error cleanup.** Allowlist 6 -> 5.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.**
- **#812 / `f357daa6…` — raw-error presentation spread frozen behind the ratcheting guard.**
- **#795 / `ecffd5b2…` — Generic Database Relation-record reload fanout bounded.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**

Re-audit current production callers before every deletion; historical caller-zero conclusions are not permanent assumptions.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current intended baselines with the active Generic privacy slice applied:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. temporary Database-presentation legacy shim imports: **3 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: **forbidden; allowlist size 0**.

Never relax a numeric ceiling or reintroduce an allowlist entry merely to land unrelated work.

## Error-privacy state
#812 originally froze eight legacy raw-error hosts. Focused cleanups now cover all eight:
- `lib/views/image_editor_page.dart`;
- `lib/widgets/bookmark_detail_panel.dart`;
- `lib/views/photo_management_page.dart`;
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/views/object_inspector_page.dart`;
- `lib/views/app_shell.dart`;
- `lib/views/tag_management_page.dart`;
- `lib/views/generic_database_page.dart` (active final slice).

After the active slice merges, this track is complete at **8 -> 0 hosts**. Future work should enforce the zero boundary rather than create more isolated logging/privacy PRs unless a genuinely new defect appears.

## Temporary Database-presentation shim state
Three one-line re-export shim files remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

The only production legacy-shim imports are the three in `GenericDatabasePage`. Repository-wide audits found no other production legacy callers; package-form matches in maintainability fixture code are intentional regression coverage.

After the privacy PR is independent and merged, the next preferred Lane G slice is a separate **3 -> 0 imports / 3 -> 0 shim files** retirement: switch Generic's three imports to canonical feature paths, delete the three one-line shims, ratchet CI ceilings to zero, update inventory/tests, and keep runtime behavior unchanged. Do not combine shim deletion with the privacy PR.

## AppDatabase / caller-zero policy
Major responsibility narrowing already integrated includes migration-helper extraction, Bookmark aggregate/read responsibilities, profile path conversion, Saved View/Photo aggregation, engagement mutations, duplicate Tag hierarchy mutation, dead People helpers, dead lifecycle seams, and caller-zero Bookmark/Weblink presentation/search paths.

#882 reconfirmed that small root-repository forwarding APIs should be deleted only after fresh caller-zero proof. `BookmarkRepository.createTag(...)` remains live in Tag management, Bookmark Stage1 and Bookmark property UI, so do not remove it yet. `BookmarkLifecycleStore.dispose()` remains live despite its empty body because production bootstrap callers exist.

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

Latest ownership check for the active Generic privacy slice:
- #874 (Generic side-peek Body), #876 (Generic Table media), #879 and #882 are merged;
- open Search PR **#883** does not own `GenericDatabasePage`;
- open Primitive PR **#881** owns Bookmark image Relation/detail work, not `GenericDatabasePage`;
- no open PR currently owns Generic runtime code.

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

- #882: Flutter CI #2688 passed maintainability guards, privacy guard, Drift generation, Analyze and full Test before squash merge.
- Active Generic slice: exact base-diff must show production changes only in the 11 audited catch/message pairs; the current whole-file write also needs EOF/newline diff normalization before final one-commit rebuild.
- Final-head CI must pass maintainability guard fixtures, zero-allowlist privacy guard, Drift generation, Analyze and full Test.
- Use retained CI diagnostic logs/artifacts for failures; do not ask the user to paste logs.

## Exact next actions
1. Finish the zero-allowlist guard fixture and privacy policy documentation.
2. Normalize Generic's incidental EOF newline difference so production diff contains only the 11 catch/message pairs.
3. Rebuild `refactor/clean-generic-database-error-privacy-225` as **one commit directly on latest main**, carrying only Generic, guard, guard fixture, privacy doc, focused tests and this handoff.
4. Verify branch is ahead 1 / behind 0 and no open PR has acquired the Generic hotspot.
5. Open a focused Lane G PR, require final-head Flutter CI green, then squash-merge and verify raw-error allowlist is exactly zero.
6. Start a separate Generic Database shim retirement slice: imports **3 -> 0**, shim files **3 -> 0**, CI ceilings -> 0, with focused regression/inventory updates.
7. Continue fresh caller-zero audits only where real production references can be deleted without product-semantic changes.
8. Do not destructively remove Bookmark URL/thumbnail/Photo compatibility storage until caller-zero plus migration/import/export/backup parity is proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; final branch rebuilds must retain intervening main changes. Artificial/no-op CI-trigger commits are forbidden; rerun existing checks when appropriate instead.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
