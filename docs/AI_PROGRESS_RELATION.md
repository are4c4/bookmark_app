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
Latest audited main at this handoff: `190931d76cc00f17fa1d149b3de5a1ea2039fd2f`.

- #506: fail-closed Relation schema evolution foundation. Target changes validate every existing target; ambiguous multi -> single requires explicit choices; single -> multi preserves values; failed migration rolls back atomically; bidirectional target retargeting remains unsupported.
- #568: generic Property deletion cannot silently remove one side of a managed bidirectional Relation pair.
- #577/#590: system Relation schema creation is canonical and rejects target/cardinality/pair-structure drift or reserved structural metadata injection.
- #601: Gallery template cover Relations fail closed unless their configured source kind matches the canonical Image/Weblink target primitive; no partial ObjectType/View is created on mismatch.
- #628/#662: malformed managed bidirectional pair metadata fails closed consistently across mutation, audit, delete inspection, and schema evolution.
- #681: canonical `RelationMutationService.setRelation(...)` rejects repeated target Object ids before any Relation value/index write. Prior stored Relation value and normalized edges remain unchanged on rejection. Squash merge `81d28752d90aed6ba4bceb84b9822e30166aff35`; Flutter CI #2129 green before merge.
- #678: Value -> Object promotion is atomic across target Object creation, optional Relation Property creation, canonical attach, and optional source Value clear. A forced late clear failure exposed a Relation index readiness bug: if `object_relation_edges` was first created inside an outer transaction that later rolled back, `_relationSchemaReady` remained completed while SQLite removed the table. `ObjectStore.ensureRelationIndexSchema()` now verifies the actual edge table before trusting the cached Future and recreates it after rollback; immediate schema-creation failures also clear the cache. Squash merge `94a9189c53781ba34837eb703c3ff93c34794d22`; Flutter CI #2140 green.
- #683: Relation-group Board Object creation treats Object creation plus initial grouped preset as one transaction instead of best-effort delete cleanup. Relation presets still use `RelationMutationService`; invalid targets roll back the newly-created Object. Squash merge `daab810680264dfe1ca54b4a0957e4b070034b42`; prior Flutter CI #2133 green.

## Active Lane B checkpoint — PR #694
Branch: `feature/relation-integrity-duplicate-stored-targets`.

- Goal: cover legacy/corrupt persisted Relation values containing repeated target ids even when the normalized edge index is set-like and therefore appears consistent.
- The first #694 head `2549816f54156996eb6345d9ea4ddf01fbeec096` failed Flutter CI #2165 with 1100 passing tests and only the new duplicate-target regression failing.
- Root cause: `ObjectRelationValue.objectIds` intentionally removes duplicate ids for semantic Relation reads, so the initial audit implementation inspected an already-normalized value and could no longer see persisted duplicate corruption. The regression also incorrectly tried to prove raw preservation through the normalized semantic getter.
- The branch was refreshed onto current main `190931d76cc00f17fa1d149b3de5a1ea2039fd2f` to avoid carrying stale base state.
- Fix commit `86fb8f887622d679bb7b2f355443de514792c0eb`: `RelationIntegrityService` now inspects the raw decoded persisted Relation shape only for duplicate diagnosis, while all ordinary semantic Relation/index comparisons continue using `ObjectRelationValue.objectIds`. This preserves the canonical set-like read contract and adds no alternate writer/index.
- Regression commit `9db489a7497e3c7c9c0a6e67547866305c34704c`: the test verifies that audit reports exactly one `duplicateTargetObject`, index-only reconcile refuses the non-index corruption, raw `generic_values.value_json` remains unchanged, and the one normalized edge remains unchanged.
- Current CI on the refreshed/fixed head is pending at this handoff; the earlier #2165 failure is obsolete because it exercised the pre-fix branch.

## Cross-lane audit in this run
- #491 has advanced beyond the previous handoff trigger. Current main contains canonical quick-create target services and real page-service Relation attachment integration. Focused tests cover custom target creation, canonical Tag creation, URL-identity Weblink creation/enrichment, managed Image/File import-only paths, unsupported system fail-closed behavior, picker candidate reload after quick-create, and canonical Weblink/Image target attach with idempotent saves/backlinks plus a healthy integrity audit. No parallel Relation value/index writer was found in that production path.
- #696 is Lane C presentation/schema-authoring work for searchable editing of existing Relation target/cardinality. Its PR contract retains `RelationSchemaEvolutionService.inspectChange(...) -> impact confirmation -> updateRelationSchema(...)`; it does not introduce a Relation value/index writer.
- #492 real Gallery cover resolution remains read-only through the canonical Relation read path. Current regressions cover deterministic first-position behavior for multi Relations, stale serialized/index disagreement fail-closed behavior, target-kind validation, and single-cardinality corruption fail-closed behavior.
- Current unrelated open PRs #698/#703/#708/#709/#691 do not introduce a competing Relation writer in their declared scope.
- No shared hotspot lease is held by Lane B. PR #694 touches only `lib/data/relation_integrity_service.dart`, its focused test, and this handoff file.

## Validation state
- #681 Flutter CI #2129: green before merge.
- #678 Flutter CI #2140: green after Relation index schema-ready rollback recovery fix.
- #683 Flutter CI #2133: green before merge.
- #694 original Flutter CI #2165: analyze and maintainability guards green; full suite 1100 passed / 1 failed, with the sole failure being the new duplicate-target regression caused by semantic de-duplication hiding raw persisted corruption.
- #694 refreshed/fixed head: CI pending. Local Flutter validation is unavailable in this connector execution environment; GitHub Actions is the executable validation source.

## Exact next actions
1. Recheck #694 CI on the refreshed head; if green and mergeable, integrate it. If the focused regression still fails, fix only the raw-corruption audit/test path rather than changing normal Relation read semantics.
2. Continue auditing #491 real inline quick-create -> canonical Relation attach for failure/retry boundaries. Target creation/import succeeds before selection/attach; attach failure must not create duplicate normalized edges or silently rewrite existing Relation state.
3. Keep #492 media resolution read-only and deterministic as additional cover-source forms land; no View-layer repair or hidden single-cardinality assumption.
4. Keep bidirectional Relation target retargeting fail-closed until an explicit paired schema migration validates both sides before writes.
5. Review new primitive/template/domain/Board workflows that wrap canonical Relation writes in outer transactions; the #678 index-schema readiness recovery must remain intact when the first Relation write is rolled back.
6. Continue checking delete/detach/retarget/retry/idempotency, target/cardinality validation, backlinks/index/audit health, and fail-closed behavior for each new Relation-producing workflow.

## Cross-lane dependencies / risks
- Lane C owns schema authoring UX; Lane B owns destructive Relation target/cardinality correctness and corruption behavior.
- Primitive target quick-create must retain primitive identity/import rules before canonical Relation attach; Lane B should test integrity rather than duplicate primitive creation logic.
- Semantic Relation reads intentionally normalize duplicate target ids. Corruption diagnostics that must distinguish persisted duplicates therefore need read-only access to the raw decoded persisted shape; do not weaken ordinary Relation semantics or introduce a second persistence model to accomplish this.

## Stop rule
Do not invent speculative abstractions. After #694 is integrated, continue only when a new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression is present. Otherwise remain idle until one of the triggers above lands.
