# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional Relation integrity, Relation write validation, target/cardinality constraints, stale/inconsistent metadata handling, deterministic index reconciliation, Relation-safe deletion/detach, Relation picker candidate/selection behavior, and focused regressions for Object-owned workflows that consume the canonical Relation boundary.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink Object + managed Image workflow
- `#245` — legacy Photo -> Image consolidation; Relation owns lifecycle correctness when Bookmark/Image or Person/Image becomes a production Relation workflow.

Cross-lane coordination:
- `#225` — Refactor lane maintainability/legacy cleanup; Relation lane does not co-own unrelated refactors.

## Current checkpoint
Latest audited `main`: `25c9618c8a957aff771fd3c864be15a57e6ba339` — PR #381 `Reuse canonical Image source lookup before preview download`.

Active Relation branch: `test/relation-bookmark-image-mirror-245`.
Latest branch commit before this handoff update: `4981da841b150b651e4ecd05a821ef037bd85bdd`.

Latest previously merged focused Relation implementation: PR #307, `6a14c778602bdb89d51e53dfe9206f10199213a8`, covering direct Weblink creation/enrichment -> managed Representative Image Relation.

## Canonical Relation contract
- `RelationMutationService` is the feature-facing mutation boundary.
- `RelationReadService` resolves canonical outgoing/backlink state.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs only deterministic index drift from persisted Relation values.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- ambiguous missing-target/cardinality/bidirectional corruption is never auto-repaired from editor paths.
- no feature may introduce its own serialized-id Relation path or alternate edge/index store.
- low-level `ObjectStore.setRelation` remains storage-internal/test-facing rather than a normal product mutation path.

## Stable Relation coverage on main
Important merged guardrails include:
- `#174–#177` Bookmark/Weblink and Weblink/Image boundary integrity.
- `#182/#184/#188` Bookmark -> Weblink retarget, detach/delete, shared targets and index reconcile.
- `#190/#192` production Weblink -> Image target/cardinality/lifecycle.
- `#195/#200/#202` alias-aware Relation candidate search and real picker.
- `#198/#201` preview pipeline / real ObjectSync retry, replacement, backlink/index/audit and delete lifecycle.
- `#208/#210/#211/#216/#222` exposed Weblink/Image real-host edit/backlink/delete/composite-delete lifecycle.
- `#273` real page-services creation + explicit Relation editor attach for Representative/Related Images.
- `#264/#266/#271/#280` canonical Relation bootstrap remains separate from legacy Bookmark relation-like tables across historical migrations, including real v1 -> current.
- `#307` direct generic Weblink creation enrichment -> managed Representative Image Relation composition-root lifecycle.
- `#351` indirectly exercises canonical target ObjectType validation during Board grouped-preset failure.

## Latest repository audit — 2026-09-06 16:10 JST
Issue #245 advanced materially since the previous Relation handoff:
- #378 merged: legacy Photo mirroring now reuses the canonical `ImageObjectService` definition.
- #379 merged: managed Image identity can reuse the exact managed File when provenance differs.
- #380 merged: legacy Photo promotion reuses an existing canonical Image with the exact File and persists `photo_object_links`; native Image ownership survives later legacy Photo deletion.
- #381 merged on current main: Weblink preview pre-download source lookup reuses canonical Image source normalization.
- #382 is open and changes canonical Image import/reimport file reuse only; its PR explicitly does not change Relation persistence.
- #383 is open Refactor work centralizing read-only `bookmark_object_links` lookup; it explicitly does not change Relation writes or repair behavior.

The important new Relation finding is that `CoreObjectBridge` already contains a real production compatibility workflow from legacy `bookmark_photos` to the canonical Bookmark `Images` multi-Relation. The bridge defines `Images` with target ObjectType = system Image and `multiple: true`, resolves legacy Photo ids through `photo_object_links`, and writes through `RelationMutationService.setRelation(...)`.

This path predates the explicit single `Cover Image` model but is now directly relevant to #245 Phase 3 preparation. Existing tests covered mirror cleanup/native survival, but did not directly assert the Bookmark -> Images outgoing Relation, normalized edge, backlink, retry/idempotency, detach-on-legacy-unlink and workspace integrity together.

## Checkpoint completed in this run
Added focused tests-only regression:
- `test/core_object_bridge_bookmark_image_relation_test.dart`
- creates one legacy Photo + Bookmark + `bookmark_photos` row;
- runs `CoreObjectBridge.syncAll(...)` and asserts exactly one canonical Bookmark `Images` Relation;
- verifies canonical outgoing read, exactly one normalized edge, exactly one backlink and healthy `RelationIntegrityService.auditWorkspace(...)`;
- reruns compatibility sync and proves Relation/index/backlink remain idempotent;
- removes the legacy `bookmark_photos` link, reruns sync, and proves canonical Relation/edge/backlink detach while the Image Object survives.

No production Relation implementation, schema, migration, presentation, or alternate serialized-id/index path was added.

## Validation status
The branch change is intentionally tests-only plus handoff documentation. GitHub-hosted CI is the authoritative validation because this automation environment does not provide a checked-out Flutter workspace for local `flutter test` execution.

Open cross-lane ownership at this checkpoint:
- #382 Object lane — Image content dedupe/reimport, no Relation persistence change.
- #383 Refactor lane — read-only Bookmark object-link Store extraction, no Relation write change.
- stale handoff-only Relation PR #372 remains open and should not be integrated instead of this newer branch.

## Exact next Relation actions
1. Run/inspect CI for this Bookmark `Images` mirror regression and fix only failures caused by the test.
2. Once Object lane introduces the proposed Bookmark -> `Cover Image` single Relation, add focused lifecycle coverage for attach, retarget, retry/idempotency, backlink, cardinality, detach and Relation-safe Image deletion.
3. Verify `Cover Image` and existing `Images` multi-Relation coexist without duplicate/parallel edge semantics and preserve explicit-cover precedence in Object-owned presentation.
4. Watch #245 for Person -> Image profile migration and cover that production Relation path when it lands.
5. Audit any change touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, `RelationIntegrityService`, or reconcile behavior.
6. Do not invent automatic Object merge/dedup Relation rewriting without explicit product policy.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Future Object merge/dedup requires explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` are compatibility-era Bookmark tables, not canonical generic Object Relations.
- `bookmark_photos` is still legacy source data; the bridge's canonical `Images` Relation is compatibility mirroring, not permission to delete the legacy schema.
- Explicit cover semantics are not yet first-class: `is_cover` ordering feeds `Images`, while a distinct single `Cover Image` Relation remains the next Object-owned product contract.

## Stop reason
A newly relevant production Relation-producing workflow was identified and received focused lifecycle/idempotency/backlink/detach/integrity coverage. The next major Relation slice depends on Object lane landing the first-class single `Cover Image` Relation contract, so this run stops at the cross-lane dependency rather than inventing that product model in Relation lane.
