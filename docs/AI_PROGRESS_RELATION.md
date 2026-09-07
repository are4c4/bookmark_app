# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Preserve the canonical Relation subsystem; do not invent parallel Relation writers/indexes merely to keep this lane busy.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle, integrity-sensitive schema evolution, and deletion/reference invariants.

## Primary active issues
- #493 — integrity side of safe/reversible schema evolution, especially Relation target/cardinality changes.
- #491 — lifecycle/integrity regressions for generic Relation Property authoring/editing and inline target creation.
- #492 — integrity/read regressions for generic Gallery cover sources backed by Relations.
- #245/#484 — new primitive/domain Relation-producing workflows when real production writes appear.
- #56 — umbrella canonical Relation contract.

## Canonical Relation contract
- Feature Relation writes go through `RelationMutationService`.
- Reads/backlinks use `RelationReadService` / canonical ObjectStore projections.
- Relation Property creation uses `ObjectStore.createRelationProperty(...)` or a canonical facade delegating to it.
- `RelationIntegrityService` is read-only; `RelationIndexReconcileService` repairs deterministic index drift only.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Missing targets, cardinality conflicts, stale index/pair metadata, target-type mismatches, and ambiguous corruption fail closed.
- No parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity state — 2026-09-07
- #506: fail-closed Relation schema evolution foundation. Target changes validate every existing target; ambiguous multi -> single requires explicit choices; single -> multi preserves values; failed migration rolls back atomically; bidirectional target retargeting remains unsupported.
- #568: generic Property deletion cannot silently remove one side of a managed bidirectional Relation pair.
- #577/#590: system Relation schema creation is canonical and rejects target/cardinality/pair-structure drift or reserved structural metadata injection.
- #601: Gallery template cover Relations fail closed unless `imageRelation` targets canonical Image and Weblink representative-image cover targets canonical Weblink; no partial ObjectType/View is created on mismatch. PR #601 merged as `1431e0734af7760f1e5caf87e3d865252a3fdceb`, CI #1929 green.
- #628: system Relations carrying any managed pair metadata are rejected rather than reused as healthy schema.
- #662: `BidirectionalRelationStore.hasManagedPairMetadata(...)` is the canonical reserved-pair predicate; incomplete/false/null remnants and non-complementary `pairRole` metadata fail closed across mutation, audit, delete inspection, and schema evolution. Merge `04ef35b7b972868b718dfea90ea68d06751345ff`.

## Current B-lane implementation
Branch: `feature/relation-duplicate-target-validation`

A concrete canonical mutation gap was found while auditing retry/idempotency behavior: multi-Relation writes accepted repeated target ids until normalized-edge insertion hit the `(source_object_id, property_id, target_object_id)` primary key. That made duplicate input fail late at the storage/index layer rather than at the Relation mutation boundary.

Current slice:
- `RelationMutationService.setRelation(...)` rejects duplicate target Object ids before pair resolution or any value/index write;
- rejection is fail-closed and leaves the prior persisted Relation value and normalized edges unchanged;
- focused regression `relation_duplicate_target_validation_test.dart` first stores two valid targets, retries with a duplicate target list, expects `ArgumentError`, and verifies the original value plus exactly two edges survive.

No shared hotspot lease is held. This slice changes only the Relation mutation service, one focused test, and this handoff.

## Cross-lane audit
- #677 (Lane A) touches only `generic_database_store.dart` and its ownership regression; it does not overlap this Relation mutation-service slice. Its cross-ObjectType value-write guard preserves same-source Relation corruption fixtures and does not replace Relation target/cardinality validation.
- #657 remains presentation/schema-authoring UX; existing Relation edits still delegate to `RelationSchemaEvolutionService` and no Relation value/index writer is added.
- Latest primitive File/Image storage work does not introduce a new Relation-producing path; Object deletion continues to use canonical Relation-safe deletion where required.
- No real Relation value-editor quick-create host is present yet; #491 remains a trigger when target creation/import becomes wired to canonical attach.

## Validation state
- #601 CI #1929: green before merge.
- #662 reported green CI #2078 before merge.
- Local Flutter validation is unavailable in this execution environment because direct github.com resolution is unavailable; GitHub Actions is the executable validation source.
- Current duplicate-target branch needs Flutter CI after PR creation.

## Exact next actions
1. Run CI for the duplicate-target validation slice; fix any regression and merge only when green/mergeable against latest main.
2. Audit #491 real quick-create host wiring when it appears: target creation/import must complete before canonical Relation attach; attach failure/retry must not create duplicate edges or partial Relation state.
3. Audit #492 multi-valued media resolution for deterministic read-only selection/fallback, with no View-layer Relation repair or single-cardinality assumption.
4. Keep bidirectional target retargeting fail-closed until a paired schema migration validates both sides before writes.
5. Continue reviewing new primitive/template/domain Relation-producing workflows for target/cardinality validation, transactional no-partial behavior, delete/reference integrity, retry/idempotency, backlinks/index and audit health.

## Stop rule
Do not invent speculative abstractions. If the current duplicate-target slice is integrated and no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression exists, record the next trigger and remain idle.
