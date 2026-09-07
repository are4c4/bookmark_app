# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Preserve the canonical Relation subsystem; do not invent parallel Relation writers/indexes merely to keep this lane busy.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle, integrity-sensitive schema evolution, Relation-backed read consistency, deletion/reference invariants, and Relation-producing workflow atomicity.

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
- Missing targets, duplicate targets, cardinality conflicts, stale index/pair metadata, target-type mismatches, malformed stored values, and ambiguous corruption fail closed.
- Relation-backed presentation is read-only and must not repair serialized values or normalized edges opportunistically.
- Relation-producing workflows that create Objects/files/legacy projections around a Relation write must use one outer transaction or explicit rollback-safe ownership boundary.
- No parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity state — 2026-09-08
Latest audited main at this handoff: `882166cc77ca649bfb0e6015d1cf306792c86816` (#854).

Foundation already integrated:
- #506: fail-closed Relation schema evolution foundation. Target changes validate every existing target; ambiguous multi -> single requires explicit choices; single -> multi preserves values; failed migration rolls back atomically; bidirectional target retargeting remains unsupported.
- #568: generic Property deletion cannot silently remove one side of a managed bidirectional Relation pair.
- #577/#590: system Relation schema creation is canonical and rejects target/cardinality/pair-structure drift or reserved structural metadata injection.
- #601: Gallery template cover Relations fail closed unless their configured source kind matches the canonical Image/Weblink target primitive.
- #628/#662: malformed managed bidirectional pair metadata fails closed consistently across mutation, audit, delete inspection, and schema evolution.
- #678: Value -> Object promotion is atomic across target Object creation, optional Relation Property creation, canonical attach, and optional source Value clear. Relation index schema readiness is rollback-safe.
- #681/#694/#713: duplicate target ids are rejected by canonical mutation, persisted duplicates are visible to audit, and editor adapters preserve duplicates until canonical validation.
- #683: Relation-group Board Object creation treats Object creation plus initial grouped preset as one transaction.
- #730: integrity audit detects normalized edge order/`position` drift and reconcile repairs index order only.
- #741: integrity audit detects stray `object_relation_edges` pointing at non-Relation/wrong-owner Properties and reconcile deletes only deterministic stale edge rows.
- #758: strict persisted Relation-value inspection protects integrity-sensitive audit/write/delete paths from malformed top-level shapes/list members while ordinary compatibility parsing remains permissive.
- #765/#773: Gallery and shared `RelationReadService` projections fail closed on malformed/duplicate/cardinality-unsafe or serialized/index-inconsistent Relation state; read paths do not repair.

Recent Lane B checkpoints after the previous handoff:
- #803: `WeblinkPreviewImagePipeline` validates Representative Image Relation integrity before download/Image creation. Malformed/duplicate/cardinality/index disagreement stops before network/files/Object side effects. Squash merge `460244dc83b386e136a32f501c86a391dabbd16c`; relevant CI green.
- #806: `RelationTargetService.selectionFor(...)` fails closed on malformed persisted picker state and no longer silently drops malformed members or deduplicates diagnostic input. Squash merge `afe164eb60d72adfad81996421529ecac16c2f4b`; Flutter CI #2457 green.
- #813: Board drag/drop Relation moves route through `RelationMutationService` instead of low-level `ObjectStore.setPropertyValue(...)`; managed bidirectional source/inverse values and normalized edges remain synchronized. Squash merge `c58903069c691964be1eb90757a93a1a0a92ae5a`; full CI green.
- #836: Generic Database Relation label projection now reuses the canonical stored-value/index consistency contract, so malformed, duplicate/cardinality-unsafe, missing-target, or index-drifted Relations do not leak partial labels into Table/List/Gallery/Board presentation. Squash merge `c9d03bb6b666eab62e382530874f7d9d6bf8f6f2`; Flutter CI #2526 green.
- #850: `TagObjectBridge.syncLegacyTags(...)` now wraps Object create/link/rename, Legacy ID/Group ID refresh, Parent Relation mutation, and orphan cleanup in one outer transaction. A forced Parent Relation failure rolls back earlier mirrored Object changes while leaving legacy `tags` source rows untouched. Squash merge `96a43bcf3e9b815e4d9a62f8f223ea82d5c0fa56`; Flutter CI #2568 green.
- #854: Relation target quick-create no longer creates a legacy Tag row outside the Tag projection transaction. `TagObjectBridge.createLegacyTagObject(...)` commits or rolls back the legacy Tag row, canonical Tag Object/link/metadata, and Parent Relation together. A forced Parent Relation failure leaves no newly-created legacy Tag/Object/link and Relation index readiness recovers after rollback. Squash merge `882166cc77ca649bfb0e6015d1cf306792c86816`; Flutter CI #2584 green.

## Cross-lane audit in this run
- #491 real Relation quick-create/attach still reloads canonical selection context before save and routes Relation persistence through canonical mutation. Tag quick-create is additionally atomic after #854.
- #492 Gallery cover discovery/resolution remains read-only and inherits #765/#773 integrity filtering.
- #493 `RelationSchemaEvolutionService` still re-reads canonical persisted schema, validates workspace/target identity, blocks unhealthy audited state, requires explicit multi -> single choices, applies transactionally, and keeps bidirectional target retargeting fail-closed.
- #827 template preflight validates Relation target primitives, Gallery cover compatibility, and referenced View Properties before primitive provisioning; B audit found no blocker.
- #832 Property schema management routes Relation rename/delete through canonical lifecycle rather than ordinary schema writers; B audit found no blocker.
- #849 Search corrupt-schema isolation catches canonical schema-decoding `FormatException` and omits only the optional Relation-label bucket; it continues to use `RelationReadService` and adds no raw-edge/parser fallback or repair path. B audit found no blocker and left a PR comment.
- #852 deletes a caller-zero bidirectional Relation dialog/test only; canonical pair creation/mutation/read/index services are untouched. B audit found no blocker and left a PR comment.
- Production `BidirectionalRelationStore.setRelation(...)` remains called only through `RelationMutationService`; if a new direct production caller appears, add low-level strict stored-value validation before allowing that boundary to become feature-facing.
- No shared hotspot lease is currently held by Lane B.

## Validation state
- #803 relevant Analyze/full Test green before merge.
- #806 Flutter CI #2457: green.
- #813 full Flutter CI: green.
- #836 Flutter CI #2526: green.
- #850 Flutter CI #2568: green.
- #854 Flutter CI #2584: green.
- Earlier integrity checkpoints #681/#678/#683/#694/#713/#730/#741/#758/#765/#773 were green before merge as recorded in their PRs/history.
- Local Flutter execution is unavailable in this connector environment; GitHub Actions is the executable validation source.

## Work in progress / exact next actions
1. Re-audit post-#854 #491 target quick-create paths for any new Relation-producing side effect that can occur before canonical validation or outside an ownership/transaction boundary.
2. Re-scan production callers of low-level Relation writers/readers (`ObjectStore.setRelation`, Relation branch of `setPropertyValue`, raw `ObjectRelationValue.fromJson`, `BidirectionalRelationStore.setRelation`) and fix only concrete feature-level bypasses.
3. Continue #493 integrity review when target/cardinality schema evolution changes land; bidirectional target retargeting remains unsupported until both sides can be validated before writes.
4. Audit new #492 Relation-backed media/read resolvers for read-time repair or malformed/index disagreement assumptions.
5. Audit new primitive/template/domain/Board workflows around their first Relation write for partial side effects and #678 relation-index rollback readiness.
6. If no concrete defect or new trigger remains after the above audit, stop rather than inventing speculative Relation abstractions.

## Cross-lane dependencies / risks
- Lane C owns schema authoring UX; Lane B owns destructive Relation target/cardinality correctness and corruption behavior.
- Primitive target quick-create must retain primitive identity/import rules before canonical Relation attach; Lane B should test integrity rather than duplicate primitive creation logic.
- Ordinary semantic Relation parsing remains permissive for compatibility. Integrity-sensitive audit/write/read projections use strict persisted-value inspection instead; do not replace the storage model or silently normalize malformed persisted data.
- Relation adapters must preserve malformed/duplicate caller input until canonical mutation validation; adapter-level set normalization can hide caller/corruption bugs and weaken fail-closed guarantees.
- `RelationReadService` is an integrity-filtered projection, not an index authority or repair service. Consumers should not bypass it with raw edges unless they are themselves an integrity service.
- Relation-producing legacy/primitive bridges must define whether surrounding side effects are source-of-truth changes or projections and place transaction/rollback boundaries accordingly (#850/#854 are the Tag examples).

## Stop / resume rule
This handoff was refreshed while the run was still active, after merging #850/#854 and auditing #827/#832/#849/#852. Continue with the exact next actions above. When no concrete feature-level Relation/data-integrity defect remains, stop under the `AGENTS.md` idle-is-acceptable rule and record the then-current main/open PR state rather than creating speculative work.
