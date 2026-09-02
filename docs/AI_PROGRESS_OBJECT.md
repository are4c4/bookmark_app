# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

Issue #56 is the active product/design contract and contains delivery Milestones A–D.

## Current integration state

`main` includes the major Object/Relation foundations plus the following current Database/View work:

- PR #79 merged: grouped Board Object creation planner/service, including Relation-safe grouped initialization.
- PR #82 merged as `689c84de46cee1292f7f126eb3d5719658f8d8e8`: Phase-1 `Database = target ObjectType + collectionFilter`, separate persistence, resolver, config service, and Database-first/View-second projection composition. Latest head CI #474 passed before merge.
- PR #85 merged: focused Database collection settings dialog, including target ObjectType selection and collection-filter editing without leaking View state.
- PR #86 merged as `d3632b2ac725a87b3eae66eb86e582d5c3bd5544`: `GenericDatabaseCollectionPageLoader` keeps Database identity/View scope on the collection container while loading filtered Objects/records/Properties from the configured target ObjectType. CI #477 passed before merge.
- PR #87 merged as `13e301634c764e252263647e700638d0e06d4e5a`: collection-aware normal/Board Object creation plus canonical Object-owned Relation editor adapter. CI #480 passed before merge.
- PR #88 merged as `2ba2142d13de7e7a3a60cf0de1b7f4dea4bdf878`: adopted dual-path View creation service (duplicate-current primary, blank secondary) with independent persisted identities. CI #481 passed before merge.

PR #83 remains closed/unmerged and is not an active implementation branch.

## Completed checkpoints in this run

1. **Validated and advanced Database collection foundations**
   - Confirmed PR #82 was already merged and latest-head Flutter CI #474 succeeded.
   - Inspected PR #86 and CI #477, then squash-merged #86.
   - The page now has a narrow collection-aware loader available that preserves Database identity while resolving target ObjectType membership separately.

2. **Added and merged collection-aware Object creation**
   - `GenericDatabaseObjectCreateService.create()` resolves the current collection target before creating an Object.
   - `createInGroup()` resolves the canonical target ObjectType Property and delegates grouped presets to the existing Relation-safe `ObjectBoardCreateService`.
   - This prevents the legacy `databaseId` assumption from creating records in the collection container when the Database targets another ObjectType.
   - PR #87 CI #480 passed and the PR was squash-merged.

3. **Added and merged canonical Relation editor adapter**
   - `ObjectRelationEditorService.load()` delegates to canonical `RelationTargetService.selectionFor()`.
   - `save()` validates selected ids against canonical candidates/cardinality and delegates writes to `RelationMutationService`.
   - Merely loading/opening editor state remains read-only and does not silently repair legacy/corrupt values.
   - This was included in green/merged PR #87.

4. **Added and merged adopted View creation paths**
   - `DatabaseViewCreationService.duplicateCurrent()` implements duplicate-current as the primary path with a new identity.
   - `createBlank()` implements the secondary blank path from Database definition defaults.
   - Regression coverage verifies the duplicate can mutate independently from its source.
   - PR #88 CI #481 passed and the PR was squash-merged.

5. **Refreshed durable handoffs**
   - `docs/AI_PROGRESS_OBJECT.md` and repository-wide `docs/AI_PROGRESS.md` were updated for the new Database/View integration phase.

## Exact next actions

1. Refresh from latest `main` before touching `GenericDatabasePage`.
2. Wire `GenericDatabaseCollectionPageLoader` into `GenericDatabasePage._reload()` so Database-level membership resolves first and existing View projection remains the second stage.
3. Replace legacy `_createRecord` assumptions with `GenericDatabaseObjectCreateService`, so creation always targets the collection ObjectType.
4. Connect `ObjectBoardView.onCreateInGroup` to `GenericDatabaseObjectCreateService.createInGroup()`: prompt for title, create, reload, and select/open the new Object.
5. Migrate the real Relation picker/editor in `GenericDatabasePage` onto `ObjectRelationEditorService`; surface missing target ids/cardinality drift without silent repair.
6. Add focused widget/page regression coverage for the real collection-aware reload/create/Relation edit paths.
7. Wire the merged Database collection settings dialog through `DatabaseCollectionConfigService` in the real page.
8. Wire `DatabaseViewCreationService` to top-tab multi-View UX, then rename/reorder/delete/overflow behavior.
9. Expose URL -> reusable Weblink promotion through a narrow Object-owned affordance while preserving the source URL by default.
10. Continue side peek / center peek / full-page Object opening after Database/View navigation state is stable.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Stable Relation APIs consumed by Object UI include `RelationMutationService`, `RelationReadService.neighborhood()`, and `RelationTargetService.selectionFor()`.
- Object UI must not duplicate Relation validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion UI and multi-View UX are Object-owned surfaces.
- `GenericDatabasePage` remains the main integration hotspot; avoid competing broad Relation-lane edits there.

## Validation

- PR #82 latest-head Flutter CI #474: success before merge.
- PR #86 Flutter CI #477: success before merge.
- PR #87 Flutter CI #480: success before merge.
- PR #88 Flutter CI #481: success before merge.
- This connector runtime does not expose a local Flutter SDK, so executable validation is delegated to GitHub CI; exact branch-caused failures must be inspected and corrected.

## Risks / blockers

- No product/design blocker is active.
- The main remaining Milestone A risk is the legacy assumption inside `GenericDatabasePage` that Database id and ObjectType id are the same; the merged loader/create adapters are specifically designed to remove that assumption incrementally.
- User-facing Relation writes must not regress to low-level direct Relation mutation.
- Board Relation-group creation must continue through `RelationMutationService` via the existing Board create service.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

Multiple safe checkpoints were completed and validated/merged in this run. The next step is the broad `GenericDatabasePage` wiring on refreshed `main`; the available GitHub connector only supports whole-file replacement for edits to that large integration hotspot, so continuing that broad UI rewrite in this run would add avoidable merge/corruption risk. The next run should start from current `main` and perform that page integration with an environment that can safely patch the file, then validate via Flutter CI.
