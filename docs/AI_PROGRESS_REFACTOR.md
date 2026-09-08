# AI Progress — Refactor & Architecture Health lane

> Durable Lane G handoff. GitHub is the source of truth: always re-read `AGENTS.md`, Issue #225, latest `main`, open PR ownership, this file, and current CI before editing shared code.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Own behavior-preserving extraction/deletion, caller-zero retirement, failure/privacy policy cleanup, measurable dependency reduction, maintainability guardrails, and incremental legacy convergence. Do not redesign Relation semantics, primitive identity/storage behavior, Search semantics, Database/View product behavior, or Vault recovery policy from this lane.

## Active checkpoint — 2026-09-08

The latest integrated caller-zero chain is complete:
- **#899 / `c6157b3a…` — final Database-presentation shims retired.** Legacy Database-presentation imports reached **0** and re-export shim files reached **0**; CI ceilings now enforce 0/0.
- **#903 / `48e945fd…` — caller-zero Bookmark Photo forwarding APIs retired.** Six legacy Bookmark -> Photo mutation forwarding methods were deleted from `BookmarkRepository`; production diff was 9 deleted lines only and final CI #2748 was full green.
- **#915 / `545e07e1…` — lower-level AppDatabase Photo mutation helpers retired.** Five superseded `BookmarkPhotos` mutation helpers were removed from `AppDatabase`; the only test-only caller was converted to direct legacy-row fixture setup. Production diff was **0 additions / 42 deletions**.

Follow-up audit on current main confirms:
- legacy Photo CRUD/read UI is still live through `PhotoManagementPage`; do not delete Photo CRUD/schema yet;
- `bookmark_photos` remains required as compatibility storage/read data;
- production writes to `bookmark_photos` are now confined to `BookmarkImageRelationService`, which derives the legacy projection from canonical Bookmark `Images` / `Cover Image` Relations. There is no remaining second Bookmark-Photo mutation authority in `BookmarkRepository` or `AppDatabase`;
- open Primitive #921 owns the Stage1 image-drop migration and is expected to remove one remaining `BookmarkRepository.addPhoto(...)` caller, but `PhotoManagementPage` remains live even after that slice.

## Latest integrated Lane G checkpoints
- **#915 / `545e07e1…` — AppDatabase legacy Bookmark/Photo mutation helpers removed.** Five methods, 42 production LOC deleted.
- **#903 / `48e945fd…` — BookmarkRepository legacy Photo mutation forwarders removed.** Six methods, 9 production LOC deleted; CI #2748 full green.
- **#899 / `c6157b3a…` — final Database-presentation shims removed.** Legacy imports/files 0/0.
- **#886 / `4469a549…` — Generic Database raw-error privacy cleanup.** Raw-error allowlist completed at **8 -> 0 hosts**; CI #2720 full green.
- **#882 / `7ff4e273…` — caller-zero Workspace/Tag BookmarkRepository wrappers retired.** Five dead forwarding APIs removed; CI #2688 full green.
- **#875 / `f2d54ad…` — Tag management raw-error cleanup.** Six failure paths stabilized; allowlist 2 -> 1.
- **#872 / `51420bab…` — AppShell raw-error cleanup.** Allowlist 3 -> 2.
- **#870 / `a18ce533…` — Object Inspector raw-error cleanup.** Allowlist 4 -> 3.
- **#868 / `c55146f…` — Stage1 Database-presentation shim imports retired.** Legacy shim imports 5 -> 3.
- **#867 / `4fb55d3…` — Stage1 raw-error cleanup.** Allowlist 5 -> 4.
- **#863 / `84350e59…` — Photo management raw-error cleanup.** Allowlist 6 -> 5.
- **#829 / `6fffec0d…` — caller-zero Weblink detail preview retired.**
- **#812 / `f357daa6…` — raw-error presentation spread frozen behind CI guardrails.**
- **#795 / `ecffd5b2…` — Generic Database Relation-record reload fanout bounded.**
- **#735 / `60d6ac5a…` — caller-zero Database toolbar re-export shim retired.**

