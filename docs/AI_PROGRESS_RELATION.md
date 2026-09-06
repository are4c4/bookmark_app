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

This gives the lane useful independent work without inventing new Relation architecture.

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

## Initial next actions
1. For #493, define transactional validation rules for `Relation(A) -> Relation(B)` target changes: validate all existing targets first and leave old schema/data intact on any failure.
2. Define `multi -> single` behavior: require explicit deterministic user choice when multiple values exist; never silently drop targets.
3. Define `single -> multi` behavior: preserve the existing target without rewriting unrelated edges.
4. Add focused service/domain regressions around schema mutation rollback, edge/index/backlink preservation and fail-closed target mismatch.
5. As #491 lands, verify generic Relation Property creation still uses canonical target/cardinality validation and no alternate writer/index.
6. Resume product-workflow lifecycle coverage only when Primitive/Database-View lanes add a genuinely new Relation-producing production path.

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

## Handoff checklist
Before ending a run, record:
- active Issue and exact integrity contract;
- branch/commit/PR;
- regressions/services added;
- validation results;
- cross-lane dependency and hotspot ownership;
- next independent integrity actions;
- explicit stop reason.

## Stop rule
If there is no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression, remain idle rather than adding speculative abstractions. The broadened #493/#491 scope is the current source of independent work.
