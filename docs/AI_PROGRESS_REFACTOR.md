# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, caller-zero retirement after proof, failure-policy/privacy cleanup, maintainability guardrails, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Latest verified `main`: **`844f6b77e7b6947bceaaf6986e6ff8182212e71b`** after Refactor **#499**, on top of Object **#496** and Refactor **#488/#485/#482**.

Recent Refactor sequence:
- **#472 merged** — caller-zero `PersonRoleProperties` + dead-only test retired.
- **#474 merged** — temporary Database-presentation shim import guard; test-only canonical import migration lowered debt **22 -> 19**.
- **#482 merged** — limits Database-presentation re-export shim files to **5**, preventing a sixth compatibility shim from bypassing the known-import guard.
- **#485 merged** — presentation `workspaceStore.database` ceiling ratcheted **12 -> 9** after real responsibility-moving cleanup reduced the measured baseline to 9 references across 6 files.
- **#488 merged** — Bookmark -> mirrored Object lookup remains fail-soft; ordinary missing rows remain quiet, while an exception thrown by the compatibility SQL lookup emits a fixed privacy-safe debug/assert diagnostic + stack trace. Flutter CI #1676 green before merge.
- **#499 merged** — moved `BookmarkAttachmentSection` from the temporary `DetailPropertyRow` shim to the canonical feature import and ratcheted shim-import debt **19 -> 18**. Flutter CI #1682 green before merge.
- Stale/non-mergeable **#478** and duplicate replacement **#487** were closed instead of force-merging.

Current Object/Relation ownership at this checkpoint:
- **Object #496 merged** — List thumbnails can resolve managed Image identity/path without decoding missing geometry. This is Object-owned product/performance behavior and does not change Refactor guardrails.
- **Object #498** may own canonical Image edit composition if still open; do not overlap its Image service files.
- **Object #486** and **Relation #477** are docs-only handoff refreshes if still open.
- **#502** proposes a repository-wide expansion to seven focused development lanes. Until it merges, continue using the currently merged lane ownership rules; if it merges, re-read `AGENTS.md` and all affected handoffs before the next code edit.

Re-read live PR ownership before every shared-host edit because parallel lanes move `main` quickly.

## Current measurable guardrails
Flutter CI now enforces three ratchets:

1. Presentation direct `workspaceStore.database` reach-through: **9 references maximum**.
2. Temporary Database-presentation re-export shim imports: **18 imports maximum**.
3. Database-presentation re-export shim files under `lib/widgets/`: **5 files maximum**.

These metrics are intentionally regression-only. Lower them only when a real cleanup removes responsibility/dependency debt; never add wrappers or rename shims merely to hide a metric.

Tracked temporary shims:
- `lib/widgets/database_page_toolbar.dart`
- `lib/widgets/database_view_tabs.dart`
- `lib/widgets/database_create_tiles.dart`
- `lib/widgets/resizable_detail_pane.dart`
- `lib/widgets/detail_property_row.dart`

#474 reduced the initial shim-import baseline from 22 to 19 using three test-only canonical import migrations. #499 then moved the single `BookmarkAttachmentSection` production caller directly to the canonical `DetailPropertyRow`, reducing the accepted ceiling to 18. Remaining shim imports are still concentrated in large/shared production hosts. Do not reconstruct those hosts just to lower the count; migrate imports opportunistically when a host is safely touched, then ratchet the ceiling in the same slice or immediately after.

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
### Guardrails
Integrated guardrails include:
- `tool/maintainability_report.sh` and isolated fixture regression;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- dependency-boundary guidance in `docs/architecture.md`;
- #401 guard against new direct Bookmark URL/visual resolver construction in presentation;
- #443/#448 presentation/database reach-through measurement;
- #474 shim-import measurement;
- #482 shim-file measurement;
- #485/#499 current **9 / 18 / 5** CI ceilings.

New Object/Database/View work must not deepen Bookmark-era coupling unless it is an explicit compatibility/migration boundary.

### Failure policy
- Expected compatibility absence stays quiet. For `BookmarkObjectLinkReadStore`, invalid ids or a normal empty query result still return `null` without logging.
- #488 only adds a debug/assert fixed diagnostic when the compatibility SQL lookup itself throws. It does not log workspace ids, bookmark ids, SQL values, URLs, paths, or persisted user content.
- Similar best-effort paths should distinguish expected absence from exceptional infrastructure/query failure instead of mechanically logging every fallback.
- Remaining raw user-visible implementation exception interpolation is concentrated in large/shared legacy hosts; do not reconstruct those hosts merely to change one message string.

### AppDatabase
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Responsibility moves include #281 `BookmarkReadStore`, #282 `ProfilePathResolver`, #283 `SavedViewReadStore`, and #289 `PhotoReadStore`.

Possible future mutation responsibility remains favorite/status/rating/open-count and nearby batch updates that are close passthroughs from `BookmarkRepository`. Only move them when `app_database.dart` can be patched safely and the change deletes real database-root responsibility.

### GenericDatabasePage
Focused extractions include #310 `GenericDatabasePageStateLoader` and #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC.

### Legacy Bookmark compatibility
Canonical Bookmark visual/URL presentation is converged through shared resolvers/components in the inventoried hosts. Legacy Bookmark URL/thumbnail/Photo storage remains live compatibility/import/export data until production caller-zero and migration/backup handling are proven. Presentation convergence alone is not permission to delete storage.

