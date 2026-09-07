# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Preserve the canonical Relation subsystem; do not invent parallel Relation writers/indexes merely to keep this lane busy.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle, integrity-sensitive schema evolution, Relation-backed read consistency, and deletion/reference invariants.

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
- No parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity state — 2026-09-07
Latest audited main at this handoff: `3cf960082814c54f4f262b8061ba9320c4952e31`.

- #506: fail-closed Relation schema evolution foundation. Target changes validate every existing target; ambiguous multi -> single requires explicit choices; single -> multi preserves values; failed migration rolls back atomically; bidirectional target retargeting remains unsupported.
- #568: generic Property deletion cannot silently remove one side of a managed bidirectional Relation pair.
- #577/#590: system Relation schema creation is canonical and rejects target/cardinality/pair-structure drift or reserved structural metadata injection.
- #601: Gallery template cover Relations fail closed unless their configured source kind matches the canonical Image/Weblink target primitive; no partial ObjectType/View is created on mismatch.
- #628/#662: malformed managed bidirectional pair metadata fails closed consistently across mutation, audit, delete inspection, and schema evolution.
- #681: canonical `RelationMutationService.setRelation(...)` rejects repeated target Object ids before any Relation value/index write. Prior stored Relation value and normalized edges remain unchanged on rejection. Squash merge `81d28752d90aed6ba4bceb84b9822e30166aff35`; Flutter CI #2129 green.
- #678: Value -> Object promotion is atomic across target Object creation, optional Relation Property creation, canonical attach, and optional source Value clear. `ObjectStore.ensureRelationIndexSchema()` verifies the actual edge table before trusting cached schema readiness so an outer transaction rollback can recreate the index correctly. Squash merge `94a9189c53781ba34837eb703c3ff93c34794d22`; Flutter CI #2140 green.
- #683: Relation-group Board Object creation treats Object creation plus initial grouped preset as one transaction. Relation presets still use `RelationMutationService`; invalid targets roll back the newly-created Object. Squash merge `daab810680264dfe1ca54b4a0957e4b070034b42`; Flutter CI #2133 green.
- #694: persisted duplicate Relation targets are visible to read-only integrity audit even though ordinary semantic reads intentionally de-duplicate. Index-only reconcile refuses this non-index corruption and leaves raw value/index untouched. Squash merge `ebdc703baa963338688dd1287ed4105cbe99c19d`.
- #713: `ObjectRelationEditorService.save(...)` no longer de-duplicates caller selections before canonical validation. Repeated ids therefore reach the #681 duplicate-target guard and fail closed instead of silently becoming a valid-looking set. Squash merge `5f3c6496f87f86888fa4b8915735b5cfb4a731cb`.
- #730: integrity audit now detects normalized edge order/`position` drift even when the target set is unchanged. Reconcile treats persisted Relation order as truth and repairs index order only; Relation values are not rewritten. Squash merge `becaf872b5513cd3fe6ee0f26f821eed7d62c1f7`; relevant CI green before merge.
- #741: integrity audit detects stray `object_relation_edges` that point at a non-Relation Property or a Relation Property owned by another ObjectType. Reconcile deletes only deterministic stale edge rows after transaction-local re-audit; persisted values/schema are untouched. Squash merge `243fb0496fdaf7b03830a36bbaa5a3b28fae4baa`; relevant CI green before merge.
- #758: added strict persisted Relation-value inspection for integrity-sensitive paths while preserving permissive compatibility semantics in ordinary `ObjectRelationValue.fromJson(...)`. Malformed top-level shapes/list members are reported as `malformedStoredValue`; index reconcile refuses the corruption; feature-level canonical writes and Relation-safe delete fail closed before overwrite. Managed bidirectional facade writes validate source/inverse stored values before delegation. Squash merge `550c7d16d480cf371eaca40178aacf4cadc066ba`; Flutter CI #2356 green.
- #765: Relation-backed Gallery covers use the strict stored-value inspection before interpreting ids. A malformed serialized Relation cannot render a cover from only its parseable subset, and Gallery remains read-only with no repair. Squash merge `77336561581dbb2af4589b1660244ebad1bfcc57`; Flutter CI #2370 green.
- #773: canonical `RelationReadService` outgoing/backlink projections now fail closed unless the stored Relation value is well formed, duplicate/cardinality-safe, and exactly matches normalized edge targets/order/positions for the Property. Target ObjectType must still belong to the source workspace. Valid reads preserve normalized edge ordering; no read-time repair occurs. Squash merge `66d3da4d80f2a8b071410dff0d86cbf62e92ddbb`; Flutter CI #2385 green.

