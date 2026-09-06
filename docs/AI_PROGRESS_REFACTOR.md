# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Object Core owns shared Object/Body product semantics, Relations owns canonical Relation semantics, Database/View owns Database presentation semantics, Primitive Objects & Media owns Weblink/Image/File/etc. product behavior, Search owns indexing/query semantics, and Storage/Vault owns storage/delivery behavior. Lane G owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Latest verified `main` at the current branch/PR checkpoint: **`821c7abb229217a88e5caf88a691d7a0bb2fd458`** after Search **#514**. Parallel lanes move `main` quickly, so re-read it before every merge/shared-host edit.

Integrated in this run:
- **#510 merged** as `1c998a4136e9671a3b5ca4d2d2f32032e195d835` — `maintainability_report.sh --help` no longer duplicates numeric CI ceilings; help uses `<N>` and points to `.github/workflows/flutter_ci.yml`, with a focused regression preventing numeric `--max-*` examples from returning.
- #510 final CI #1723 passed maintainability guardrail tests, current regression ceilings, Drift generation, Analyze and full Test.

Active branch: `refactor/feature-presentation-boundary-225`.
Active PR: **#522 — Cover feature presentation in database boundary guard**.
Current implementation/test commits before this handoff refresh:
- `e2040faafcc51d4e5889eaf31ad8d11691ad478d` — extend presentation/database reach-through scanning from legacy `lib/views` + `lib/widgets` to every `lib/features/**/presentation` tree.
- `ac463ffebb9cbd8faaa06b7578f44207b19eceda` — extend the fixture so feature-owned presentation reach-through is counted and trips the same existing threshold.

Recent integrated architecture-health sequence:
- **#474 merged** — guard temporary Database-presentation shim imports; migrated three test-only imports and ratcheted 22 → 19.
- **#482 merged** — guard the number of Database-presentation re-export shim files; current ceiling 5.
- **#485 merged** — ratchet direct presentation → database reach-through ceiling to 9.
- **#488 merged** — make unexpected Bookmark object-link compatibility-query failures observable with privacy-safe diagnostics while preserving expected-miss fallback behavior.
- **#499 merged** — move `BookmarkAttachmentSection` from the legacy `DetailPropertyRow` shim to the canonical feature import and ratchet shim-import ceiling 19 → 18.
- **#502 merged** — expand repository routing to seven focused lanes.
- **#510 merged** — remove maintainability-help threshold duplication and guard its source-of-truth contract.

## Live open-PR ownership at this checkpoint
Rechecked after #510 merged:
- **Object #503** — owns the patch-sized `ObjectInspectorPage._canEditBody(...)` universal-Body hunk. Lane G must not retire the plain-text Body chain or touch that Inspector seam while #503 remains open.
- **Primitive #498** — owns canonical Image edit composition. Lane G must not alter Image edit/ownership semantics.
- **Refactor #504** — already owns the separate `lib/features` legacy-Bookmark dependency guard plus its CI wiring. Do not duplicate/rewrite that guard from #522; #522 only closes the existing presentation/database reach-through measurement blind spot.
- Storage #509 currently touches `app_database.dart`; do not use AppDatabase narrowing as a pretext to reconstruct that shared hotspot while the Vault path slice is active.

Re-read open PRs again before every shared-hotspot edit because parallel lanes move quickly.

## Current measurable guardrails
Flutter CI currently enforces three monotonic ceilings:

1. Presentation direct `workspaceStore.database` reach-through: **9 references maximum**.
2. Temporary Database-presentation re-export shim imports: **18 imports maximum**.
3. Temporary Database-presentation re-export shim files: **5 files maximum**.

### Presentation reach-through coverage
Before #522, the reach-through scan only covered legacy presentation roots `lib/views` and `lib/widgets`, leaving canonical `lib/features/<feature>/presentation` outside the measurement even though that is the target module layout.

#522 adds every `lib/features/**/presentation` directory to the same scanner. It deliberately:
- does **not** scan feature application/data/service code as presentation debt;
- does **not** create a new threshold;
- does **not** increase the existing ceiling of 9;
- adds a fixture regression proving a feature-presentation `workspaceStore.database` reference is counted.

