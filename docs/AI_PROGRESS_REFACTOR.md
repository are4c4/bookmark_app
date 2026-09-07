# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G production checkpoint: **`1efdf8d32347dc4755ee82d7fad3570e27539ef7` — #701 Sanitize Database Property add failure message**.

Immediately preceding Lane G checkpoint: **`a2d22e89792ea4d46abe030bc56e1c7910c5fe60` — #695 Retire Photo Database presentation shim imports**.

This run completed two independent behavior-preserving slices:

### #695 — Photo Database-presentation shim cleanup
- `PhotoManagementPage` now imports `DatabaseActionCard` / `DatabaseActionRow`, `DatabasePageToolbar`, `DatabaseViewTabs`, and `ResizableDetailPane` directly from `lib/features/database/presentation/widgets/`;
- Photo rendering, search, saved View behavior, import/edit/delete flows, Bookmark attachment behavior, and detail-pane behavior are unchanged;
- the CI legacy-shim-import ceiling is ratcheted **13 → 9**;
- maintainability and legacy inventory docs were updated in the same PR;
- the production host diff remained four import substitutions only after current-main refresh.

### #701 — Database Property-add failure policy
- `DatabasePropertyAddPopoverHost` no longer interpolates raw caught exception text into its SnackBar;
- a focused widget regression forces a deliberately sensitive exception payload and proves it is not rendered;
- the user-visible contract is a stable retry message;
- debug-only diagnostics use a fixed operation label plus stack trace, without exception text, paths, Property names, or persisted values;
- Property persistence still goes through the existing `DatabasePropertyAuthoringService`; Relation schema/cardinality semantics are unchanged.

Parallel main changes #685 and #702 landed between these Refactor merges. Their changed files were non-overlapping with #701, so #701 was merged only after GitHub recomputed it as mergeable and its full CI was green.

## Validation completed
For **#695** current-head Flutter CI passed:
- Maintainability guardrail tests;
- Maintainability regression ceilings;
- feature legacy dependency guard;
- Drift generation;
- `flutter analyze`;
- full `flutter test`.

For **#701** current-head Flutter CI passed the same full sequence, including the new Property-add failure regression.

Both merges used expected-head SHA checks so a moving branch could not be integrated accidentally.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. Current accepted ceilings after #695 are:

1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **8 maximum**;
3. temporary Database-presentation legacy shim imports: **9 maximum**;
4. temporary Database-presentation re-export shim files: **4 maximum**.

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
- #701 — sanitize the canonical Database Property-add user-visible failure boundary with a focused regression.

Key rule: tests dedicated only to a caller-zero implementation do not make that implementation live. Prove production callers are zero and surviving behavior is independently covered before deletion.

## Temporary Database-presentation re-export shims
Four legacy shim files still exist:
- `lib/widgets/database_page_toolbar.dart`;
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

After #687 and #695, the remaining real shim callers are concentrated in larger/shared hosts such as People management, `GenericDatabasePage`, and Stage1. Do **not** reconstruct those files merely to reduce the metric. Switch callers only when a naturally patch-sized edit is already safe, then delete a shim only after true caller-zero is proven.

## AppDatabase responsibility state
Major completed narrowing includes Bookmark aggregate reads -> `BookmarkReadStore`, profile-relative paths -> `ProfilePathResolver`, Saved View aggregation -> `SavedViewReadStore`, Photo aggregate/path reads -> `PhotoReadStore`, versioned migration helpers, engagement mutations -> `BookmarkEngagementStore`, and dead People helpers removed.

Two audited dead seams remain deferred because applying them requires editing large `bookmark_repository.dart`:
- `AppDatabase.updateBookmarkFields(... personNames ...)` currently has one production caller that passes `personNames: null`; live Person updates are role-aware elsewhere;
- `BookmarkLifecycleStore.remove()` is an empty method with one production call from permanent deletion.

