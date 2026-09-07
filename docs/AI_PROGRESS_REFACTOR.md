# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. This lane owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement. It does not redesign Relation semantics, primitive identity/storage semantics, Search semantics, Database/View product behavior, or Vault recovery policy.

## Current checkpoint — 2026-09-07
Latest integrated Lane G production checkpoint: **`6f1238f0d400bd5d6195a64085e6b702694bdb64` — #687 Retire Collection Database presentation shim imports**.

Current Lane G work in progress: **PR #695 `refactor/photo-presentation-shims-225`**, created from main **`91824121156fbfebfa260b09d80e604d5923d8ab`** after Primitive #692.

PR #695 is intentionally narrow:
- `PhotoManagementPage` imports `DatabaseActionCard`/`DatabaseActionRow`, `DatabasePageToolbar`, `DatabaseViewTabs`, and `ResizableDetailPane` directly from `lib/features/database/presentation/widgets/` instead of the four temporary `lib/widgets/` re-export shims;
- Photo rendering, search, saved View behavior, import/edit/delete flows, Bookmark attachment behavior, and detail-pane behavior are unchanged;
- the CI legacy-shim-import ceiling is ratcheted **13 → 9**;
- `docs/MAINTAINABILITY.md` records the new accepted baseline.

GitHub reported the initial PR delta as **3 files, +8 / -8**, which is consistent with four import substitutions plus one guardrail/doc ratchet and provides an important check against accidental full-host reconstruction drift. The branch then updates this handoff as required by `AGENTS.md`.

Open PR ownership was checked before editing. At branch creation, active work included Object, Relation, Primitive and Storage slices (#685/#686/#689, #694, #693, #691, plus docs/presentation work), but no active PR owned `photo_management_page.dart` or this Refactor guardrail slice. Re-check live ownership before merge because `main` moves quickly.

## Current measurable guardrails
`.github/workflows/flutter_ci.yml` is the source of truth. On PR #695 the intended accepted ceilings are:

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
- #695 — current slice moves Photo management off the same four shims and ratchets shim imports 13 → 9.

Key rule: tests dedicated only to a caller-zero implementation do not make that implementation live. Prove production callers are zero and surviving behavior is independently covered before deletion.

## Temporary Database-presentation re-export shims
Four legacy shim files still exist:
- `lib/widgets/database_page_toolbar.dart`;
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

After #687 and current #695, the remaining real shim callers are concentrated in larger/shared hosts such as People management, `GenericDatabasePage`, and Stage1. Do **not** reconstruct those files merely to reduce the metric. Switch callers only when a naturally patch-sized edit is already safe, then delete a shim only after true caller-zero is proven.

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
High-value raw-error and silent-failure boundaries are largely stabilized. Intentional compatibility/best-effort failures may remain fail-soft with privacy-safe diagnostics where useful.

`PhotoManagementPage` still contains legacy raw exception interpolation in import failure Toasts. PR #695 deliberately does **not** combine that user-visible failure-policy change with the import-only shim cleanup. If that boundary is changed later, use a focused regression-backed slice and stable user message; do not leak paths/content/exception text into diagnostics.

Profile/Vault recovery semantics remain Storage-owned and must not be changed under Refactor merely because a catch is broad.

## Validation / work in progress
For #695:
- open PR ownership checked before edit;
- exact current `photo_management_page.dart` was fetched from branch base before replacement;
- initial GitHub PR delta verified as 3 files, +8 / -8 before this handoff update;
- Flutter CI is expected to run maintainability guard tests/ceilings, feature legacy dependency guard, Drift generation, `flutter analyze`, and full `flutter test`;
- do not merge until CI is green and current `main` still has no overlapping Photo/guardrail changes.

## Exact next actions
1. Inspect #695 CI and mergeability; merge only when Analyze/full Test are green and current main remains non-overlapping.
2. While CI runs, continue true production caller-zero audits in small non-hotspot modules; prefer whole-module deletion over wrapper creation.
3. Re-audit the remaining nine Database-presentation shim imports; lower 9 only through naturally safe host edits, not broad rewrites.
4. Keep the two dead Bookmark API seams deferred until `bookmark_repository.dart` can be patched safely.
5. Continue GenericDatabasePage extraction only with a focused test-first slice and an available hotspot lease.
6. Lower presentation/database or feature-presentation `AppDatabase` ceilings only after a real responsibility/boundary move removes references.
7. Do not touch Relation semantics, canonical Object search semantics, primitive storage semantics, or Vault lifecycle under Refactor.
8. Do not destructively remove Bookmark URL/thumbnail/Photo storage until caller-zero and portability/migration parity are proven.

## Risks / sequencing
- parallel lanes move `main` quickly;
- complete-file connector writes require exact-current-source preservation and diff verification;
- open PR ownership takes precedence over this handoff;
- a falling metric is useful only when real dependency/responsibility disappears;
- behavior-preserving cleanup must not silently become schema, Relation, Search, primitive-storage, or recovery-policy redesign.

## Stop / continuation state
Current independent Lane G slice is PR #695. Continue with CI/integration and another verified caller-zero or naturally patch-sized dependency cleanup. If the remaining candidates all require broad edits to leased/shared hotspots, record that blocker rather than manufacturing a new abstraction.
