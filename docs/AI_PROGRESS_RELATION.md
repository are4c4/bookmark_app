# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope

Own Relation and backlink lifecycle, bidirectional Relation integrity, relation write validation, rename/delete propagation, relation-target constraints, Tag hierarchy where implemented through Relations, and reusable Relation APIs consumed by the Object lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state

- Relation lifecycle foundation PR #66 is merged.
- Read-only integrity audit PR #69 is merged.
- Relation neighborhood read API PR #73 is merged.
- Fail-closed Relation index reconciliation PR #74 is merged.
- Canonical Relation target candidate API PR #75 is merged.
- Canonical Relation selection-context PR #80 is merged as `614d654e6bb08011d9cb4ca242b50174ce44e5e4`.
- Core Object mirror lifecycle PR #81 is merged as `0390d12162cb2a2dd5c063e8e4cbca95f036a248`.
- Object PRs #76/#77/#78 have already adopted `RelationNeighborhood` / `RelationMutationService` in shared detail, Value promotion, and Object inspector flows.
- Object PR #79 remains active around Board grouped creation and intends to edit `GenericDatabasePage` next.
- No active Relation implementation PR remains from this sustained run.

## Stable Relation APIs now on main

### Mutation / lifecycle

- `RelationMutationService`
  - canonical persisted Property resolution;
  - safe unidirectional and bidirectional Relation writes;
  - pair-aware Relation Property rename/delete;
  - Relation-safe Object deletion that detaches surviving references first;
  - fail-closed behavior for inconsistent bidirectional metadata.
- `BidirectionalRelationStore`
  - reciprocal pair integrity validation;
  - canonical persisted pair writes;
  - transactional pair rename/delete.

### Read / backlinks

- `RelationReadService`
  - resolved outgoing Relations;
  - resolved backlinks;
  - `RelationNeighborhood` for one Object's outgoing + incoming graph context.
- Property-filtered edge helpers remain available for lower-level callers.

### Target selection

- `RelationTargetService`
  - resolves the persisted Relation Property instead of trusting stale caller config;
  - validates workspace and target ObjectType ownership;
  - returns canonical target ObjectType and immutable candidate Object list;
  - `selectionFor()` returns canonical source Object + current selected ids/Objects + valid candidates;
  - missing target ids remain visible as diagnostics rather than being silently discarded;
  - legacy single-Relation cardinality drift is surfaced read-only;
  - a source Object outside the persisted source ObjectType is rejected.

### Persistence / integrity

- `RelationIndexService`
  - rebuilds normalized edge indexes from persisted Relation values.
- `RelationIntegrityService`
  - read-only detection of missing/cross-workspace target ObjectTypes, missing targets, cardinality violations, missing/stale index edges, invalid bidirectional metadata, and inverse-value mismatches;
  - symmetric bidirectional validation;
  - no automatic user-value mutation.
- `RelationIndexReconcileService`
  - no-op on healthy workspaces;
  - repairs only `missingIndexEdge` / `staleIndexEdge` drift;
  - treats persisted Relation values as source of truth;
  - refuses reconciliation before writes when any ambiguous schema/value/bidirectional issue exists;
  - verifies post-rebuild integrity.

### Tag / legacy mirror lifecycle

- Legacy Tag -> Tag Object synchronization uses the general Relation lifecycle path.
- Removing orphan Tag Objects cleans incoming Parent Relations rather than leaving deleted Object ids in surviving values.
- `CoreObjectBridge` bookmark Images/Tags synchronization now writes through `RelationMutationService`.
- Removing orphan mirrored Image/Bookmark Objects now uses Relation-safe Object deletion, so surviving Objects are detached before the mirrored Object disappears.

## Checkpoints completed in the latest sustained run

