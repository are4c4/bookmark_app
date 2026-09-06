# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Preserve the canonical Relation subsystem; do not invent parallel Relation writers/indexes merely to keep this lane busy.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle, integrity-sensitive schema evolution, and deletion/reference invariants.

## Primary active issues
- #493 — integrity side of safe/reversible schema evolution, especially Relation target/cardinality changes.
- #491 — lifecycle/integrity regressions for generic Relation Property authoring/editing and inline target creation.
- #492 — integrity/read regressions for generic Gallery cover sources backed by Relations.
- #245/#484 — new primitive/domain Relation-producing workflows only when real production writes appear.
- #56 — umbrella canonical Relation contract.

## Canonical Relation contract
- Feature Relation value writes go through `RelationMutationService`.
- Reads/backlinks use `RelationReadService` / canonical ObjectStore projections.
- Relation Property creation uses `ObjectStore.createRelationProperty(...)` or a canonical facade delegating to it.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index drift only.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Ambiguous damage, missing targets, cardinality conflicts, stale metadata, target-type mismatches, or broken bidirectional metadata fail closed rather than being guessed or silently repaired.
- No feature may introduce a parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity foundation
- #506: `RelationSchemaEvolutionService.inspectChange(...)` / transactional `updateRelationSchema(...)`; all-target validation, explicit multi->single survivor choice, single->multi preservation, rollback regressions, broken index/pair metadata fail closed.
- #568: one-sided bidirectional Relation Property deletion is blocked by delete-impact inspection, including empty pairs and corrupt pair metadata.
- #577: system Relation schema provisioning validates workspace/target/cardinality and delegates creation to canonical `ObjectStore.createRelationProperty(...)`.
- #590: safe non-structural Relation metadata is allowed while target/cardinality/bidirectional pair keys stay reserved to canonical Relation APIs.
- #601: template Gallery cover settings validate Relation target kind before schema/View creation; Image cover -> Tag Relation and other mismatches fail with no partial ObjectType. This preserves #592 primitive target provisioning and canonical Relation Property creation.

## Current implementation — pairRole-only metadata corruption
Original PR #649 `Detect pairRole-only Relation metadata corruption` reached Flutter CI #2035 fully green but became non-mergeable after main advanced.

Latest-main replacement branch: `feature/relation-pair-metadata-detection-v2`.

This slice closes a concrete fail-open gap:
- managed bidirectional metadata detection previously checked `bidirectional == true` or non-null `inversePropertyId` only;
- historical/corrupt schema with only `pairRole` could therefore be treated as an ordinary unidirectional Relation;
- `RelationMutationService` now treats non-null `pairRole` as managed-pair metadata and routes it through `BidirectionalRelationStore.pairFor(...)`, so incomplete pair metadata fails closed before value/index mutation;
- `RelationIntegrityService.auditWorkspace(...)` uses the same detection and reports `invalidBidirectionalPair`;
- focused regression proves mutation rejection leaves Relation value/backlink/index state untouched.

No shared hotspot lease is held; this branch changes only Relation service/test files and this handoff.

## Other active B-lane work
- #628 `Reject pair metadata pollution on system Relations` also passed Flutter CI #2037 on its old branch but is non-mergeable against current main. Its change remains independently useful: system Relation provisioning should reject any persisted `bidirectional`, `inversePropertyId`, or `pairRole` key presence rather than reusing corrupted schema. Refresh it only after the current pairRole detection slice is integrated or clearly non-overlapping on latest main.

## Cross-lane audits
- #633 (#491): compact Relation Property authoring delegates target/cardinality creation to `DatabasePropertyAuthoringService` and canonical `ObjectStore.createRelationProperty(...)`; no parallel persistence/index path.
- #608 (#491/#493): shared Relation authoring fields are presentation-only; existing Relation edits keep `inspectChange -> impact confirmation -> updateRelationSchema`.
- #492 Gallery media work remains read-only from the Relation side; no View-layer Relation repair/writer should be introduced.
- #596 Value schema evolution keeps Value -> Relation outside ordinary Value conversion.

## Validation state
- #601 merged after the refreshed target-kind guard.
- original #649 Flutter CI #2035: fully green, but old head became stale/non-mergeable.
- original #628 Flutter CI #2037: fully green, but old head became stale/non-mergeable.
- latest-main `feature/relation-pair-metadata-detection-v2` requires its own CI after replacement PR creation.
- local Flutter validation is unavailable in the connector execution environment; GitHub Actions is the executable validation source.

## Exact next actions
1. Open the latest-main replacement PR for pairRole-only corruption detection and close superseded #649.
2. If replacement CI is green/mergeable, integrate it.
3. Refresh #628 on then-current main and re-run its focused/full CI.
4. Continue auditing #491 real host quick-create wiring: target creation/import must succeed first, then canonical Relation attach; failure/retry must not leave partial/duplicate attachments.
5. Keep bidirectional target retargeting fail-closed until a paired migration validates both schema sides before writes.
6. Audit any new Relation-producing workflow for target/cardinality validation, delete/detach/retarget, retry/idempotency, backlink/index consistency, and integrity audit health.

## Risks / stop rule
- Non-empty Relation retargeting may proceed only when every existing target is valid for the proposed ObjectType; mapping/conversion requires an explicit migration.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- Corrupt pair metadata must never be silently downgraded to an ordinary Relation.
- Do not add speculative abstractions. If the active corruption guards are integrated and no concrete Relation-producing workflow or correctness regression exists, record the next trigger and remain idle.
