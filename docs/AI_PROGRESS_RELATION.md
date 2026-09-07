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
- Missing targets, duplicate targets, cardinality conflicts, stale index/pair metadata, target-type mismatches, and ambiguous corruption fail closed.
- No parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity state — 2026-09-07
Latest audited main at this handoff: `cc6e34ca03fa23e12548c3d2c2a4a09f995999a7`; it includes #694 squash merge `ebdc703baa963338688dd1287ed4105cbe99c19d`.

- #506: fail-closed Relation schema evolution foundation. Target changes validate every existing target; ambiguous multi -> single requires explicit choices; single -> multi preserves values; failed migration rolls back atomically; bidirectional target retargeting remains unsupported.
- #568: generic Property deletion cannot silently remove one side of a managed bidirectional Relation pair.
- #577/#590: system Relation schema creation is canonical and rejects target/cardinality/pair-structure drift or reserved structural metadata injection.
- #601: Gallery template cover Relations fail closed unless their configured source kind matches the canonical Image/Weblink target primitive; no partial ObjectType/View is created on mismatch.
- #628/#662: malformed managed bidirectional pair metadata fails closed consistently across mutation, audit, delete inspection, and schema evolution.
- #681: canonical `RelationMutationService.setRelation(...)` rejects repeated target Object ids before any Relation value/index write. Prior stored Relation value and normalized edges remain unchanged on rejection. Squash merge `81d28752d90aed6ba4bceb84b9822e30166aff35`; Flutter CI #2129 green.
- #678: Value -> Object promotion is atomic across target Object creation, optional Relation Property creation, canonical attach, and optional source Value clear. `ObjectStore.ensureRelationIndexSchema()` verifies the actual edge table before trusting cached schema readiness so an outer transaction rollback can recreate the index correctly. Squash merge `94a9189c53781ba34837eb703c3ff93c34794d22`; Flutter CI #2140 green.
- #683: Relation-group Board Object creation treats Object creation plus initial grouped preset as one transaction. Relation presets still use `RelationMutationService`; invalid targets roll back the newly-created Object. Squash merge `daab810680264dfe1ca54b4a0957e4b070034b42`; Flutter CI #2133 green.
- #694: persisted duplicate Relation targets are visible to read-only integrity audit even though ordinary `ObjectRelationValue.objectIds` intentionally de-duplicates semantic reads. Audit inspects the raw decoded persisted shape only for duplicate diagnosis; index-only reconcile refuses this non-index corruption and leaves raw value/index untouched. Flutter CI #2249 green; squash merge `ebdc703baa963338688dd1287ed4105cbe99c19d`.

## Active Lane B checkpoint — PR #713
Branch: `feature/relation-editor-duplicate-selection-fail-closed`.

- #491 quick-create/Relation editor audit found that `ObjectRelationEditorService.save(...)` converted selected ids to a Set before delegating to `RelationMutationService`.
- That adapter-level normalization could silently turn `[A, A]` into `[A]`, bypassing the canonical duplicate-target rejection established by #681.
- The refreshed branch is based on main `cc6e34ca03fa23e12548c3d2c2a4a09f995999a7` after the first merge attempt correctly exposed branch divergence following concurrent main integrations.
- Commit `ad2931e4c81cf6123af9b9614d8cf3d737fdb2d5` preserves caller selection multiplicity until canonical validation instead of de-duplicating it in the editor adapter.
- Regression commit `d325e9c7666dee063265a86426d7a74430f2f15a` covers a multi-Relation editor save containing a repeated target id and proves rejection leaves the prior Relation value and normalized edge unchanged.
- The equivalent pre-refresh executable head passed Flutter CI #2251; the refreshed code is semantically identical and a new PR-head CI is expected after reopening/updating the PR.
- This is service/test-only apart from this handoff and does not change UI presentation, Relation persistence, index shape, or canonical mutation semantics.

## Cross-lane audit in this run
- #491 now has real canonical quick-create target services and page-service Relation attachment integration. Focused tests cover custom target creation, canonical Tag creation, URL-identity Weblink creation/enrichment, managed Image/File import-only paths, unsupported-system fail-closed behavior, picker candidate reload after quick-create, and canonical Weblink/Image target attach with idempotent saves/backlinks plus a healthy integrity audit. No parallel Relation value/index writer was found.
- The #713 duplicate-selection finding is the concrete retry/idempotency boundary discovered while auditing this new #491 workflow: adapters must not normalize malformed repeated ids before the canonical mutation boundary can reject them.
- #696 is Lane C presentation/schema-authoring work for searchable existing Relation target editing and retains the canonical schema-evolution service path; it does not add a Relation value/index writer.
- #492 Gallery cover resolution remains read-only through canonical Relation reads. Regressions cover deterministic first-position behavior for multi Relations, stale serialized/index disagreement fail-closed behavior, target-kind validation, and single-cardinality corruption fail-closed behavior.
- Concurrent #709/#712 main changes are outside Relation persistence and do not introduce a competing Relation writer.
- No shared hotspot lease is held by Lane B. #713 touches only `lib/data/object_relation_editor_service.dart`, a focused test, and this handoff file.

## Validation state
- #681 Flutter CI #2129: green.
- #678 Flutter CI #2140: green.
- #683 Flutter CI #2133: green.
- #694 original CI #2165 exposed the raw-vs-semantic duplicate audit bug; refreshed/fixed Flutter CI #2249 green and #694 merged as `ebdc703baa963338688dd1287ed4105cbe99c19d`.
- #713 equivalent pre-refresh executable head `fbce5dd264ae9dab8018b6baad326773a0159be4`: Flutter CI #2251 green. Refreshed head CI pending after rebase-equivalent branch reconstruction on latest main.
- Local Flutter execution is unavailable in this connector environment; GitHub Actions is the executable validation source.

## Exact next actions
1. Recheck refreshed #713 CI; if green and mergeable, integrate it. If it fails, keep the fix at the editor/canonical-validation boundary and preserve existing Relation mutation semantics.
2. Continue auditing #491 quick-create -> canonical attach failure/retry boundaries. Target creation/import may succeed before selection/attach; a failed attach must not create duplicate edges or silently rewrite the prior Relation value.
3. Keep #492 media resolution read-only and deterministic; no View-layer repair or hidden single-cardinality assumption.
4. Keep bidirectional Relation target retargeting fail-closed until an explicit paired schema migration validates both sides before writes.
5. Review new primitive/template/domain/Board workflows wrapping canonical Relation writes in outer transactions; #678 index-schema rollback recovery must remain intact.
6. Continue checking delete/detach/retarget/retry/idempotency, target/cardinality validation, backlinks/index/audit health, and fail-closed behavior for each new Relation-producing workflow.

## Cross-lane dependencies / risks
- Lane C owns schema authoring UX; Lane B owns destructive Relation target/cardinality correctness and corruption behavior.
- Primitive target quick-create must retain primitive identity/import rules before canonical Relation attach; Lane B should test integrity rather than duplicate primitive creation logic.
- Semantic Relation reads intentionally normalize duplicate target ids. Corruption diagnostics that must distinguish persisted duplicates therefore use read-only access to raw decoded persisted shape; do not weaken ordinary Relation semantics or introduce a second persistence model.
- Relation adapters must preserve malformed duplicate input until canonical mutation validation; adapter-level `toSet()` normalization can hide caller/corruption bugs and weaken fail-closed guarantees.

## Stop rule
Do not invent speculative abstractions. After #713 is integrated, continue only when a new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression is present. Otherwise remain idle until one of the triggers above lands.
