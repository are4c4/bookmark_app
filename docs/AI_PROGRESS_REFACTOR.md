# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G checkpoints:
- **`241803aa4d8fc6e0bdc779b9112d68d6831568db` — #745 Guard canonical feature presentation error privacy**;
- **`60d6ac5ac4834488ca20168c39149c323deb8f64` — #735 Retire caller-zero Database toolbar shim from current main**;
- **`2bde122bd9a3c07e976a476f3ac3ba48e2380554` — #731 Retire dead Bookmark People and lifecycle seams**;
- **`6f27c85577a429c1b1abd5980573cb5105c9863a` — #728 Remove dead Bookmark people update seam**;
- **#707** — move People management off four temporary Database-presentation shim imports and ratchet the legacy-shim-import ceiling to **5**.

Earlier relevant integrated checkpoints include #705 (duplicate AppDatabase Tag hierarchy mutation retired), #701 (Database Property-add raw exception exposure removed), #695 (Photo management shim imports retired), #687 (Collection management shim imports retired), #672 (caller-zero DetailPropertyRow shim retired), #654 (caller-zero Bookmark-only FTS retired), #642/#637 (dead Bookmark/AppDatabase seams removed), #586 (plain-text Object Body mutation chain retired), and #579 (engagement writes moved out of AppDatabase).

### #728 / #731 — dead Bookmark seams removed
- removed the unused `personNames` parameter/branch from `AppDatabase.updateBookmarkFields(...)` and its always-null Repository argument;
- removed caller-zero `BookmarkRepository.setBookmarkPeopleFromDatabase(...)`;
- removed empty `BookmarkLifecycleStore.remove(...)` and its sole no-op permanent-delete call;
- live Person edits remain role-aware through `setPeopleForRole(...)`;
- attachment cleanup still runs before real Bookmark deletion;
- both PRs passed full Flutter CI before merge.

### #735 — Database toolbar shim reached caller-zero
- removed `lib/widgets/database_page_toolbar.dart` after exact production import audit found zero legacy callers;
- canonical toolbar imports remain under `lib/features/database/presentation/widgets/database_page_toolbar.dart`;
- ratcheted Database-presentation re-export shim-file ceiling **4 → 3**;
- no widget implementation or UI behavior changed;
- full Flutter CI passed before merge.

### #745 — canonical feature-presentation error privacy guard
- added `tool/feature_presentation_error_privacy_guard.sh` and isolated fixture coverage;
- CI now rejects direct interpolation of a caught exception variable inside `lib/features/**/presentation/` catch bodies;
- safe typed forwarding such as `onError(error)`, stable mapped messages, raw strings, and escaped dollar literals remain allowed;
- legacy `lib/views/` / `lib/widgets/` are intentionally outside this new-regression boundary so existing debt does not block unrelated work;
- current repository scan, maintainability guardrails, Drift generation, Analyze and full Test all passed before merge.

### #736 — rejected cleanup candidate
A proposed removal of empty `BookmarkLifecycleStore.dispose()` was **not merged**. CI exposed eight production callers in `lib/main.dart` that a narrow caller search had missed. The method body is empty, but it is still part of the live bootstrap/lifecycle contract. Do not remove it merely for line-count cleanup; revisit only during a naturally scoped bootstrap/lifecycle refactor with fresh ownership checks.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth:

1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **8 maximum**;
3. temporary Database-presentation legacy shim imports: **5 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature presentation caught-error interpolation: **forbidden by CI**.

Ratchet numeric ceilings downward only when real debt is removed. Never relax a ceiling merely to land unrelated work.

## Remaining temporary Database-presentation shims
Three re-export shims remain:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

The remaining five production shim imports are concentrated in two large/shared hosts:
- `GenericDatabasePage`: 3 imports (`database_create_tiles`, `database_view_tabs`, `resizable_detail_pane`);
- `BookmarkUnifiedStage1Page`: 2 imports (`database_create_tiles`, `database_view_tabs`).

