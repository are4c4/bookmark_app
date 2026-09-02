# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope

Own Relation and backlink lifecycle, bidirectional Relation integrity, relation write validation, rename/delete propagation, relation-target constraints, Tag hierarchy where implemented through Relations, and reusable Relation APIs consumed by the Object lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state

- Relation lifecycle foundation PR #66 is merged.
- Read-only integrity audit PR #69 is merged at `23fc9703`.
- Relation neighborhood read API PR #73 is merged at `578f8361`.
- Fail-closed Relation index reconciliation PR #74 is merged at `fd2810d0`.
- Canonical Relation target candidate API PR #75 is merged at `b6511bf3`.
- Latest `main` before this handoff update: `b6511bf36e37e0bea84ac99da745ee40f85e1cb1`.
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
  - returns canonical target ObjectType and immutable candidate Object list for Relation pickers.

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

### Tag hierarchy

- Legacy Tag -> Tag Object synchronization uses the general Relation lifecycle path.
- Removing orphan Tag Objects cleans incoming Parent Relations rather than leaving deleted Object ids in surviving values.

## Checkpoints completed in the latest sustained run

1. Finished and merged PR #69 read-only Relation integrity audit.
2. Added symmetric bidirectional mismatch detection, cardinality diagnostics, stale/missing index diagnostics, and audit read caching.
3. Added and merged PR #73 `RelationReadService.neighborhood()` for shared Object detail / Daily Note graph consumption.
4. Added and merged PR #74 fail-closed deterministic Relation index reconciliation.
5. Added and merged PR #75 canonical Relation target candidate loading for safe picker UIs.
6. Confirmed Object lane is consuming Relation-owned APIs instead of duplicating lifecycle logic:
   - Object PR #70 uses `RelationMutationService` for Value -> Object promotion execution.
   - Object PR #72 uses `RelationReadService` for shared Object detail Relation context.
7. Deliberately did not edit `GenericDatabasePage`, `core_object_bridge.dart`, Object detail UI, or promotion UI from the Relation lane.

## Validation

All latest heads were validated through GitHub Actions before merge:

- PR #69: dependency install, Drift generation, `flutter analyze`, full test suite — success.
- PR #73: dependency install, Drift generation, `flutter analyze`, full test suite — success.
- PR #74: dependency install, Drift generation, `flutter analyze`, full test suite — success.
- PR #75: dependency install, Drift generation, `flutter analyze`, full test suite — success.

Local Flutter execution was unavailable in the connector-only session; GitHub Actions was the executable validation source.

## Exact next actions

1. Let the Object lane adopt the stable Relation services in its owned surfaces:
   - use `RelationTargetService` + `RelationMutationService` for real Relation editing/pickers;
   - use `RelationNeighborhood` / `RelationReadService` for Object detail and Daily Note graph context;
   - migrate `core_object_bridge.dart` Relation writes/deletions only from the Object lane or in a deliberately sequenced integration slice.
2. Keep integrity audit and repair separate. Do not add automatic repair for missing targets, cardinality conflicts, broken bidirectional values, or other ambiguous user data without an explicit product/data policy decision.
3. If a concrete Relation regression appears during Object-lane integration, resume this lane with a focused failing test and additive fix.
4. Continue Tag hierarchy changes only through the general Relation APIs; do not create a special Relation persistence silo.

## Cross-lane boundary

- ObjectType defaults, Value semantics, Body/block persistence, Object detail containers, Daily Note creation, Value-to-Object promotion UX, `GenericDatabasePage`, and `core_object_bridge.dart` integration belong to `docs/AI_PROGRESS_OBJECT.md`.
- `lib/data/object_store.dart` is shared infrastructure; future Relation edits there must stay narrow and refresh from latest main before integration.
- Relation services are now intentionally stable consumption boundaries for Object-owned UI and workflows.

## Known risks / blockers

- `ObjectStore.deleteObject` and `ObjectStore.deleteProperty` remain deliberately low-level generic operations. Relation-aware callers should use `RelationMutationService`.
- Existing Object-owned UI can still call lower-level Relation APIs until the Object lane migrates it; do not create a competing Relation-lane edit of those files while Object work is active.
- Ambiguous automatic Relation-value repair could discard user intent and remains outside routine autonomous changes.

## Stop reason

The Relation lane has completed the currently actionable standalone work from Issue #56: source/target integrity, bidirectional lifecycle, backlinks/read APIs, target-candidate API, persistence/index handling, diagnostics, deterministic index-only reconciliation, Tag hierarchy lifecycle, and regression coverage are integrated and green. The next concrete steps are now Object-owned integration surfaces already under active Object-lane PRs, while the only deeper Relation-only repair work would require an explicit policy for ambiguous user data. This matches the AGENTS.md stopping conditions: no remaining safe independent Relation slice without crossing the active Object-lane boundary or making a material data-repair decision.
