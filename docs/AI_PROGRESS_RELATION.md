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

## Current checkpoint — 2026-09-07 02:28 JST
Latest Relation lifecycle merge: `27b68985871e3d4180b8b07c369ebc0f8735b8a9` — PR `#430 Preserve Bookmark Relations when legacy Image deletion is blocked`.
Latest Relation handoff merge: PR `#445 Refresh Relation handoff after Image edit actions audit`, merged as `e2d4d6237b63c58a14699a0f031766f74c2a9e27` after Flutter CI `#1566` succeeded.
Latest non-Relation main integrated during the final audit: Refactor `#448 Enforce presentation database reach-through ceiling in CI`, merged as `21eb29ae08d6e51bea1264792d204be0470d9065`; it changes CI/maintainability guardrails only. Latest production Object behavior remains `#442 Add safe canonical Image detail edit actions` at `340215ef530d00c577eb2fe3e5fca501d646773b`, with Object handoff `#446` at `f87b463b0991c8e2b4a3aa7e41db68a677b28aa3`.

The production Bookmark -> Image Relation contract remains:
- `CoreObjectBridge` mirrors legacy Bookmark photo attachments into canonical Bookmark `Images` multi-Relation;
- legacy explicit cover mirrors into canonical Bookmark `Cover Image` single Relation;
- writes use canonical `RelationMutationService`;
- `#403` proves attach/retry/idempotency/retarget/edge/backlink/delete/integrity lifecycle while preserving the multi-Relation;
- `#430` proves the Object-owned compatibility deletion preflight leaves those Relations completely unchanged when deletion is rejected.

## Completed Relation slice — #430
Object `#423 Guard Images participating in legacy Photo sync from deletion` introduced a user-facing preflight before `super.deleteObject(...)` for system Images. Relation `#430` added `test/generic_database_legacy_image_delete_relation_guard_test.dart` and proves that a rejected Image delete preserves Bookmark `Images`, `Cover Image`, normalized edges, backlinks, the Image Object, and a healthy integrity audit. No production Relation code, schema, migration, presentation or alternate index path changed.

## Validation
- Relation `#403`: Flutter CI `#1457` green; merged as `c8f00b25f38e6bc3523fba524798b1f7200f326a`.
- Relation `#430`: Flutter CI `#1522` green; merged as `27b68985871e3d4180b8b07c369ebc0f8735b8a9`.
- Object `#432`: Flutter CI `#1530` green; no Relation semantics changed.
- Object `#434`: Flutter CI `#1536` green; advisory `canEdit(...)` is Relation-read/write neutral.
- Relation `#437`: merged after green CI.
- Object `#436`: Flutter CI `#1540` green; format-aware edit availability is Relation-neutral.
- Object `#438`: Flutter CI `#1549` green; merged as `5724bdbf0cb3b8657548721c4c19d93d29076477`.
- Relation `#440`: Flutter CI `#1550` green; merged successfully.
- Stale Relation handoff `#441`: Flutter CI `#1554` green at its head, but subsequent main changes made it non-mergeable; superseded.
- Object `#442`: Flutter CI `#1555` green; merged as `340215ef530d00c577eb2fe3e5fca501d646773b`.
- Relation handoff `#445`: prior head also passed CI `#1561`; refreshed head `90a3dd6c9a03995162c276214b5fe9ec04a7f162` passed Flutter CI `#1566` — maintainability guardrail tests, Drift generation, Analyze and full Test all succeeded — then merged as `e2d4d6237b63c58a14699a0f031766f74c2a9e27`.
- Refactor `#448`: Flutter CI `#1565` green before merge as `21eb29ae08d6e51bea1264792d204be0470d9065`; no Relation production files or semantics changed.