Do not reconstruct either large host merely to lower a metric. Switch callers only through a naturally patch-sized safe edit, then delete a shim only after production caller-zero is proven.

## AppDatabase / Bookmark responsibility state
Major narrowing already integrated includes Bookmark aggregate reads, profile path conversion, Saved View aggregation, Photo aggregation/path reads, versioned migration helpers, engagement mutations, dead People helpers, dead lifecycle remnants, duplicate Tag hierarchy mutation, the unreachable `updateBookmarkFields.personNames` branch, the caller-zero Repository People wrapper, and the empty lifecycle `remove()` seam.

The previously listed dead Bookmark seams are closed. Re-audit current production callers before identifying any next deletion candidate; do not assume historical caller-zero status remains valid.

## Failure-policy state
Canonical feature presentation is now protected by #745 from new raw caught-exception interpolation.

Legacy raw user-visible exception interpolation still exists in larger or other-lane surfaces such as `AppShell`, `ObjectInspectorPage`, Tag management, `GenericDatabasePage`, Stage1, Image editor, Photo management, and `BookmarkDetailPanel`. Treat these as cleanup candidates, not blanket rewrite targets. For example, `BookmarkDetailPanel` has a single inline-save raw `$error` SnackBar, but the host is roughly 550 lines; do not reconstruct the full file solely for that one string. Take a failure-policy slice only when the host can be edited safely and a focused regression can be added.

Vault/Profile recovery semantics remain Storage-owned. Relation, Search, Primitive, Object, and Database/View product semantics remain their respective lane ownership.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include `GenericDatabasePageStateLoader` (#310) and `GenericDatabasePageServices.fromWorkspaceStore(...)` (#323).

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows, and layout-specific host code. Continue only as small regression-backed slices coordinated with Database/View ownership.

Before non-trivial edits, inspect open PR ownership for `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, `app_database.dart`, and other active shared hosts.

## Legacy Bookmark / Photo convergence
Legacy Bookmark URL/thumbnail/Photo rows remain compatibility/import/export data. Presentation convergence is not storage-retirement proof. Do not remove persisted compatibility fields until production read/write callers and portability/migration contracts are proven zero/replaced.

`BacklinkRepository`, Bookmark presentation resolvers, transfer/backup services, attachment paths, and canonical Object search remain live unless independently proven otherwise.

## Exact next actions
1. Re-read current `main`, Issue #225, and open PR ownership before every next slice; parallel lanes move quickly.
2. Continue true production caller-zero audits, but search by both concrete method name and receiver/host usage before classifying a lifecycle API as dead.
3. Re-audit the remaining five Database-presentation shim imports; lower 5 only through naturally safe host edits, not broad complete-file rewrites.
4. Delete a remaining shim only after repository-wide production caller-zero is proven.
5. Keep `BookmarkLifecycleStore.dispose()` live unless a bootstrap/lifecycle refactor naturally removes all production callers.
6. Continue `GenericDatabasePage` extraction only with regression coverage and ownership clearance.
7. Lower presentation/database or feature-presentation `AppDatabase` ceilings only after a real responsibility/boundary move removes references.
8. Use #745 as the canonical feature-presentation privacy baseline; clean legacy raw-error surfaces only in small independently owned hosts.
9. Do not redesign Relation semantics, canonical Object search, primitive storage, or Vault lifecycle under Refactor.
10. Do not destructively remove Bookmark URL/thumbnail/Photo storage before proven caller-zero and portability/migration parity.

## Risks / stop condition
Parallel lanes move `main` quickly. Complete-file connector writes require exact-current-source preservation and base-diff verification. Open PR ownership always overrides this handoff. If all remaining candidates are confined to actively leased hotspots, another lane's product territory, or broad high-risk edits, idling is preferable to manufacturing abstraction or broad churn.