On #522 head `ac463ff...`, both **Maintainability guardrail tests** and **Maintainability regression ceilings** passed immediately. Therefore the expanded real-repository scan still fits the existing ceiling of 9; canonical feature presentation currently adds no regression requiring the ceiling to be relaxed.

### Legacy Database-presentation shims
Shim-import history:
- initial baseline: **22**;
- #474: three test-only imports moved canonical, **22 → 19**;
- #499: `BookmarkAttachmentSection` moved canonical, **19 → 18**.

Current remaining shim-import distribution from the current source/guardrail history:
- Photo management: 4
- People management: 4
- Collection management: 4
- GenericDatabasePage: 3
- Stage1: 2
- BookmarkReorderableProperties: 1

Do not reconstruct these large/shared hosts merely to lower a metric. Migrate imports when a host can be patched naturally and safely, then ratchet the ceiling in the same or immediately following slice.

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

## 2026-09-07 current-source caller audit
This run re-audited small/medium modules rather than trusting old inventory labels. The following still have real production callers and are **not deletion candidates**:
- `AutoOrganizeService` — BookmarkRepository/settings automation remains live.
- `BookmarkTransferService` — import/export compatibility remains live through `AppShell`.
- `AppSettingsService` and `ProfileStorageMigrator` — composition/bootstrap callers remain live in `main.dart`.
- `DatabaseBackupService` — settings backup section remains live.
- `BookmarkPresentationResolverFactory` — Bookmark visual/URL compatibility hosts still compose through it.
- `GenericDatabaseImageImportService` — `GenericDatabasePageServices` still owns the live composition path.
- `BookmarkObjectLinkReadStore` — canonical/legacy URL and visual resolvers still use it.
- `DatabaseViewQueryAdapter` and `DatabaseViewManagementService` — canonical Object/View projection and Database View tabs still use them.
- `GenericDatabaseCollectionPageData` — state loader/page services/object creation still use it.
- `ObjectBodyBlockActionController` — shared Inspector Body actions still use it.
- `ObjectBoardMoveService` — board creation, GenericDatabasePage and page services still use it.
- `ObjectDetailPropertyPresentation` — Inspector, GenericDatabasePage and canonical feature widgets still use it.
- `ObjectValuePromotion` — promotion execution/Weblink services and Inspector still use it.
- `BacklinkRepository` / `FullTextSearchRepository` — live compatibility/search boundaries.
- Small presentation helpers audited in this pass (`NotionInlineField`, `DetailSection`, `BookmarkResolvedUrlText`, `ObjectTypeTemplatePicker`, `TagDetailPane`) also retain production callers.

`tool/performance_probe.dart` has no import caller, but it is an intentional standalone CLI entrypoint added for repeatable performance measurement and aligns with Issue #225 P3; do not classify CLI/tools as caller-zero merely because production Dart does not import them.

No new safe whole-module production caller-zero deletion was proven in this pass.

## Architecture / responsibility state
### P0 / P3 guardrails
Integrated or active guardrails include:
- `tool/maintainability_report.sh` and fixture regression;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- dependency-boundary guidance in `docs/architecture.md`;
- #401 guard against new direct Bookmark URL/visual resolver construction in presentation;
- #443/#448 presentation/database reach-through measurement and regression ceiling;
- #474 legacy presentation-shim import measurement/ceiling;
- #482 shim-file-count ceiling;
- #485 reach-through ratchet to 9;
- #499 shim-import ratchet to 18;
- #510 non-duplicated maintainability-help source of truth;
- **#522 active** — include canonical feature presentation in the reach-through ceiling;
- **#504 active separately** — forbid new `BookmarkItem` / `BookmarkRepository` dependencies under `lib/features`.

New feature work must not deepen Bookmark-era coupling or bypass application composition by reaching from presentation into the raw workspace database.

### AppDatabase
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Responsibility moves include #281 `BookmarkReadStore`, #282 `ProfilePathResolver`, #283 `SavedViewReadStore`, and #289 `PhotoReadStore`.

Possible future mutation responsibility remains favorite/status/rating/open-count and nearby batch updates that are close passthroughs from `BookmarkRepository`. Move only when `app_database.dart` is not actively leased and the change removes real database-root responsibility rather than adding a wrapper.

### GenericDatabasePage
Focused extractions already integrated:
- #310 `GenericDatabasePageStateLoader`
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC; do not reconstruct the large file through connector whole-file writes.

