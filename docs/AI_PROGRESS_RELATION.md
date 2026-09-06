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

## Current checkpoint — 2026-09-07 05:11 JST
Latest Relation lifecycle merge: `27b68985871e3d4180b8b07c369ebc0f8735b8a9` — PR `#430 Preserve Bookmark Relations when legacy Image deletion is blocked`.
Latest Relation handoff merge: PR `#468 Refresh Relation handoff after Image crop audit`, merged as `fc15dc004f8c16873bd89c40d2d76bc7f03ddc9a` after Flutter CI `#1627` succeeded.
Latest audited `main`: `31be90e1dbbfd66592832273820b092cc3a0ce7d` after Refactor `#474 Guard legacy Database presentation shim imports`; Object `#475 Add edge handles to canonical Image free crop` is also merged on this main history.

Since Relation handoff `#468`, canonical Relation services/storage/index ownership were not changed. The six commits from `#468` to current `main` are Object Image edit/geometry presentation work, Object/Repository handoff documentation, and Refactor maintainability guardrails. None adds a Relation Property writer, direct serialized-id path, edge/index mutation path, or Person -> Image production contract.

The production Bookmark -> Image Relation contract remains:
- `CoreObjectBridge` mirrors legacy Bookmark photo attachments into canonical Bookmark `Images` multi-Relation;
- legacy explicit cover mirrors into canonical Bookmark `Cover Image` single Relation;
- writes use canonical `RelationMutationService`;
- `#403` proves attach/retry/idempotency/retarget/edge/backlink/delete/integrity lifecycle while preserving the multi-Relation;
- `#430` proves the Object-owned compatibility deletion preflight leaves those Relations completely unchanged when deletion is rejected.

## Latest repository audit
- Object `#473` is merged: `ImageVisualResolver` can resolve missing/partial geometry read-only from managed bytes while preserving persisted-geometry fast paths. This is read-only media metadata fallback and does not change Object identity, Relation values, edges, backlinks, mutation service ownership, or Photo mapping.
- Object `#469` is merged: safe vertical flip remains behind `CanonicalImageEditService`; no Relation/Photo/schema changes.
- Object `#475` is merged after Flutter CI `#1641` succeeded. It adds edge handles to the normalized free-crop selector; the selector remains presentation-only and final byte mutation still routes through `CanonicalImageEditService`. No Relation Property, target, edge, backlink, detach, retarget, or alternate writer is introduced.
- Open Object `#476 Restore pan and zoom parity in canonical Image free crop` is mergeable on current main. Its diff adds a presentation-only pan/zoom crop selector and dialog toggle that emits only a normalized source `Rect`; final mutation remains behind `CanonicalImageEditService`. It explicitly does not touch Relation, Photo mapping, schema, `ObjectInspectorPage`, Stage1, or generic Database hosts. Flutter CI `#1650` is currently in progress.
- Refactor `#474` is merged. It ratchets legacy Database presentation shim-import guardrails and adjusts CI/reporting only; no Relation persistence/lifecycle semantics changed.
- Open Refactor handoff `#470` is docs-only and does not own Relation semantics.
- Default-branch audit remains consistent with the established contract: no new product Relation writer or parallel Relation index appeared in the audited changes.
- `object_relation_edges` production ownership remains in `ObjectStore`, with `ObjectGraphQueryStore` read-side; no new direct SQL mutation path appeared in the audited changes.
- Person profile images remain legacy `profilePhotoId` / `PhotoRecord`; no first-class Person -> Image Relation producer exists yet.
- `Related images` remains an existing schema/editor concept; no new production population producer or batch Relation writer appeared.

