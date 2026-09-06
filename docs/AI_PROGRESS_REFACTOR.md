# AI Progress — Refactor & Architecture Health lane

> Durable handoff for behavior-preserving maintainability work. Always re-read live GitHub state before editing shared code; PR/commit numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate/unused legacy paths while preserving product behavior.

Primary lane: **G — Refactor & Architecture Health**. Object Core owns shared Object/Body product semantics, Relations owns canonical Relation semantics, Database/View owns Database presentation semantics, Primitive Objects & Media owns Weblink/Image/File/etc. product behavior, Search owns indexing/query semantics, and Storage/Vault owns storage/delivery behavior. Lane G owns measurable responsibility reduction, proven caller-zero retirement, failure-policy/privacy cleanup, maintainability guardrails, architecture-health audits, and incremental legacy shim retirement.

## Current checkpoint — 2026-09-07
Latest verified `main` at branch creation: **`844f6b77e7b6947bceaaf6986e6ff8182212e71b`** after Refactor **#499**.

Active branch for this checkpoint: `refactor/guardrail-help-handoff-225`.

Current Lane G commits:
- `c933efe47bd2b28b81bd07fa231361d85ddfd030` — initially aligned stale `maintainability_report.sh --help` threshold examples with the then-current ceilings.
- `268f678bf1243dc1afc635deefd32976f9c04f3e` — removed threshold literals from the help examples entirely and pointed users to the CI workflow as the single current-ceiling source, preventing the same documentation drift on future ratchets.

Recent integrated architecture-health sequence:
- **#474 merged** — guard temporary Database-presentation shim imports; migrated three test-only imports and ratcheted 22 → 19.
- **#482 merged** — guard the number of Database-presentation re-export shim files; current ceiling 5.
- **#485 merged** — ratchet direct presentation → database reach-through ceiling to 9.
- **#488 merged** — make unexpected Bookmark object-link compatibility-query failures observable with privacy-safe diagnostics while preserving expected-miss fallback behavior.
- **#499 merged** as `844f6b77...` — move `BookmarkAttachmentSection` from the legacy `DetailPropertyRow` shim to the canonical feature import and ratchet shim-import ceiling 19 → 18.
- **#502 merged** — expand repository routing to seven focused lanes; this handoff now follows Lane G ownership.

Adjacent Object/Primitive work after the prior Refactor handoff is architecture-relevant but not Lane G product ownership. In particular, Image media/edit behavior remains outside Lane G.

## Live open-PR ownership at this checkpoint
Rechecked directly before this run's writes:
- **Object #503** — open and mergeable; owns the patch-sized `ObjectInspectorPage._canEditBody(...)` hunk plus universal-Body regression coverage. Lane G must not touch `ObjectInspectorPage` or retire the plain-text Body chain while this shared host is actively changing.
- **Primitive #498** — open and mergeable; owns `CanonicalImageEditService.fromStores(...)` plus its focused test. Lane G must not alter canonical Image edit composition/ownership semantics.
- Refactor **#500 is closed and unmerged**; it does not own `docs/AI_PROGRESS_REFACTOR.md`.

Re-read open PRs again before every shared-hotspot edit because parallel lanes move quickly.

## Current measurable guardrails
Flutter CI currently enforces three monotonic ceilings:

1. Presentation direct `workspaceStore.database` reach-through: **9 references maximum**.
2. Temporary Database-presentation re-export shim imports: **18 imports maximum**.
3. Temporary Database-presentation re-export shim files: **5 files maximum**.

Shim-import history:
- initial baseline: **22**;
- #474: three test-only imports moved canonical, **22 → 19**;
- #499: `BookmarkAttachmentSection` moved canonical, **19 → 18**.

Current remaining shim-import distribution inferred from the current source/guardrail history is:
- Photo management: 4
- People management: 4
- Collection management: 4
- GenericDatabasePage: 3
- Stage1: 2
- BookmarkReorderableProperties: 1

Do not reconstruct these large/shared hosts merely to lower a metric. Migrate imports when a host can be patched naturally and safely, then ratchet the ceiling in the same or immediately following slice.

### Guardrail help drift fixed in this run
`tool/maintainability_report.sh` already accepted caller-supplied thresholds correctly, but its `--help` usage block embedded a stale historical checkpoint. This run changed the help examples to use `<N>` placeholders and names `.github/workflows/flutter_ci.yml` as the source for the current CI-owned ceilings. Report/threshold behavior is unchanged, and future ratchets no longer require updating example literals.

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
This run deliberately re-audited small/medium modules rather than trusting old inventory labels. The following still have real production callers and are **not deletion candidates**:
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
- `BacklinkRepository` / `FullTextSearchRepository` — the only repository-layer modules remain live compatibility boundaries.
- Small presentation helpers audited in this pass (`NotionInlineField`, `DetailSection`, `BookmarkResolvedUrlText`, `ObjectTypeTemplatePicker`, `TagDetailPane`) also retain production callers.

No new whole-module production caller-zero deletion was proven in this pass. Do not delete any of the above simply to reduce LOC.

## Architecture / responsibility state
### P0 guardrails
Integrated guardrails include:
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
- #499 shim-import ratchet to 18.

New feature work must not deepen Bookmark-era coupling unless it is an explicit compatibility/migration boundary.