Re-audit current production callers before every deletion. Historical caller-zero conclusions are not permanent assumptions.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` and live guard scripts are authoritative.

Current key baselines:
1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **4 maximum**;
3. Database-presentation legacy shim imports: **0 maximum**;
4. Database-presentation re-export shim files: **0 maximum**;
5. canonical feature-presentation caught-error interpolation: **forbidden**;
6. legacy presentation caught-error interpolation: **forbidden; allowlist size 0**.

Never relax a numeric ceiling, recreate a compatibility shim under a new filename, or add an error-privacy allowlist entry merely to land unrelated work.

## Completed consolidation tracks

### Error privacy
#812 froze eight legacy raw-error hosts. #886 completed cleanup at **8 -> 0 hosts**. Future work should enforce the zero boundary; do not create new privacy exceptions unless a concrete defect requires a focused fix.

### Database-presentation shims
#868 moved Stage1 off the compatibility imports and #899 removed the final Generic imports plus the last three re-export files. Current state is **0 legacy shim imports / 0 shim files**. Historical shim names remain in scanners/tests to reject reintroduction.

### Bookmark Photo mutation authority
#903 removed six BookmarkRepository forwarding methods after canonical Image Relation writes reached parity. #915 removed the corresponding five lower-level AppDatabase helpers. `bookmark_photos` is still compatibility data, but its production mutation is now owned by `BookmarkImageRelationService` as a projection of canonical Image Relations. Do not remove the table/read paths until Photo UI/read/import/export/migration parity is explicitly proven.

## AppDatabase / caller-zero policy
Major narrowing already integrated includes migration-helper extraction, Bookmark aggregate/read responsibilities, profile path conversion, Saved View/Photo aggregation, engagement mutations, duplicate Tag hierarchy mutation, dead People helpers, caller-zero Bookmark/Weblink paths, and now legacy Bookmark/Photo mutation helpers.

Continue narrowing only where a real responsibility disappears. Prefer deletion over pass-through wrappers added solely to improve a metric.

Known live examples that must not be mechanically deleted:
- `BookmarkRepository.createTag(...)` remains live;
- `BookmarkLifecycleStore.dispose()` remains a live lifecycle contract despite its empty body;
- Photo CRUD (`addPhoto`, `updatePhoto`, `deletePhoto`) remains live through `PhotoManagementPage` and safety/integrity tests;
- `PhotoStorageService.activePhotoDirectoryPath` remains used by bootstrap/storage fallbacks and Image managed-file deletion safety.

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

Latest ownership check on current main `2ef65ae4…`:
- #919 Daily Note identity protection is merged; its Object-core lease is released;
- open Lane D #921 owns `bookmark_unified_stage1_page.dart` and the Stage1 image-drop migration; do not edit Stage1 until that lease clears;
- open Lane F #917 is docs-only;
- no open PR currently owns `app_database.dart` or `GenericDatabasePage` at this checkpoint.

Parallel lanes move quickly; re-check immediately before every final branch rebuild/merge.

## Cross-lane boundaries
- Lane A owns Object/ObjectType/Body and Object-owned presentation behavior.
- Lane B owns canonical Relation integrity, backlink/index/audit/reconcile and destructive Relation correctness.
- Lane C owns Database/View/schema/template product UX.
- Lane D owns Weblink/Image/File/Tag primitive product semantics and media/import behavior.
- Lane E owns canonical Object search/indexing.
- Lane F owns Vault/filesystem lifecycle and delivery.
- Lane G may delete or narrow legacy paths only after replacement parity/ownership is established; do not hide product changes inside refactor PRs.

## Validation
Local Flutter/Dart execution is unavailable in this connector environment, so GitHub Flutter CI is the merge gate for runtime changes.

Recent validated checkpoints:
- #899 final head: full Flutter CI green before merge; shim ceilings 0/0 passed.
- #903 final head: Flutter CI #2748 passed maintainability/privacy guards, Drift generation, Analyze and full Test.
- #915 merged after focused source/read-store regression coverage; production AppDatabase diff remained pure deletion.

Use retained CI diagnostics for failures; do not ask the user to paste logs.

## Exact next actions
1. Keep auditing true caller-zero modules/forwarding methods after every Primitive/Object migration merge; delete only with fresh production reference proof.
2. Let #921 finish Stage1 image-drop migration, then re-audit `BookmarkRepository.addPhoto(...)`; do not remove it while `PhotoManagementPage` remains a live production caller.
3. Resume incremental `GenericDatabasePage` P1 work only when a patch-sized responsibility extraction is demonstrably smaller than the host and no Database/View lane owns the same hotspot. Prioritize schema/database actions or Property workflow extraction over cosmetic wrapper layers.
4. Continue dependency-composition cleanup only when it reduces actual presentation/database reach-through; avoid adapters created solely for tests/metrics.
5. Continue `AppDatabase` narrowing only where responsibility truly disappears; do not delete Photo schema/read compatibility while #245 migration still needs it.
6. Keep `bookmark_photos` as projection/read compatibility until Photo UI/read/import/export/backup/migration caller parity is explicitly proven.

## Risks / stop conditions
Parallel lanes move `main` frequently. Whole-file connector writes require exact-current-source preservation plus base-diff verification; final branch rebuilds must retain intervening main changes. Artificial/no-op CI-trigger commits are forbidden.

Stop only when the active Lane G work has no independent safe next slice, a genuine external/product blocker remains, an unavoidable hotspot conflict blocks the next step, validation is externally blocked with no independent work left, or the runtime/tool limit is reached. Pending CI by itself is not a stop reason.
