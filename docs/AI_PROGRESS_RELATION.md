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

## Current checkpoint — 2026-09-07 04:22 JST
Latest Relation lifecycle merge: `27b68985871e3d4180b8b07c369ebc0f8735b8a9` — PR `#430 Preserve Bookmark Relations when legacy Image deletion is blocked`.
Latest merged Relation handoff baseline: PR `#445 Refresh Relation handoff after Image edit actions audit`, merged as `e2d4d6237b63c58a14699a0f031766f74c2a9e27` after green Flutter CI.
Latest audited `main`: `da44f7811e744a11363f0b693333715d44de2d59` — Refactor `#467 Make Image visual file probe failure observable`, directly on top of Object `#465 Add safe free crop to canonical Image panel`.

Since `#445`, `main` is 23 commits ahead. Canonical Relation services/storage/index ownership were not changed. The only Relation-named production files changed in that range were removals of caller-zero Object-detail Relation/session composition under Refactor `#451`; live `RelationReadService`, `RelationMutationService`, `ObjectStore` Relation storage/index ownership, integrity/reconcile services and current Object detail Relation paths remain independently used.

The production Bookmark -> Image Relation contract remains:
- `CoreObjectBridge` mirrors legacy Bookmark photo attachments into canonical Bookmark `Images` multi-Relation;
- legacy explicit cover mirrors into canonical Bookmark `Cover Image` single Relation;
- writes use canonical `RelationMutationService`;
- `#403` proves attach/retry/idempotency/retarget/edge/backlink/delete/integrity lifecycle while preserving the multi-Relation;
- `#430` proves the Object-owned compatibility deletion preflight leaves those Relations completely unchanged when deletion is rejected.

## Latest repository audit
- Object `#447` is merged: same-path canonical Image preview refresh/cache eviction only; no Relation writes or ownership semantic changes.
- Object `#457` is merged: canonical Image detail panel composes preview + edit actions; no Relation production path.
- Object `#460` is merged: crop presets route through `CanonicalImageEditService`; no Relation mutation/read/index changes.
- Object `#465` is merged: free-crop selector/dialog plus canonical crop-request validation. It changes Image bytes/geometry only and introduces no Relation Property, edge, backlink, detach, retarget or alternate writer.
- Refactor `#451` removed only a caller-zero Object-detail Relation/session composition chain. Current `ObjectInspectorPage` still constructs/uses canonical `RelationReadService` and `RelationMutationService`; production Bookmark/Weblink/Image resolvers/bridges also retain canonical Relation service usage.
- Refactor `#463` removed caller-zero `ObjectDetailValueEditor` / input codec, not the live Relation editor. The retained `ObjectDetailEditService` rejects Relation/Computed ordinary-value editing, while current Relation editing remains on the explicit canonical Relation path in `ObjectInspectorPage`.
- Refactor `#453/#454/#455/#458/#459/#464/#466` are caller-zero/dead-layer cleanup outside Relation persistence/lifecycle.
- Refactor `#467` is now merged as current main. Its production change is limited to debug-observable `ImageVisualResolver` file-probe failure while preserving fail-soft visual resolution; no Relation semantics or storage changed.
- Open Object `#469 Add safe vertical flip to canonical Image actions` only composes existing canonical Image edit primitives behind `canEdit(...)`; no Relation/Photo/schema changes.
- Open Object handoff `#471` is docs-only and explicitly records `Legacy Tags` as compatibility metadata rather than inventing a new Tag Relation producer.
- Open Refactor handoff `#470` is docs-only.
- Open Refactor `#472 Retire unused Person role properties widget` deletes a caller-zero legacy Bookmark/People-role widget and its dead architecture test. The removed widget used legacy `BookmarkRepository`/person-role storage and a legacy people picker, not canonical Object Relation persistence; live canonical Relation services/hosts are untouched.
- The compare from Relation handoff merge `e2d4d623...` to current `main` contains no changes to `relation_mutation_service.dart`, `relation_read_service.dart`, `relation_integrity_service.dart`, `relation_index_reconcile_service.dart`, canonical Relation index SQL, or Relation-producing Object bridges.
- Default-branch audit still finds product `objectStore.setRelation(...)` calls only inside canonical Relation internals (`RelationMutationService` / `BidirectionalRelationStore`); remaining direct uses are tests.
- `object_relation_edges` production ownership remains in `ObjectStore`, with `ObjectGraphQueryStore` read-side; direct SQL mutation hits outside it remain corruption/reconcile tests.
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
- Object `#447/#457/#460/#465` are merged; their production diffs are Relation-neutral.
- Refactor `#451/#463` are merged caller-zero cleanup; live canonical Relation read/mutation paths remain on default branch.
- Relation handoff `#468` prior head `2157299fc4da568dbc012f011a5fc7fc673f42c7` passed Flutter CI `#1619`: maintainability guardrail, boundary ceiling, Drift generation, Analyze and full Test all succeeded. The refreshed handoff commits after it change documentation only; recheck the latest head CI before integration.

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
- Caller-zero removal of legacy Person-role UI does not establish a Person Object/Relation migration contract; do not infer one from Refactor cleanup.

## Stop reason
Current `main` through Refactor `#467`, plus open Object `#469`, Object handoff `#471`, Refactor handoff `#470` and caller-zero Refactor `#472`, does not introduce an uncovered Relation-producing workflow, canonical Relation storage/index/service change, or concrete lifecycle correctness regression. The Relation-adjacent Refactor removals (`#451/#463/#472`) are caller-zero/dead-layer cleanup while live canonical Relation read/mutation hosts remain intact. No further independent Relation implementation is justified without duplicating existing coverage or crossing into Object/Refactor ownership. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, explicit Related-images/batch writes, Relation storage/index/service changes, or a concrete lifecycle regression.
