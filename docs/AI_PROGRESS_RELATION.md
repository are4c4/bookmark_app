# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope

Own Relation and backlink lifecycle, bidirectional Relation integrity, relation write validation, rename/delete propagation, relation-target constraints, Tag hierarchy where implemented through Relations, and reusable Relation APIs consumed by the Object lane.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current state

- PR #62 is merged to `main`; bidirectional pair validation now rejects broken inverse metadata.
- PR #63 passed Flutter CI but became unmergeable after Object-lane PR #64 updated `main`.
- The Relation changes from #63 were replayed on latest `main` in `feature/relation-write-integrity-v2` to avoid overwriting Object-lane handoff changes.
- Object lane has merged Value/Object Relation/Computed semantics and Object promotion/Body/defaults/detail contracts; do not duplicate those concerns here.

## Checkpoints completed in the current sustained run

1. Confirmed PR #63 Flutter CI succeeded: Drift generation, `flutter analyze`, and full tests all passed.
2. Detected merge conflict caused by concurrent Object-lane `main` advancement rather than a failing Relation change.
3. Created `feature/relation-write-integrity-v2` from latest `main` (`3358cb6d`).
4. Replayed Relation write integrity on latest `main`:
   - Relation writes require the source Object to belong to the persisted Relation Property's ObjectType.
   - writes use the persisted canonical Relation Property, preventing forged target/cardinality config from redirecting edges.
   - `setRelation` rejects non-Relation Properties.
5. Replayed Relation Property creation integrity:
   - source and target ObjectTypes must exist;
   - source and target ObjectTypes must belong to the same workspace.
6. Replayed ObjectType delete lifecycle protection:
   - deletion is blocked while another ObjectType has a Relation Property targeting it;
   - self-Relation ObjectTypes remain deletable as one atomic schema deletion.
7. Replayed reusable Relation graph query helpers:
   - Property-filtered backlinks;
   - Property-filtered outgoing edges.
8. Restored focused regression tests for all of the above on the rebased branch.

## Validation

- Original PR #63 head `b6cb3888c942cb3bdab2c5e921784ac5ed2cea67` passed Flutter CI run #349:
  - Set up Flutter: success
  - Install dependencies: success
  - Generate Drift code: success
  - Analyze: success
  - Test: success
- The v2 branch is code-equivalent for Relation-owned files but rebased onto Object-lane PR #64. A fresh CI run is required on its replacement PR before merge.

## Next priorities

1. Open a replacement PR from `feature/relation-write-integrity-v2`, close #63 as superseded, and validate fresh CI.
2. Merge the replacement PR once green and refresh from latest `main` again if Object lane advances meanwhile.
3. Harden bidirectional Relation mutation entry points so stale/forged inverse metadata cannot be used during `setRelation`.
4. Prevent public Relation lifecycle APIs from deleting one side of a valid bidirectional pair without deleting the inverse side.
5. Add higher-level backlink resolution APIs required by shared Object detail content and Daily Notes without duplicating Object-lane UI logic.
6. Continue Tag hierarchy support only through general Relation mechanisms.

## Cross-lane boundary

- ObjectType defaults, Value semantics, Body/block persistence, Object detail containers, Daily Note creation, and Value-to-Object promotion UX belong to `docs/AI_PROGRESS_OBJECT.md`.
- `lib/data/object_store.dart` is shared infrastructure. Relation changes there must stay narrow and be refreshed from latest `main` before integration.
- The Object lane may consume `relation_queries.dart`; changes to its API should remain additive and backward-compatible.

## Known risks / blockers

- Concurrent Object work can advance `main` while a Relation PR is in CI; replay narrow Relation changes rather than force-merging conflicting handoff files.
- Bidirectional pair deletion safety needs a coordinated public API contract because `ObjectStore.deleteProperty` is also used for ordinary Property deletion.
- No destructive schema migration is required for the current Relation integrity work.

## Stop reason for the previous checkpoint

The previous run stopped after multiple safe checkpoints because the next lifecycle guard required refreshing against concurrent Object-lane work. That refresh is now in progress on the v2 branch; there is no product-design blocker.
