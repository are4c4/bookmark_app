# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, caller-zero retirement after proof, failure-policy/privacy cleanup, maintainability guardrails, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Latest verified `main`: **`31be90e1dbbfd66592832273820b092cc3a0ce7d`** after Refactor **#474**, directly on top of Object **#475**.

Recent integrated sequence relevant to this lane:
- **#467 merged** — privacy-safe observability for unexpected canonical Image visual file-probe failures while preserving fail-soft behavior.
- **#472 merged** — caller-zero `PersonRoleProperties` retirement.
- **#468 merged** — Relation handoff only; no Relation production change.
- **#473 merged** — Object-owned read-only fallback geometry probing for canonical managed Images.
- **#469 merged** — Object-owned safe vertical Image flip routed through canonical edit semantics.
- **#471 merged** — Object/repository handoff refresh only.
- **#475 merged** as `4e744193...` — Object-owned canonical free-crop edge handles; no Relation/shared-host change.
- **#474 merged** as `31be90e1...` — CI guard for temporary Database-presentation re-export shim imports, plus three test-only imports migrated to canonical feature paths.

Open PR ownership at this checkpoint:
- **Refactor #470** — this docs-only handoff/inventory refresh.
- **Object #476** — canonical Image free-crop pan/zoom parity. It owns the Image crop selector/dialog geometry/widget files in its four-file diff and does not touch `ObjectInspectorPage`, Stage1, generic Database hosts, Relation, Photo mapping or schema.

Refactor must not edit #476's active Image crop files or redefine Image mutation/ownership semantics. Re-read live ownership before every shared-host edit because parallel lanes move `main` quickly.

## Current measurable guardrails
Two maintainability ceilings are now enforced by Flutter CI:

1. Presentation direct `workspaceStore.database` reach-through: **12 references maximum**.
2. Temporary Database-presentation re-export shim imports: **19 imports maximum**.

The shim ceiling started from 22 observed imports. #474 migrated three test-only imports to canonical `lib/features/database/presentation/widgets/...` paths and immediately ratcheted the accepted ceiling to **19**. Lower either ceiling whenever a real cleanup slice removes debt; never add wrappers merely to hide a metric.

Tracked temporary shims:
- `lib/widgets/database_page_toolbar.dart`
- `lib/widgets/database_view_tabs.dart`
- `lib/widgets/database_create_tiles.dart`
- `lib/widgets/resizable_detail_pane.dart`
- `lib/widgets/detail_property_row.dart`

Remaining shim imports are production callers in large/shared legacy hosts. Current distribution at the #474 merge was:
- Photo management: 4
- People management: 4
- Collection management: 4
- GenericDatabasePage: 3
- Stage1: 2
- BookmarkAttachmentSection: 1
- BookmarkReorderableProperties: 1

Do not reconstruct those hosts just to lower the count. Migrate imports opportunistically when a host is safely/patched naturally touched, then ratchet the ceiling downward in the same slice or immediately after.

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

Shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`) were deliberately not reconstructed in these cleanup PRs.

## Architecture / responsibility state
### P0 guardrails
Integrated guardrails include:
- `tool/maintainability_report.sh` and fixture regression;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- dependency-boundary guidance in `docs/architecture.md`;
- #401 guard against new direct Bookmark URL/visual resolver construction in presentation;
- #443/#448 presentation/database reach-through measurement and CI ceiling;
- #474 temporary Database-presentation shim-import measurement and CI ceiling.

New Object/Database/View work must not deepen Bookmark-era coupling unless it is an explicit compatibility/migration boundary.

### AppDatabase
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Responsibility moves include #281 `BookmarkReadStore`, #282 `ProfilePathResolver`, #283 `SavedViewReadStore`, and #289 `PhotoReadStore`.

Possible future mutation responsibility remains favorite/status/rating/open-count and nearby batch updates that are close passthroughs from `BookmarkRepository`. Only move them when `app_database.dart` can be patched safely and the change deletes real database-root responsibility.

### GenericDatabasePage
Focused extractions already integrated:
- #310 `GenericDatabasePageStateLoader`
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC.

### Legacy Bookmark compatibility
Canonical Bookmark visual/URL presentation is converged through shared resolvers/components in the originally inventoried hosts. `docs/LEGACY_BOOKMARK_INVENTORY.md` records #472 as caller-zero retirement rather than live product behavior.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark storage remains live compatibility/import/export data until production caller-zero and migration/backup handling are proven. Presentation convergence alone is not permission to delete storage.

## Failure-policy state
The small high-value silent/privacy boundaries are largely complete. #467 and Object #473 keep Image read failures fail-soft and privacy-safe. Expected compatibility misses such as absent mirrored Object-link storage should remain quiet when logging would only add noise.

Remaining raw user-visible implementation exception interpolation is concentrated in large/shared legacy hosts such as Photo/Tag/Stage1. Do not reconstruct those hosts merely to change one error string.

## Confirmed live — not deletion candidates
Recent current-source audits found real production callers for:
- `ObjectDetailContent`, `ObjectDetailContentLoader`, and live rename/typed-Value `ObjectDetailEditService` path;
- `ObjectBodyBlockIdAllocator`, `ObjectBodyBlockDuplicator`, `ObjectBodyEditor`, action/position/reference helpers;
- `ObjectIdentitySearchService`;
- `DailyNoteNavigationService` / `DailyNoteDetailNavigationService`;
- `DatabaseCollectionResolver` / `DatabaseCollectionConfigService`;
- `GenericObjectViewCoordinator` / `ObjectViewProjection`;
- `DatabaseViewGalleryAdapter`, `DatabaseViewGroupAdapter`, `DatabaseViewCreationService`, `DatabaseViewOpenModeService`;
- `ObjectOpenPresentationService` and its real hosts;
- `PdfAnnotationStore`, `PhotoReadStore`, `BookmarkAttachmentStore`;
- Bookmark lifecycle/state enums and current Bookmark detail/list/reverse-lookup/property/relation widgets;
- legacy `person_roles.dart` persistence and `BookmarkRepository.watchPersonRoles(...)` used by Stage1 / Bookmark property UI;
- legacy `ImageEditorPage` / `ImageEditService` while Photo management still invokes raw-path editing;
- `ObjectBoardCreatePlanner` via production `ObjectBoardCreateService`;
- `GenericDatabaseCollectionPageLoader`, `ObjectAliasStore`, `ObjectTypeTemplateStore`, `SavedViewReadStore`, `WeblinkImageSchemaService` and other inspected small data/services with current production callers.

Future caller-zero deletion requires current `main` verification of the candidate file plus class/function and filename/import references. GitHub code-search indexing can lag recent merges.

## Deferred real cleanup candidates
### Plain-text Body mutation chain
`ObjectBodySection` is gone. `ObjectDetailEditService.setPlainTextBody(...)` has no production caller; remaining calls are regression-only. `ObjectBodyPlainTextAdapter` is referenced by that dead service method plus its dedicated test.

Fully retiring the chain should remove the now-unneeded body-store/adapter dependency from `ObjectDetailEditService` and its one production constructor in `ObjectInspectorPage`. Do this only when the Inspector constructor/import edit can be applied as a genuinely small hunk; do not replace the whole shared host.

### Temporary Database-presentation re-export shims
Canonical implementations already live under `lib/features/database/presentation/widgets/`. #474 prevents new shim-import debt and lowered test-only debt from 22 to 19. Remove each shim only after every production caller has naturally moved to the canonical feature path.

### Presentation/database reach-through
Known direct reach-through remains concentrated in `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`.

Do not introduce a page-specific wrapper merely to hide `workspaceStore.database`. Revisit Collection rename/note persistence or shared `DatabaseViewStore` composition only when an existing meaningful boundary can absorb actual responsibility for multiple real callers.

## Exact next actions
1. Merge #470 after its refreshed docs head is green and mergeable against latest `main`.
2. Post an Issue #225 checkpoint recording the caller-zero net -1,770 LOC, #474 shim guard + 22→19 ratchet, current main, active Object #476 ownership, and remaining deferred chains.
3. Continue current-source caller-zero auditing outside active Object/Relation ownership; delete only when production callers are zero and still-live behavior has independent coverage.
4. Lower the shim ceiling below 19 whenever a production host is safely moved from a temporary shim import to its canonical feature import.
5. Lower the presentation/database ceiling below 12 whenever a real responsibility move removes reach-through.
6. Retire the plain-text Body chain only when `ObjectInspectorPage` can be patched narrowly.
7. Continue GenericDatabasePage P1 only via patch-sized extraction of concrete schema/database action, Property workflow, or layout-host responsibility.
8. Revisit AppDatabase mutation responsibility only when `app_database.dart` can be patched safely without whole-file reconstruction.
9. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
10. Treat Issue #414 as separate search-correctness work.

## Validation
- #467 Flutter CI #1618 green.
- #472 Flutter CI #1623 green before merge.
- #474 Flutter CI **#1646 green**: maintainability fixture, both regression ceilings, Drift generation, Analyze and full Test all succeeded before squash merge as `31be90e1dbbfd66592832273820b092cc3a0ce7d`.
- #470 earlier docs heads passed CI; recheck the refreshed head before merge.

## Risks / sequencing
- parallel lanes can move `main` quickly; re-read open PR ownership before shared code changes;
- Object #476 currently owns canonical Image crop selector/dialog geometry/widget files; do not overlap them;
- large shared hosts must remain patch-sized;
- connector file writes replace complete existing files, so do not reconstruct a large host for a one-line import/constructor change;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data;
- wrapper-only abstractions that reduce a metric without deleting responsibility should be rejected;
- Image product semantics remain Object-owned and Relation semantics remain Relation-owned.

## Continuation state
The obvious whole-module caller-zero candidates found in the latest pass are retired through #472. #474 now makes temporary Database-presentation shim debt monotonic and immediately reduced the measured count to 19 without production-host churn.

The next safe Refactor work should be a true caller-zero deletion, a patch-sized responsibility move, or an opportunistic canonical-import migration that lowers an existing ceiling. Avoid Object #476's active Image crop files. Do not force the plain-text Body chain, shim removal, or database reach-through cleanup through whole-file reconstruction.