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

## Current checkpoint — 2026-09-07 00:10 JST
Latest Relation merge: `27b68985871e3d4180b8b07c369ebc0f8735b8a9` — PR `#430 Preserve Bookmark Relations when legacy Image deletion is blocked`.
Latest audited `main`: `bc799c123dbdd3313d9d1538f3336721de259b74` after Object `#436 Align canonical Image edit availability with supported formats`.

The production Bookmark -> Image Relation contract remains:
- `CoreObjectBridge` mirrors legacy Bookmark photo attachments into canonical Bookmark `Images` multi-Relation;
- legacy explicit cover mirrors into canonical Bookmark `Cover Image` single Relation;
- writes use canonical `RelationMutationService`;
- `#403` proves attach/retry/idempotency/retarget/edge/backlink/delete/integrity lifecycle while preserving the multi-Relation;
- `#430` proves the Object-owned compatibility deletion preflight leaves those Relations completely unchanged when deletion is rejected.

## Completed Relation slice — #430
Object `#423 Guard Images participating in legacy Photo sync from deletion` introduced a user-facing preflight before `super.deleteObject(...)` for system Images. It rejects deletion while an Image is an active `photo_object_links` target, is a legacy-owned mirror with non-null `Legacy Photo ID`, or compatibility ownership cannot be proven safely.

Relation `#430` added `test/generic_database_legacy_image_delete_relation_guard_test.dart` using the real `CoreObjectBridge` + `GenericDatabasePageServices.relationMutations` path. Before and after the rejected delete it proves:
- Bookmark `Images` still resolves to the same Image;
- Bookmark `Cover Image` still resolves to the same Image;
- both normalized Relation edges remain present exactly once;
- both Image backlinks remain present exactly once;
- the Image Object remains present;
- `RelationIntegrityService.auditWorkspace(...)` remains healthy;
- the deletion fails at the Object-owned preflight with `LegacyPhotoCompatibilityImageDeletionException`, before canonical Relation-safe detach can partially mutate state.

No production Relation code, schema, migration, Object identity, filesystem behavior, presentation or alternate index path changed in #430.

## Validation
- Relation `#403`: Flutter CI `#1457` green; merged as `c8f00b25f38e6bc3523fba524798b1f7200f326a`.
- Object `#423`: Flutter CI `#1512` green before merge as `a8c39f6941a9959791b7d36305e921b4e5d0784f`.
- Relation `#430`: Flutter CI `#1522` green — Drift generation, Analyze and full Test all succeeded; merged as `27b68985871e3d4180b8b07c369ebc0f8735b8a9`.
- Object `#432`: Flutter CI `#1530` green before merge as `07cd55648d6bb62bfdfbea7fe8af880ede9be94b`.
- Object `#434`: Flutter CI `#1536` green; merged as `53f4b9f5536883918c18213cddc408c88b9d7465`; advisory `canEdit(...)` does not mutate Relations or Photo compatibility mappings.
- Relation handoff `#437`: merged as `773259195dba90a759fa9fd73c0ee31fecf7aa47` after green CI.
- Object `#436`: Flutter CI `#1540` green; merged as `bc799c123dbdd3313d9d1538f3336721de259b74`; format-aware edit availability is read-only with respect to Relation state.
- Open Object `#438`: mergeable; Flutter CI `#1548` currently in progress at head `63672058bb9ea3ab81c2a1c2b110a7f6f9b90f65`.

## Repository audit since previous handoff
Recent Object/Refactor changes were classified as follows:
- `#406` — Weblink enrichment diagnostic privacy only; canonical create/enrichment behavior unchanged.
- `#408` — legacy Bookmark `bookmark_relations` read-boundary cleanup, not canonical Object Relation storage.
- `#409/#415/#416` — canonical Image detail edit/read-only/preview presentation; no Relation writes.
- `#413` — managed Image file cleanup still performs canonical `RelationMutationService.deleteObject(...)` before physical cleanup.
- `#418` — tests-only canonical Image backlink/reverse-lookup parity; no new Relation producer.
- `#423` — Relation lifecycle trigger because its new compatibility preflight can reject the user-facing Image deletion path before canonical detach; covered by #430.
- `#426` — canonical Image geometry mutation only; no Relation semantics.
- `#427/#431` and nearby Refactor caller-zero/FTS/docs work do not alter canonical Relation behavior.
- Object `#432` adds ownership-safe Image edit/restore coordination plus geometry refresh/rollback without changing Relation values, Photo mappings, schema, edge/index or Relation producers.
- Object `#434` adds advisory canonical Image edit availability only.
- Object `#436` further constrains that advisory edit availability by supported image format only; no Relation mutation/read/index behavior changed.
- Open Object `#438` adds `CanonicalImageEditService.canRestoreOriginal(...)`; the patch is limited to the Image edit service, focused tests and Object handoff. It performs canonical File/ownership lookup and backup existence checks only, with no Relation write, Photo mapping, schema or shared-host change.
- Open Refactor `#439` delegates `NotionBookmarkCard` URL resolver composition to `BookmarkPresentationResolverFactory`; its production diff is presentation composition only and does not touch canonical Relation APIs or storage.

Default-branch and open-PR audits found no new direct product use of low-level `ObjectStore.setRelation`, no alternate `object_relation_edges` writer, no new Bookmark/Weblink/Image/Person Relation producer, and no canonical Relation service bypass.

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
- Open #438 and #439 do not own Relation production files; if either expands before merge, re-audit the actual changed-file list before touching a shared hotspot.

## Stop reason
Latest main through Object #436 plus open Object #438 and Refactor #439 do not introduce an uncovered Relation-producing workflow, canonical Relation storage/index/service change, or concrete lifecycle correctness regression. No further independent Relation implementation is justified without duplicating existing coverage or crossing into Object/Refactor ownership. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, explicit Related-images/batch writes, Relation storage/index/service changes, or a concrete lifecycle regression.
