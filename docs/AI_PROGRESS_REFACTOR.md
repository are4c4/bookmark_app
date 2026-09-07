# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G production checkpoint: **`190931d76cc00f17fa1d149b3de5a1ea2039fd2f` — #707 Retire People Database presentation shim imports**.

Recent integrated sequence:
- #695 `a2d22e89792ea4d46abe030bc56e1c7910c5fe60` — Photo management moved off four temporary Database-presentation shims; import ceiling **13 → 9**.
- #701 `1efdf8d32347dc4755ee82d7fad3570e27539ef7` — Database Property-add raw exception text removed from the user-visible failure boundary with focused privacy regression coverage.
- #705 `6cb9fa50482e44ed30f6b828bddc44c5a709e3d3` — duplicate Tag hierarchy mutation/cycle logic removed from `AppDatabase`; `TagGroupStore.moveTag(...)` remains canonical.
- #706 `05eb665b1af9d303fbad1cc6778a9d85c245eb00` — durable Refactor handoff refresh.
- #707 `190931d76cc00f17fa1d149b3de5a1ea2039fd2f` — People management moved off four temporary Database-presentation shims; import ceiling **9 → 5**.

All production Refactor PRs above passed maintainability guardrails, Drift generation, `flutter analyze`, and full `flutter test` on their merge heads.

## Current work in progress
Branch **`refactor/retire-database-toolbar-shim-225`** starts from #707 main.

After #707, `lib/widgets/database_page_toolbar.dart` became true production caller-zero: Collection, Photo, People, Stage1 and tests already import the canonical `lib/features/database/presentation/widgets/database_page_toolbar.dart`, while GenericDatabasePage does not import the toolbar shim. The current branch therefore:
- deletes the one-line `lib/widgets/database_page_toolbar.dart` re-export;
- ratchets the CI legacy shim-file ceiling **4 → 3**;
- updates maintainability documentation;
- leaves the historical toolbar shim name guarded by the existing scanner so reintroduction remains detectable.

No UI behavior, Database/View semantics, Relation behavior, schema, primitive behavior, Search behavior, or Storage behavior changes.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. On the current toolbar-shim-retirement branch the intended ceilings are:

1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **8 maximum**;
3. temporary Database-presentation legacy shim imports: **5 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**.

Ratchet a ceiling downward only when real debt is removed. Never relax one merely to land unrelated work.

## Temporary Database-presentation shims
After the current branch, three re-export shim files remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

The five remaining production shim imports are concentrated in two shared hotspots:
- `GenericDatabasePage`: `database_create_tiles`, `database_view_tabs`, `resizable_detail_pane` — **3**;
- `BookmarkUnifiedStage1Page`: `database_create_tiles`, `database_view_tabs` — **2**.

Do not reconstruct either large host merely to lower the metric. Switch them only through naturally safe, patch-sized work with live ownership checks.

## AppDatabase / Bookmark cleanup state
Major completed narrowing includes Bookmark aggregate reads -> `BookmarkReadStore`, profile paths -> `ProfilePathResolver`, Saved View aggregation -> `SavedViewReadStore`, Photo reads -> `PhotoReadStore`, historical migration helpers, engagement writes -> `BookmarkEngagementStore`, dead People helpers removed, and duplicate Tag hierarchy mutation removed by #705.

Three audited dead seams remain deferred because applying them requires editing large `bookmark_repository.dart` or a coupled large-host path:
- `AppDatabase.updateBookmarkFields(... personNames ...)` has one production caller that always passes `null`; live Person updates use role-aware `setPeopleForRole(...)`;
- `BookmarkLifecycleStore.remove()` is an empty method with one production call from permanent deletion;
- `BookmarkRepository.setBookmarkPeopleFromDatabase(...)` has no production caller; `setPeopleForRole(...)` is the surviving role-aware path.

Re-audit before changing any of these. Preserve attachment cleanup/deletion ordering and do not reconstruct the large repository host for a one-line metric win.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include `GenericDatabasePageStateLoader` (#310) and `GenericDatabasePageServices.fromWorkspaceStore(...)` (#323).

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows, and layout-specific host code. Continue only as small regression-backed slices coordinated with Database/View ownership.

Before non-trivial edits, inspect open PR ownership for `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, `app_database.dart`, and other AGENTS-listed hotspots.

## Failure-policy state
#701 closes the canonical Database Property-add raw-exception boundary. Raw user-visible exception interpolation still exists in larger/shared legacy hosts including AppShell, ObjectInspectorPage, Tag management, GenericDatabasePage, Bookmark detail, Stage1 and Photo import. ImageEditor is active Primitive/Image territory. Take another failure-policy slice only when the host is safely owned and a focused regression can be added without broad churn.

Profile/Vault recovery semantics remain Storage-owned and must not be changed under Refactor merely because a catch is broad.

## Exact next actions
1. Validate the current caller-zero toolbar-shim deletion branch with maintainability guards, Drift, Analyze and full Test; merge only when current main remains non-overlapping and head is unchanged.
2. Re-read current main/open PR ownership after integration; parallel lanes move rapidly.
3. Keep the remaining five shim imports deferred unless GenericDatabasePage or Stage1 can be changed safely as part of naturally scoped work.
4. Continue true production caller-zero audits; prefer whole-module/API deletion over wrapper creation.
5. Keep the three dead Bookmark API seams deferred until `bookmark_repository.dart` can be patched safely.
6. Continue GenericDatabasePage responsibility extraction only with focused regression coverage and an available hotspot lease.
7. Do not touch Relation semantics, canonical Object search semantics, primitive storage semantics, or Vault lifecycle under Refactor.
8. Do not destructively remove Bookmark URL/thumbnail/Photo storage until production caller-zero and portability/migration parity are proven.

## Stop / continuation state
#695, #701, #705, #706 and #707 are integrated. The current independent safe slice is the now-caller-zero `database_page_toolbar.dart` shim deletion. After it lands, the remaining shim debt is confined to GenericDatabasePage and Stage1 shared hotspots; if no other independent caller-zero/dependency-narrowing slice exists, idling is preferable to manufacturing abstractions or broad hotspot churn.
