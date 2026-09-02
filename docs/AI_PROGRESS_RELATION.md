# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope

Own Relation and backlink lifecycle, bidirectional Relation integrity, relation write validation, rename/delete propagation, relation-target constraints, Tag hierarchy where implemented through Relations, and reusable Relation APIs consumed by the Object lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state

- PR #62 is merged to `main`; bidirectional pair validation rejects broken inverse metadata.
- PR #63 passed Flutter CI run #349 but became unmergeable after concurrent Object-lane PR #64 advanced `main`; #63 is closed as superseded.
- Replacement PR #66 uses `feature/relation-write-integrity-v2`, created from Object-lane main `3358cb6d` and contains the replayed Relation integrity work plus additional stable Relation APIs.
- Object lane has merged Value/Object Relation/Computed semantics and Object promotion/Body/defaults/detail contracts; Relation work remains API/lifecycle focused and does not edit Object-owned UI surfaces.

## Checkpoints completed in the current sustained run

1. Confirmed superseded PR #63 was functionally green before conflict:
   - Drift generation passed;
   - `flutter analyze` passed;
   - full tests passed.
2. Replayed Relation write integrity on latest Object-lane main:
   - source Object must belong to the persisted Relation Property's ObjectType;
   - writes use canonical persisted Property metadata;
   - forged target/cardinality config cannot redirect Relation edges;
   - `setRelation` rejects non-Relation Properties.
3. Replayed Relation Property creation integrity:
   - source/target ObjectTypes must exist;
   - source/target ObjectTypes must be in the same workspace.
4. Replayed ObjectType deletion protection:
   - target ObjectType deletion is blocked while another ObjectType has an incoming Relation Property;
   - self-Relation ObjectTypes remain deletable atomically.
5. Added additive Relation graph query helpers:
   - Property-filtered backlinks;
   - Property-filtered outgoing edges.
6. Added `RelationMutationService` as the stable mutation facade for Object/detail consumers:
   - canonicalizes persisted Relation Properties;
   - routes valid bidirectional Relations through inverse synchronization;
   - fails closed on inconsistent pair metadata;
   - deletes a bidirectional Relation Property as a pair rather than orphaning one side.
7. Added unified Relation rename lifecycle to `RelationMutationService`:
   - bidirectional rename updates both Property names transactionally;
   - unidirectional rename preserves target/cardinality/config;
   - duplicate names and protected system schema mutations are rejected.
8. Added `RelationReadService`:
   - resolves index edges into canonical Relation Property + neighboring Object records;
   - gives Object detail/Daily Note consumers a stable graph API without generic-table knowledge.
9. Added `RelationIndexService`:
   - rebuilds one ObjectType or a complete workspace;
   - supports legacy `generic_values` that predate the normalized edge index;
   - rebuild is idempotent and does not alter stored Relation values.
10. Added Relation-safe Object deletion lifecycle to `RelationMutationService.deleteObject`:
    - validates workspace/ObjectType/Object ownership before mutation;
    - rebuilds the edge index first so legacy unindexed references are included;
    - validates all backlinks/pair metadata before the first write;
    - detaches the deleted Object ID from every surviving Relation value;
    - uses safe Relation mutation so valid bidirectional inverse values stay synchronized;
    - deletes the Object only after detachments succeed.
11. Hardened low-level `BidirectionalRelationStore.setRelation` itself:
    - canonicalizes the persisted source Relation Property;
    - treats any bidirectional metadata as managed pair metadata;
    - requires a valid reciprocal pair before mutation;
    - stale/forged target metadata cannot redirect a bidirectional write;
    - inconsistent persisted pair metadata fails closed before writing.
12. Added/extended regression coverage for:
    - source ownership and forged metadata;
    - Relation Property creation/workspace constraints;
    - ObjectType target deletion lifecycle;
    - filtered edge queries;
    - mutation facade bidirectional set/delete/rename behavior;
    - inconsistent pair metadata;
    - resolved read APIs;
    - legacy edge-index rebuild;
    - Relation-safe Object deletion for unidirectional, bidirectional, legacy-unindexed, and wrong-workspace cases;
    - direct bidirectional write canonicalization and broken-pair failure.

## Branch / PR

- Branch: `feature/relation-write-integrity-v2`
- Replacement PR: #66 — `Rebase and harden Relation APIs on latest main`
- Latest relevant implementation commit before this handoff update: `7bd85c533a81f19265550031cf0b3f310777d5a2`
- Additional latest commits on the branch include Relation-safe Object deletion/tests and handoff updates; always inspect PR #66 head before resuming.

## Validation

- Superseded PR #63 head `b6cb3888c942cb3bdab2c5e921784ac5ed2cea67` passed Flutter CI run #349 completely.
- PR #66 runs fresh Flutter CI on each head; intermediate runs may be cancelled by workflow concurrency as commits are pushed.
- A final latest-head run must pass Drift generation, `flutter analyze`, and the full test suite before #66 is merged.
- Local Flutter execution is unavailable in this connector-only session, so GitHub Actions is the executable validation source.

## Next priorities

1. Inspect the final PR #66 head and latest Flutter CI; fix only failures caused by Relation changes.
2. Merge #66 when latest-head CI is green and it remains conflict-free; if Object lane advances again, replay the narrow Relation changes rather than force-merging stale shared files.
3. After #66 is integrated, migrate Relation-owned callers such as Tag/Object bridges toward `RelationMutationService` where doing so does not conflict with Object-lane ownership.
4. Coordinate with the Object lane before changing `GenericDatabasePage`; it currently has a direct `ObjectStore.setRelation` call but is Object-owned UI.
5. Build Tag hierarchy behavior only from the general Relation APIs; do not introduce a special Relation persistence silo.
6. Consider explicit orphan/stale-edge diagnostics only if real data-repair needs emerge after index bootstrap is integrated.

## Cross-lane boundary

- ObjectType defaults, Value semantics, Body/block persistence, Object detail containers, Daily Note creation, and Value-to-Object promotion UX belong to `docs/AI_PROGRESS_OBJECT.md`.
- `lib/data/object_store.dart` is shared infrastructure; keep Relation changes narrow and refresh from latest `main` before integration.
- `GenericDatabasePage` and Object detail presentation are Object-owned. Expose stable Relation services for that lane rather than editing those surfaces concurrently.
- `relation_queries.dart`, `relation_read_service.dart`, `relation_mutation_service.dart`, and `relation_index_service.dart` are intended as additive Relation APIs for Object-lane consumption.

## Known risks / blockers

- Concurrent Object work may advance `main` while Relation CI runs; #63 demonstrated this. Prefer replay/rebase of narrow Relation work over force merging.
- `ObjectStore.deleteObject` remains deliberately low-level. Object/detail callers that require referential cleanup should use `RelationMutationService.deleteObject`.
- `ObjectStore.deleteProperty` remains a low-level generic schema operation; Relation-aware UI/API callers should use `RelationMutationService.deleteRelationProperty` so bidirectional pairs cannot be orphaned.
- No destructive schema migration or product-design blocker is currently required.

## Stop condition

No Relation product blocker has been reached yet. Continue until the latest #66 CI/integration state or a new cross-lane conflict determines the next safe checkpoint.
