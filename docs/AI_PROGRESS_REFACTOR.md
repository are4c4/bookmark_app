# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, caller-zero retirement after proof, failure-policy/privacy cleanup, maintainability guardrails, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Latest verified `main`: **`1d4775530b4c1646cb4a88d719e96f48b6bec39b`**.

Recent main sequence relevant to Refactor:
- **#467 merged** — make unexpected canonical Image visual file-probe failures observable without changing fail-soft behavior.
- **#472 merged** — retire caller-zero `PersonRoleProperties` plus its dead-only source-string architecture test.
- **#468 merged** — Relation handoff refresh only; no Relation production semantics.
- **#473 merged** as `a1ea19391f07412c4117d9543f395d79f7f1f8da` — Object-owned read-only fallback geometry probing for canonical managed Images.
- **#469 merged** as current main `1d477553...` — Object-owned safe vertical flip action routed through canonical Image edit semantics.

Current open PR ownership:
- **Refactor #470** — this docs-only handoff/inventory refresh.
- **Refactor #474** — maintainability guard for temporary Database-presentation re-export shim imports; production Dart behavior is untouched.
- **Object #471** — Object/repository handoff refresh only; docs-only.

There is currently no open Object production PR or Relation production PR at this checkpoint. Re-read live ownership before every shared-host edit because parallel lanes move `main` quickly.

The CI presentation/database boundary guard introduced by #443 is enforced by #448 at a ceiling of **12** `workspaceStore.database` references. Refactor #474 proposes a second ratchet ceiling for the five temporary Database-presentation re-export shims, measured at **22** current imports. Ratchet either ceiling downward only when a real cleanup slice removes debt; do not add wrappers merely to hide a metric.

## Latest caller-zero cleanup series
Merged behavior-preserving cleanup PRs:
- **#451** — retired caller-zero Object detail session composition chain, **337 deletions / 0 additions**.
- **#453** — retired unused drag/drop intent hierarchy, **49 / 0**; Flutter CI #1577 green.
- **#454** — retired caller-zero `ObjectBodyReferenceIndex` + dead-only test, **106 / 0**; CI #1578 green.
- **#455** — retired caller-zero `ObjectBodyBlockValidator` and validator-only assertions while preserving live factory/reference/round-trip coverage, **116 deletions / 1 addition**; CI #1582 green.
- **#458** — retired caller-zero `ObjectGroupMode`, **4 / 0**; CI #1590 green.
- **#459** — retired caller-zero `ResolvedObjectTypeDefaults` / `ObjectTypeDefaultsResolver` + dead-only test, **84 / 0**; CI #1591 green.
- **#463** — retired caller-zero Object detail Value editor/descriptor/input-codec layer + dead-only tests while retaining live `ObjectDetailEditService`, **480 / 0**; CI #1608 green.
- **#464** — retired caller-zero `DatabaseRecordAdapter<T>`, `DatabasePropertyValue`, and abandoned property presenter module, **89 / 0**; CI #1609 green.
- **#466** — retired old paragraph-only `ObjectBodySection` compatibility widget + dead-only widget regression, **216 / 0**; CI #1612 green.
- **#472** — retired caller-zero `PersonRoleProperties` + dead-only architecture test after confirming live Bookmark detail/property behavior already uses `BookmarkReorderableProperties` plus canonical Property rows, **290 / 0**; CI #1623 green.

Combined for #451/#453/#454/#455/#458/#459/#463/#464/#466/#472: **1,771 deletions / 1 addition, net -1,770 LOC**.

Earlier handoff #456 merged after its rerun completed successfully. Stale docs-only #452 was closed rather than force-merged after main moved.

Shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`) were deliberately not reconstructed in these cleanup PRs.

## Failure-policy / observability state
- **#467** added a stable privacy-safe debug diagnostic for unexpected managed Image file-probe failure while preserving fail-soft `null` behavior; Flutter CI #1618 green.
- **#473** now owns the additional Image geometry decode fallback and keeps decode/read failure fail-soft with fixed privacy-safe diagnostics.
- Do not mechanically log expected compatibility misses. `BookmarkObjectLinkReadStore` intentionally fails soft when mirrored Object-link storage is absent/unavailable on older/pre-sync data; routine logging there would add noise without improving recovery.
- Raw persisted/request user content must not be interpolated merely to make diagnostics more verbose.

The small high-value failure-policy boundaries are largely complete. Remaining raw user-visible exception interpolation is concentrated in large/shared legacy hosts such as Photo/Tag/Stage1; do not reconstruct those hosts for one message string.

## Cross-lane ownership
### Object lane
Recent merged Image product work includes #457 detail panel composition, #460 crop presets, #465 safe free-crop, #473 read-only missing-geometry fallback, and #469 safe vertical flip.

Refactor must not redefine canonical Image byte mutation, file ownership/copy-on-edit, Photo mapping, geometry persistence, or Object product behavior. Object #471 is docs-only.

`ObjectInspectorPage` remains a shared hotspot. Only touch it when the change can be applied as a genuinely patch-sized write; do not reconstruct the whole host for one constructor argument/import.

### Relation lane
#468 is merged and docs-only. Canonical Relation mutation/read/index/backlink/audit/reconcile semantics remain Relation-owned. Refactor must not create alternate Relation writes, indexes, repair paths, or presentation-side mutation.

## Major completed Refactor checkpoints
### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh` and `docs/MAINTAINABILITY.md`;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- dependency-boundary guidance in `docs/architecture.md`;
- #401 guard against new direct Bookmark URL/visual resolver construction in presentation;
- #443 opt-in presentation/database reach-through regression threshold;
- #448 CI enforcement at 12 references.

