# AI Progress — Relation Lane

> Durable handoff for Relation/backlink lifecycle and integrity work. Update before every Relation-lane run ends.

## Lane scope
Own canonical Relation mutation/read/index/backlink/audit/reconcile behavior, target ObjectType/cardinality validation, Relation-safe delete/detach/retarget/retry/idempotency, picker candidate/selection behavior, and focused regressions for new Object-owned Relation-producing or Relation-lifecycle boundaries.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink + managed Image workflow
- `#245` — legacy Photo -> canonical Image convergence

Cross-lane coordination:
- Object lane owns Bookmark/Image and Person/Image product semantics, compatibility policy and UI.
- Refactor `#225` owns behavior-preserving cleanup; it must not redesign Relation semantics.
- `#166` alias-aware Relation picker is complete/closed.

## Canonical contract
- Feature writes go through `RelationMutationService`.
- Reads/backlinks use `RelationReadService` / canonical ObjectStore projections.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index drift only.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- A product-level preflight that rejects deletion must leave persisted Relation values, normalized edges and backlinks unchanged.
- Ambiguous damage, missing targets, cardinality conflicts, or stale metadata are not guessed/auto-repaired from editor paths.
- No feature may introduce a parallel serialized-id Relation writer or alternate Relation edge/index store.
- Low-level `ObjectStore.setRelation` remains storage-internal/test-facing rather than a normal product mutation path.

## Current checkpoint — 2026-09-06 20:07 JST
Latest audited `main`: `a7f57bf853c24099da905b23c48208ad4c905a5d` — Object `#426 Refresh canonical Image geometry after managed edits`.

Latest merged Relation implementation: `#403`, merged as `c8f00b25f38e6bc3523fba524798b1f7200f326a`, with Flutter CI `#1457` green (Drift / Analyze / full Test).

The production Bookmark -> Image Relation contract remains:
- `CoreObjectBridge` mirrors legacy Bookmark photo attachments into canonical Bookmark `Images` multi-Relation;
- legacy explicit cover mirrors into canonical Bookmark `Cover Image` single Relation;
- writes use canonical `RelationMutationService`;
- `#403` proves attach/retry/idempotency/retarget/edge/backlink/delete/integrity lifecycle while preserving the multi-Relation.

## New Relation lifecycle trigger — Object #423
Object `#423 Guard Images participating in legacy Photo sync from deletion` merged as `a8c39f6941a9959791b7d36305e921b4e5d0784f` after Flutter CI `#1512` passed Analyze + full suite.

It adds a user-facing preflight in `GenericDatabasePageServices.relationMutations.deleteObject(...)` for system Images:
- reject deletion while an Image is an active `photo_object_links` target;
- reject legacy-owned mirrors with non-null `Legacy Photo ID`;
- fail closed on ambiguous duplicate compatibility metadata;
- allowed deletes still delegate to `super.deleteObject(...)`, then best-effort managed-file cleanup.

Object-side #423 tests prove the blocked Image, legacy Photo and managed file remain. They do not explicitly assert that existing canonical Bookmark `Images` / `Cover Image` Relation values, normalized edges and backlinks remain intact after the rejected delete.

That is a concrete Relation-lifecycle boundary because the preflight now runs before canonical Relation-safe deletion.

## Active Relation slice
Branch: `test/relation-legacy-image-delete-guard-245`

Added `test/generic_database_legacy_image_delete_relation_guard_test.dart` on latest main.

The regression uses the real `CoreObjectBridge` compatibility path to create:
- one legacy Photo -> canonical Image mapping;
- one Bookmark -> `Images` Relation to that Image;
- one Bookmark -> `Cover Image` Relation to the same Image.

It then attempts deletion through the real `GenericDatabasePageServices.relationMutations` boundary and expects `LegacyPhotoCompatibilityImageDeletionException`.

Before and after the rejected delete it verifies:
- both canonical outgoing Relations still resolve to the same Image;
- both normalized Relation edges remain present exactly once;
- both Image backlinks from the Bookmark remain present exactly once;
- the Image Object remains present;
- `RelationIntegrityService.auditWorkspace(...)` remains healthy.

No production Relation code, schema, migration, Object identity, filesystem policy, presentation or alternate index path is changed by this Relation slice.