### AppDatabase
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Responsibility moves include #281 `BookmarkReadStore`, #282 `ProfilePathResolver`, #283 `SavedViewReadStore`, and #289 `PhotoReadStore`.

Possible future mutation responsibility remains favorite/status/rating/open-count and nearby batch updates that are close passthroughs from `BookmarkRepository`. Move only when `app_database.dart` can be patched safely and the change removes real database-root responsibility rather than adding a wrapper.

### GenericDatabasePage
Focused extractions already integrated:
- #310 `GenericDatabasePageStateLoader`
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)`

Remaining high-value responsibility includes schema/database actions, Property create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC.

### Legacy Bookmark compatibility
Canonical Bookmark visual/URL presentation has converged substantially, but legacy `bookmarks.url`, thumbnail, Photo and Bookmark storage remains live compatibility/import/export data until production caller-zero and migration/backup handling are proven. Presentation convergence alone is not permission to delete storage.

## Failure-policy state
The small high-value silent/privacy boundaries are largely complete. #488 clarifies Bookmark object-link fallback policy: a normal missing mirror row remains quiet; a thrown compatibility-query failure may emit a privacy-safe debug/assert diagnostic while the user-visible fallback stays fail-soft.

Remaining raw implementation exception interpolation is concentrated in large/shared legacy hosts. Do not reconstruct those hosts merely to change one error string.

## Deferred real cleanup candidates
### Plain-text Body mutation chain
`ObjectBodySection` is gone. `ObjectDetailEditService.setPlainTextBody(...)` previously had no production caller and `ObjectBodyPlainTextAdapter` was only needed by that dead service method plus dedicated tests.

**Do not retire this chain during Object #503.** `ObjectInspectorPage` is actively owned by the universal-Body PR, and universal Body semantics are changing in the shared host. Re-audit after #503 merges; if the plain-text path is still caller-zero, remove it only through a genuinely patch-sized Inspector/service change.

### Temporary Database-presentation re-export shims
Canonical implementations live under `lib/features/database/presentation/widgets/`. The remaining 18 imports are concentrated in shared/large production hosts. Remove a shim only after all real callers naturally move to canonical imports; do not hand-reconstruct a hotspot for a one-line import change.

### Presentation/database reach-through
The accepted ceiling is now 9. Known direct reach-through is concentrated in shared legacy/Database hosts. Do not introduce a page-specific wrapper merely to hide `workspaceStore.database`; the next reduction must move or delete real responsibility.

## Exact next actions
1. Validate/merge the current Lane G PR for the guardrail-help drift fix plus this handoff refresh; fix only failures caused by this slice.
2. Re-run current-source caller-zero audits after parallel lane merges; delete only when production callers are zero and surviving behavior has independent coverage.
3. After Object #503 merges, re-audit the plain-text Body chain before touching `ObjectInspectorPage`.
4. Lower shim-import ceiling below 18 only when a production host can safely switch to canonical imports without whole-file reconstruction.
5. Lower presentation/database ceiling below 9 only when a real responsibility move removes reach-through.
6. Continue GenericDatabasePage P1 only via patch-sized extraction of concrete schema/database action, Property workflow, or layout-host responsibility.
7. Revisit AppDatabase mutation responsibility only when `app_database.dart` can be patched safely without monolithic reconstruction.
8. Follow Object-first storage retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
9. Treat search correctness (including Issue #414) as Search-lane work, not a Refactor pretext for semantic change.

## Validation
- Current main guardrail values were verified directly from `.github/workflows/flutter_ci.yml`: **9 / 18 / 5**.
- #499 diff was verified directly: canonical import migration for `BookmarkAttachmentSection`, CI/doc ceiling 19 → 18, and maintainability documentation.
- #503 and #498 ownership were rechecked directly and are both open/mergeable at this checkpoint.
- On PR #510's first head, both **Maintainability guardrail tests** and **Maintainability regression ceilings** passed before the help examples were generalized; the final head must rerun CI after `268f678b...`.
- This run's tool change remains comment/help-text only; behavior of `maintainability_report.sh` is unchanged. CI should run the existing guardrail tests/current ceilings, Analyze and full Test on the final PR head.

## Risks / sequencing
- parallel lanes can move `main` quickly; re-read open PR ownership before shared code changes;
- Object #503 owns `ObjectInspectorPage` now; Primitive #498 owns canonical Image edit composition;
- large shared hosts must remain patch-sized;
- connector file writes replace complete existing files, so do not reconstruct a large host for a one-line import/constructor change;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data;
- wrapper-only abstractions that reduce a metric without deleting responsibility should be rejected;
- product semantics remain with their owning lanes; Lane G is behavior-preserving by default.

## Stop/continuation state
This pass did not prove another safe whole-module caller-zero deletion. The next obvious code cleanup (plain-text Body chain) is temporarily blocked by active Object #503 ownership of the shared Inspector, while the remaining shim-import reductions sit in large/shared hosts that should not be reconstructed through whole-file connector writes merely to change imports.

A concrete architecture-health defect was fixed at its source: `maintainability_report.sh --help` no longer hard-codes historical threshold values, so future guardrail ratchets have one CI-owned source of truth instead of a second drifting example. Continue from the exact next actions above after checking the live repository state again.
