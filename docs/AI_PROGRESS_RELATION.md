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
- #601: template Gallery cover settings validate Relation target kind before schema/View creation; Image cover -> Tag Relation and other mismatches fail with no partial ObjectType.
- #628: system Relation provisioning rejects any persisted `bidirectional`, `inversePropertyId`, or `pairRole` key presence instead of reusing pair-polluted system schema; focused tests cover each reserved key and preserve the corrupt Property unchanged.

## Current implementation — pairRole-only metadata corruption
Original PR #649 `Detect pairRole-only Relation metadata corruption` passed Flutter CI #2035 but became non-mergeable after main advanced and was closed as superseded.

Replacement PR #658 on `feature/relation-pair-metadata-detection-v2` is the current B-lane implementation.

This slice closes the same fail-open condition everywhere canonical code decides whether Relation pair metadata is present:
- `RelationMutationService` treats non-null `pairRole` as managed-pair metadata before feature Relation mutation;
- `RelationIntegrityService.auditWorkspace(...)` reports pairRole-only state as `invalidBidirectionalPair`;
- direct `BidirectionalRelationStore.setRelation(...)` no longer downgrades pairRole-only corruption to an ordinary unidirectional write;
- `RelationSchemaEvolutionService.inspectChange(...)` fails closed before target/cardinality migration when pairRole-only metadata is present;
- `DatabaseViewPropertySchemaService.inspectDelete(...)` fails closed rather than presenting a corrupt pair as an independently deletable Relation.

All paths route incomplete pair metadata through `BidirectionalRelationStore.pairFor(...)`, which returns no valid pair and therefore blocks the operation. No repair is guessed and no pair format changes.

The focused regression creates one canonical Relation, corrupts it to contain only `pairRole`, then proves audit reports it and all four mutation/schema/delete-impact entry points reject it while Relation value, backlink/index-visible state, target/cardinality schema, and corrupt metadata remain untouched.

No shared hotspot lease is held; #658 changes Relation/data-integrity services, one focused test, and this handoff only.

## #491 / #492 correctness audit
- #627 is merged: `RelationTargetQuickCreateService` creates custom targets through canonical Object creation, Tags through Tag bridge sync, Weblinks through normalized/reusable Weblink identity, and requires canonical managed Image/File import callbacks. Returned ids are revalidated against workspace and configured target ObjectType. It does not write Relation values.
- #604 is merged: quick-create must reload canonical selection context before the created Object can be selected; the picker does not bypass `ObjectRelationEditorService.save(...)` / `RelationMutationService`.
- #633 is merged: compact Relation Property authoring uses `DatabasePropertyAuthoringService` and canonical `ObjectStore.createRelationProperty(...)` with explicit target/cardinality.
- #608 was closed unmerged; do not rely on that branch as current production state.
- #492 Gallery media consumers remain read-only from the Relation side; no View-layer Relation repair/writer should be introduced.

No production host currently composes the target quick-create service into a Relation value editor; code search still finds `createManagedImage` only inside the service and its focused tests. The next value-writing trigger is the real host composition.

## Validation state
- #601 merged.
- #628 merged as `59a56231632edae94f4fe5554378a543a4489460`; CI #2037 was green.
- original #649 CI #2035 was fully green before supersession.
- #658 had guardrail/Drift/Analyze green on earlier replacement heads; extending the branch to all pair-metadata detection sites triggers a fresh Flutter CI and that latest run is authoritative before merge.
- local Flutter validation is unavailable in the connector execution environment; GitHub Actions is the executable validation source.

## Exact next actions
1. Re-check the latest #658 Flutter CI after the expanded regression commit; if fully green and mergeable, integrate it. If main advanced without overlapping Relation files, refresh only this small slice rather than carrying unrelated changes.
2. On real #491 quick-create host composition, add lifecycle regression covering canonical target create/import -> refreshed candidate context -> canonical Relation attach; cancellation/failure must leave no attachment and retry must not duplicate edges/backlinks.
3. Keep bidirectional target retargeting fail-closed until a paired migration validates both schema sides before writes.
4. Audit new Relation-producing workflows for target/cardinality validation, delete/detach/retarget, retry/idempotency, backlink/index consistency, and integrity audit health.

## Risks / stop rule
- Non-empty Relation retargeting may proceed only when every existing target is valid for the proposed ObjectType; mapping/conversion requires an explicit migration.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- Corrupt pair metadata must never be silently downgraded to an ordinary Relation in mutation, audit, schema evolution, or delete-impact paths.
- Do not add speculative abstractions. If #658 is integrated and no real quick-create host, new Relation-producing workflow, or concrete correctness regression exists, record the next trigger and remain idle.
