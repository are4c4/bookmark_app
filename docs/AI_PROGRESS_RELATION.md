# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope

Own Relation and backlink lifecycle, bidirectional Relation integrity, relation write validation, rename/delete propagation, relation-target constraints, Tag hierarchy where implemented through Relations, and reusable Relation APIs consumed by the Object lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state

- PR #62 is merged to `main`; bidirectional pair validation rejects broken inverse metadata.
- PR #63 passed Flutter CI run #349 but became unmergeable after concurrent Object-lane PR #64 advanced `main`; #63 is closed as superseded.
- Replacement PR #66 uses `feature/relation-write-integrity-v2` and contains the replayed Relation integrity work plus stable mutation/read/index/lifecycle APIs.
- Object PR #65 subsequently advanced `main` to `93d8cf18` with Object Body/defaults persistence, Weblink, Daily Note, and detail-loader work. PR #66 remains narrow and currently reports mergeable; re-check after final CI.
- Object-owned UI surfaces are intentionally untouched.

## Checkpoints completed in the current sustained run

1. Confirmed superseded PR #63 was functionally green before conflict: Drift generation, `flutter analyze`, and full tests passed.
2. Replayed Relation write integrity on latest Object-lane base:
   - source Object must belong to the persisted Relation Property's ObjectType;
   - writes use canonical persisted Property metadata;
   - forged target/cardinality config cannot redirect Relation edges;
   - `setRelation` rejects non-Relation Properties.
3. Replayed Relation Property creation integrity: source/target ObjectTypes must exist and belong to the same workspace.
4. Replayed ObjectType deletion protection: deletion is blocked while another ObjectType targets it; self-Relation ObjectTypes remain deletable atomically.
5. Added Property-filtered backlink/outgoing edge helpers.
6. Added `RelationMutationService` as the stable mutation facade:
   - canonical persisted Properties;
   - valid bidirectional inverse synchronization;
   - fail-closed inconsistent pair metadata;
   - pair-safe Relation Property deletion.
7. Added unified Relation rename lifecycle:
   - bidirectional names update together transactionally;
   - unidirectional rename preserves target/cardinality/config;
   - duplicate/system mutations are rejected.
8. Added `RelationReadService` resolving edge-index entries into canonical Relation Property + neighboring Object records.
9. Added `RelationIndexService` for idempotent ObjectType/workspace index bootstrap from legacy `generic_values`.
10. Added Relation-safe Object deletion:
    - validates workspace/Object ownership;
    - rebuilds legacy indexes first;
    - validates all incoming Relation metadata before writing;
    - detaches deleted IDs from surviving values;
    - preserves bidirectional inverse consistency;
    - deletes the Object last.
11. Hardened low-level `BidirectionalRelationStore.setRelation` itself:
    - canonical persisted source Property;
    - managed-pair detection from persisted metadata;
    - valid reciprocal pair required before mutation;
    - stale/forged metadata cannot redirect writes;
    - broken pair metadata fails closed.
12. Added broad regression coverage for write/create/delete/rename/read/index/bidirectional lifecycle, including legacy-unindexed data and wrong-workspace deletion.
13. Migrated Relation-owned Tag hierarchy synchronization to the safe mutation facade:
    - `Parent` Relation writes use `RelationMutationService`;
    - orphan Tag Objects use Relation-safe Object deletion;
    - deleting a legacy parent Tag no longer leaves a surviving child Object with a stale `Parent` Object id;
    - added Tag hierarchy cleanup regression coverage.
14. Reviewed `core_object_bridge.dart`: it still contains direct Relation writes/orphan deletion, but it is an Object-owned integration surface. No concurrent edit was made; adoption of the safe facade is handed off to Object-lane integration after #66 stabilizes.

## Branch / PR

- Branch: `feature/relation-write-integrity-v2`
- PR #66 — `Harden Relation lifecycle and stable APIs`
- Latest Relation implementation checkpoint before final documentation updates: `e58f8d77bce0a0692e04b990a29fea0d50305f60`
- Always inspect the actual #66 head before resuming because handoff/documentation commits follow implementation commits.

## Validation

- Superseded PR #63 head `b6cb3888c942cb3bdab2c5e921784ac5ed2cea67` passed Flutter CI run #349 completely.
- PR #66 runs fresh Flutter CI on each latest head; intermediate runs are expected to be cancelled by workflow concurrency during this sustained run.
- Final integration requirement: latest #66 head must pass dependency install, Drift generation, `flutter analyze`, and full tests.
- Local Flutter execution is unavailable in this connector-only session, so GitHub Actions is the executable validation source.

## Next priorities

1. Inspect the final PR #66 latest-head Flutter CI and fix only Relation-caused failures.
2. If green and still conflict-free against current `main` (`93d8cf18` or newer), merge #66. If Object lane advances into a real conflict, replay narrow Relation-owned changes rather than force merging shared files.
3. After #66 integration, coordinate Object-lane adoption of `RelationMutationService` / `RelationReadService` in `GenericDatabasePage`, `core_object_bridge.dart`, shared Object detail, promotion execution, and Daily Note composition.
4. Continue Tag hierarchy behavior only through general Relation APIs; no special Relation persistence silo.
5. Add orphan/stale-edge diagnostics only if actual repair needs appear after index bootstrap is used in practice.

## Cross-lane boundary

- ObjectType defaults, Value semantics, Body/block persistence, Object detail containers, Daily Note creation, Value-to-Object promotion UX, `GenericDatabasePage`, and `core_object_bridge.dart` integration belong to `docs/AI_PROGRESS_OBJECT.md`.
- `lib/data/object_store.dart` is shared infrastructure; Relation changes there must stay narrow and be refreshed from latest main before integration.
- `relation_queries.dart`, `relation_read_service.dart`, `relation_mutation_service.dart`, and `relation_index_service.dart` are additive Relation APIs intended for Object-lane consumption.

## Known risks / blockers

- Concurrent Object work can advance main during Relation CI; #63 already demonstrated this. Prefer narrow replay/rebase over force merging.
- `ObjectStore.deleteObject` remains deliberately low-level; relation-aware callers should use `RelationMutationService.deleteObject`.
- `ObjectStore.deleteProperty` remains a generic low-level schema operation; relation-aware callers should use `RelationMutationService.deleteRelationProperty`.
- No destructive schema migration or unresolved product-design decision is required for current Relation work.

## Stop condition

No product blocker is active. The immediate integration boundary is final latest-head CI plus conflict check for PR #66; after merge, the next direct consumer changes are predominantly Object-owned and must be sequenced through the Object lane rather than edited concurrently here.