## Confirmed live — not deletion candidates
Recent current-source audits found real production callers for:
- `ObjectDetailContent`, `ObjectDetailContentLoader`, and live rename/typed-Value `ObjectDetailEditService` path;
- Object Body block identity/editor/action/position/reference helpers;
- `ObjectIdentitySearchService`;
- `DailyNoteNavigationService` / `DailyNoteDetailNavigationService`;
- `DatabaseCollectionDefinition`, `DatabaseCollectionResolver` and `DatabaseCollectionConfigService`;
- `GenericObjectViewCoordinator` / `ObjectViewProjection`;
- `DatabaseViewGalleryAdapter`, `DatabaseViewGroupAdapter`, `DatabaseViewCreationService`, `DatabaseViewOpenModeService`;
- `ObjectOpenPresentationService` and current hosts;
- `PdfAnnotationStore`, `PhotoReadStore`, `BookmarkAttachmentStore`;
- `BookmarkResolvedUrlText`, `BookmarkVisualImage`, `AppEmptyState`, `InlineRenameText`, Bookmark lifecycle/state and current Bookmark detail/list/reverse-lookup/property/relation widgets;
- `BacklinkRepository` through live `BookmarkRelationSection`;
- legacy `person_roles.dart` persistence and `BookmarkRepository.watchPersonRoles(...)`;
- legacy `ImageEditorPage` / `ImageEditService` while Photo management still invokes raw-path editing;
- `ObjectBoardCreatePlanner` via production `ObjectBoardCreateService`;
- `lib/database/database_definition.dart` through View stores/services and current management/Stage1/GenericDatabase hosts;
- `GenericDatabaseCollectionPageLoader`, `ObjectAliasStore`, `ObjectTypeTemplateStore`, `SavedViewReadStore`, `WeblinkImageSchemaService` and other inspected small data/services with current production callers.

Future caller-zero deletion requires current `main` verification of the candidate file plus class/function and filename/import references. GitHub code-search indexing can lag recent merges.

## Deferred real cleanup candidates
### Plain-text Body mutation chain
`ObjectBodySection` is gone. `ObjectDetailEditService.setPlainTextBody(...)` has no production caller; `ObjectBodyPlainTextAdapter` is referenced by that dead service method plus dedicated tests.

Fully retiring the chain should remove the now-unneeded body-store/adapter dependency from `ObjectDetailEditService` and its one production constructor in `ObjectInspectorPage`. Do this only when the Inspector constructor/import edit can be applied as a genuinely small hunk; do not replace the whole shared host.

### Temporary Database-presentation re-export shims
Canonical implementations already live under `lib/features/database/presentation/widgets/`. #474/#482 prevent both dependency growth and creation of additional shim files; #499 demonstrates the preferred opportunistic migration pattern. Remove each shim only after every production caller has naturally moved to the canonical feature path.

### Presentation/database reach-through
The ceiling is **9**. Current presentation debt is concentrated in `app_shell.dart`, People/Photo/Collection management, GenericDatabasePage and Stage1. Existing audits found no meaningful Repository/Service boundary that can absorb these remaining constructors/operations without either adding a metric-hiding wrapper or reconstructing a large host. AppShell's `GenericDatabaseStore` use has no existing `BookmarkRepository` passthrough; do not add one solely to lower 9 -> 7.

## Exact next actions
1. Re-read latest `main`, merged `AGENTS.md`, and open PR ownership before every code edit; if #502 lands, adopt its new lane boundaries immediately.
2. Continue current-source caller-zero auditing outside active Object/Relation ownership; delete only when production callers are zero and still-live behavior has independent coverage.
3. Lower any of the **9 / 18 / 5** ceilings when a real cleanup reduces the corresponding measured debt.
4. Retire the plain-text Body chain only when `ObjectInspectorPage` can be patched narrowly.
5. Continue GenericDatabasePage work only via patch-sized extraction of concrete responsibility and only if still owned by Refactor under the latest lane model.
6. Revisit AppDatabase mutation responsibility only when `app_database.dart` can be patched safely and if still in Refactor scope after any lane split.
7. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting legacy storage.
8. Treat Issue #414 as separate search-correctness work unless lane ownership changes assign it elsewhere.

## Validation
- #474 Flutter CI #1646 green before merge.
- #482 Flutter CI #1663 green before merge.
- #485 Flutter CI #1671 green before merge.
- #488 Flutter CI #1676 green before merge.
- #499 Flutter CI #1682 green before merge.

## Risks / sequencing
- parallel lanes can move `main` quickly; rebuild small diffs on current main rather than force-merging stale branches;
- large shared hosts must remain patch-sized;
- connector file writes replace complete existing files, so do not reconstruct a large host for a one-line import/constructor change;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data;
- wrapper-only abstractions that reduce a metric without deleting responsibility should be rejected;
- Image product semantics remain Object-owned and Relation semantics remain Relation-owned until/unless merged lane instructions explicitly change that ownership.

## Continuation state
The obvious whole-module caller-zero candidates found in the latest pass are retired through #472. Refactor now has monotonic CI ratchets for direct database reach-through, legacy shim imports, and shim-file count; the accepted shim-import debt has already ratcheted **22 -> 19 -> 18** without broad production churn.

The next safe Refactor work should be a true caller-zero deletion, a patch-sized responsibility move, or an opportunistic canonical-import migration that lowers an existing ceiling. Do not force the plain-text Body chain, shim removal, or database reach-through cleanup through whole-file reconstruction.
