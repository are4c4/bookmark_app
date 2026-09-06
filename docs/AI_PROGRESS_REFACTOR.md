# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Object Core owns shared Object/Body product semantics, Relations owns canonical Relation semantics, Database/View owns Database presentation semantics, Primitive Objects & Media owns Weblink/Image/File/etc. product behavior, Search owns indexing/query semantics, and Storage/Vault owns storage/delivery behavior. Lane G owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, AppDatabase responsibility reduction, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Lane G integration checkpoint: **`6e6b1bdb737b513fb2f7fe40c94012c3783c703b`** after Refactor **#541**. Latest `main` observed during this handoff refresh: **`735c8be7bba099b9c5b253ff3bb509caafae9086`** after Primitive **#528**. Re-read current `main` before the next edit because parallel lanes move rapidly.

Integrated in the current Lane G run:
- **#510 merged** as `1c998a4136e9671a3b5ca4d2d2f32032e195d835` — remove duplicated numeric ceilings from `maintainability_report.sh --help`; point to CI as the source of truth and guard that contract with a regression.
- **#522 merged** as `0254b87e8a29b31333a1cc99edf17a462759e919` — extend direct presentation/database reach-through measurement from legacy `lib/views` / `lib/widgets` into canonical `lib/features/**/presentation` without raising the ceiling.
- **#504 merged** as `34a4ac24a5a3fe5bbe1b29f8118627082792dc1d` — reject new `BookmarkItem` / `BookmarkRepository` dependencies under canonical `lib/features`.
- **#532 merged** as `f8882dd2a0955f57e867ea98394d210ecfbea463` — extend the same feature dependency guard so canonical feature code cannot import/export legacy `lib/views` or `lib/widgets`, while preserving feature-to-feature imports.
- **#541 merged** as `6e6b1bdb737b513fb2f7fe40c94012c3783c703b` — move `BookmarkReorderableProperties` from the legacy `DetailPropertyRow` re-export to the canonical feature widget and ratchet shim-import ceiling **18 → 17**.

#532 and #541 both passed maintainability guardrails, current ceilings, Drift generation, Analyze and full Test before merge. #541 production behavior change is import-only: the Bookmark properties host diff is one added canonical import and one removed shim import.

## Live ownership / sequencing
Rechecked during this run:
- **Object #503 remains open** and owns the patch-sized `ObjectInspectorPage._canEditBody(...)` universal-Body hunk. Lane G must not touch `ObjectInspectorPage` or retire the plain-text Body chain while #503 remains open.
- **Primitive #498 remains open** and owns canonical Image edit composition. Lane G must not alter Image edit/ownership semantics.
- **Storage #509 is merged**. Its prior `app_database.dart` lease is clear; a later AppDatabase refactor still requires a fresh open-PR check immediately before editing.
- No open PR was found owning `bookmark_reorderable_properties.dart` or `app_database.dart` when their latest audits were run.

Parallel lanes move `main` rapidly. Re-read open PR ownership before every shared-host edit.

## Current measurable guardrails
Flutter CI currently enforces three monotonic ceilings:

1. Presentation direct `workspaceStore.database` reach-through: **9 references maximum**.
2. Temporary Database-presentation re-export shim imports: **17 imports maximum**.
3. Temporary Database-presentation re-export shim files: **5 files maximum**.

### Presentation/database reach-through
#522 closes the folder-layout loophole: the same ceiling now scans legacy `lib/views` / `lib/widgets` and canonical `lib/features/**/presentation`. Moving presentation code into `lib/features` therefore cannot hide direct database reach-through.

The accepted ceiling remains **9**. Lower it only when a real responsibility move removes reach-through; do not add page-specific wrappers merely to hide the metric.

A separate audit found **7 `AppDatabase` references under current `lib/features`**, including existing Database/Object presentation widgets. Therefore a blanket zero-`AppDatabase` feature guard would currently encode a behavior/architecture migration rather than a regression-only boundary. Do not add such a guard until those references are classified and an explicit replacement boundary exists.

### Legacy Database-presentation shims
Shim-import history:
- initial baseline: **22**;
- #474: three test-only imports moved canonical, **22 → 19**;
- #499: `BookmarkAttachmentSection` moved to canonical `DetailPropertyRow`, **19 → 18**;
- #541: `BookmarkReorderableProperties` moved to canonical `DetailPropertyRow`, **18 → 17**.

