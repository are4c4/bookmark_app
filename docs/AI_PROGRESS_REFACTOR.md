# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, caller-zero retirement after proof, failure-policy/privacy cleanup, maintainability guardrails, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Latest verified `main`: **`b5f589cb4e1d4efc42a592ab452963c1a714f7fb`**.

Recent main sequence relevant to Refactor:
- **#467 merged** — make unexpected canonical Image visual file-probe failures observable without changing fail-soft behavior.
- **#472 merged** — retire caller-zero `PersonRoleProperties` plus its dead-only source-string architecture test.
- **#468 merged** as `fc15dc004f8c16873bd89c40d2d76bc7f03ddc9a` — Relation handoff refresh only; no Relation production semantics.
- `b5f589cb...` finalizes that Relation handoff after merge.

Current open PR ownership:
- **Refactor #470** — this docs-only handoff refresh.
- **Object #469** — safe vertical flip for canonical Image actions; owns `ObjectImageEditActions` and focused tests.
- **Object #473** — missing/partial canonical Image geometry fallback; owns `ImageVisualResolver` and its focused tests. Refactor must not touch that resolver while #473 is open.
- **Object #471** — Object handoff refresh only; docs-only.

Re-read live ownership before every shared-host edit because parallel lanes move `main` quickly.

The CI presentation/database boundary guard introduced by #443 is enforced by #448 at a ceiling of **12** `workspaceStore.database` references. Ratchet the ceiling downward only when a real Refactor slice removes measured presentation reach-through; do not add wrappers merely to hide the metric.

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
- Do not mechanically log expected compatibility misses. `BookmarkObjectLinkReadStore` intentionally fails soft when mirrored Object-link storage is absent/unavailable on older/pre-sync data; routine logging there would add noise without improving recovery.
- Raw persisted/request user content must not be interpolated merely to make diagnostics more verbose.

Object #473 now owns further `ImageVisualResolver` behavior. Refactor must not overlap it while open.

## Cross-lane ownership
### Object lane
Recent merged Image product work includes #457 detail panel composition, #460 crop presets, and #465 safe free-crop routed through `CanonicalImageEditService`.

Active production ownership:
- #469 — canonical Image edit actions.
- #473 — canonical Image visual geometry fallback / `ImageVisualResolver`.

Refactor must not alter canonical Image byte mutation, file ownership/copy-on-edit, Photo mapping, managed geometry semantics, or the files currently owned by #469/#473.

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

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include #281 `BookmarkReadStore`, #282 `ProfilePathResolver`, #283 `SavedViewReadStore`, and #289 `PhotoReadStore`.

Possible future AppDatabase work remains favorite/status/rating/open-count and nearby batch state mutations that are close passthroughs from `BookmarkRepository`. Only move them when the change removes real database-root responsibility and `app_database.dart` can be patched safely; do not reconstruct the file wholesale.

### Legacy Bookmark presentation / retirement
Canonical Bookmark visual/URL presentation now routes through shared resolvers/components in the previously inventoried hosts. Whole-module caller-zero retirement is preferred to speculative wrappers.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain live compatibility/import/export data until production caller-zero and migration/backup policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices include #310 `GenericDatabasePageStateLoader` and #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibility includes schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC.

## Dependency-composition state
Presentation `workspaceStore.database` reach-through remains enforced at **12**.

Known remaining reach-through is concentrated in `app_shell.dart`, People/Photo/Collection management, Stage1 and `generic_database_page.dart`.

`DatabaseViewStore` composition still has several genuine callers. There is no meaningful existing boundary that can absorb the presentation constructors without either touching conflict-prone hosts or adding a wrapper solely to lower the metric. Do not create such an abstraction until at least two real callers lose actual responsibility.

`CollectionManagementPage` create/delete/membership already use `BookmarkRepository`, while rename/note persistence still updates `database.collections` directly. There is no existing semantic update API. Do not add a one-caller wrapper merely to hide access, and do not reconstruct `app_database.dart`/a large repository file through connector writes.

