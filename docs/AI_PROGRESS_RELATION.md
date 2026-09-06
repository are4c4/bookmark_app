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

### Integrated deletion/reference integrity
PR #568 `Block Property deletion when a bidirectional Relation pair is affected` is merged on main as commit `11d89aaae346b7f83341a67f5d86ccb5d92e8195`.
- `DatabaseViewPropertySchemaService.inspectDelete(...)` surfaces the inverse Property even when neither side has stored values.
- corrupt/incomplete bidirectional metadata fails closed.
- delete confirmation remains disabled while a managed Relation pair would be affected, preventing one-sided schema deletion from generic Property UX.

### Integrated canonical system Relation schema creation
PR #577 `Validate system Relation schemas through canonical creation` is merged on main as merge commit `30d3ccf51a944fb22d5a072a43b0be6c1ce6cbb6`.
- final PR head `dd29e7b395e2a701a15afc392694e55800a5e391` passed Flutter CI #1890 fully green;
- `SystemObjectStore.ensureRelationProperty(...)` validates source/target existence and same-workspace membership;
- matching existing system Relations are reused idempotently only when target/cardinality match exactly;
- same-name Value Properties or target/cardinality drift fail closed without schema mutation;
- new system Relation Properties delegate to `ObjectStore.createRelationProperty(..., allowSystemMutation: true)` rather than hand-building structural Relation config.

PR #590 `Allow safe metadata on canonical Relation Property creation` is also merged on latest main `f4c44e33b8ef9cbff840836d0cb0415c1402f87e`.
- canonical Relation creation now accepts non-structural metadata;
- structural/pair keys (`targetObjectTypeId`, `multiple`, `bidirectional`, `inversePropertyId`, `pairRole`) are reserved and rejected when injected through metadata;
- this keeps target/cardinality/pair structure owned by canonical Relation schema APIs.

### Active B-lane PR #593
Branch: `feature/relation-template-gallery-cover-target-guard`
PR: #593 `Reject mismatched Gallery cover Relation targets in templates`
Head: `f7b77c7c7a8bdfc4ec7fcf95942fc7942c1bc647`

#593 is a #492/#493 fail-closed follow-up to template Gallery cover configuration:
- validates symbolic Gallery cover Relation references before creating a user ObjectType/View;
- `imageRelation` must reference a Relation targeting the canonical Image system key;
- `weblinkRelationRepresentativeImage` must reference a Relation targeting the canonical Weblink system key;
- one-sided cover declarations, duplicate/non-Relation references, and target-kind mismatches fail before schema creation;
- the existing transaction and stable created Property-id persistence path are preserved;
- focused regression proves an Image cover kind pointed at a Tag Relation leaves no partial ObjectType.

No shared hotspot lease is held by Lane B. #593 changes a service/domain file and focused tests only.

### Cross-lane audits in this run
- #592 (#490/#492/#484): fresh-workspace template Relation targets reuse existing system ObjectTypes or delegate to canonical primitive ensure paths for Tag/Weblink/Image/File; template Relation schema still uses canonical ObjectStore creation. No Relation value/index writer is introduced.
- #595 (#491): the new Relation target quick-create action is presentation-only. Persistence is callback-supplied by the host, unavailable/missing-writer cases render no fallback, and Image/File/Weblink/Tag modes do not perform title-only persistence themselves.
- #590: metadata extension preserves the canonical structural Relation boundary by rejecting structural/pair metadata injection.

## Validation state
- #506 Flutter CI: fully green before merge.
- #568 merged with focused bidirectional delete-impact regressions.
- #577 Flutter CI #1890: fully green before merge.
- #593 Flutter CI #1911 is currently running; merge only after green and a fresh mergeability check against latest main.
- Local Flutter validation is unavailable in this execution environment; GitHub Actions is the executable validation source.

## Exact next actions
1. Re-check #593 CI #1911 and mergeability; if green/mergeable, integrate it, otherwise refresh only its two-file fail-closed slice onto latest main.
2. Continue auditing #491 host wiring: creation must use `createRelationProperty(...)`; existing target/cardinality edits must use `inspectChange(...)` / `updateRelationSchema(...)`; inline quick-create callbacks must invoke canonical target creation/import and then canonical Relation mutation.
3. Audit #492 actual media resolution for multi-valued Relations: deterministic read-only selection/fallback only, no View-layer repair/mutation, and no leaked single-cardinality assumption.
4. Keep bidirectional Relation target retargeting fail-closed until a paired migration validates both schema sides before writes.
5. Review new template/primitive Relation-producing workflows for target/cardinality validation, transactional no-partial-schema behavior, deletion/reference integrity, retry/idempotency, and canonical mutation/index lifecycle.

## Current risks / stop rule
- Non-empty Relation target retargeting can proceed only when every existing target is valid for the proposed target ObjectType; mapping/conversion is a separate explicit migration decision.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- One-sided bidirectional Relation Property deletion is blocked by #568; a future explicit paired-delete UX must still call canonical Relation lifecycle rather than deleting schema rows directly.
- Quick-create host wiring is safe only if target creation/import succeeds before canonical Relation attachment and failures cannot leave a partially-attached Relation.
- Do not add speculative abstractions. If #593 is integrated and no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression exists, record the next trigger and remain idle.
