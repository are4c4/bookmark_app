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
- PR #85 merged: focused Database collection settings dialog on current main, including target ObjectType selection and collection-filter editing without leaking View state.
- PR #86 merged as `d3632b2ac725a87b3eae66eb86e582d5c3bd5544`: `GenericDatabaseCollectionPageLoader` keeps Database identity/View scope on the collection container while loading filtered Objects/records/Properties from the configured target ObjectType. CI #477 passed before merge.

### Active Object PRs

- PR #87 `feature/object-page-integration-services`
  - adds `GenericDatabaseObjectCreateService` so normal and Board grouped creation target the resolved collection ObjectType instead of assuming `databaseId == objectTypeId`;
  - adds `ObjectRelationEditorService` so real picker/editor UI can load canonical selection diagnostics through `RelationTargetService.selectionFor()` and persist explicit choices through `RelationMutationService`;
  - focused tests cover cross-ObjectType collection creation, grouped presets, canonical Relation selection, and invalid-target rejection;
  - Flutter CI #480 is running on head `43a75a6a2b03bdf8424dc9814a82d847ceecf688`.

- PR #88 `feature/object-view-creation-service`
  - adds `DatabaseViewCreationService` for the adopted dual-path View creation UX;
  - duplicate-current creates a new persisted identity while copying View configuration;
  - blank View starts from Database definition defaults with empty View query/settings state;
  - tests verify duplicated View independence and blank defaults;
  - Flutter CI #481 is running on head `6f4ad751490849d8e612844a17e59366c7b60a0b`.

PR #83 remains closed/unmerged and is not an active implementation branch.

## Completed checkpoints in this run

1. **Validated the collection-semantics foundation already landed**
   - Confirmed PR #82 was merged and its latest head Flutter CI #474 completed successfully.

2. **Landed collection-aware page loading**
   - Inspected PR #86 and CI #477.
   - CI was green, so squash-merged #86 as `d3632b2ac725a87b3eae66eb86e582d5c3bd5544`.
   - The real page now has a narrow loader available that preserves Database identity while resolving target ObjectType membership separately.

3. **Added collection-aware creation adapter**
   - `GenericDatabaseObjectCreateService.create()` resolves the current collection target before creating an Object.
   - `createInGroup()` resolves the canonical target ObjectType Property and delegates grouped presets to the existing Relation-safe `ObjectBoardCreateService`.
   - This prevents the legacy `databaseId` assumption from creating records in the collection container when the Database targets another ObjectType.

4. **Added canonical Relation editor adapter**
   - `ObjectRelationEditorService.load()` delegates to canonical `RelationTargetService.selectionFor()`.
   - `save()` validates selected ids against canonical candidates/cardinality and delegates writes to `RelationMutationService`.
   - Merely loading/opening editor state remains read-only and does not silently repair legacy/corrupt values.

5. **Added adopted View creation paths**
   - `DatabaseViewCreationService.duplicateCurrent()` implements duplicate-current as the primary path with a new identity.
   - `createBlank()` implements the secondary blank path from Database definition defaults.
   - Regression coverage verifies the duplicate can mutate independently from its source.

## Exact next actions

1. Inspect CI #480 for PR #87 and CI #481 for PR #88. Fix any branch-caused failure; merge each when latest-head CI is green.
2. Refresh from latest `main` after those merges before touching `GenericDatabasePage`.
3. Wire `GenericDatabaseCollectionPageLoader` into `GenericDatabasePage._reload()` so Database-level membership resolves first and existing View projection remains the second stage.
4. Replace legacy `_createRecord` assumptions with `GenericDatabaseObjectCreateService`, so creation always targets the collection ObjectType.
5. Connect `ObjectBoardView.onCreateInGroup` to `GenericDatabaseObjectCreateService.createInGroup()`: prompt for title, create, reload, and select/open the new Object.
6. Migrate the real Relation picker/editor in `GenericDatabasePage` onto `ObjectRelationEditorService`; surface missing target ids/cardinality drift without silent repair.
7. Add focused widget/page regression coverage for the real collection-aware reload/create/Relation edit paths.
8. Wire the merged Database collection settings dialog through `DatabaseCollectionConfigService` in the real page.
9. After Milestone A page integration is coherent, wire `DatabaseViewCreationService` to top-tab multi-View UX, then rename/reorder/delete/overflow behavior.
10. Expose URL -> reusable Weblink promotion through a narrow Object-owned affordance while preserving the source URL by default.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Stable Relation APIs consumed by Object UI include `RelationMutationService`, `RelationReadService.neighborhood()`, and `RelationTargetService.selectionFor()`.
- Object UI must not duplicate Relation validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion UI and multi-View UX are Object-owned surfaces.
- `GenericDatabasePage` remains the main integration hotspot; avoid competing broad Relation-lane edits there.

## Validation

- PR #82 latest-head Flutter CI #474: success before merge.
- PR #86 Flutter CI #477: success before merge.
- PR #87 Flutter CI #480: in progress at handoff time.
- PR #88 Flutter CI #481: in progress at handoff time.
- This connector runtime does not expose a local Flutter SDK, so executable validation is delegated to GitHub CI; exact branch-caused failures must be inspected and corrected.

## Risks / blockers

- No product/design blocker is active.
- The main remaining Milestone A risk is the legacy assumption inside `GenericDatabasePage` that Database id and ObjectType id are the same; the new loader/create adapters are specifically designed to remove that assumption incrementally.
- User-facing Relation writes must not regress to low-level direct Relation mutation.
- Board Relation-group creation must continue through `RelationMutationService` via the existing Board create service.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

Multiple safe checkpoints were completed in this run. Two focused PRs are now under executable CI, while the next major step is the broad `GenericDatabasePage` wiring that should be sequenced after their latest-head results and refreshed `main` to avoid stacking conflicting integration histories. Pending CI alone was not used as a stopping reason; independent View creation work was completed while CI ran.
