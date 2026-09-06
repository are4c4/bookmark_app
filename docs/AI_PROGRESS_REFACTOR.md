# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always read live GitHub state before editing; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, caller-zero retirement after proof, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-07
Latest verified `main` for this handoff: **`2b25c55bd621ad438290923995c24756827beb53`** after Refactor #463/#464/#466 and Object #465.

At this checkpoint there were **no open PRs**. Re-read live PR ownership before every shared-host edit because Object/Relation work moves main quickly.

The CI presentation/database boundary guard introduced by #443 is enforced by #448 at a ceiling of **12** `workspaceStore.database` references. The local report remains non-blocking unless a threshold is supplied. Ratchet the CI ceiling downward only when a Refactor slice actually removes a measured presentation reach-through; do not add wrappers merely to hide the metric.

## Latest caller-zero cleanup series
Merged behavior-preserving cleanup PRs in the current series:
- **#451 merged** — retired the caller-zero Object detail session composition chain (`ObjectDetailRelationContextLoader`, `ObjectDetailSessionLoader`, `ObjectTypeDefaultsService` and dead-only models/tests), **337 deletions / 0 additions**.
- **#453 merged** — retired unused drag/drop intent payload/target hierarchy, **49 deletions / 0 additions**; Flutter CI #1577 green.
- **#454 merged** — retired caller-zero `ObjectBodyReferenceIndex` and its dead-only test, **106 deletions / 0 additions**; Flutter CI #1578 green.
- **#455 merged** — retired caller-zero `ObjectBodyBlockValidator` and removed only validator-specific assertions while preserving live Object Body factory/reference/round-trip coverage, **116 deletions / 1 addition**; Flutter CI #1582 green.
- **#458 merged** — retired caller-zero `ObjectGroupMode` while preserving live `ObjectGroupRule` / `ObjectGroupBucket`, **4 deletions / 0 additions**; Flutter CI #1590 green.
- **#459 merged** — retired caller-zero `ResolvedObjectTypeDefaults` / `ObjectTypeDefaultsResolver` and its dead-only test while preserving live `ObjectTypeDefaults` / `ObjectOpenMode` persistence and presentation consumers, **84 deletions / 0 additions**; Flutter CI #1591 green.
- **#463 merged** — retired the caller-zero Object detail Value editor/descriptor/input-codec mini-layer plus dead-only tests while keeping live `ObjectDetailEditService`, **480 deletions / 0 additions**; Flutter CI #1608 green.
- **#464 merged** — retired caller-zero `DatabaseRecordAdapter<T>`, `DatabasePropertyValue`, and the abandoned database-property presenter module, **89 deletions / 0 additions**; Flutter CI #1609 green.
- **#466 merged** — retired the old paragraph-only `ObjectBodySection` compatibility widget and its dead-only widget regression, **216 deletions / 0 additions**; Flutter CI #1612 green.

Combined for #451/#453/#454/#455/#458/#459/#463/#464/#466: **1,481 deletions / 1 addition, net -1,480 LOC**.

**#456 merged** refreshed the handoff after the first cleanup batch. Its first CI attempt was externally cancelled during Flutter setup after both maintainability guards passed; rerun attempt 2 completed successfully before merge.

Stale docs-only PR #452 was closed rather than force-merged after main moved.