### Legacy Bookmark compatibility
Canonical Bookmark visual/URL presentation has converged substantially, but legacy `bookmarks.url`, thumbnail, Photo and Bookmark storage remains live compatibility/import/export data until production caller-zero and migration/backup handling are proven. Presentation convergence alone is not permission to delete storage.

## Failure-policy state
The small high-value silent/privacy boundaries are largely complete. #488 clarifies Bookmark object-link fallback policy: a normal missing mirror row remains quiet; a thrown compatibility-query failure may emit a privacy-safe debug/assert diagnostic while the user-visible fallback stays fail-soft.

Remaining raw implementation exception interpolation is concentrated in large/shared legacy hosts. Do not reconstruct those hosts merely to change one error string.

## Deferred real cleanup candidates
### Plain-text Body mutation chain
`ObjectBodySection` is gone. `ObjectDetailEditService.setPlainTextBody(...)` previously had no production caller and `ObjectBodyPlainTextAdapter` was only needed by that dead service method plus dedicated tests.

**Do not retire this chain during Object #503.** Re-audit after #503 merges; if the plain-text path is still caller-zero, remove it only through a genuinely patch-sized Inspector/service change.

### Temporary Database-presentation re-export shims
Canonical implementations live under `lib/features/database/presentation/widgets/`. The remaining 18 imports are concentrated in shared/large production hosts. Remove a shim only after all real callers naturally move to canonical imports.

### Presentation/database reach-through
The accepted ceiling remains 9. #522 broadens where that ceiling is enforced; it does not hide or redistribute existing debt. Lower the ceiling only when a real responsibility move removes reach-through.

## Exact next actions
1. Validate/merge **#522**; fix only failures caused by expanded presentation scanning/test coverage.
2. Do not duplicate **#504** while it owns the separate feature legacy-Bookmark dependency guard/CI slice; re-evaluate after it merges/closes.
3. Re-run current-source caller-zero audits after parallel lane merges; delete only when production callers are zero and surviving behavior has independent coverage.
4. After Object #503 merges, re-audit the plain-text Body chain before touching `ObjectInspectorPage`.
5. Lower shim-import ceiling below 18 only when a production host can safely switch to canonical imports without whole-file reconstruction.
6. Lower presentation/database ceiling below 9 only when a real responsibility move removes reach-through.
7. Continue GenericDatabasePage P1 only via patch-sized extraction of concrete schema/database action, Property workflow, or layout-host responsibility.
8. Revisit AppDatabase mutation responsibility only after Storage #509/shared-hotspot ownership clears.
9. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
10. Treat search correctness/index semantics as Search-lane work rather than a Refactor pretext for semantic change.

## Validation
- #510 final CI #1723: maintainability guardrail tests **pass**, regression ceilings **pass**, Drift generation **pass**, Analyze **pass**, full Test **pass**.
- #510 merged as `1c998a4136e9671a3b5ca4d2d2f32032e195d835`.
- Before #510 merge, parallel main changes through Relation/Object/Database-View work were compared and did not overlap #510's files.
- Current CI-owned guardrail values remain **9 / 18 / 5**.
- #522 first implementation/test head `ac463ff...`: Maintainability guardrail tests **pass** and Maintainability regression ceilings **pass** with `lib/features/**/presentation` included; full Flutter setup/Analyze/Test were still running before this handoff-doc commit advanced the PR head.

## Risks / sequencing
- parallel lanes can move `main` quickly; compare/re-read before merge;
- #503 owns `ObjectInspectorPage`; #498 owns canonical Image edit composition; #509 touches AppDatabase; #504 owns the separate feature legacy-dependency CI guard;
- large shared hosts must remain patch-sized;
- connector file writes replace complete existing files, so do not reconstruct a large host for a one-line import/constructor change;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data;
- wrapper-only abstractions that reduce a metric without deleting responsibility should be rejected;
- product semantics remain with their owning lanes; Lane G is behavior-preserving by default.

## Stop/continuation state
#510 is integrated and #522 is the active safe G-lane slice. The expanded guard already proves canonical feature presentation can be brought under the existing ceiling without relaxing it. After #522 validation/merge, the obvious next cleanup targets remain sequenced behind active shared-hotspot ownership or already-active #504 guard work; do not manufacture a duplicate abstraction merely to keep the lane busy.
