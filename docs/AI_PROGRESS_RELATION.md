# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope

Own Relation and backlink lifecycle, bidirectional Relation integrity, relation write validation, rename/delete propagation, relation-target constraints, Tag hierarchy where implemented through Relations, and reusable Relation APIs consumed by the Object lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state

- PR #66 is merged to `main` at `6770a5f1`; source/target validation, stable Relation mutation/read/index APIs, bidirectional lifecycle hardening, Relation-safe Object deletion, and Tag hierarchy cleanup are now integrated.
- Current branch: `feature/relation-integrity-audit`.
- Current PR: #69 — `Add read-only Relation integrity audit`.
- Object-owned UI surfaces remain intentionally untouched.

## Completed integration checkpoints

1. Relation writes validate source ObjectType ownership and use canonical persisted Property metadata.
2. Relation Property creation validates source/target existence and same-workspace ownership.
3. Target ObjectType deletion is protected while incoming Relation Properties exist.
4. Property-filtered backlink/outgoing edge helpers are available.
5. `RelationMutationService` provides safe set/delete/rename/Object-delete lifecycle behavior.
6. `RelationReadService` resolves indexed edges into canonical Property/Object neighbors.
7. `RelationIndexService` rebuilds Relation indexes from legacy persisted values.
8. `BidirectionalRelationStore.setRelation` canonicalizes persisted pair metadata and fails closed on broken pairs.
9. Tag hierarchy synchronization uses Relation-safe mutation/deletion paths.
10. PR #66 latest head passed dependency install, Drift generation, `flutter analyze`, and the full test suite before merge.

## Current sustained-run checkpoints — PR #69

1. Added `RelationIntegrityService` as a read-only workspace audit API.
2. Audit detects:
   - missing target ObjectType metadata;
   - cross-workspace target ObjectTypes;
   - persisted references to missing target Objects;
   - single-Relation cardinality violations in legacy/corrupt values;
   - missing normalized edge-index entries;
   - stale normalized edge-index entries;
   - invalid bidirectional pair metadata;
   - bidirectional inverse-value mismatches.
3. Audit is deliberately non-destructive. Repair remains an explicit separate action through existing index/lifecycle APIs.
4. Added focused regression coverage for healthy Relations, missing edges, missing targets, cardinality violations, broken pairs, inverse mismatches, and cross-workspace metadata.
5. PR #69 is open; latest-head Flutter CI must pass before merge.

## Validation

- PR #66 final latest-head Flutter CI passed Drift generation, `flutter analyze`, and full tests before merge.
- PR #69 runs fresh Flutter CI on each latest head. Intermediate runs may be superseded as this sustained run adds checkpoints.
- Local Flutter execution is unavailable in this connector-only session; GitHub Actions is the executable validation source.

## Next priorities

1. Validate PR #69 latest-head CI; fix Relation-caused analyzer/test failures only.
2. Merge #69 when green and conflict-free.
3. After #69 integration, keep audit and repair separate. Consider an explicit, narrowly scoped repair planner only if a deterministic safe action can be derived from audit results without silently discarding Relation values.
4. Coordinate Object-lane adoption of `RelationMutationService` / `RelationReadService` in `GenericDatabasePage`, `core_object_bridge.dart`, shared Object detail, promotion execution, and Daily Note composition rather than editing those surfaces concurrently here.
5. Continue Tag hierarchy behavior only through general Relation APIs; no special Relation persistence silo.

## Cross-lane boundary

- ObjectType defaults, Value semantics, Body/block persistence, Object detail containers, Daily Note creation, Value-to-Object promotion UX, `GenericDatabasePage`, and `core_object_bridge.dart` integration belong to `docs/AI_PROGRESS_OBJECT.md`.
- `lib/data/object_store.dart` is shared infrastructure; Relation changes there must stay narrow and refresh from latest main before integration.
- `relation_queries.dart`, `relation_read_service.dart`, `relation_mutation_service.dart`, `relation_index_service.dart`, and `relation_integrity_service.dart` are additive Relation APIs intended for Object-lane consumption.

## Known risks / blockers

- Concurrent Object work can advance main during Relation CI; prefer narrow replay/rebase over force merging.
- `ObjectStore.deleteObject` and `ObjectStore.deleteProperty` remain deliberately low-level generic operations. Relation-aware callers should use `RelationMutationService`.
- Integrity audit must remain read-only; automatic repair of ambiguous user data would be a destructive policy decision and is outside routine Relation-lane changes.

## Stop condition

No product blocker is active. Continue through PR #69 validation/integration and additional clearly safe Relation-owned diagnostics or API hardening. Stop before ambiguous/destructive automatic repair or broad Object-owned UI integration.