Re-audit before changing either. Preserve attachment cleanup/deletion ordering and do not reconstruct the repository host for a one-line metric win.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include `GenericDatabasePageStateLoader` (#310) and `GenericDatabasePageServices.fromWorkspaceStore(...)` (#323).

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows, and layout-specific host code. Continue only as small regression-backed slices coordinated with Database/View ownership.

Before non-trivial edits, inspect open PR ownership for `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, `app_database.dart`, and other active shared hosts.

## Legacy Bookmark / Photo convergence
Legacy Bookmark URL/thumbnail/Photo rows remain compatibility/import/export data. Presentation convergence is not storage-retirement proof. Do not delete persisted compatibility fields until production read/write callers and portability/migration contracts are proven zero/replaced.

`BacklinkRepository` remains live through Bookmark relation presentation. `BookmarkPresentationResolverFactory`, URL/visual resolvers, `BookmarkTransferService`, `DatabaseBackupService`, attachment paths, and canonical Object search remain live and must not be deleted merely because newer infrastructure exists.

## Failure-policy state
#701 closes the small canonical Database Property-add raw-exception boundary.

A current search still finds raw user-visible exception interpolation in larger/shared legacy hosts including `AppShell`, `ObjectInspectorPage`, Tag management, `GenericDatabasePage`, Bookmark detail, and Stage1. `ImageEditorPage` also has raw edit/restore exception interpolation, but it belongs to active Primitive/Image product territory. Do **not** rewrite a shared hotspot or cross into Primitive semantics just to eliminate one string; take a failure-policy slice only when the file is safely owned and a focused regression can be added without broad churn.

`PhotoManagementPage` still contains legacy raw exception interpolation in import failure Toasts. #695 intentionally kept that behavior out of the import-only shim cleanup.

Profile/Vault recovery semantics remain Storage-owned and must not be changed under Refactor merely because a catch is broad.

## Current-source non-candidates / audit result
The latest caller-zero sweep did not find another safe small production deletion. Candidate services/resolvers inspected still have real production callers, including Gallery cover compatibility/target resolution, Object search refresh planning, Image edit infrastructure, Database View management/group adapters, Generic Object View coordination, remote image storage, and the four remaining Database-presentation shims.

Do not create wrappers or speculative abstractions merely because no deletion candidate is currently available.

## Exact next actions
1. Re-read current `main` and open PR ownership before every next slice; parallel lanes are merging rapidly.
2. Continue true production caller-zero audits and prefer whole-module/API deletion when independent canonical coverage exists.
3. Re-audit the remaining nine Database-presentation shim imports; lower 9 only through naturally safe host edits, not broad rewrites.
4. Keep the two dead Bookmark API seams deferred until `bookmark_repository.dart` can be patched safely.
5. Continue `GenericDatabasePage` extraction only with a focused regression-backed slice and an available hotspot lease.
6. Lower presentation/database or feature-presentation `AppDatabase` ceilings only after a real responsibility/boundary move removes references.
7. Take additional raw-error/privacy cleanup only in small independently owned hosts; do not invade active Primitive/Relation/Storage semantics.
8. Do not touch Relation semantics, canonical Object search semantics, primitive storage semantics, or Vault lifecycle under Refactor.
9. Do not destructively remove Bookmark URL/thumbnail/Photo storage until caller-zero and portability/migration parity are proven.

## Risks / sequencing
- parallel lanes move `main` quickly;
- complete-file connector writes require exact-current-source preservation and diff verification;
- open PR ownership takes precedence over this handoff;
- a falling metric is useful only when real dependency/responsibility disappears;
- behavior-preserving cleanup must not silently become schema, Relation, Search, primitive-storage, or recovery-policy redesign.

## Stop / continuation state
#695 and #701 are integrated and fully validated. The next obvious legacy-shim and raw-error candidates are currently concentrated in shared hotspots or another lane's active product territory. Continue with a fresh ownership/caller-zero audit on the next run; if no independent safe slice exists, idling is preferable to manufacturing abstraction or broad hotspot churn.