Remaining shim-import distribution:
- Photo management: 4
- People management: 4
- Collection management: 4
- GenericDatabasePage: 3
- Stage1: 2

These 17 callers are concentrated in large/shared legacy hosts. Do not reconstruct those files merely to lower a metric. Migrate imports when a host is naturally and safely touched, then ratchet the CI ceiling in the same or immediately following focused slice.

Tracked shim files remain:
- `lib/widgets/database_page_toolbar.dart`
- `lib/widgets/database_view_tabs.dart`
- `lib/widgets/database_create_tiles.dart`
- `lib/widgets/resizable_detail_pane.dart`
- `lib/widgets/detail_property_row.dart`

Delete a shim file only after every real caller is gone.

## Canonical feature dependency boundary
#504 + #532 now make `lib/features` monotonic in two directions:
- no new `BookmarkItem` / `BookmarkRepository` dependency;
- no import/export back to legacy `lib/views` / `lib/widgets`, for both package and relative forms.

This does **not** prohibit feature-to-feature presentation imports. Reusable presentation should move to a canonical feature/shared boundary instead of making canonical feature code depend back on legacy hosts.

## Caller-zero cleanup series
Merged behavior-preserving cleanup PRs:
- **#451** — Object detail session composition chain, 337 deletions.
- **#453** — unused drag/drop intent hierarchy, 49 deletions.
- **#454** — `ObjectBodyReferenceIndex` + dead-only test, 106 deletions.
- **#455** — `ObjectBodyBlockValidator` and validator-only assertions, 116 deletions / 1 addition.
- **#458** — `ObjectGroupMode`, 4 deletions.
- **#459** — `ResolvedObjectTypeDefaults` / `ObjectTypeDefaultsResolver` + dead-only test, 84 deletions.
- **#463** — Object detail Value editor/descriptor/input-codec layer + dead-only tests, 480 deletions.
- **#464** — `DatabaseRecordAdapter<T>`, `DatabasePropertyValue`, abandoned property presenter module, 89 deletions.
- **#466** — paragraph-only `ObjectBodySection` compatibility widget + dead-only regression, 216 deletions.
- **#472** — `PersonRoleProperties` + dead-only architecture test, 290 deletions.

Combined #451/#453/#454/#455/#458/#459/#463/#464/#466/#472: **1,771 deletions / 1 addition, net -1,770 LOC**.

Shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`) were deliberately not reconstructed for these deletions.

## Current-source caller audit
The following audited modules still have real production callers and are **not deletion candidates**:
- `AutoOrganizeService`
- `BookmarkTransferService`
- `AppSettingsService`
- `ProfileStorageMigrator`
- `DatabaseBackupService`
- `BookmarkPresentationResolverFactory`
- `GenericDatabaseImageImportService`
- `BookmarkObjectLinkReadStore`
- `DatabaseViewQueryAdapter`
- `DatabaseViewManagementService`
- `GenericDatabaseCollectionPageData`
- `ObjectBodyBlockActionController`
- `ObjectBoardMoveService`
- `ObjectDetailPropertyPresentation`
- `ObjectValuePromotion`
- `BacklinkRepository`
- `FullTextSearchRepository`
- `NotionInlineField`, `DetailSection`, `BookmarkResolvedUrlText`, `ObjectTypeTemplatePicker`, and `TagDetailPane`.

`tool/performance_probe.dart` is an intentional standalone CLI entrypoint; lack of an import caller does not make it dead production code.

No new safe whole-module caller-zero deletion was proven in this run.

## Deferred cleanup candidates
### Plain-text Body mutation chain
`ObjectBodySection` is already gone. `ObjectDetailEditService.setPlainTextBody(...)` and `ObjectBodyPlainTextAdapter` were previously identified as a possible caller-zero chain.

**Do not retire it while Object #503 remains open.** After #503 merges, re-audit production callers from current `main`; remove only if caller-zero is still proven and surviving Body behavior has independent coverage.

### AppDatabase mutation responsibility
`BookmarkRepository` still forwards favorite/status/rating/open-count and batch mutation operations into methods implemented on `AppDatabase`.

Storage #509 no longer owns `app_database.dart`, but the next change must remove real root-database responsibility rather than add a one-caller wrapper. Current constraints:
- creating a new mutation abstraction solely for `BookmarkRepository` would violate the repository rule against abstractions without multiple real callers;
- pushing unrelated favorite/rating semantics into `BookmarkLifecycleStore` would distort ownership;
- connector whole-file replacement of `app_database.dart` is too risky for a small extraction.

Revisit only when a patch-sized edit/extraction mechanism is available or an existing meaningful Store boundary can absorb the responsibility without semantic distortion.

### Remaining shim imports
All 17 remaining imports live in large/shared hosts. Prefer opportunistic canonical-import migration during naturally owned patches rather than a whole-file reconstruction campaign.

## Architecture / responsibility state
### AppDatabase
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical migration bodies.

Existing responsibility moves include #281 `BookmarkReadStore`, #282 `ProfilePathResolver`, #283 `SavedViewReadStore`, and #289 `PhotoReadStore`.

### GenericDatabasePage
Focused extractions already integrated:
- #310 `GenericDatabasePageStateLoader`
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC.

### Legacy Bookmark compatibility
Canonical Bookmark visual/URL presentation has converged substantially, but legacy Bookmark URL/thumbnail/Photo/storage remains live compatibility/import/export data. Presentation convergence alone is not permission to delete storage.

### Failure policy
The small high-value silent/privacy boundaries are largely complete. Keep intentional compatibility/read fallbacks fail-soft, keep rollback cleanup secondary to the original failure, and avoid raw exception/user-data diagnostics.

## Exact next actions
1. Re-read current `main`, Issue #225, open PRs and CI before the next edit.
2. If Object #503 has merged, re-audit the plain-text Body chain; otherwise leave the Inspector untouched.
3. Continue caller-zero audits only on small/medium modules and delete only after production caller-zero plus replacement coverage are proven.
4. Lower shim-import ceiling below 17 only when a real production caller can safely move canonical without reconstructing a large shared host.
5. Lower presentation/database ceiling below 9 only through real responsibility reduction.
6. Revisit AppDatabase mutation responsibility only with a patch-sized extraction that reduces responsibility without creating a one-caller wrapper or distorting `BookmarkLifecycleStore`.
7. Continue GenericDatabasePage P1 only via patch-sized extraction; never rewrite the whole hotspot for architecture aesthetics.
8. Treat Relation/Object/Primitive/Search/Storage product semantics as their owning lanes, not as Refactor opportunities.

## Validation checkpoint
- #510 CI: guardrails, ceilings, Drift, Analyze, full Test **pass**.
- #522 CI: expanded feature-presentation reach-through fixture and unchanged ceiling **pass**; PR merged.
- #504 CI: feature legacy-domain guard **pass**; PR merged.
- #532 CI run #1770: guardrails, ceilings, feature dependency guard, Drift, Analyze, full Test **pass**; PR merged.
- #541 CI run #1780: guardrails, ceiling **17**, feature dependency guard, Drift, Analyze, full Test **pass**; PR merged.

## Risks / sequencing
- `main` moves rapidly across seven parallel lanes; always refresh ownership immediately before shared edits/merges;
- Object #503 owns `ObjectInspectorPage`; Primitive #498 owns canonical Image edit composition;
- large shared hosts must remain patch-sized;
- connector file writes replace complete files, so avoid using them to reconstruct production hotspots for one-line changes;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data;
- reject wrapper-only abstractions that improve a metric without reducing responsibility;
- G lane is behavior-preserving by default.

## Stop / continuation state
The current safe G-lane guardrail sequence is integrated through #541. Guardrails are now **9 / 17 / 5**, canonical feature code cannot regress into Bookmark-era types or legacy presentation, and folder migration cannot hide direct `workspaceStore.database` reach-through.

The next obvious production cleanups are intentionally sequenced: plain-text Body retirement is blocked by Object #503, remaining shim callers are large/shared hosts, and AppDatabase mutation extraction currently lacks a safe patch-sized boundary. Continue with fresh current-source audits rather than manufacturing an abstraction solely to keep the lane busy.
