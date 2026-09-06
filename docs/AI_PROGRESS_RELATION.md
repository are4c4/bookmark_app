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

PR #590 `Allow safe metadata on canonical Relation Property creation` is merged.
- canonical Relation creation accepts non-structural metadata;
- structural/pair keys (`targetObjectTypeId`, `multiple`, `bidirectional`, `inversePropertyId`, `pairRole`) are reserved and rejected when injected through metadata;
- target/cardinality/pair structure therefore remains owned by canonical Relation schema APIs.

### Current B-lane implementation — Gallery cover target integrity
Original PR #593 `Reject mismatched Gallery cover Relation targets in templates` reached fully green Flutter CI #1911, but became non-mergeable after #592 changed the same template store.

To avoid discarding #592's fresh-workspace primitive provisioning, the same focused integrity slice was refreshed from latest main `f8fa8f8bd9dd6a9a5dc4bba52216b5893e0b8574` onto:
- branch `feature/relation-template-gallery-cover-target-guard-v2`
- production commit `6416b12f5e156f4e161b22b9b14b864225c4a685`
- regression commit `2b99cb6ddcdb39b69ca2adcab0035ee01c7657a0`

The refreshed slice:
- validates symbolic Gallery cover Relation references before creating the user ObjectType/View;
- requires `imageRelation` to reference an Image-target Relation;
- requires `weblinkRelationRepresentativeImage` to reference a Weblink-target Relation;
- rejects one-sided declarations, duplicate/non-Relation references, and target-kind mismatches before schema creation;
- preserves #592 primitive target provisioning and canonical `ObjectStore.createRelationProperty(...)` schema creation;
- preserves the existing transaction and stable created Property-id persistence path;
- includes a regression proving Image cover kind -> Tag Relation fails with no partial ObjectType.

No shared hotspot lease is held by Lane B; only service/domain, focused tests, and this handoff are touched.

### Cross-lane audits
- #592 (#490/#492/#484) is merged: fresh-workspace template Relation targets reuse/provision Tag/Weblink/Image/File through canonical primitive ensure paths; no Relation value/index writer is introduced.
- #595 (#491) remains presentation-only: quick-create persistence is callback-supplied by the host; unavailable/missing writer cases render no fallback, and built-in primitive modes do not title-create Objects directly.
- #596 (#493) is Value-schema preflight only and explicitly keeps Value -> Relation outside that path.

## Validation state
- #506 Flutter CI: fully green before merge.
- #568 merged with focused bidirectional delete-impact regressions.
- #577 Flutter CI #1890: fully green before merge.
- original #593 Flutter CI #1911: fully green, but branch became non-mergeable after #592.
- refreshed v2 branch now needs its own Flutter CI after PR creation.
- local Flutter validation is unavailable in this execution environment because the container cannot resolve `github.com`; GitHub Actions is the executable validation source.

## Exact next actions
1. Open a replacement PR for `feature/relation-template-gallery-cover-target-guard-v2`, close stale #593, and run Flutter CI on the refreshed branch.
2. If refreshed CI is green and mergeable against latest main, integrate the Gallery cover target-kind fail-closed guard.
3. Continue auditing #491 host wiring: target creation/import must succeed first, then canonical Relation attach; failures/retries must not leave partial or duplicate attachments.
4. Audit #492 media resolution for multi-valued Relations: deterministic read-only selection/fallback only, no View-layer repair/mutation, and no leaked single-cardinality assumption.
5. Keep bidirectional Relation target retargeting fail-closed until a paired migration validates both schema sides before writes.

## Current risks / stop rule
- Non-empty Relation target retargeting can proceed only when every existing target is valid for the proposed target ObjectType; mapping/conversion is a separate explicit migration decision.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- One-sided bidirectional Relation Property deletion is blocked by #568; a future explicit paired-delete UX must still call canonical Relation lifecycle rather than deleting schema rows directly.
- Quick-create host wiring is safe only if target creation/import succeeds before canonical Relation attachment and failures cannot leave a partially-attached Relation.
- Do not add speculative abstractions. If the refreshed Gallery cover guard is integrated and no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression exists, record the next trigger and remain idle.
