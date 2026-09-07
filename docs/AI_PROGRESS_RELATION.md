# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Preserve the canonical Relation subsystem; do not invent parallel Relation writers/indexes merely to keep this lane busy.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle, integrity-sensitive schema evolution, Relation-backed read consistency, deletion/reference invariants, and Relation-producing workflow atomicity.

## Current issue state
- #56 — open umbrella for the generic Object/Database/Relation architecture and the continuing canonical Relation contract.
- #491 — completed/closed. Generic Relation Property authoring and inline target creation are integrated; future changes are regression triggers, not unfinished acceptance work.
- #492 — completed/closed. Generic Gallery Relation cover-source architecture is integrated; future Relation-backed media readers are regression triggers.
- #493 — completed/closed. Safe Relation schema-evolution acceptance criteria are integrated; future target/cardinality changes remain integrity triggers.
- #245/#484 and new primitive/domain work may create new Relation-producing workflow obligations when real production writes/readers land.

## Canonical Relation contract
- Feature Relation writes go through `RelationMutationService`.
- Canonical UI/read consumers use `RelationReadService` or another reader that explicitly enforces the same stored-value/index/target-integrity contract.
- Relation Property creation uses `ObjectStore.createRelationProperty(...)` or a canonical facade delegating to it.
- `RelationIntegrityService` is read-only; `RelationIndexReconcileService` repairs deterministic index-only drift only.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Missing/wrong-type targets, duplicate targets, cardinality conflicts, stale index/pair metadata, malformed stored values, and ambiguous corruption fail closed.
- Relation-backed presentation/readers never repair serialized values or normalized edges opportunistically.
- Relation-producing workflows that create Objects/files/legacy projections around a Relation write must use one outer transaction or an explicit rollback-safe ownership boundary.
- No parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity state — 2026-09-08
Latest audited main at this handoff: `36588e0d89e4f95e204d72d7a00194d7c7a2f0ba` (includes #871 and subsequent #869).

Foundation already integrated:
- #506/#568/#577/#590/#601/#628/#662: fail-closed Relation schema evolution, managed bidirectional pair lifecycle, canonical system Relation schema creation, and Gallery/template structural validation.
- #678: Value -> Object promotion is atomic; Relation index schema readiness is safe after outer-transaction rollback.
- #681/#694/#713: duplicate target ids are rejected by canonical mutation, persisted duplicates are visible to audit, and editor adapters preserve malformed/duplicate caller input until canonical validation.
- #683: Relation-group Board Object creation treats Object creation plus initial preset as one transaction.
- #730/#741: audit/reconcile handles edge position/order drift and stray non-Relation/wrong-owner edges as deterministic index-only repair; persisted Relation values are not rewritten.
- #758: strict persisted Relation-value inspection protects integrity-sensitive audit/write/delete paths while ordinary compatibility parsing remains permissive.
- #765/#773: Gallery and shared `RelationReadService` projections fail closed on malformed/duplicate/cardinality-unsafe or serialized/index-inconsistent Relation state, with no read-time repair.

Recent Lane B checkpoints:
- #803 — Weblink Representative Image Relation is validated before remote download/Image/file side effects. Corrupt Relation state stops before side effects. Merge `460244dc83b386e136a32f501c86a391dabbd16c`.
- #806 — Relation picker state fails closed on malformed persisted values and no longer silently drops malformed members or deduplicates diagnostic input. Merge `afe164eb60d72adfad81996421529ecac16c2f4b`; CI #2457 green.
- #813 — Board Relation drag/drop routes through `RelationMutationService`; managed bidirectional source/inverse values and normalized edges stay synchronized. Merge `c58903069c691964be1eb90757a93a1a0a92ae5a`; full CI green.
- #836 — Generic Database Relation-label projection uses the canonical stored-value/index consistency contract, so malformed, duplicate/cardinality-unsafe, missing-target, or index-drifted Relations do not leak partial labels. Merge `c9d03bb6b666eab62e382530874f7d9d6bf8f6f2`; CI #2526 green.
- #850 — `TagObjectBridge.syncLegacyTags(...)` is atomic across mirrored Object/link/metadata/Parent Relation/orphan cleanup. Merge `96a43bcf3e9b815e4d9a62f8f223ea82d5c0fa56`; CI #2568 green.
- #854 — Tag Relation target quick-create commits/rolls back the legacy Tag row, canonical Tag Object/link/metadata, and Parent Relation together. Merge `882166cc77ca649bfb0e6015d1cf306792c86816`; CI #2584 green.
- #865 — Relation-backed Rollups no longer evaluate through permissive `ObjectStore.resolveRelation(...)`; corrupt/unresolved Relation state returns `null`, while healthy empty Relation still yields `count == 0`. Merge `aa94499e73931438aa88992ec448b1578dd65018`; CI #2620 green.
- #871 — `RelationReadService` now exposes a Relation Property only when every stored/indexed target exists in the declared target ObjectType. `ObjectGraphQueryStore.backlinks(...)` no longer joins raw `object_relation_edges`; Object Inspector/Graph backlinks route through canonical `RelationReadService`. Wrong-type/missing targets and serialized/index drift fail closed without repair. Merge `eaf70d24cbceb2cdd1e9a74a71e220005553bdb7`; CI #2647 Analyze + full Test green.

## Cross-lane audit
- #491 production quick-create/attach reloads canonical selection context before save and persists through canonical mutation; Tag quick-create is additionally atomic after #854.
- #492 Gallery discovery/resolution remains read-only and inherits strict stored/index integrity filtering.
- #493 schema evolution re-reads canonical persisted schema, validates source/target workspace identity, blocks unhealthy audited state, requires explicit multi -> single choices, applies transactionally, and keeps bidirectional target retargeting fail-closed.
- #827 template preflight validates Relation target primitives, Gallery cover compatibility, and referenced View Properties before primitive provisioning; no B blocker.
- #832 Property schema management routes Relation rename/delete through canonical lifecycle; no B blocker.
- #849 Search corrupt-schema isolation continues to use `RelationReadService` and adds no raw-edge/parser fallback or repair path; no B blocker.
- #852 removed caller-zero bidirectional UI/test only; canonical pair services are untouched; no B blocker.
- #869 adds canonical Image/Weblink media presentation in Database List rows only; it does not add Relation writes or a new Relation reader contract.
- Production direct `ObjectStore.setRelation(...)` callers remain subsystem/internal. Production `BidirectionalRelationStore.setRelation(...)` is still reached through `RelationMutationService`, which performs strict validation first.
- No shared hotspot lease is currently held by Lane B.

## Validation state
- #803 relevant Analyze/full Test green before merge.
- #806 Flutter CI #2457 green.
- #813 full Flutter CI green.
- #836 Flutter CI #2526 green.
- #850 Flutter CI #2568 green.
- #854 Flutter CI #2584 green.
- #865 Flutter CI #2620 green.
- #871 Flutter CI #2647: Analyze + full Test green after fixture correction; initial #2643 failed only because the new test called a nonexistent `GenericDatabaseStore.getRecord()` helper.
- Earlier checkpoints #678/#681/#683/#694/#713/#730/#741/#758/#765/#773 were green before merge as recorded in their PR/history.
- Local Flutter execution is unavailable in this connector environment; GitHub Actions is the executable validation source.

## Exact next triggers
1. A new production Relation writer/editor/quick-create path that bypasses `RelationMutationService`, normalizes malformed/duplicate input before canonical validation, or can leave partial side effects on retry/failure.
2. A production caller that invokes `BidirectionalRelationStore.setRelation(...)` directly instead of `RelationMutationService`; add strict low-level stored-value validation before allowing that boundary to become feature-facing.
3. A future Relation target/cardinality schema-evolution change, especially bidirectional target retargeting; unsupported cases remain fail-closed until both sides can be validated before writes.
4. A new Relation-backed media/graph/search/computed-value reader that uses raw `object_relation_edges`, permissive `ObjectRelationValue.fromJson(...)`, or `ObjectStore.resolveRelation(...)` without the canonical integrity contract.
5. A primitive/template/domain/Board workflow that creates external side effects around its first Relation write; preserve atomicity and #678 rollback-safe relation-index readiness.
6. Any new delete/detach/cross-object reference workflow, stale index/backlink issue, reconcile ambiguity, corruption regression, or Relation-producing workflow.

## Cross-lane dependencies / risks
- Lane C owns schema-authoring UX; Lane B owns destructive Relation target/cardinality correctness and corruption behavior.
- Primitive target quick-create must retain primitive identity/import rules before canonical Relation attach; Lane B should test integrity rather than duplicate primitive creation logic.
- Ordinary semantic Relation parsing remains permissive for compatibility. Integrity-sensitive audit/write/read projections use strict persisted-value inspection; do not silently normalize malformed persisted data.
- Relation adapters must preserve malformed/duplicate caller input until canonical mutation validation.
- `RelationReadService` is an integrity-filtered projection, not an index authority or repair service. UI/graph/computed consumers should not bypass it with raw edges unless they are themselves an integrity service.

## Work in progress / next actions
There is no open Lane B production PR after #871. Before starting new code, re-scan the latest main/open PRs for one of the exact triggers above. If no concrete defect exists, do not invent a Relation abstraction merely to keep the lane active.

## Stop reason
Latest main through `36588e0d89e4f95e204d72d7a00194d7c7a2f0ba`, completed Issues #491/#492/#493, open #56, current open PR ownership, low-level Relation writer/read callers, raw edge consumers, Graph backlinks, Rollups, Generic Database labels, Gallery, Search, Weblink preview, Board moves, and Tag projection/quick-create were re-audited. No additional independent feature-level Relation/data-integrity defect is currently identified. This satisfies the AGENTS stop condition: the lane has no remaining actionable safe work until a new concrete trigger lands.