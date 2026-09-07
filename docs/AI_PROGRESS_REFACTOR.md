# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G checkpoints:
- **`7d4d3077ee311ec5ede06b4fee1988a302a3efb6` — #823 refresh Lane G handoff after reload/privacy guards**;
- **`f357daa6d2f9da38b67214af3ff3e81d2049744f` — #812 Freeze legacy raw-error presentation spread**;
- **`ecffd5b244510bc45b1d7d6409003efae7167319` — #795 Bound GenericDatabasePage relation record fanout**;
- **`085201b8...` — #786 add a repeatable GenericDatabasePage reload performance probe**;
- **`241803aa4d8fc6e0bdc779b9112d68d6831568db` — #745 Guard canonical feature presentation error privacy**;
- **`60d6ac5ac4834488ca20168c39149c323deb8f64` — #735 Retire caller-zero Database toolbar shim from current main**;
- **`2bde122bd9a3c07e976a476f3ac3ba48e2380554` — #731 Retire dead Bookmark People and lifecycle seams**;
- **`6f27c85577a429c1b1abd5980573cb5105c9863a` — #728 Remove dead Bookmark people update seam**;
- **#707** — move People management off four temporary Database-presentation shim imports and ratchet the legacy-shim-import ceiling to **5**.

Active Lane G slice:
- **#829 — Retire caller-zero Weblink detail preview** on `refactor/retire-dead-weblink-detail-preview-225`;
- repository-wide production search found no caller of `ObjectWeblinkDetailPreview` outside its own module; only its dedicated test imported it;
- the branch deletes the dead module and dedicated test, and ratchets canonical feature-presentation direct `AppDatabase` imports **8 → 7** in CI and `docs/MAINTAINABILITY.md`;
- no shared hotspot or live Weblink visual resolver is removed; Gallery / Bookmark visual paths remain live.

Earlier relevant integrated checkpoints include #705 (duplicate AppDatabase Tag hierarchy mutation retired), #701 (Database Property-add raw exception exposure removed), #695 (Photo management shim imports retired), #687 (Collection management shim imports retired), #672 (caller-zero DetailPropertyRow shim retired), #654 (caller-zero Bookmark-only FTS retired), #642/#637 (dead Bookmark/AppDatabase seams removed), #586 (plain-text Object Body mutation chain retired), and #579 (engagement writes moved out of AppDatabase).

### #795 — GenericDatabasePage reload fanout reduced
- #786 first added a repeatable structural performance probe for the real `GenericDatabasePageStateLoader` reload path;
- an initial attempt to remove `objectTypes` / `recordsByType` entirely was rejected by CI because Relation chips/editor candidates still consume those projections indirectly;
- the corrected #795 keeps one ObjectType catalog load for Relation editor choices but calls `listRecords(...)` only for distinct ObjectTypes actually targeted by Relation Properties on the current Database;
- unrelated ObjectTypes no longer trigger record-catalog reads on every reload;
- focused tracking-store coverage plus the full Flutter Test suite preserve Relation label/editor behavior;
- corrected head passed Flutter CI run #2446 before merge.

### #812 — legacy error-privacy spread frozen
- #745 already forbids raw caught-exception interpolation in canonical `lib/features/**/presentation/`;
- #812 extends the same scanner to legacy `lib/views/` / `lib/widgets/` without forcing broad hotspot rewrites;
- only eight currently known legacy hosts are temporarily allowlisted: `app_shell.dart`, `bookmark_unified_stage1_page.dart`, `generic_database_page.dart`, `image_editor_page.dart`, `object_inspector_page.dart`, `photo_management_page.dart`, `tag_management_page.dart`, and `bookmark_detail_panel.dart`;
- a new legacy host with raw caught-error interpolation fails CI;
- when an allowlisted host is cleaned, a stale allowlist entry also fails CI so the boundary ratchets smaller;
- fixture guard, live repository guard, Drift generation, Analyze and full Test all passed in CI run #2477 before merge.

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

### #736 — rejected cleanup candidate
A proposed removal of empty `BookmarkLifecycleStore.dispose()` was **not merged**. CI exposed eight production callers in `lib/main.dart` that a narrow caller search had missed. The method body is empty, but it is still part of the live bootstrap/lifecycle contract. Do not remove it merely for line-count cleanup; revisit only during a naturally scoped bootstrap/lifecycle refactor with fresh ownership checks.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. On active #829 the numeric ceilings are:

