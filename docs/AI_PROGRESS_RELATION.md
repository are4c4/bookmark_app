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

Replacement PR #658 on `feature/relation-pair-metadata-detection-v2` is based on current main at branch creation.

This slice closes a concrete fail-open gap:
- managed bidirectional metadata detection previously checked `bidirectional == true` or non-null `inversePropertyId` only;
- historical/corrupt schema with only `pairRole` could therefore be treated as an ordinary unidirectional Relation;
- `RelationMutationService` now treats non-null `pairRole` as managed-pair metadata and routes it through `BidirectionalRelationStore.pairFor(...)`, so incomplete pair metadata fails closed before value/index mutation;
- `RelationIntegrityService.auditWorkspace(...)` uses the same detection and reports `invalidBidirectionalPair`;
- focused regression proves mutation rejection leaves Relation value/backlink/index state untouched.

No shared hotspot lease is held; #658 changes only Relation service/test files and this handoff.

## #491 / #492 correctness audit
- #627 is merged: `RelationTargetQuickCreateService` creates custom targets through canonical Object creation, Tags through Tag bridge sync, Weblinks through normalized/reusable Weblink identity, and requires canonical managed Image/File import callbacks. Returned ids are revalidated against workspace and configured target ObjectType. It does not write Relation values.
- #604 is the refresh-safe picker seam: quick-create must reload canonical selection context before the created Object can be selected; the picker does not bypass `ObjectRelationEditorService.save(...)` / `RelationMutationService`.
- #633 is merged: compact Relation Property authoring uses `DatabasePropertyAuthoringService` and canonical `ObjectStore.createRelationProperty(...)` with explicit target/cardinality.
- #608 keeps Relation schema editing on `inspectChange -> impact confirmation -> updateRelationSchema` and is presentation-only around the canonical service.
- #492 Gallery media consumers remain read-only from the Relation side; no View-layer Relation repair/writer should be introduced.

No production host currently composes the target quick-create service into a Relation value editor; code search still finds `createManagedImage` only inside the service and its focused tests. The next value-writing trigger is the real host composition.

## Validation state
- #601 merged.
- #628 merged as `59a56231632edae94f4fe5554378a543a4489460`; its old CI #2037 was green.
- original #649 CI #2035: fully green before supersession.
- #658 CI #2069: maintainability guards, dependency setup, Drift generation, and Analyze are green; full Test is running at this handoff update.
- local Flutter validation is unavailable in the connector execution environment; GitHub Actions is the executable validation source.

## Exact next actions
1. Re-check #658 CI #2069; if fully green and mergeable, integrate it. If main advanced without overlapping Relation files, refresh only this small slice rather than broad rebasing unrelated changes.
2. On real #491 quick-create host composition, add lifecycle regression covering canonical target create/import -> refreshed candidate context -> canonical Relation attach; cancellation/failure must leave no attachment and retry must not duplicate edges/backlinks.
3. Keep bidirectional target retargeting fail-closed until a paired migration validates both schema sides before writes.
4. Audit new Relation-producing workflows for target/cardinality validation, delete/detach/retarget, retry/idempotency, backlink/index consistency, and integrity audit health.

## Risks / stop rule
- Non-empty Relation retargeting may proceed only when every existing target is valid for the proposed ObjectType; mapping/conversion requires an explicit migration.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- Corrupt pair metadata must never be silently downgraded to an ordinary Relation.
- Do not add speculative abstractions. If #658 is integrated and no real quick-create host, new Relation-producing workflow, or concrete correctness regression exists, record the next trigger and remain idle.
