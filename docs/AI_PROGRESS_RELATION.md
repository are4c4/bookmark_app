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
Latest audited main at this handoff: `5a7da287c65210a89ce95fd243a9624f98225580`.

- #506: fail-closed Relation schema evolution foundation. Target changes validate every existing target; ambiguous multi -> single requires explicit choices; single -> multi preserves values; failed migration rolls back atomically; bidirectional target retargeting remains unsupported.
- #568: generic Property deletion cannot silently remove one side of a managed bidirectional Relation pair.
- #577/#590: system Relation schema creation is canonical and rejects target/cardinality/pair-structure drift or reserved structural metadata injection.
- #601: Gallery template cover Relations fail closed unless their configured source kind matches the canonical Image/Weblink target primitive; no partial ObjectType/View is created on mismatch.
- #628/#662: malformed managed bidirectional pair metadata fails closed consistently across mutation, audit, delete inspection, and schema evolution.
- #681: canonical `RelationMutationService.setRelation(...)` rejects repeated target Object ids before any Relation value/index write. Prior stored Relation value and normalized edges remain unchanged on rejection. Squash merge `81d28752d90aed6ba4bceb84b9822e30166aff35`; Flutter CI #2129 green.
- #678: Value -> Object promotion is atomic across target Object creation, optional Relation Property creation, canonical attach, and optional source Value clear. `ObjectStore.ensureRelationIndexSchema()` verifies the actual edge table before trusting cached schema readiness so an outer transaction rollback can recreate the index correctly. Squash merge `94a9189c53781ba34837eb703c3ff93c34794d22`; Flutter CI #2140 green.
- #683: Relation-group Board Object creation treats Object creation plus initial grouped preset as one transaction. Relation presets still use `RelationMutationService`; invalid targets roll back the newly-created Object. Squash merge `daab810680264dfe1ca54b4a0957e4b070034b42`; Flutter CI #2133 green.
- #694: persisted duplicate Relation targets are visible to read-only integrity audit even though ordinary `ObjectRelationValue.objectIds` intentionally de-duplicates semantic reads. Audit inspects the raw decoded persisted shape only for duplicate diagnosis; index-only reconcile refuses this non-index corruption and leaves raw value/index untouched. Flutter CI #2249 green; squash merge `ebdc703baa963338688dd1287ed4105cbe99c19d`.
- #713: `ObjectRelationEditorService.save(...)` no longer de-duplicates caller selections before canonical validation. Repeated ids therefore reach the #681 duplicate-target guard and fail closed instead of silently becoming a valid-looking set. Regression proves a rejected duplicate multi-Relation save leaves the prior Relation value and normalized edge unchanged. Flutter CI #2251 green on the original executable head and #2260 green on the refreshed latest-main head; squash merge `5f3c6496f87f86888fa4b8915735b5cfb4a731cb`.

## Cross-lane audit in this run
- #491 now has real canonical quick-create target services and page-service Relation attachment integration. Focused tests cover custom target creation, canonical Tag creation, URL-identity Weblink creation/enrichment, managed Image/File import-only paths, unsupported-system fail-closed behavior, picker candidate reload after quick-create, and canonical Weblink/Image target attach with idempotent saves/backlinks plus a healthy integrity audit. No parallel Relation value/index writer was found.
- The #713 duplicate-selection finding was the concrete retry/idempotency gap found in that #491 audit: adapters must not normalize malformed repeated ids before the canonical mutation boundary can reject them.
- Open PR #696 is Lane C presentation/schema-authoring work for searchable existing Relation target editing. Its diff still delegates mutation through `RelationSchemaEvolutionService.inspectChange(...) -> impact confirmation -> updateRelationSchema(...)`; no Relation value/index writer, serialized-id writer, or read-time repair path is introduced. It currently needs refresh against newer main but presents no independent Lane B correctness defect.
- #492 Gallery cover resolution remains read-only through canonical Relation reads. Regressions cover deterministic first-position behavior for multi Relations, stale serialized/index disagreement fail-closed behavior, target-kind validation, and single-cardinality corruption fail-closed behavior.
- Main commits merged after the prior code audit (#703 template View property ids, #712 exact Object create ids, and unrelated primitive/refactor/object work) do not add a new Relation-producing persistence path.
- Current open PRs #718/#719/#720 are Primitive MIME, Refactor caller-zero shim, and Object timestamp-integrity work respectively; none changes Relation persistence or claims a Relation hotspot lease.
- No shared hotspot lease is held by Lane B. This run made no production/shared-hotspot edit.

## Validation state
- #681 Flutter CI #2129: green.
- #678 Flutter CI #2140: green.
- #683 Flutter CI #2133: green.
- #694 original CI #2165 exposed the raw-vs-semantic duplicate audit bug; refreshed/fixed Flutter CI #2249 green and #694 merged as `ebdc703baa963338688dd1287ed4105cbe99c19d`.
- #713 Flutter CI #2251 green on the first executable head. After refreshing onto concurrent latest main, Flutter CI #2260 also green; #713 merged as `5f3c6496f87f86888fa4b8915735b5cfb4a731cb`.
- 2026-09-07 latest-state audit is docs-only: no production Relation code changed, so no new focused executable test was required. Existing latest relevant Relation CI remains green as above.
- Local Flutter execution is unavailable in this connector environment; GitHub Actions is the executable validation source.

## Exact next triggers
1. A new #491 quick-create/attach or editor path that can bypass `RelationMutationService`, normalize malformed input before canonical validation, or produce non-idempotent edges on retry.
2. A #493 Relation schema-evolution change involving target/cardinality, especially bidirectional target retargeting; keep unsupported cases fail-closed until both sides can be validated before writes.
3. A new #492 Relation-backed media resolver form that could repair on read, trust stale serialized/index disagreement, or assume single cardinality without validation.
4. A primitive/template/domain/Board workflow wrapping the first Relation write in an outer transaction; preserve #678 relation-index schema readiness after rollback.
5. Any new delete/detach/cross-object reference workflow, stale index/backlink issue, reconcile ambiguity, corruption regression, or Relation-producing workflow.

## Cross-lane dependencies / risks
- Lane C owns schema authoring UX; Lane B owns destructive Relation target/cardinality correctness and corruption behavior.
- Primitive target quick-create must retain primitive identity/import rules before canonical Relation attach; Lane B should test integrity rather than duplicate primitive creation logic.
- Semantic Relation reads intentionally normalize duplicate target ids. Corruption diagnostics that must distinguish persisted duplicates therefore use read-only access to raw decoded persisted shape; do not weaken ordinary Relation semantics or introduce a second persistence model.
- Relation adapters must preserve malformed duplicate input until canonical mutation validation; adapter-level set normalization can hide caller/corruption bugs and weaken fail-closed guarantees.

## Stop reason
Latest main `5a7da287c65210a89ce95fd243a9624f98225580`, Issues #491/#492/#493, current open PRs, recent commits, and hotspot ownership were re-audited. No additional independent Relation/data-integrity defect or safe integrity slice is currently identified. Do not invent speculative abstractions. Resume when one of the exact triggers above lands or a concrete Relation correctness regression appears.
