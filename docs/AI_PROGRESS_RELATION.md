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
Latest audited main at this handoff: `daab810680264dfe1ca54b4a0957e4b070034b42`.

- #506: fail-closed Relation schema evolution foundation. Target changes validate every existing target; ambiguous multi -> single requires explicit choices; single -> multi preserves values; failed migration rolls back atomically; bidirectional target retargeting remains unsupported.
- #568: generic Property deletion cannot silently remove one side of a managed bidirectional Relation pair.
- #577/#590: system Relation schema creation is canonical and rejects target/cardinality/pair-structure drift or reserved structural metadata injection.
- #601: Gallery template cover Relations fail closed unless their configured source kind matches the canonical Image/Weblink target primitive; no partial ObjectType/View is created on mismatch.
- #628/#662: malformed managed bidirectional pair metadata fails closed consistently across mutation, audit, delete inspection, and schema evolution.
- #681: canonical `RelationMutationService.setRelation(...)` rejects repeated target Object ids before any Relation value/index write. Prior stored Relation value and normalized edges remain unchanged on rejection. Squash merge `81d28752d90aed6ba4bceb84b9822e30166aff35`; Flutter CI #2129 green before merge.
- #678: Value -> Object promotion is atomic across target Object creation, optional Relation Property creation, canonical attach, and optional source Value clear. A forced late clear failure exposed a real Relation index readiness bug: if `object_relation_edges` was first created inside an outer transaction that later rolled back, `_relationSchemaReady` remained completed while SQLite removed the table. `ObjectStore.ensureRelationIndexSchema()` now verifies the actual edge table before trusting the cached Future and recreates it after rollback; immediate schema-creation failures also clear the cache. Squash merge `94a9189c53781ba34837eb703c3ff93c34794d22`; Flutter CI #2140 green.
- #683: Relation-group Board Object creation now treats Object creation plus initial grouped preset as one transaction instead of best-effort delete cleanup. Relation presets still use `RelationMutationService`; invalid targets roll back the newly-created Object. Squash merge `daab810680264dfe1ca54b4a0957e4b070034b42`; prior Flutter CI #2133 green and PR was clean after #678 integration.

## Cross-lane audit in the latest run
- #492 real Gallery cover resolution is read-only through `RelationReadService`. For multi Relations it deterministically uses the first persisted Relation position only after serialized target ids and normalized edge target ids match exactly in order; disagreement, missing/corrupt state, or target-kind mismatch returns no media rather than repairing Relation data from View code.
- #657 remains presentation/schema-authoring UX. Target search and explicit single/multi selection do not write Relation values/indexes; existing Relation target/cardinality edits still delegate to `RelationSchemaEvolutionService.inspectChange(...)` / `updateRelationSchema(...)`.
- No actual #491 quick-create -> Relation attach host wiring is present on current main yet. The quick-create presentation seam therefore remains a future Relation-producing trigger rather than a current B-lane writer.
- #685 is generic Value/freshness atomicity and does not alter Relation target/cardinality semantics.
- No shared hotspot lease is held by Lane B.

## Validation state
- #681 Flutter CI #2129: fully green before merge.
- #678 Flutter CI #2140: fully green after the Relation index schema-ready rollback recovery fix; full test suite completed successfully.
- #683 Flutter CI #2133: fully green before merge; mergeability rechecked clean after #678 landed.
- Local Flutter validation is unavailable in this connector execution environment; GitHub Actions is the executable validation source.

## Exact next actions
1. Audit #491 when real inline target quick-create host wiring lands: target creation/import must succeed before canonical Relation attach; attach failure/retry must not leave a partial Relation or duplicate normalized edge.
2. Keep #492 media resolution read-only and deterministic as additional cover-source forms land; no View-layer repair or hidden single-cardinality assumption.
3. Keep bidirectional Relation target retargeting fail-closed until an explicit paired schema migration validates both sides before writes.
4. Review new primitive/template/domain/Board workflows that wrap canonical Relation writes in outer transactions; the #678 index-schema readiness recovery must remain intact when the first Relation write is rolled back.
5. Continue checking delete/detach/retarget/retry/idempotency, target/cardinality validation, backlinks/index/audit health, and fail-closed behavior for each new Relation-producing workflow.

## Stop rule
Do not invent speculative abstractions. At this checkpoint #681/#678/#683 are integrated and the current open PR set introduces no new Relation value/index writer. If no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression appears, remain idle until one of the triggers above lands.