1. Re-read latest main after Object PRs #76/#77/#78 adopted stable Relation APIs.
2. Audited production low-level Relation mutations/deletions.
3. Added PR #80 `RelationSelectionContext` for a complete read-only Relation-picker payload.
4. Added tests for canonical current selection, missing target ids, legacy single-cardinality drift, and wrong-source rejection.
5. Initial #80 full test run exposed only an invalid ordering assumption in the new test; analyzer was green and 251 other tests passed. The assertion was corrected to unordered candidate comparison.
6. #80 replacement latest-head CI passed dependency install, Drift generation, `flutter analyze`, and full tests; PR #80 was merged.
7. Used the explicitly allowed deliberately-sequenced cross-lane path for `core_object_bridge.dart`, because active Object PR #79 was Board-only and did not touch that file.
8. Added PR #81 migrating bookmark Images/Tags writes to `RelationMutationService` and mirror orphan deletion to Relation-safe Object deletion.
9. Added regression coverage proving deletion of a mirrored Image Object detaches an incoming Relation from a surviving custom Object rather than leaving a stale deleted Object id.
10. PR #81 latest-head CI passed dependency install, Drift generation, `flutter analyze`, and full tests; PR #81 was merged.
11. Re-audited remaining user-facing low-level Relation writes. The remaining concrete caller is `GenericDatabasePage`, which is Object-owned and is the next surface expected to be edited by active Object PR #79.

## Validation

Latest Relation heads were validated through GitHub Actions before merge:

- PR #80 first head: Drift generation + `flutter analyze` success; one new test failed only because it incorrectly assumed candidate ordering. All other tests passed.
- PR #80 corrected head `56f634d666c2d4e15fc5917f0559ef2fb02225cd`: dependency install, Drift generation, `flutter analyze`, full test suite — success.
- PR #81 head `c99ee94ea26bb2588e27321398ebe635870e2f8d`: dependency install, Drift generation, `flutter analyze`, full test suite — success.

Previous merged Relation PRs #66/#69/#73/#74/#75 were also CI-green before merge.

Local Flutter execution is unavailable in the connector-only session; GitHub Actions is the executable validation source.

## Exact next actions

1. Sequence the remaining real Relation editor migration through the Object lane after/with its `GenericDatabasePage` Board work:
   - picker load: `RelationTargetService.selectionFor()`;
   - picker save: `RelationMutationService.setRelation()`;
   - never silently remove `missingTargetObjectIds` merely by opening the picker.
2. Keep `GenericDatabasePage` out of the Relation lane while active Object PR #79 is preparing to edit the same surface.
3. Keep integrity audit and repair separate. Do not auto-repair missing targets, cardinality conflicts, broken bidirectional values, or other ambiguous user data without explicit product/data policy.
4. Resume this lane with a focused failing test if Object integration exposes a concrete Relation regression.
5. Continue Tag hierarchy and legacy mirror behavior only through the general Relation APIs; do not create special Relation persistence silos.

## Cross-lane boundary

- ObjectType defaults, Value semantics, Body/block persistence, Object detail containers, Daily Note creation, Value-to-Object promotion UX, `GenericDatabasePage`, and Board integration belong to `docs/AI_PROGRESS_OBJECT.md`.
- `core_object_bridge.dart` has now completed its deliberately sequenced Relation lifecycle migration and should return to normal Object ownership for future feature changes.
- `lib/data/object_store.dart` is shared infrastructure; future Relation edits there must stay narrow and refresh from latest main before integration.
- Relation services are intentionally stable consumption boundaries for Object-owned UI and workflows.

## Known risks / blockers

- `ObjectStore.deleteObject` and `ObjectStore.deleteProperty` remain deliberately low-level generic operations. Relation-aware callers should use `RelationMutationService`.
- `GenericDatabasePage` still contains a low-level Relation write until the Object lane completes its picker/editor migration.
- Object PR #79 plans to touch `GenericDatabasePage`; a concurrent Relation edit there would create an avoidable cross-lane conflict.
- Ambiguous automatic Relation-value repair could discard user intent and remains outside routine autonomous changes.

## Stop reason

This continuation exhausted the newly available independent Relation work: canonical selection diagnostics and legacy mirror lifecycle are implemented, tested, merged, and handed off. The remaining concrete user-facing Relation editor lives in `GenericDatabasePage`, the same Object-owned file that active Object PR #79 intends to modify next. Editing it concurrently would violate the repository ownership/concurrency rule. Deeper automatic repair still requires an explicit policy for ambiguous user data. This matches the AGENTS.md stopping conditions: the next actionable step is an unavoidable cross-lane sequencing boundary, not merely pending CI or completion of one PR.