People management has the same constraint: hiding `PersonGroupStore`/`DatabaseViewStore` construction behind a page-specific composition wrapper would not reduce responsibility.

## Caller-zero audit notes
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
- Bookmark state/lifecycle enums;
- `BookmarkReorderableProperties`, `BookmarkListMetadata`, `BookmarkResolvedUrlText`, `BookmarkReverseLookupDialog`;
- legacy `ImageEditorPage` / `ImageEditService`, because Photo management still invokes the raw-path editor;
- `ObjectBoardCreatePlanner`, because it is the default live planner inside production `ObjectBoardCreateService` and participates in grouped/Relation preset semantics;
- `DatabaseViewCreationService`, `GenericDatabaseCollectionPageLoader`, `ObjectAliasStore`, `ObjectTypeTemplateStore`, `SavedViewReadStore`, `WeblinkImageSchemaService` and the other inspected small data/services with real production callers.

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

2. **`lib/widgets/detail_property_row.dart` re-export shim**
   - Canonical implementation: `lib/features/database/presentation/widgets/detail_property_row.dart`.
   - Remaining shim consumers after #472 are `bookmark_attachment_section.dart`, `bookmark_reorderable_properties.dart`, plus one test import.
   - `bookmark_reorderable_properties.dart` is a large legacy host; do not replace it wholesale for a one-line import change.

Future caller-zero searches must verify the candidate file itself plus class/function and filename/import references on current `main`; GitHub code-search indexing can lag recent merges.

## Exact next actions
1. Re-read latest `main` and open PR ownership before every code edit.
2. Merge this handoff only after its latest head has green CI and remains mergeable on current main.
3. Post an Issue #225 checkpoint after #470 lands, recording #467/#472, net -1,770 LOC, active Object ownership, and the two connector-blocked cleanup chains.
4. Continue caller-zero auditing outside active Image/Relation ownership; delete only when production callers are zero and still-live behavior has independent coverage.
5. Prefer real responsibility/LOC reduction over wrappers added solely to hide property access.
6. Retire the plain-text Body chain only when `ObjectInspectorPage` can be patched narrowly.
7. Retire the `detail_property_row.dart` shim only when `bookmark_reorderable_properties.dart` can be patched narrowly or is already being safely touched.
8. If a presentation `workspaceStore.database` reference is genuinely removed, lower the CI ceiling from 12 with the responsibility move.
9. Revisit Collection/People dependency reach-through only when an existing meaningful boundary can absorb the responsibility.
10. Continue GenericDatabasePage P1 only through patch-sized extraction of concrete schema/database action, Property workflow, or layout-host responsibility.
11. Revisit AppDatabase mutations only when `app_database.dart` can be patched safely.
12. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
13. Treat Issue #414 as separate search-correctness work.

## Validation
- #467 Flutter CI #1618 green.
- #472 Flutter CI #1623 green before merge.
- #470 prior handoff head `83f81c4a598ac3e4881076837f41a6ecccdaad69` passed Flutter CI #1629, including maintainability guardrails, Drift generation, Analyze and full Test.
- The current handoff commit changes documentation only; recheck CI for the new head before integration.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small diffs on latest main rather than force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- connector file writes replace complete existing files, so do not reconstruct a large host merely for a small hunk;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- abstractions that add wrappers without removing responsibility should be rejected;
- stale code-search results can lag main;
- Object #469/#473 currently own canonical Image action/resolver behavior.

## Stop / continuation state
The latest obvious whole-module caller-zero candidates were retired through #472. Fresh audits found real production callers for the other inspected small modules. Two genuine cleanup chains remain (`ObjectBodyPlainTextAdapter`/`setPlainTextBody` and the `detail_property_row.dart` shim), but both currently require a one-line change inside a substantially larger shared/legacy host and should wait for a hunk-sized edit path rather than trigger whole-file reconstruction.

Safe Refactor work should continue from live ownership audits and only take caller-zero deletions, patch-sized responsibility moves, or explicit failure-policy/guardrail work that does not overlap active Object/Relation semantics.