## Repository audit since previous handoff
- `#438` adds `CanonicalImageEditService.canRestoreOriginal(...)`, reusing canonical File lookup and exclusive managed-file ownership checks plus backup existence. It adds no Relation write, Photo mapping, schema, edge/index or shared-host mutation.
- `#439` delegates `NotionBookmarkCard` URL resolver composition to the shared presentation resolver factory; it is presentation/read composition and does not touch canonical Relation APIs or storage.
- `#442` adds Image detail edit controls that route only through `CanonicalImageEditService.edit/restoreOriginal`; the production file imports only the canonical Image edit service and Flutter presentation APIs. It changes Image bytes/geometry under Object-owned safety policy but does not create, mutate, detach or retarget Relations, does not alter Photo mappings, and does not bypass canonical Relation APIs.
- `#443` adds an opt-in maintainability reach-through regression threshold; it is Refactor-lane guardrail work and does not change Relation semantics.
- `#446` is Object handoff documentation only; it changes no production Relation, Object persistence or index behavior.
- Refactor `#448` is now merged and only enforces the accepted presentation database reach-through ceiling in CI; no product persistence or Relation semantics changed.
- Open Object `#447 Refresh canonical Image preview after same-path edits` changes only `object_image_detail_preview.dart` plus its focused widget regression. Its production patch re-resolves geometry and evicts Flutter's same-path `FileImage` cache after Object-owned edits; it introduces no Relation write or ownership semantic change.
- Open stacked Object `#449 Compose canonical Image detail media and edit actions` changes only new `object_image_detail_section.dart` plus its focused test. The production section composes `ObjectImageDetailPreview`, `ObjectImageEditActions`, `CanonicalImageEditService`, Image/file ownership services and preview refresh; it imports no Relation service, creates no Relation Property, and does not alter Photo mappings/schema.
- Comparing Relation handoff merge `#440` through audited Object/Refactor main shows no Relation source file changes: only Object Image edit/restore presentation/service work, Refactor maintainability files, tests and docs changed.
- Default-branch audits found low-level `objectStore.setRelation(...)` production use only inside canonical Relation internals (`RelationMutationService` / `BidirectionalRelationStore`); remaining hits are tests/docs.
- `object_relation_edges` production ownership remains `ObjectStore`, with `ObjectGraphQueryStore` read-side; direct SQL mutations outside it remain corruption/reconcile tests.
- Person profile images remain legacy `profilePhotoId` / `PhotoRecord` in production; no first-class Person -> Image Relation producer exists yet.
- `Related images` has schema and existing generic editor/lifecycle coverage, but no new production population producer appeared; current direct population hits are tests.

## Stable Relation coverage
Important guardrails include:
- `#174–#177`, `#182/#184/#188` — Bookmark -> Weblink integrity, retarget/detach/delete/idempotency/reconcile.
- `#190/#192`, `#198/#201`, `#208/#210/#211/#216/#222/#273/#307` — Weblink -> Image target/cardinality, lifecycle, real-host and direct-enrichment coverage.
- `#195/#200/#202` — alias-aware Relation candidate/picker behavior.
- `#264/#266/#271/#280` — canonical Relation bootstrap remains separate from compatibility-era Bookmark relation-like tables across historical migrations.
- `#351` — target ObjectType validation during Board grouped creation while preserving the original Relation validation failure.
- `#403` — Bookmark `Cover Image` + `Images` attach/retry/retarget/backlink/index/delete/integrity lifecycle.
- `#430` — blocked generic Image deletion preserves canonical Bookmark Image Relation values, edges, backlinks and integrity.

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
- Open `#447/#449` are Object-only preview/edit-composition work and do not own Relation production files; re-audit their actual diffs only if scope expands before merge.

## Stop reason
Latest main through merged Refactor `#448`, plus open Object `#447/#449`, does not introduce an uncovered Relation-producing workflow, canonical Relation storage/index/service change, or concrete lifecycle correctness regression. Relation handoff `#445` is merged and green. No further independent Relation implementation is justified without duplicating existing coverage or crossing into Object/Refactor ownership. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, explicit Related-images/batch writes, Relation storage/index/service changes, or a concrete lifecycle regression.