#474 is the current follow-up guardrail slice: it reports imports of the five temporary Database-presentation re-export shims and proposes a CI ceiling of 22 so new legacy shim imports cannot accumulate while existing large hosts remain untouched.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include #281 `BookmarkReadStore`, #282 `ProfilePathResolver`, #283 `SavedViewReadStore`, and #289 `PhotoReadStore`.

Possible future AppDatabase work remains favorite/status/rating/open-count and nearby batch state mutations that are close passthroughs from `BookmarkRepository`. Only move them when the change removes real database-root responsibility and `app_database.dart` can be patched safely; do not reconstruct the file wholesale.

### Legacy Bookmark presentation / retirement
Canonical Bookmark visual/URL presentation now routes through shared resolvers/components in the previously inventoried hosts. Whole-module caller-zero retirement is preferred to speculative wrappers.

`docs/LEGACY_BOOKMARK_INVENTORY.md` now records #472 as retired caller-zero behavior rather than incorrectly classifying `PersonRoleProperties` as live product behavior.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain live compatibility/import/export data until production caller-zero and migration/backup policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices include #310 `GenericDatabasePageStateLoader` and #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibility includes schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC.

## Dependency-composition / shim state
Presentation `workspaceStore.database` reach-through remains enforced at **12**.

Known remaining reach-through is concentrated in `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`.

`DatabaseViewStore` composition still has several genuine callers. There is no meaningful existing boundary that can absorb the presentation constructors without either touching conflict-prone hosts or adding a wrapper solely to lower the metric. Do not create such an abstraction until at least two real callers lose actual responsibility.

`CollectionManagementPage` create/delete/membership already use `BookmarkRepository`, while rename/note persistence still updates `database.collections` directly. There is no existing semantic update API. Do not add a one-caller wrapper merely to hide access, and do not reconstruct `app_database.dart`/a large repository file through connector writes.

People management has the same constraint: hiding `PersonGroupStore`/`DatabaseViewStore` construction behind a page-specific composition wrapper would not reduce responsibility.

Five temporary re-export shims remain under `lib/widgets/`:
- `database_page_toolbar.dart`;
- `database_view_tabs.dart`;
- `database_create_tiles.dart`;
- `resizable_detail_pane.dart`;
- `detail_property_row.dart`.

Their canonical implementations live in `lib/features/database/presentation/widgets/`. Current legacy imports total **22 across 8 caller files**. Several callers are large shared/legacy hosts, so shim removal must happen opportunistically through patch-sized import changes rather than whole-file reconstruction. #474 prevents this debt from increasing and is designed to ratchet downward as imports disappear.

## Caller-zero audit notes
Confirmed live and therefore **not** deletion candidates include:
- `ObjectDetailContent`, `ObjectDetailContentLoader`, and live `ObjectDetailEditService` rename/typed-Value path;
- `ObjectBodyBlockIdAllocator` / `ObjectBodyBlockDuplicator`;
- `ObjectBodyEditor` and Object Body action/position/reference helpers;
- `ObjectIdentitySearchService` / Object reference catalog path;
- `DailyNoteNavigationService` / `DailyNoteDetailNavigationService`;
- `DatabaseCollectionResolver` / `DatabaseCollectionConfigService` and collection loading path;
- `GenericObjectViewCoordinator` / `ObjectViewProjection`;
- `DatabaseViewGalleryAdapter` / `DatabaseViewGroupAdapter` / `DatabaseViewCreationService` / `DatabaseViewOpenModeService`;
- `ObjectOpenPresentationService` and its real GenericDatabase/Object presentation hosts;
- `PdfAnnotationStore` / attachment viewer path;
- `PhotoReadStore`;
- `BookmarkAttachmentStore` / attachment UI, drop and deletion paths;
- Bookmark state/lifecycle enums;
- `BookmarkRelationSection`, `BookmarkReorderableProperties`, `BookmarkListMetadata`, `BookmarkResolvedUrlText`, `BookmarkReverseLookupDialog`;
- legacy `person_roles.dart` persistence and `BookmarkRepository.watchPersonRoles(...)`, still used by Stage1 / `BookmarkReorderableProperties`;
- legacy `ImageEditorPage` / `ImageEditService`, because Photo management still invokes the raw-path editor;
- `ObjectBoardCreatePlanner`, because it is the default live planner inside production `ObjectBoardCreateService` and participates in grouped/Relation preset semantics;
- `GenericDatabaseCollectionPageLoader`, `ObjectAliasStore`, `ObjectTypeTemplateStore`, `SavedViewReadStore`, `WeblinkImageSchemaService` and the other inspected small data/services with real production callers.