## Repository audit since previous handoff
The 21 commits from `b8a74717...` through current main were classified as follows:
- `#406` — Weblink enrichment diagnostic privacy only; canonical create/enrichment behavior unchanged.
- `#408` — legacy Bookmark `bookmark_relations` read-boundary cleanup, not canonical Object Relation storage.
- `#409/#415/#416` — canonical Image detail edit/read-only/preview presentation; no Relation writes.
- `#413` — managed Image file cleanup still performs canonical `RelationMutationService.deleteObject(...)` before physical cleanup.
- `#418` — tests-only canonical Image backlink/reverse-lookup parity; no new Relation producer.
- `#423` — **Relation lifecycle trigger** because a new compatibility preflight can block the user-facing deletion path before canonical detach; covered by the active regression above.
- `#426` — canonical Image geometry mutation only; no Relation semantics.
- Refactor caller-zero/FTS/docs work in `#417/#422/#424/#425/#427/#429` does not alter canonical Relation behavior.
- Object handoff `#428` records future Image editor work but introduces no Relation producer.

No new direct serialized-id Relation writer, alternate `object_relation_edges` writer, or canonical Relation service bypass was found.

Stale Relation handoff PR `#420` was based on `853d5839...` and is superseded by this current-main Relation slice/handoff. Do not merge it.

## Stable Relation coverage
Important guardrails include:
- `#174–#177`, `#182/#184/#188` — Bookmark -> Weblink integrity, retarget/detach/delete/idempotency/reconcile.
- `#190/#192`, `#198/#201`, `#208/#210/#211/#216/#222/#273/#307` — Weblink -> Image target/cardinality, lifecycle, real-host and direct-enrichment coverage.
- `#195/#200/#202` — alias-aware Relation candidate/picker behavior.
- `#264/#266/#271/#280` — canonical Relation bootstrap remains separate from compatibility-era Bookmark relation-like tables across historical migrations.
- `#351` — target ObjectType validation during Board grouped creation while preserving the original Relation validation failure.
- `#403` — Bookmark `Cover Image` + `Images` attach/retry/retarget/backlink/index/delete/integrity lifecycle.

## Validation
- Relation `#403`: Flutter CI `#1457` green; merged.
- Object `#423`: Flutter CI `#1512` green before merge.
- Active Relation branch: PR CI must validate the new focused blocked-delete regression on current main. Fix only failures caused by this test/handoff slice.

## Exact next Relation actions
1. Run/integrate the active blocked-delete Relation preservation regression after green CI; if main moves and the branch becomes non-mergeable, replay only this test + handoff from latest main rather than force-merging stale history.
2. Close stale handoff-only `#420` as superseded once the current Relation PR exists.
3. If Object adds a distinct user-facing Bookmark `Cover Image` / `Images` editor-write path beyond compatibility bridge sync, cover the real host attach/retarget/detach/retry path only where generic Relation editor coverage is insufficient.
4. When `#245` introduces Person -> Image production Relation migration, add target/cardinality/backlink/delete/detach/idempotency coverage before legacy `profilePhotoId` retirement.
5. Watch for explicit `Related images` population, batch Relation writes, or genuinely new Relation Property creation paths.
6. Audit actual changes touching persisted Relation values, `object_relation_edges`, `ObjectStore`, canonical Relation services, integrity or reconcile behavior.
7. Never invent Object merge/dedup Relation rewriting without explicit product policy.

## Risks / sequencing notes
- Legacy `bookmark_photos`, `photo_object_links` and `Legacy Photo ID` remain compatibility state during `#245`; Relation tests do not authorize destructive cleanup.
- Product-level Image deletion guards are Object-owned; Relation lane only protects invariants at the boundary.
- `CoreObjectBridge` keeps its separate canonical Relation-safe stale-mirror cleanup after legacy Photo removal; do not route that compatibility cleanup through the user-facing deletion guard unless Object policy explicitly changes.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Person profile Image migration remains deferred until Object lane establishes the first-class Person/Image product contract.

## Stop reason
The active Relation slice is the focused invariant regression for Object #423's new deletion preflight. After this regression is validated and integrated, no further independent Relation work is currently justified unless a new Relation-producing workflow, Relation storage/index change, or concrete correctness regression appears.