Shared hotspots (`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `app_database.dart`) were deliberately not rewritten in these cleanup PRs.

## Cross-lane ownership
### Object lane
Recent Object product work is now merged through:
- **#457 merged** — canonical Image detail preview/edit panel composition.
- **#460 merged** — safe canonical Image crop presets.
- **#465 merged** — safe free-crop selector/dialog routed through `CanonicalImageEditService`; latest main for this handoff is the #465 merge commit.

At the latest live check there were no open Object PRs. Object handoff text is stale relative to #457/#460/#465, so trust live GitHub state first.

Refactor must still avoid changing canonical Image byte-edit/file-ownership semantics, Photo mapping, or Relation semantics. `ObjectInspectorPage` remains a shared hotspot and should only be touched through a genuinely patch-sized write path; do not reconstruct the whole file to remove one argument/import.

### Relation lane
No open Relation production PR was present at the latest live open-PR check. Canonical Relation mutation/read/index/backlink/audit/reconcile semantics remain Relation-owned. Refactor must not create alternate Relation writes, indexes, repair paths, or presentation-side mutation.

## Recent Refactor convergence
- **#373 merged** — Bookmark visual/lifecycle URL presentation delegates resolver composition to `BookmarkPresentationResolverFactory`.
- **#374 merged** — backup workflow moved out of `SettingsPage` into `DatabaseBackupSettingsSection`.
- **#377 merged** — maintainability reporting exposes presentation `workspaceStore.database` reach-through without failing existing debt.
- **#383 merged** — duplicate Bookmark -> mirrored Object lookup SQL/catch logic centralized in `BookmarkObjectLinkReadStore`.
- **#395 merged** — reverse-lookup resolver composition delegates to the shared factory.
- **#400 merged** — backup section no longer reaches through `BookmarkRepository` to `workspaceStore.database`.
- **#401 merged** — architecture guard prevents new direct Bookmark URL/visual resolver construction in presentation.
- **#404/#406 merged** — optional Image/Weblink diagnostics are privacy-safe while preserving fail-soft behavior.
- **#408 merged** — `BacklinkRepository` delegates focused relation reads through `BookmarkRepository.watchRelationsForBookmark(...)`.
- **#417 merged** — retired caller-zero `saved_view_extensions.dart` and dead-only tests.
- **#422 merged** — deduplicated Bookmark -> FTS projection SQL used by rebuild and focused refresh.
- **#431 merged** — retired caller-zero `DailyNoteDetailService` plus dead-only tests, deleting 94 LOC.
- **#439 merged** — `NotionBookmarkCard` delegates URL resolver composition through `BookmarkPresentationResolverFactory`.
- **#443 merged** — opt-in presentation/database reach-through regression threshold plus fixture regression test.
- **#448 merged** — enforces the accepted repository boundary ceiling of 12 in Flutter CI.
- **#451/#453/#454/#455/#458/#459/#463/#464/#466 merged** — latest caller-zero retirement series described above.

Issue #414 separately tracks possible FTS focused-refresh stale-token correctness. Do not turn that semantic question into behavior-preserving cleanup.

## Major completed checkpoints
### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh` and `docs/MAINTAINABILITY.md`;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- #401 direct Bookmark resolver construction guard;
- #443 opt-in boundary threshold and fixture coverage;
- #448 actual CI enforcement at 12 references.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

A possible future AppDatabase target remains favorite/status/rating/open-count plus batch state updates that are near-passthrough calls from `BookmarkRepository` into the database root. Only move them when the change deletes real database-root responsibility and `app_database.dart` can be patched safely; do not reconstruct the file wholesale.

### Legacy Bookmark presentation / retirement
The originally inventoried direct Bookmark visual duplicates are canonicalized through `BookmarkVisualImage`. Canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and Bookmark List metadata.

#401 prevents new direct URL/visual resolver construction in presentation. #439 removed the remaining known direct Notion-card URL resolver construction.

Whole-module caller-zero retirement is preferred to speculative compatibility wrappers. Current examples include #417, #431 and the #451–#466 cleanup series.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain live compatibility/import/export data until production caller-zero and migration/backup policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Do not reconstruct the large host for a small hunk.

### Failure policy / diagnostic privacy
Intentional fail-soft behavior stays fail-soft; rollback cleanup never replaces the primary failure; user-visible errors use stable messages; debug diagnostics avoid raw persisted/request user content. Remaining raw exception interpolation is concentrated in large/shared legacy hosts and should not trigger isolated logging churn.

## Dependency-composition state
Presentation database reach-through is measured by `tool/maintainability_report.sh` and enforced in CI at **12**. Confirmed reductions include resolver composition (#373/#395/#439), backup composition (#400) and focused Bookmark backlink reads (#408).

Known remaining reach-through is concentrated in `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`. Photo management remains adjacent to Object-owned Image semantics.

`DatabaseViewStore` composition has several genuine callers (`PhotoManagementPage`, `PeopleManagementPage`, `CollectionManagementPage`, Stage1, Object Inspector and GenericDatabasePage services), but there is no single existing boundary that can absorb the presentation constructors without either touching conflict-prone hosts or adding a factory/wrapper solely to lower the metric. `GenericDatabasePageServices` already owns its own composition. Do not introduce a new composition abstraction until at least two real callers can lose responsibility through the same meaningful boundary.

`CollectionManagementPage` was re-audited: collection create/delete/membership already use `BookmarkRepository`, while rename and note persistence still update `database.collections` directly. There is no existing semantic update API. Do **not** add a one-caller wrapper merely to hide the access, and do not reconstruct `app_database.dart`/a large repository file through connector writes. Revisit only when a patch-sized existing boundary can own those mutations. Until then the CI ceiling remains 12.

People management has the same constraint: composing `PersonGroupStore` and `DatabaseViewStore` behind a page-specific wrapper would hide reach-through without deleting responsibility, so it remains deferred.

## Caller-zero audit notes from this checkpoint
Confirmed live and therefore **not** deletion candidates include:
- `ObjectDetailContent`, `ObjectDetailContentLoader`, and live `ObjectDetailEditService` rename/typed-Value path;
- `ObjectBodyBlockIdAllocator` / `ObjectBodyBlockDuplicator`;
- `ObjectBodyEditor` and Object Body action/position/reference helpers;
- `ObjectIdentitySearchService` / Object reference catalog path;
- `DailyNoteDetailNavigationService`;
- `DatabaseCollectionResolver` / `DatabaseCollectionConfigService` and collection loading path;
- `GenericObjectViewCoordinator` / `ObjectViewProjection`;
- `DatabaseViewOpenModeService` / View tabs / Object opening path;
- `PdfAnnotationStore` / attachment viewer path;
- `PhotoReadStore`;
- `BookmarkAttachmentStore` / attachment UI, drop and deletion paths;
- Bookmark state/lifecycle enums used by repository/lifecycle code;
- legacy `ImageEditorPage` / `ImageEditService`, because Photo management still invokes the raw-path editor;
- live `ObjectTypeDefaults` / `ObjectOpenMode` storage and open-presentation consumers.

Confirmed dead and removed in this series:
- Object detail session composition chain (#451);
- drag/drop intent type hierarchy (#453);
- `ObjectBodyReferenceIndex` (#454);
- `ObjectBodyBlockValidator` (#455);
- `ObjectGroupMode` (#458);
- `ResolvedObjectTypeDefaults` / `ObjectTypeDefaultsResolver` (#459);
- Object detail Value editor/descriptor/input codec (#463);
- abandoned Database record adapter/property presenter layer (#464);
- old paragraph-only `ObjectBodySection` compatibility widget (#466).

### Deferred dead-chain candidates because of connector/write shape
Two follow-up candidates are real but should not be forced with whole-file rewrites:

1. **Plain-text Body mutation chain**
   - `ObjectBodySection` is now gone.
   - `ObjectDetailEditService.setPlainTextBody(...)` has no production caller; remaining calls are regression-only.
   - `ObjectBodyPlainTextAdapter` is now referenced by that dead service method plus its dedicated test.
   - Fully retiring this chain should also remove the now-unneeded `bodyStore`/adapter dependency from `ObjectDetailEditService` and its one production constructor in `ObjectInspectorPage`.
   - Do this only when the Inspector change can be applied as a small hunk. Do not replace the entire ~34 KB Inspector file for one constructor argument.

2. **`lib/widgets/detail_property_row.dart` re-export shim**
   - Canonical implementation is `lib/features/database/presentation/widgets/detail_property_row.dart`.
   - Remaining shim consumers are `person_role_properties.dart`, `bookmark_attachment_section.dart`, `bookmark_reorderable_properties.dart`, plus one test import.
   - The first two/test are easy, but `bookmark_reorderable_properties.dart` is ~18 KB and currently requires whole-file replacement for a one-line import change through the connector.
   - Remove the shim when a hunk-sized edit path is available or when that legacy widget is otherwise being safely touched.

Future caller-zero searches must re-run current-source and filename/import searches against latest main before deletion; stale GitHub search-index hits are not sufficient proof by themselves.

## Exact next actions
1. Re-read live open PR ownership and latest main before any code edit.
2. Continue current-source caller-zero auditing outside active Image/Relation ownership; delete only when production callers are zero and any still-live behavior has independent coverage.
3. Prefer a real responsibility/LOC reduction over wrappers added solely to hide property access.
4. Retire the plain-text Body chain when `ObjectInspectorPage` can be changed as a genuinely patch-sized hunk; do not whole-file rewrite the host.
5. Retire the `detail_property_row.dart` shim when the remaining import in `bookmark_reorderable_properties.dart` can be changed without whole-file reconstruction.
6. If a presentation `workspaceStore.database` reference is genuinely removed, lower the CI ceiling from 12 in the same focused PR or an immediately following focused guardrail PR.
7. Revisit Collection management rename/note persistence only when an existing meaningful Store/Repository boundary can absorb it through a patch-sized edit.
8. Revisit `DatabaseViewStore` presentation composition only when at least two callers can use one meaningful existing boundary without touching active/conflict-prone hosts merely for metric reduction.
9. Continue GenericDatabasePage P1 only when a safe extraction removes concrete schema/database action, Property workflow or layout-host responsibility.
10. Revisit AppDatabase mutation responsibility only when `app_database.dart` can be patched safely without whole-file reconstruction.
11. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
12. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.
13. Treat Issue #414 as separate search correctness work.

## Validation expectations
- P0 tooling: focused shell fixture regression, actual repository report with CI ceiling, plus Flutter Analyze/Test baseline;
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- caller-zero deletion: current production-code search plus import/file-name audit and independent coverage for still-live behavior;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- legacy storage deletion: prove production caller-zero and import/export/backup handling first.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small diffs on latest main rather than force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- connector file writes replace complete files, so do not reconstruct a large host merely for a small hunk;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- abstractions that add wrappers without removing responsibility should be rejected;
- stale search-index results can lag main, so verify candidate files and callers against current-source content before deletion.

## Stop / continuation state
The latest obvious whole-module caller-zero candidates were retired through #463/#464/#466. Fresh audits found live callers for the other inspected small modules. Two genuine cleanup chains remain (`ObjectBodyPlainTextAdapter`/`setPlainTextBody` and the `detail_property_row.dart` shim), but both currently need a one-line change inside a substantially larger file and should wait for a patch/hunk-sized edit path rather than trigger whole-file reconstruction.

Safe next Refactor work should therefore begin from a fresh live ownership audit and proceed only when a true caller-zero module or patch-sized existing responsibility boundary is found. Avoid Relation semantics, Object-owned Image mutation policy, and large-host reconstruction.
