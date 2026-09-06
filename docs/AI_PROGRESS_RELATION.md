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
- Managed bidirectional metadata is structural. Presence of any reserved pair key (`bidirectional`, `inversePropertyId`, `pairRole`) means the Property must resolve as a valid canonical pair or fail closed.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index drift only.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Ambiguous damage, missing targets, cardinality conflicts, stale metadata, target-type mismatches, or broken pair metadata fail closed rather than being guessed or silently repaired.
- No feature may introduce a parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity foundation
- #506: `RelationSchemaEvolutionService.inspectChange(...)` / transactional `updateRelationSchema(...)`; all-target validation, explicit multi->single survivor choice, single->multi preservation, stale index/pair metadata fail closed, rollback coverage.
- #568: one-sided bidirectional Relation Property deletion is blocked by delete-impact inspection, including empty pairs and corrupt pair metadata.
- #577: system Relation schema provisioning validates workspace/target/cardinality and delegates creation to canonical `ObjectStore.createRelationProperty(...)`.
- #590: safe non-structural Relation metadata is allowed while target/cardinality/pair keys remain reserved to canonical Relation APIs.
- #601: template Gallery cover settings validate Relation target kind before schema/View creation and leave no partial ObjectType on mismatch.
- #628: system Relation provisioning rejects any persisted reserved pair key presence instead of reusing pair-polluted system schema.
- #662: incomplete managed-pair metadata now fails closed consistently across mutation, audit, schema evolution, and deletion inspection.

### #662 managed-pair corruption hardening
PR #662 `Fail closed on incomplete Relation pair metadata` merged as `04ef35b7b972868b718dfea90ea68d06751345ff` after Flutter CI #2078 passed fully green.

The merged contract:
- `BidirectionalRelationStore.hasManagedPairMetadata(...)` centralizes structural-key presence detection for `bidirectional`, `inversePropertyId`, and `pairRole`;
- false/null remnants are still treated as managed/stale metadata, not ordinary unidirectional Relation metadata;
- `pairFor(...)` requires `pairRole` to be `source` or `inverse` and requires the reciprocal Property to carry the complementary role;
- direct `BidirectionalRelationStore.setRelation(...)` fails closed on incomplete pair metadata;
- `RelationMutationService`, `RelationIntegrityService`, `RelationSchemaEvolutionService`, and `DatabaseViewPropertySchemaService.inspectDelete(...)` all reuse the same predicate;
- incomplete pairs are reported as `invalidBidirectionalPair`; no repair or downgrade is guessed;
- regressions cover role mismatch and null/remnant metadata while proving Relation value/index state is not mutated.

This supersedes the unmerged #649/#658 attempts. Do not revive their branches unless a future concrete regression is not covered by #662.

## #491 Relation authoring / quick-create correctness
- #604 is merged: Relation picker quick-create must refresh canonical `RelationSelectionContext` before the new target can be selected; stale pre-create candidates cannot bypass validation.
- #627 is merged: `RelationTargetQuickCreateService` uses canonical Object creation for custom targets, Tag bridge synchronization for Tags, normalized/reusable Weblink identity for Weblinks, and requires canonical managed Image/File import callbacks. Returned Object ids are revalidated against workspace and configured target ObjectType. It does not write Relation values.
- #633 is merged: compact Relation Property creation uses `DatabasePropertyAuthoringService` -> canonical `ObjectStore.createRelationProperty(...)` with explicit target/cardinality.
- latest main #666 composes canonical Property authoring, delete-impact, Relation schema evolution, and Value conversion/migration services into `GenericDatabasePageServices`; no alternate Relation writer or integrity path is introduced.
- production code search still shows the managed Image/File quick-create callbacks only inside `RelationTargetQuickCreateService` and focused tests. A real Relation value-editor host has not yet composed the full quick-create -> refresh -> attach path.

Next #491 correctness trigger: when the real host composes target quick-create, regress canonical target create/import -> refreshed candidate context -> `ObjectRelationEditorService.save(...)` -> `RelationMutationService`, with cancellation/failure leaving no attachment and retry producing no duplicate edge/backlink.

## #492 Gallery Relation correctness
- template Gallery cover target-kind integrity is merged through #601.
- Gallery Relation consumers remain read-only from the Relation side; View/media resolver code must not repair Relation values or indexes.
- multi-valued Relation cover selection must remain deterministic/read-only and must not leak a single-cardinality assumption.

## Current validation / repository state
- Latest main observed during this handoff run: `a6d2a0cb20b6cffa09bcd6efc7837a27cbf6146b` (#666).
- #662 Flutter CI #2078: fully green before merge.
- #628 and #601 are merged.
- #649 and #658 are closed unmerged/superseded.
- No shared hotspot lease is held by Lane B in this handoff update; this change is docs-only.
- Local Flutter execution is unavailable in this connector environment; GitHub Actions remains the executable validation source.

## Exact next actions
1. Audit any new #491 real-host quick-create composition; add attach/failure/retry/idempotency regressions only when the actual value-writing path lands.
2. Audit #492 multi-valued Relation media resolution for deterministic read-only behavior and corrupted/missing Relation fail-closed semantics.
3. Keep bidirectional Relation target retargeting fail-closed until a paired migration validates both schema sides before writes.
4. Review every new Relation-producing primitive/template/domain workflow for target/cardinality validation, delete/detach/retarget, retry/idempotency, backlink/index consistency, and integrity audit health.
5. If none of those triggers exists, remain idle rather than inventing new Relation abstractions.

## Risks / stop rule
- Non-empty Relation retargeting may proceed only when every existing target is valid for the proposed ObjectType; mapping/conversion requires an explicit migration.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- Corrupt pair metadata must never be silently downgraded to an ordinary Relation.
- A future quick-create host is safe only if target creation/import succeeds before canonical Relation attachment, refreshed candidates are used for validation, cancellation/failure leaves no partial Relation write, and retries stay idempotent.