1. presentation direct `workspaceStore.database` reach-through: **9 maximum**;
2. direct `AppDatabase` imports under canonical feature presentation: **7 maximum**;
3. temporary Database-presentation legacy shim imports: **5 maximum**;
4. temporary Database-presentation re-export shim files: **3 maximum**;
5. canonical feature presentation caught-error interpolation: **forbidden by CI**;
6. legacy presentation caught-error interpolation may exist only in the current temporary eight-host allowlist; it must not spread to another legacy host, and cleaned hosts must be removed from the allowlist.

Until #829 merges, `main` still has the prior feature-presentation `AppDatabase` ceiling of 8. Ratchet numeric ceilings and allowlists downward only when real debt is removed. Never relax a boundary merely to land unrelated work.

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

#829 additionally proves that feature-presentation `AppDatabase` debt can sometimes fall through deletion rather than another wrapper: the unused Weblink detail preview existed only as a dead host and test, while shared Weblink visual resolution remains live elsewhere.

The previously listed dead Bookmark seams are closed. Re-audit current production callers before identifying any next deletion candidate; do not assume historical caller-zero status remains valid.

## Failure-policy state
Canonical feature presentation is protected by #745, and #812 now prevents raw caught-error interpolation from spreading to additional legacy presentation hosts.

Eight legacy hosts remain temporarily allowlisted because they still contain raw user-visible exception interpolation. Clean them only as focused, independently tested slices with current ownership checks. When one becomes clean, remove it from `legacy_allowed_hosts` in the same PR so CI ratchets the debt boundary smaller.

Vault/Profile recovery semantics remain Storage-owned. Relation, Search, Primitive, Object, and Database/View product semantics remain their respective lane ownership.

## GenericDatabasePage / shared hotspots
Focused extractions already integrated include `GenericDatabasePageStateLoader` (#310), `GenericDatabasePageServices.fromWorkspaceStore(...)` (#323), the reload performance probe (#786), Relation-target-only record fanout (#795), and Database/View Relation-picker quick-create integration #819 (`dfc0717613142e115c8211c7ecf1b9889879a9af`).

#819 is merged, so its previous GenericDatabasePage ownership lease is cleared. Before any new GenericDatabasePage edit, search current open PRs again; do not assume the hotspot is free merely because #819 closed.

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows, and layout-specific host code. Continue only as small regression-backed slices coordinated with Database/View ownership.

Before non-trivial edits, inspect open PR ownership for `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, `settings_page.dart`, `profile_manager.dart`, `app_database.dart`, and other active shared hosts.

## Legacy Bookmark / Photo convergence
Legacy Bookmark URL/thumbnail/Photo rows remain compatibility/import/export data. Presentation convergence is not storage-retirement proof. Do not remove persisted compatibility fields until production read/write callers and portability/migration contracts are proven zero/replaced.

`BacklinkRepository`, Bookmark presentation resolvers, transfer/backup services, attachment paths, `ObjectSearchCompatibilityBridge`, and canonical Object search remain live unless independently proven otherwise. `ObjectSearchCompatibilityBridge` currently has a single production `GlobalSearchPage` caller, but deleting it directly would reintroduce a presentation `workspaceStore.database` reach-through; retire it only when composition can move safely without worsening the boundary ceiling.

## Exact next actions
1. Validate #829 against current `main`; merge only after maintainability ceiling 7, Analyze and full Test are green and no overlapping main change appears.
2. After #829, re-run caller-zero audits against current production rather than assuming the next feature-presentation `AppDatabase` import is removable.
3. Re-audit the remaining five Database-presentation shim imports now that #819 is merged; lower 5 only through naturally safe host edits, not broad complete-file rewrites.
4. Delete a remaining shim only after repository-wide production caller-zero is proven.
5. Keep `BookmarkLifecycleStore.dispose()` live unless a bootstrap/lifecycle refactor naturally removes all production callers.
6. Re-check current open ownership before any GenericDatabasePage patch; its #819 lease is cleared but the file remains a shared hotspot.
7. Lower presentation/database or feature-presentation `AppDatabase` ceilings only after a real responsibility/boundary move or caller-zero deletion removes references.
8. Shrink the #812 legacy raw-error allowlist one host at a time when a host can be edited safely with a focused regression; do not rewrite large hosts solely to satisfy the metric.
9. Do not redesign Relation semantics, canonical Object search, primitive storage, or Vault lifecycle under Refactor.
10. Do not destructively remove Bookmark URL/thumbnail/Photo storage before proven caller-zero and portability/migration parity.

## Risks / stop condition
Parallel lanes move `main` quickly. Complete-file connector writes require exact-current-source preservation and base-diff verification. Open PR ownership always overrides this handoff. If all remaining candidates are confined to actively leased hotspots, another lane's product territory, or broad high-risk edits, idling is preferable to manufacturing abstraction or broad churn.
