# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G production checkpoint before this branch: **`190931d76cc00f17fa1d149b3de5a1ea2039fd2f` — #707 Retire People Database presentation shim imports**.

Other recent integrated Lane G checkpoints:
- **`6cb9fa50482e44ed30f6b828bddc44c5a709e3d3` — #705 Retire duplicate AppDatabase tag hierarchy mutation**;
- **`1efdf8d32347dc4755ee82d7fad3570e27539ef7` — #701 Sanitize Database Property add failure message**;
- **`a2d22e89792ea4d46abe030bc56e1c7910c5fe60` — #695 Retire Photo Database presentation shim imports**.

### Active slice — caller-zero Database toolbar shim retirement
The original PR #710 was opened from #707-era main, but parallel lane merges advanced `main` and the PR became non-mergeable. The behavior-preserving change has therefore been recreated from latest main on branch **`refactor/retire-database-toolbar-shim-225-v2`** rather than forcing or reconstructing conflicting history.

Current branch checkpoints:
- `4988734685198f3c282e063a7a0fdc987c24bd7c` — ratchet CI Database-presentation re-export shim ceiling **4 → 3**;
- `80e5be6c4d39c2d7aa325829d5e785306f4d89c2` — delete caller-zero `lib/widgets/database_page_toolbar.dart`.

Caller audit on current main confirms the historical toolbar shim itself has no production import caller. Real hosts found by repository search use the canonical `lib/features/database/presentation/widgets/database_page_toolbar.dart` path; the only direct occurrence of the legacy shim path is the shim file itself plus documentation/guardrail references. The deletion therefore removes one temporary compatibility layer without changing widget implementation or UI behavior.

No `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`, Relation code, primitive storage, Search, or Vault code is touched in this slice.

## Validation state
For merged #695/#701/#705/#707, relevant Flutter CI passed before integration.

For the active toolbar-shim branch, repository-level static caller audit is complete and the CI ceiling has been ratcheted with the deletion. Normal PR CI must pass before merge. Do not merge a moving head without re-checking expected head SHA and mergeability.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. On the active branch the accepted ceilings are:

1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **8 maximum**;
3. temporary Database-presentation legacy shim imports: **5 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum** after the toolbar shim deletion.

Ratchet a ceiling downward only when real debt is removed. Never relax a ceiling merely to land unrelated work.

## Recent Lane G sequence
Important integrated cleanup includes:
- #504 — forbid new `BookmarkItem` / `BookmarkRepository` dependencies under `lib/features/**`;
- #522 — measure presentation/database reach-through in canonical feature presentation;
- #561 — guard direct feature-presentation `AppDatabase` imports;
- #579 — move Bookmark engagement writes out of `AppDatabase`;
- #586 — retire the caller-zero plain-text Object Body mutation chain;
- #637 — remove dead Bookmark People batch/read helpers from `AppDatabase`;
- #642 — remove dead Bookmark lifecycle read remnants;
- #654 — retire the caller-zero Bookmark-only FTS repository after canonical Object Global Search replacement;
- #672 — remove caller-zero `DetailPropertyRow` re-export shim and ratchet shim-file ceiling 5 → 4;
- #687 — move Collection management off four Database-presentation shims and ratchet shim imports 17 → 13;
- #695 — move Photo management off the same four shims and ratchet shim imports 13 → 9;
- #701 — sanitize the canonical Database Property-add user-visible failure boundary with a focused regression;
- #705 — delete duplicate Tag hierarchy mutation/cycle logic from `AppDatabase` and keep `TagGroupStore.moveTag(...)` canonical;
- #707 — move People management off four Database-presentation shims and ratchet shim imports 9 → 5;
- active slice — retire the now-caller-zero Database toolbar shim and ratchet shim-file ceiling 4 → 3.

Key rule: tests dedicated only to a caller-zero implementation do not make that implementation live. Prove production callers are zero and surviving behavior is independently covered before deletion.

## Temporary Database-presentation re-export shims
After the active toolbar deletion, three legacy shim files remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

The remaining legacy shim imports are concentrated in larger/shared hosts. Do not reconstruct a large host merely to reduce a metric. Switch callers only when a naturally patch-sized edit is safe, then delete a shim only after true caller-zero is proven.

