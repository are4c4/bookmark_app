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
- Ambiguous damage, missing targets, cardinality conflicts, stale metadata, target-type mismatches, or broken bidirectional metadata fail closed rather than being guessed or silently repaired by editor/View code.
- No feature may introduce a parallel serialized-id Relation writer or alternate edge/index store.
- Low-level `ObjectStore.setRelation` remains storage-internal/test-facing rather than a normal product mutation path.

## Stable integrated coverage
Production workflows already have lifecycle coverage for Bookmark -> Weblink, Weblink -> Image Representative/Related image Relations, Bookmark -> Image `Images`/`Cover Image`, delete/detach/retarget/backlink/index/audit/reconcile behavior, alias-aware Relation candidate/picker behavior, and historical migration/bootstrap separation from legacy relation-like tables.

## Current implementation checkpoint — 2026-09-07

### Integrated #493 integrity foundation
- merged PR #506 `Add fail-closed Relation schema evolution integrity`
- squash merge: `6cc91cccb4b1ac4d23b6dc8ae3d1f1e7c40aa8e4`
- final reviewed PR head: `c60e0800a4ea78439c0fc1de34990a1f9779d9ba`
- duplicate #508 was compared and closed unmerged.

`RelationSchemaEvolutionService` now provides read-only `inspectChange(...)` plus transactional `updateRelationSchema(...)`:
- Relation target ObjectType changes validate persisted source/target schema, workspace, current integrity/index state, and every existing target before writes;
- ambiguous `multi -> single` requires an explicit surviving target already present for each conflicting source;
- `single -> multi` preserves existing values/edges;
- stale/missing index state, missing targets, corrupt pair metadata, and target mismatch fail closed;
- bidirectional target retargeting remains deliberately unsupported until an explicit paired migration exists;
- forced database-failure coverage proves schema/data/index rollback atomicity.

### Newly integrated deletion/reference integrity
PR #568 `Block Property deletion when a bidirectional Relation pair is affected` is merged on main as commit `11d89aaae346b7f83341a67f5d86ccb5d92e8195`.
- `DatabaseViewPropertySchemaService.inspectDelete(...)` now surfaces the inverse Property even when neither side has stored values.
- corrupt/incomplete bidirectional metadata fails closed.
- delete confirmation remains disabled while a managed Relation pair would be affected, preventing one-sided schema deletion from generic Property UX.
- This is inspection/UI gating only; it does not duplicate canonical Relation deletion semantics.

### Active B-lane PR #577
Branch: `feature/relation-system-schema-validation`
PR: #577 `Validate system Relation schemas through canonical creation`
Current implementation head before this handoff update: `ed88422ac2a9c534dbe180ecb0a2e26b0b99338a`
Branch base at PR creation: `07bd5b693a16a923cdbe5687b00ce57ba68bb4f9`
Latest audited main while this handoff was updated: `ece01fb104933570d320ffb2d0f1af0d750e0369`.

#577 closes a remaining production Relation-schema creation exception in `SystemObjectStore.ensureRelationProperty(...)`:
- validates source/target ObjectTypes exist and belong to the same workspace before return/create;
- reuses an existing same-name system Property only when it is exactly the required Relation target/cardinality;
- mismatched Value Property, target, or cardinality fails closed without mutating existing schema;
- new system Relation Properties are created through `ObjectStore.createRelationProperty(..., allowSystemMutation: true)` rather than hand-building Relation config with generic Property creation;
- repeated matching ensure calls remain idempotent;
- focused tests cover canonical same-workspace creation, cross-workspace rejection/no partial Property, incompatible existing Property rejection, and target/cardinality drift preservation.

No shared hotspot lease was taken. #577 changes only `lib/data/system_object_store.dart`, focused tests, and this handoff.

### Cross-lane audits in this run
- #567 (#491/#493): existing Relation Property editing routes proposed changes through `RelationSchemaEvolutionService.inspectChange(...)` and `updateRelationSchema(...)`; ambiguous multi-to-single stays disabled until an explicit target is chosen. No direct Relation config write was found.
- #563 (#490/#492): template Gallery cover configuration resolves the newly-created stable Relation Property id and Relation schema creation uses `ObjectStore.createRelationProperty(...)`; invalid symbolic cover references fail transactionally. No alternate Relation writer/index was found.
- #556 (#492): Gallery compatibility discovery is read-only and fail-closed for malformed persisted cover settings. It selects schema-defined Relation sources but does not repair/mutate Relation values.
- #550 (#56/#484): ObjectType duplication preserves Property order and fails transactionally on missing Relation target metadata. Its Relation copy path remains a schema-copy concern; keep canonical `createRelationProperty(...)` validation intact when the PR is refreshed/merged.

## Validation state
- #506 Flutter CI: fully green before merge, including maintainability guards, Drift generation, analyze and full tests.
- #568 is merged on main with focused bidirectional Relation delete-impact regressions.
- #577 Flutter CI run #1869: maintainability guardrails, dependency install, Drift generation and `flutter analyze` are green; full test step was still running at the last check before this handoff commit.
- Local Flutter validation is unavailable in this execution environment because the container cannot resolve `github.com`; GitHub Actions is the executable validation source.

## Exact next actions
1. Re-check #577 CI after this handoff commit; fix any regression, then refresh against latest main if needed and merge only when green/mergeable.
2. Continue auditing #567 real host wiring for #491/#493: Relation edits must keep using `inspectChange` / `updateRelationSchema`; creation must use `createRelationProperty(...)` rather than hand-built config.
3. Audit #492's actual media resolver when it reads Relation values: multi-valued Relations must have deterministic read-only selection/fallback, missing/corrupt Relation state must not be repaired from View code, and no single-cardinality assumption may leak in.
4. Keep bidirectional Relation target retargeting fail-closed until a paired migration validates both schema sides before writes.
5. Review any new Relation-producing primitive/template/domain workflow for canonical target/cardinality validation, transactional no-partial-schema behavior, deletion/reference integrity, retry/idempotency, and canonical value mutation/index lifecycle.

## Current risks / stop rule
- Non-empty Relation target retargeting can proceed only when every existing target is already valid for the proposed target ObjectType; mapping/conversion is a separate explicit migration decision.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- One-sided bidirectional Relation Property deletion is now blocked by #568, but a future explicit paired-delete UX must still call the canonical Relation lifecycle rather than deleting schema rows directly.
- Do not add speculative abstractions. If #577 is integrated and no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression exists, record the next trigger and remain idle.
