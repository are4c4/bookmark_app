# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current integration state

- `main` includes Object detail/Body UI (#68), shared Relation detail context (#76), safe Value -> Object/Weblink promotion (#77), canonical Relation-neighborhood rendering (#78), and grouped Board Object creation service/planner (#79).
- PR #79 head `35642c88376b8bb38ddfaf85b3605fc6d18d616b` passed Flutter CI #458 after fixing Relation preset decoding, then squash-merged as `6b991708f294e83b236d396a84d3841e4e43bcd4`.
- Active Object branch: `feature/database-collection-semantics`.
- Active PR #82 adds Phase-1 `Database = target ObjectType + collectionFilter` semantics and is mergeable.

## Checkpoints completed in the latest sustained run

1. **Fixed and landed grouped Board Object creation**
   - CI #449 exposed that `ObjectRelationValue` was being passed back through `fromJson`, producing an empty Relation value.
   - Fixed Relation-group creation to preserve the planned target ids and continue routing writes through `RelationMutationService`.
   - Added rollback so a failed grouped preset does not leave an orphan new Object.
   - Flutter CI #458 passed Drift generation, `flutter analyze`, and the full test suite before merge.
   - Squash-merged PR #79 as `6b991708f294e83b236d396a84d3841e4e43bcd4`.

2. **Added Database collection Phase-1 persistence and compatibility contract**
   - Added `DatabaseCollectionDefinition` and additive `database_collection_definitions` persistence.
   - Legacy databases with no explicit collection definition resolve as self ObjectType + empty collection filter, preserving current behavior without rewriting data.
   - Explicit definitions validate same-workspace target ObjectTypes and filter Property ownership.
   - Malformed persisted collection filters fail closed instead of silently broadening membership.
   - Deferred target FK allows an explicit self-target Database to be deleted while protecting ObjectTypes referenced by another Database collection.

3. **Separated Database membership from View projection end-to-end**
   - Added `DatabaseCollectionResolver` to load the target ObjectType and apply Database-level `collectionFilter` only.
   - Added `DatabaseCollectionViewProjector` to compose collection membership first, then the existing View search/filter/sort/group pipeline.
   - Added regression coverage for `北海道` Database collection followed by independent `行きたい=true` View filtering.
   - Cross-Database View application is rejected.

4. **Added UI-facing collection configuration facade**
   - Added `DatabaseCollectionConfigService` to expose current effective definition, target ObjectType, same-workspace ObjectType candidates, save, and reset-to-legacy operations.
   - UI does not need to duplicate workspace/target/filter validation.

5. **Inspected and corrected PR #82 CI failures**
   - CI #466 passed Drift generation and `flutter analyze`; only two new tests failed.
   - Both failures were ordering expectations: `ObjectStore.listObjects()` already returns its existing storage order, while the tests incorrectly assumed insertion order.
   - Corrected the tests without changing membership implementation.
   - Latest branch head is `80904b14a9901040db9c7de61b123fd3a216cb23`; newer Flutter CI is running.

## Validation

- PR #79 Flutter CI #458: success before merge.
- PR #82 CI #466: Drift generation and analyze success; 266 tests passed, 2 new ordering assertions failed and were corrected.
- Latest PR #82 CI is running on head `80904b14a9901040db9c7de61b123fd3a216cb23`.
- This connector runtime does not provide a local Flutter SDK, so executable validation is delegated to PR CI and exact workflow logs.

## Exact next actions

1. Inspect latest CI for PR #82; fix only branch-caused failures and merge when green.
2. After #82 lands, connect `GenericDatabasePage` loading/projection to `DatabaseCollectionResolver` / `DatabaseCollectionViewProjector` so the real page shows target ObjectType membership before View filtering.
3. Add a narrow Database collection settings UI using `DatabaseCollectionConfigService`; start with target ObjectType and collection filter editing, keeping View controls separate.
4. Connect merged `ObjectBoardCreateService` to `ObjectBoardView.onCreateInGroup` in `GenericDatabasePage`, prompting for title, creating in the selected bucket, reloading, and selecting the new Object.
5. Add focused page/widget coverage for Board-column creation and Database-vs-View filtering.
6. Continue URL -> Weblink promotion UI and Relation picker migration only through stable Relation APIs.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, and Tag hierarchy mutation stay in `docs/AI_PROGRESS_RELATION.md`.
- Stable Relation APIs consumed by Object lane include `RelationMutationService`, `RelationReadService.neighborhood()`, and `RelationTargetService`.
- Object-owned callers may consume those APIs but must not reimplement Relation lifecycle/index rules.
- Database collection semantics, Object detail UI, Daily Note UI, Value promotion UI, and Object-centric Database/View interactions remain Object-owned.

## Blockers / risks

- PR #82 still requires latest-head CI before merge.
- Real-page collection integration must not collapse Database `collectionFilter` into View filters or duplicate Objects when a collection targets another ObjectType.
- Board Relation-group creation must continue using `RelationMutationService`.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

No product/design blocker is currently known. Continue from PR #82 latest-head CI, then land the Phase-1 collection foundation and wire it into the real generic Database page in a separate focused slice.