Confirmed dead and removed in the latest series:
- Object detail session composition (#451);
- drag/drop intent hierarchy (#453);
- `ObjectBodyReferenceIndex` (#454);
- `ObjectBodyBlockValidator` (#455);
- `ObjectGroupMode` (#458);
- `ResolvedObjectTypeDefaults` / `ObjectTypeDefaultsResolver` (#459);
- Object detail Value editor/descriptor/input codec (#463);
- abandoned Database record/property presenter layer (#464);
- paragraph-only `ObjectBodySection` compatibility widget (#466);
- `PersonRoleProperties` (#472).

## Deferred real cleanup candidates
These are genuine cleanup opportunities but should not be forced with whole-file rewrites.

1. **Plain-text Body mutation chain**
   - `ObjectBodySection` is gone.
   - `ObjectDetailEditService.setPlainTextBody(...)` has no production caller; remaining calls are regression-only.
   - `ObjectBodyPlainTextAdapter` is now referenced by that dead service method plus its dedicated test.
   - Fully retiring the chain also removes the now-unneeded `bodyStore`/adapter dependency from `ObjectDetailEditService` and its one production constructor in `ObjectInspectorPage`.
   - Do this only when the Inspector constructor/import change can be applied as a small hunk.

2. **Temporary Database-presentation re-export shims**
   - Canonical implementations already live under `lib/features/database/presentation/widgets/`.
   - `detail_property_row.dart` currently has legacy callers in `bookmark_attachment_section.dart`, `bookmark_reorderable_properties.dart`, and one test.
   - The other four shims have legacy callers across Photo/People/Collection management, GenericDatabasePage, Stage1 and a focused test.
   - Do not replace those large hosts wholesale for one import line. Use #474's ceiling to prevent regression and ratchet the count downward when a host is naturally/patched safely touched.

Future caller-zero searches must verify the candidate file itself plus class/function and filename/import references on current `main`; GitHub code-search indexing can lag recent merges.

## Exact next actions
1. Re-read latest `main` and open PR ownership before every code edit.
2. Merge #470 only after its latest docs head has green CI and remains mergeable on current main.
3. Post an Issue #225 checkpoint after #470 lands, recording #467/#472, net -1,770 LOC, #469/#473 merged Object state, deferred cleanup chains, and #474 status.
4. Validate #474 against the real repository baseline: maintainability fixture must pass and the report must observe at most the accepted 22 shim imports; merge only with green Analyze/Test and mergeability.
5. After #474 lands, lower its shim ceiling whenever a safe caller import is migrated to the canonical feature path.
6. Continue caller-zero auditing outside active Object/Relation ownership; delete only when production callers are zero and still-live behavior has independent coverage.
7. Prefer real responsibility/LOC reduction over wrappers added solely to hide property access.
8. Retire the plain-text Body chain only when `ObjectInspectorPage` can be patched narrowly.
9. If a presentation `workspaceStore.database` reference is genuinely removed, lower the CI ceiling from 12 with the responsibility move.
10. Revisit Collection/People dependency reach-through only when an existing meaningful boundary can absorb the responsibility.
11. Continue GenericDatabasePage P1 only through patch-sized extraction of concrete schema/database action, Property workflow, or layout-host responsibility.
12. Revisit AppDatabase mutations only when `app_database.dart` can be patched safely.
13. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
14. Treat Issue #414 as separate search-correctness work.

## Validation
- #467 Flutter CI #1618 green.
- #472 Flutter CI #1623 green before merge.
- #470 prior head `37f617a34a10c6eef737a5c02d4fa46269019a1e` passed Flutter CI #1636, including maintainability guards, Drift generation, Analyze and full Test. This handoff update changes documentation only; recheck CI for its new head.
- #474 is open and its latest CI must validate both the existing boundary ceiling and the new shim-import ceiling before merge.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small diffs on latest main rather than force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- connector file writes replace complete existing files, so do not reconstruct a large host merely for a small hunk;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- abstractions that add wrappers without removing responsibility should be rejected;
- stale code-search results can lag main;
- Image product semantics remain Object-owned even though #469/#473 are now merged.

## Stop / continuation state
The latest obvious whole-module caller-zero candidates were retired through #472. Fresh audits found real production callers for the other inspected small modules. The remaining plain-text Body chain requires a tiny change inside the large shared Inspector, and the temporary Database-presentation shims require tiny import changes inside several large hosts; neither should trigger whole-file reconstruction.

Safe Refactor work should continue through caller-zero deletion, patch-sized responsibility moves, or guardrails that make existing migration debt monotonically decrease. #474 is the current actionable guardrail slice.