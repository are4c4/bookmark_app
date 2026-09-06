# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. This lane supersedes the former narrow Relation-only routing while preserving the canonical Relation subsystem.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle plus integrity-sensitive schema evolution and deletion/reference invariants.

## Primary active issues
- #493 — integrity side of safe/reversible schema evolution, especially Relation target/cardinality changes.
- #491 — lifecycle/integrity regressions for new generic Relation Property authoring and inline target creation.
- #492 — integrity/read regressions if generic Gallery cover-source work introduces new Relation traversal assumptions.
- #245/#484 — new primitive/person/file Relation-producing workflows only when real production writes appear.
- #56 — umbrella canonical Relation contract.

## Canonical Relation contract
- Feature writes go through `RelationMutationService`.
- Reads/backlinks use `RelationReadService` / canonical ObjectStore projections.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index drift only.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Ambiguous damage, missing targets, cardinality conflicts, stale metadata, or target-type mismatches are not guessed or silently repaired from editor paths.
- No feature may introduce a parallel serialized-id Relation writer or alternate edge/index store.
- Low-level `ObjectStore.setRelation` remains storage-internal/test-facing rather than a normal product mutation path.

## Why this lane is broader now
The Relation subsystem itself is mature, so production Relation redesign is rarely justified. The lane now also owns independent **data-integrity obligations** created by user-composable schema work:
- validating every existing target before changing a Relation target ObjectType;
- safe `single <-> multi` cardinality changes;
- deterministic/fail-closed migration behavior;
- rollback/atomicity when a schema mutation fails;
- deletion/reference integrity across newly composable domains;
- corruption/inconsistent-index regressions.

## Current implementation checkpoint — 2026-09-07
Active Issue: #493.

Branch: `feature/relation-safe-schema-evolution`
Latest lane commit: `88c34d390da5246ebd2252ca70233d629a553252`
Base inspected: main `844f6b77e7b6947bceaaf6986e6ff8182212e71b`.

Implemented first fail-closed schema-evolution slice:
- added `RelationSchemaEvolutionService.changeRelationSchema(...)` for custom unidirectional Relation Properties;
- resolves the persisted Relation Property rather than trusting stale caller metadata;
- requires the new target ObjectType to exist in the same workspace;
- validates every currently referenced target before changing `targetObjectTypeId`;
- rejects `multi -> single` when any Object currently stores multiple targets, requiring a later explicit target-choice flow instead of silently dropping data;
- allows `single -> multi` by changing schema metadata only, preserving the existing stored target and normalized edges/backlinks;
- target changes with no existing values update schema metadata only;
- system Relations and bidirectional pairs fail closed pending explicit system/paired migration semantics;
- no Relation values, normalized edges, or backlinks are rewritten by this schema-only service.

Focused regressions added in `test/relation_schema_evolution_service_test.dart`:
- failed target-type change preserves old schema/value/edge/backlink;
- ambiguous `multi -> single` preserves old schema/data;
- `single -> multi` preserves stored target and exact normalized edge shape;
- empty target-type change updates only the Relation schema.

Open PR ownership was checked before editing. Current open #503/#504/#498 do not overlap this new service/test slice; no shared hotspot lease was required. Stale docs-only Relation PR #477 was closed rather than rebased because this #493 implementation supersedes its handoff.

Validation status: GitHub-hosted CI will be the first executable validation because the runtime container cannot resolve github.com for a local clone. Review/CI failures should be fixed on this branch before merge.

## Stable integrated coverage
Existing production workflows already have strong lifecycle coverage for:
- Bookmark -> Weblink;
- Weblink -> Image Representative/Related image Relations;
- Bookmark -> Image `Images` multi-Relation;
- Bookmark -> Image `Cover Image` single Relation;
- delete/detach/retarget/backlink/index/audit/reconcile behavior;
- alias-aware Relation candidate/picker behavior;
- historical migration/bootstrap separation from legacy relation-like tables.

Recent Image edit/crop/geometry work is Relation-neutral and does not justify new Relation production code.

## Next actions
1. Run/fix CI for the first #493 schema-evolution slice and merge when green.
2. Add an explicit deterministic `multi -> single` choice API only after the Database/View lane establishes the migration prompt contract; it must validate the selected target before any write.
3. Define explicit bidirectional-pair schema migration semantics; do not mutate only one half of a managed pair.
4. Add transaction/rollback coverage around any future schema migration that rewrites values rather than metadata only.
5. As #491 lands, verify generic Relation Property creation/inline target creation still uses canonical target/cardinality validation and no alternate writer/index.
6. As #492 lands, audit Gallery Relation traversal assumptions without moving presentation work into this lane.
7. Resume product-workflow lifecycle coverage only when Primitive/Database-View lanes add a genuinely new Relation-producing production path.

## Cross-lane boundaries
- **Database/View lane** owns schema-authoring dialogs and user-facing migration prompts.
- **Object Core lane** owns Object/ObjectType core model and Body semantics.
- **Primitive lane** owns Image/File/Weblink/Tag product semantics and decides when new Relations are required.
- **Refactor lane** may delete dead compatibility code only after product parity; it must not redesign Relation semantics.

## Safety / sequencing
- Legacy Bookmark/Photo compatibility state remains live until caller-zero; integrity tests do not authorize destructive cleanup.
- Do not infer a new Person -> Image Relation contract until Primitive/Object work establishes a real production workflow.
- Do not add Relation tests merely because an Image/Weblink participates in Relations; add them only when identity/targets/writes/deletion semantics change.
- Prefer tests/integrity services and avoid presentation-only edits.
- Never silently discard Relation targets during a cardinality migration.
- Never mutate only one side of a managed bidirectional Relation pair.

## Stop rule
Continue #493 while independent integrity slices exist. If there is no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression, remain idle rather than adding speculative abstractions.
