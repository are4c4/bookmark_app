# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, and live GitHub state before implementation. Preserve the canonical Relation subsystem; do not invent parallel Relation writers/indexes merely to keep this lane busy.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle, integrity-sensitive schema evolution, Relation-backed read consistency, deletion/reference invariants, and Relation-producing workflow atomicity.

## Current issue state
- #56 — open umbrella for the generic Object/Database/Relation architecture and the continuing canonical Relation contract.
- #895 — completed/closed by PR #922. Newly-live Bookmark `Images` / `Cover Image` writers now fail closed on untrusted stored/index/target/cardinality state and cannot partially rewrite canonical Relations or the temporary `bookmark_photos` projection.
- #947 — completed/closed by PR #965. Canonical Person `Profile Image` is now a single Relation to Image with strict preflight, deterministic legacy Photo migration, atomic compatibility projection, and Relation-safe delete/detach coverage.
- #491 — completed/closed. Generic Relation Property authoring and inline target creation are integrated; future changes are regression triggers, not unfinished acceptance work.
- #492 — completed/closed. Generic Gallery Relation cover-source architecture is integrated; future Relation-backed media readers are regression triggers.
- #493 — completed/closed. Safe Relation schema-evolution acceptance criteria are integrated; future target/cardinality changes remain integrity triggers.
- #245 and future primitive/domain work may reactivate Lane B when they add a new production Relation writer, reader, delete/detach flow, or compatibility projection.
- #948 is now unblocked for Lane D. People profile-photo UI can consume the #947 canonical Person/Image Relation contract; Lane B should re-enter only if that UI integration exposes a concrete Relation/data-integrity defect.

## Canonical Relation contract
- Feature Relation writes go through `RelationMutationService`.
- Canonical UI/read consumers use `RelationReadService` or another reader that explicitly enforces the same stored-value/index/target-integrity contract.
- Integrity-sensitive mutation preflight may use `RelationTargetService.selectionForMutation(...)`, which requires a well-formed stored value, valid targets/cardinality, and exact serialized/index count/target/order/position agreement before mutation.
- Ordinary picker/diagnostic reads remain non-repairing and may expose corruption diagnostics; strict mutation preflight must not replace that UX with opportunistic repair.
- Relation Property creation uses `ObjectStore.createRelationProperty(...)` or a canonical facade delegating to it.
- `RelationIntegrityService` is read-only; `RelationIndexReconcileService` repairs deterministic index-only drift only.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Missing/wrong-type targets, duplicate targets, cardinality conflicts, stale index/pair metadata, malformed stored values, and ambiguous corruption fail closed.
- Relation-backed presentation/readers never repair serialized values or normalized edges opportunistically.
- Relation-producing workflows that create Objects/files/legacy projections around a Relation write use one outer transaction or an explicit rollback-safe ownership boundary.
- No parallel serialized-id Relation writer or alternate edge/index store.