## Stable Relation coverage
Important guardrails include:
- `#174–#177`, `#182/#184/#188` — Bookmark -> Weblink integrity, retarget/detach/delete/idempotency/reconcile.
- `#190/#192`, `#198/#201`, `#208/#210/#211/#216/#222/#273/#307` — Weblink -> Image target/cardinality, lifecycle, real-host and direct-enrichment coverage.
- `#195/#200/#202` — alias-aware Relation candidate/picker behavior.
- `#264/#266/#271/#280` — canonical Relation bootstrap remains separate from compatibility-era Bookmark relation-like tables across historical migrations.
- `#351` — target ObjectType validation during Board grouped creation while preserving the original Relation validation failure.
- `#403` — Bookmark `Cover Image` + `Images` attach/retry/retarget/backlink/index/delete/integrity lifecycle.
- `#430` — blocked generic Image deletion preserves canonical Bookmark Image Relation values, edges, backlinks and integrity.

## Validation / CI state
- Relation `#403`: green and merged as `c8f00b25f38e6bc3523fba524798b1f7200f326a`.
- Relation `#430`: green and merged as `27b68985871e3d4180b8b07c369ebc0f8735b8a9`.
- Relation `#445`: green and merged as `e2d4d6237b63c58a14699a0f031766f74c2a9e27`.
- Relation `#468`: refreshed head `a638015af08a1671cbc67bea84b100b1069395ee` passed Flutter CI `#1627` with maintainability guardrail, boundary ceiling, Drift generation, Analyze and full Test all successful, then merged as `fc15dc004f8c16873bd89c40d2d76bc7f03ddc9a`.
- Object `#475`: head `e2c81ecc858b009722a8457584c90d1eb32c9639` passed Flutter CI `#1641` and merged as `4e744193ee11556cc29d21722e090f4572caba7c`.
- Open Object `#476`: head `1ed69a48d92656e5e37cfd63085bbd210ebe1897`; Flutter CI `#1650` is in progress at this checkpoint.
- Refactor `#474` is merged on current main and is Relation-neutral.

## Exact next Relation actions
1. If Object adds a distinct user-facing Bookmark `Cover Image` / `Images` editor-write path beyond compatibility bridge sync, cover the real host attach/retarget/detach/retry path only where generic Relation editor coverage is insufficient.
2. When `#245` introduces Person -> Image production Relation migration, add target/cardinality/backlink/delete/detach/idempotency coverage before legacy `profilePhotoId` retirement.
3. Watch for explicit `Related images` population, batch Relation writes, or genuinely new Relation Property creation paths.
4. Audit actual changes touching persisted Relation values, `object_relation_edges`, `ObjectStore`, canonical Relation services, integrity or reconcile behavior.
5. Never invent Object merge/dedup Relation rewriting without explicit product policy.

## Risks / sequencing notes
- Legacy `bookmark_photos`, `photo_object_links` and `Legacy Photo ID` remain compatibility state during `#245`; Relation tests do not authorize destructive cleanup.
- Product-level Image deletion/edit ownership policy is Object-owned; Relation lane only protects invariants at canonical boundaries.
- `CoreObjectBridge` keeps its separate canonical Relation-safe stale-mirror cleanup after legacy Photo removal; do not route that compatibility cleanup through the user-facing deletion guard unless Object policy explicitly changes.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Person profile Image migration remains deferred until Object lane establishes the first-class Person/Image product contract.
- Image crop/edit UI is presentation/Object behavior even when the Image participates in Relations; do not add Relation tests unless edit semantics actually change Object identity or Relation targets.
- Refactor presentation/import guardrails do not establish Relation product semantics; do not infer a new Relation workflow from maintainability-only changes.

## Stop reason
Current `main` through Object `#473/#469/#475` and Refactor `#474`, plus open Object `#476` and Refactor handoff `#470`, does not introduce an uncovered Relation-producing workflow, canonical Relation storage/index/service change, or concrete lifecycle correctness regression. The new Image crop/geometry work changes presentation or managed-byte editing behind the existing canonical Image edit boundary without changing Image identity or Relation targets. No further independent Relation implementation is justified without duplicating existing coverage or crossing into Object/Refactor ownership. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, explicit Related-images/batch writes, Relation storage/index/service changes, or a concrete lifecycle regression.