## AppDatabase responsibility state
Major completed narrowing includes Bookmark aggregate reads -> `BookmarkReadStore`, profile-relative paths -> `ProfilePathResolver`, Saved View aggregation -> `SavedViewReadStore`, Photo aggregate/path reads -> `PhotoReadStore`, versioned migration helpers, engagement mutations -> `BookmarkEngagementStore`, dead People helpers removed, and duplicate Tag hierarchy mutation removed by #705.

Three audited dead seams remain deferred because applying them requires editing large `bookmark_repository.dart` or a coupled large-host path:
- `AppDatabase.updateBookmarkFields(... personNames ...)` currently has one production caller that always passes `personNames: null`; live Person updates are role-aware elsewhere;
- `BookmarkLifecycleStore.remove()` is an empty method with one production call from permanent deletion;
- `BookmarkRepository.setBookmarkPeopleFromDatabase(...)` has no production caller; the surviving role-aware path is `setPeopleForRole(...)`.

Re-audit before changing any of these. Preserve attachment cleanup/deletion ordering and do not reconstruct the repository host for a one-line metric win.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include `GenericDatabasePageStateLoader` (#310) and `GenericDatabasePageServices.fromWorkspaceStore(...)` (#323).

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows, and layout-specific host code. Continue only as small regression-backed slices coordinated with Database/View ownership.

Before non-trivial edits, inspect open PR ownership for `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, `app_database.dart`, and other active shared hosts.

## Legacy Bookmark / Photo convergence
Legacy Bookmark URL/thumbnail/Photo rows remain compatibility/import/export data. Presentation convergence is not storage-retirement proof. Do not delete persisted compatibility fields until production read/write callers and portability/migration contracts are proven zero/replaced.

`BacklinkRepository` remains live through Bookmark relation presentation. `BookmarkPresentationResolverFactory`, URL/visual resolvers, `BookmarkTransferService`, `DatabaseBackupService`, attachment paths, and canonical Object search remain live and must not be deleted merely because newer infrastructure exists.

## Failure-policy state
#701 closes the small canonical Database Property-add raw-exception boundary.

Raw user-visible exception interpolation remains in larger/shared legacy hosts including `AppShell`, `ObjectInspectorPage`, Tag management, `GenericDatabasePage`, Bookmark detail, Stage1, and legacy Photo import flows. Primitive Image editing has its own product ownership. Do not rewrite a shared hotspot or cross into another lane merely to eliminate one string; take a failure-policy slice only when the file is safely owned and a focused regression can be added without broad churn.

Profile/Vault recovery semantics remain Storage-owned and must not be changed under Refactor merely because a catch is broad.

## Exact next actions
1. Open the refreshed toolbar-shim PR from `refactor/retire-database-toolbar-shim-225-v2`, then verify current-head CI and mergeability; merge only after required checks pass.
2. Close stale #710 after the refreshed PR supersedes it, so the old branch does not remain an ambiguous ownership signal.
3. Re-read current `main` and open PR ownership before every next slice; parallel lanes are merging rapidly.
4. Continue true production caller-zero audits and prefer whole-module/API deletion when independent canonical coverage exists.
5. Re-audit the remaining five Database-presentation shim imports; lower 5 only through naturally safe host edits, not broad complete-file rewrites.
6. Keep the three dead Bookmark API seams above deferred until `bookmark_repository.dart` can be patched safely.
7. Continue `GenericDatabasePage` extraction only with a focused regression-backed slice and an available hotspot lease.
8. Lower presentation/database or feature-presentation `AppDatabase` ceilings only after a real responsibility/boundary move removes references.
9. Take additional raw-error/privacy cleanup only in small independently owned hosts; do not invade active Primitive/Relation/Storage semantics.
10. Do not destructively remove Bookmark URL/thumbnail/Photo storage until caller-zero and portability/migration parity are proven.

## Risks / sequencing
- parallel lanes move `main` quickly;
- connector writes require exact-current-source preservation and diff verification;
- open PR ownership takes precedence over this handoff;
- a falling metric is useful only when real dependency/responsibility disappears;
- behavior-preserving cleanup must not silently become schema, Relation, Search, primitive-storage, or recovery-policy redesign.

## Stop / continuation state
The refreshed toolbar-shim slice is independent and safe: it deletes a one-line caller-zero re-export and tightens the existing guardrail. Continue through PR/CI/integration if possible. If later work is confined to shared hotspots, another lane's active product territory, or large-host edits with no patch-sized safe mechanism, idling is preferable to manufacturing abstraction or broad hotspot churn.