## Integrated integrity state — 2026-09-08
Latest audited main at this handoff: `09de5d4fdec3cd019f43102e2d7437c63a438064` (PR #965 / Issue #947).

Foundation already integrated:
- #506/#568/#577/#590/#601/#628/#662: fail-closed Relation schema evolution, managed bidirectional pair lifecycle, canonical system Relation schema creation, and Gallery/template structural validation.
- #678: Value -> Object promotion is atomic; Relation index schema readiness is safe after outer-transaction rollback.
- #681/#694/#713: duplicate target ids are rejected by canonical mutation, persisted duplicates are visible to audit, and editor adapters preserve malformed/duplicate caller input until canonical validation.
- #683: Relation-group Board Object creation treats Object creation plus initial preset as one transaction.
- #730/#741: audit/reconcile handles edge position/order drift and stray non-Relation/wrong-owner edges as deterministic index-only repair; persisted Relation values are not rewritten.
- #758: strict persisted Relation-value inspection protects integrity-sensitive audit/write/delete paths while ordinary compatibility parsing remains permissive.
- #765/#773: Gallery and shared `RelationReadService` projections fail closed on malformed/duplicate/cardinality-unsafe or serialized/index-inconsistent Relation state, with no read-time repair.
- #871: `RelationReadService` validates declared target ObjectType existence/type and Graph/Object Inspector backlinks use the same canonical contract instead of raw edges.

Recent Lane B checkpoints:
- #803 — Weblink Representative Image Relation is validated before remote download/Image/file side effects. Corrupt Relation state stops before side effects. Merge `460244dc83b386e136a32f501c86a391dabbd16c`.
- #806 — Relation picker state fails closed on malformed persisted values and no longer silently drops malformed members or deduplicates diagnostic input. Merge `afe164eb60d72adfad81996421529ecac16c2f4b`; CI #2457 green.
- #813 — Board Relation drag/drop routes through `RelationMutationService`; managed bidirectional source/inverse values and normalized edges stay synchronized. Merge `c58903069c691964be1eb90757a93a1a0a92ae5a`; full CI green.
- #836 — Generic Database Relation-label projection uses the canonical stored-value/index consistency contract. Merge `c9d03bb6b666eab62e382530874f7d9d6bf8f6f2`; CI #2526 green.
- #850 — `TagObjectBridge.syncLegacyTags(...)` is atomic across mirrored Object/link/metadata/Parent Relation/orphan cleanup. Merge `96a43bcf3e9b815e4d9a62f8f223ea82d5c0fa56`; CI #2568 green.
- #854 — Tag Relation target quick-create commits/rolls back the legacy Tag row, canonical Tag Object/link/metadata, and Parent Relation together. Merge `882166cc77ca649bfb0e6015d1cf306792c86816`; CI #2584 green.
- #865 — Relation-backed Rollups no longer evaluate through permissive `ObjectStore.resolveRelation(...)`; corrupt/unresolved Relation state returns `null`, while healthy empty Relation still yields `count == 0`. Merge `aa94499e73931438aa88992ec448b1578dd65018`; CI #2620 green.
- #871 — wrong-type/missing targets and serialized/index drift fail closed in canonical reads/backlinks without repair. Merge `eaf70d24cbceb2cdd1e9a74a71e220005553bdb7`; CI #2647 green.
- #895 — Bookmark Image Relation writers now enforce shared strict mutation preflight and rollback safety. PR #922 squash merge `bc09381b9eb77dee6b4ef12a94e7b9c06bc86c36`; Flutter CI #2793 Analyze + full Test green.
- #947 — Person profile imagery now uses one canonical Person -> `Profile Image` single Relation. Legacy `profilePhotoId` migration consumes only the established Photo -> Image mapping, missing mappings remain retryable, retarget/clear keeps the temporary legacy projection atomic, corruption/index drift fails closed, and Relation-safe Image deletion detaches the Person backlink. PR #965 squash merge `09de5d4fdec3cd019f43102e2d7437c63a438064`; Flutter CI #2873 Analyze + full Test green.

## #895 completed contract
`RelationTargetService.selectionForMutation(...)` is the shared integrity seam added for integrity-sensitive editor writes. Before returning a `RelationSelectionContext`, it rejects:
- malformed persisted Relation values;
- duplicate target ids;
- missing or wrong-type targets;
- single-cardinality violations;
- serialized/index count drift;
- target/order/position drift.

It performs no repair. Ordinary `selectionFor(...)` remains the picker/diagnostic path.

`BookmarkImageRelationService` now:
- re-reads fresh `Images` and `Cover Image` state with strict preflight inside the mutation transaction for `saveImages`, `setCover`, `clearCover`, and Bookmark-create Photo compatibility writes;
- refuses stale UI state or index corruption instead of treating it as a user edit;
- keeps canonical Relation mutation and `bookmark_photos` compatibility projection updates in the same transaction;
- protects `saveLegacyPhotosAfterCreate(...)` before `_coreBridge.syncAll(...)` when the canonical Bookmark already exists, so compatibility sync cannot turn a fail-closed corrupt Image/Cover read into a legacy-derived overwrite;
- preserves normal first-time create mirroring when no canonical Bookmark exists yet.

Regression coverage proves healthy strict selection plus edge position drift, wrong-type target, single-cardinality corruption, and Bookmark-specific rollback. Failed operations leave stored Relation values, normalized edges, and `bookmark_photos` unchanged.

## #947 completed contract
`PersonProfileImageRelationService` is the B-lane integrity boundary for canonical Person profile imagery:
- provisions/reuses one system `Profile Image` single Relation from canonical Person to canonical Image;
- migrates legacy `Person.profilePhotoId` only through the existing one-to-one `photo_object_links` mapping and never manufactures a replacement Image identity;
- leaves temporarily unavailable/missing Photo -> Image mappings retryable during workspace sync;
- strict-preflights persisted Relation/index/target/cardinality state before migration, retarget, or clear mutations;
- performs canonical Relation mutation and temporary `Person.profilePhotoId` compatibility projection updates in one database transaction;
- selecting a native canonical Image clears the legacy projection because no safe Photo identity exists;
- rejects conflicting canonical-vs-legacy selection, ambiguous/wrong-type mappings, malformed/cardinality-unsafe Relation state, and edge order/position drift without partial mutation;
- uses canonical Relation-safe Object deletion semantics so a deleted Image is detached from surviving Person backlinks without inventing Person-specific delete/index behavior.

`ObjectSyncService` runs this migration only after `CoreObjectBridge` has attempted legacy Photo -> canonical Image promotion, so stable `photo_object_links` mapping exists before Person Relation migration. This keeps unavailable managed media retry-safe and preserves one canonical Image identity.

## Cross-lane audit
- #491 production quick-create/attach reloads canonical selection context before save and persists through canonical mutation; Tag quick-create is additionally atomic after #854.
- #492 Gallery discovery/resolution remains read-only and inherits strict stored/index integrity filtering.
- #493 schema evolution re-reads canonical persisted schema, validates source/target workspace identity, blocks unhealthy audited state, requires explicit multi -> single choices, applies transactionally, and keeps bidirectional target retargeting fail-closed.
- #827 template preflight validates Relation target primitives, Gallery cover compatibility, and referenced View Properties before primitive provisioning; no B blocker.
- #832 Property schema management routes Relation rename/delete through canonical lifecycle; no B blocker.
- #849 Search corrupt-schema isolation continues to use `RelationReadService` and adds no raw-edge/parser fallback or repair path; no B blocker.
- #869 canonical Image/Weblink media presentation is presentation-only and adds no Relation authority.
- #881/#889/#892 introduced the Bookmark Image production Relation writers; #895 is the completed integrity follow-up for those paths.
- #896 Database/View Images default Gallery and #897 Storage Photo deletion safety are completed cross-lane work and do not introduce new Relation authority.
- #945 canonical Person Object identity is integrated and #947 now adds the integrity-safe Person -> Image Relation contract on top of it.
- #948 is Lane D UI integration. It should consume `PersonProfileImageRelationService` rather than add direct serialized-id writes or a parallel Person/Image relationship path.
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
- #871 Flutter CI #2647 Analyze + full Test green.
- #895 Flutter CI #2793 Analyze + full Test green. The superseded #2786 run reached Analyze green but failed only because the new rollback snapshot helper assumed a single Relation was stored as `List`; commit `517823ab71c82760dff36202d82d3397d230cb05` changed the test helper to compare raw JSON value shape, after which #2793 was fully green. Production logic was unchanged by that correction.
- #947 first PR run #2871 failed Analyze only on one unused test import. Commit `d3067325ffd22f42d92aeb070dc84fe09365b609` removed that import; rerun Flutter CI #2873 passed maintainability guards, Drift generation, Analyze, and full Flutter Test before merge.
- Local Flutter execution is unavailable in this connector environment; GitHub Actions is the executable validation source.

## Exact next triggers
1. A new production Relation writer/editor/quick-create path that bypasses `RelationMutationService`, normalizes malformed/duplicate input before canonical validation, or can leave partial side effects on retry/failure.
2. A production caller that invokes `BidirectionalRelationStore.setRelation(...)` directly instead of `RelationMutationService`; add strict low-level stored-value validation before allowing that boundary to become feature-facing.
3. A future Relation target/cardinality schema-evolution change, especially bidirectional target retargeting; unsupported cases remain fail-closed until both sides can be validated before writes.
4. A new Relation-backed media/graph/search/computed-value reader that uses raw `object_relation_edges`, permissive `ObjectRelationValue.fromJson(...)`, or `ObjectStore.resolveRelation(...)` without the canonical integrity contract.
5. A primitive/template/domain/Board workflow that creates external side effects or a legacy projection around its first Relation write; preserve atomicity and strict mutation preflight where current canonical state must be trusted.
6. Any new delete/detach/cross-object reference workflow, stale index/backlink issue, reconcile ambiguity, corruption regression, or Relation-producing workflow.

## Cross-lane dependencies / risks
- Lane C owns schema-authoring UX; Lane B owns destructive Relation target/cardinality correctness and corruption behavior.
- Lane D owns Image/Weblink/File product semantics and #245 migration; new Relation-producing production paths from that work should trigger a focused Lane B audit rather than duplicate primitive logic in Lane B.
- #948 is now unblocked by #945 + #947. `people_management_page.dart` remains a shared hotspot owned by Lane D for that slice; Lane B should not edit it merely to continue work.
- Ordinary semantic Relation parsing remains permissive for compatibility. Integrity-sensitive audit/write/read projections use strict persisted-value inspection; do not silently normalize malformed persisted data.
- Relation adapters must preserve malformed/duplicate caller input until canonical mutation validation.
- `RelationReadService` is an integrity-filtered projection, not an index authority or repair service. UI/graph/computed consumers should not bypass it with raw edges unless they are themselves an integrity service.

## Work in progress / next actions
There is no open Lane B production PR after #965. #947 is closed and #948 has been explicitly notified that its B-lane prerequisite is integrated. Before starting new B code, re-scan latest main, open Issues/PRs, and new #245/#56 production workflows for one of the exact triggers above. If no concrete trigger exists, do not invent a Relation abstraction merely to keep the lane active.

## Stop reason
#947 acceptance is complete and merged. Latest audited main `09de5d4fdec3cd019f43102e2d7437c63a438064`, current open Issue routing, Person Profile Image compatibility paths, canonical Relation readers/writers, rollback behavior, delete/detach behavior, and current cross-lane work were re-audited. #948 is correctly handed back to Lane D and no additional independent feature-level Relation/data-integrity defect is currently identified. This satisfies the AGENTS stop condition: Lane B has no remaining actionable safe work until a new concrete trigger lands.