## Cross-lane audit in this run
- #491 still routes real quick-create/attach and editor saves through canonical Relation mutation. No newly merged workflow adds another Relation value/index or serialized-id writer.
- #492 Gallery cover discovery/resolution remains read-only. #765 hardens the resolver itself and #773 hardens the shared canonical Relation read projection used by Object inspector/search/visual consumers.
- #493 `RelationSchemaEvolutionService` still re-reads the canonical persisted Relation Property, validates source/target workspace identity, blocks unhealthy audited state, requires explicit multi -> single choices, applies inside a transaction, and keeps bidirectional target retargeting fail-closed.
- #763 restores searchable Relation target ObjectType/cardinality authoring UX while preserving the canonical schema-evolution path; no Lane B writer bypass found.
- #774 makes canonical Search Relation labels fail closed on malformed Relation reads; no Search-side repair/write path was introduced.
- #785 adds Search regression coverage for the #773 canonical read consistency contract.
- Open #781 only composes the existing read-only `DatabaseViewGalleryCoverSourceService` into `GenericDatabasePageServices`; B audit found no blocker and left a review comment.
- Duplicate open #754 was re-audited and closed as superseded by #758/#765/#773. Its only unique residual behavior was defense-in-depth inside `BidirectionalRelationStore.setRelation(...)`; current production code calls that low-level method only through `RelationMutationService`, which performs strict validation first.
- No shared hotspot lease is held by Lane B. The latest B production changes are isolated data-layer/read-resolver files, not `generic_database_page.dart`, `app_shell.dart`, or `object_inspector_page.dart`.

## Validation state
- #681 Flutter CI #2129: green.
- #678 Flutter CI #2140: green.
- #683 Flutter CI #2133: green.
- #694 fixed/refresh CI green before merge.
- #713 refreshed latest-main CI green before merge.
- #730 relevant Flutter Analyze/full Test green before merge.
- #741 relevant Flutter Analyze/full Test green before merge.
- #758 Flutter CI #2356: green.
- #765 Flutter CI #2370: green.
- #773 Flutter CI #2385: green.
- Local Flutter execution is unavailable in this connector environment; GitHub Actions is the executable validation source.

## Exact next triggers
1. A new #491 quick-create/attach or editor path that can bypass `RelationMutationService`, normalize malformed input before canonical validation, or produce non-idempotent edges on retry.
2. A production caller that invokes `BidirectionalRelationStore.setRelation(...)` directly instead of `RelationMutationService`; add strict low-level stored-value validation before allowing that boundary to become feature-facing.
3. A #493 Relation schema-evolution change involving target/cardinality, especially bidirectional target retargeting; keep unsupported cases fail-closed until both sides can be validated before writes.
4. A new #492 Relation-backed media/read resolver that could repair on read, trust malformed/stale serialized/index disagreement, or assume single cardinality without validation.
5. A primitive/template/domain/Board workflow wrapping the first Relation write in an outer transaction; preserve #678 relation-index schema readiness after rollback.
6. Any new delete/detach/cross-object reference workflow, stale index/backlink issue, reconcile ambiguity, corruption regression, or Relation-producing workflow.

## Cross-lane dependencies / risks
- Lane C owns schema authoring UX; Lane B owns destructive Relation target/cardinality correctness and corruption behavior.
- Primitive target quick-create must retain primitive identity/import rules before canonical Relation attach; Lane B should test integrity rather than duplicate primitive creation logic.
- Ordinary semantic Relation parsing remains permissive for compatibility. Integrity-sensitive audit/write/read projections use the strict persisted-value inspection instead; do not replace the storage model or silently normalize malformed persisted data.
- Relation adapters must preserve malformed/duplicate caller input until canonical mutation validation; adapter-level set normalization can hide caller/corruption bugs and weaken fail-closed guarantees.
- `RelationReadService` is now an integrity-filtered projection, not an index authority or repair service. Consumers should not bypass it with raw edges unless they are themselves an integrity service.

## Stop reason
Latest main `3cf960082814c54f4f262b8061ba9320c4952e31`, Issues #491/#492/#493, recent Relation/Search merges, open PR #781, current open PR ownership, and production Relation/Bidirectional writer callers were re-audited. No additional independent feature-level Relation/data-integrity defect or safe integrity slice is currently identified. Do not invent speculative abstractions. Resume when one of the exact triggers above lands or a concrete Relation correctness regression appears.
