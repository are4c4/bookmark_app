# AI Progress — Relation Lane

> Durable handoff for Relation/backlink lifecycle and integrity work. Update before every Relation-lane run ends.

## Lane scope
Own canonical Relation mutation/read/index/backlink/audit/reconcile behavior, target ObjectType/cardinality validation, Relation-safe delete/detach/retarget/retry/idempotency, picker candidate/selection behavior, and focused regressions for new Object-owned Relation-producing workflows.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink + managed Image workflow
- `#245` — legacy Photo -> canonical Image convergence

Cross-lane:
- Object lane owns Bookmark/Image and Person/Image product semantics and UI.
- Refactor `#225` owns behavior-preserving cleanup; it must not redesign Relation semantics.

## Canonical contract
- Feature writes go through `RelationMutationService`.
- Reads/backlinks use `RelationReadService` / canonical ObjectStore projections.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index drift only.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- Ambiguous damage, missing targets, cardinality conflicts, or stale metadata are not guessed/auto-repaired from editor paths.
- No feature may introduce a parallel serialized-id Relation writer or alternate Relation edge/index store.

## Current checkpoint — 2026-09-06 17:14 JST
Latest audited `main`: `720c5781b181f92ca4c0a06bb491a2dced052984` (`#396 Skip missing legacy Photo files only when paths are resolvable`).

Important new Object-owned Relation workflow since the previous handoff:
- `#387` merged as `5a3cab0847664f2e2a7579dfa6de801223b0d4d5` and added system Bookmark `Cover Image` as a **single Relation** targeting canonical Image Objects.
- `CoreObjectBridge` mirrors legacy `bookmark_photos.is_cover` through the existing canonical `RelationMutationService.setRelation(...)` path.
- The existing Bookmark `Images` multi-Relation remains in parallel during migration.
- Object-side coverage proves schema/cardinality, initial attach, retarget, detach, multi-Image preservation, and fail-closed handling for ambiguous/missing cover mapping.
- `#391` reads canonical Bookmark `Cover Image` for presentation, so the new Relation is consumed by a real product read path.

This is a genuine new Relation-producing production workflow and triggered Relation-lane lifecycle work.

## This run — Relation checkpoint
Active branch: `test/relation-bookmark-cover-image-lifecycle-245-v2`

Added `test/core_object_bridge_bookmark_cover_relation_lifecycle_test.dart` on latest main. The focused integration regression exercises the real `CoreObjectBridge` compatibility write path and verifies:
- `Cover Image` targets the system Image ObjectType and is single-cardinality;
- initial attach resolves through canonical outgoing Relation reads;
- normalized Relation edges contain exactly one cover edge;
- cover backlinks resolve exactly once;
- repeated `CoreObjectBridge.syncAll(...)` is idempotent and does not duplicate Relation/index/backlink state;
- retarget moves the single cover edge/backlink from Image A to Image B while preserving the Bookmark `Images` multi-Relation;
- Relation-safe deletion of Image B through `RelationMutationService.deleteObject(...)` detaches both `Cover Image` and the matching `Images` entry while preserving Image A;
- workspace integrity remains healthy across attach/retry/retarget/delete.

No production Relation code, schema, Object identity, presentation, or alternate edge/index path was changed.

## Previous Relation coverage still relevant
- `#174–#177`, `#182/#184/#188` — Bookmark -> Weblink integrity, retarget/detach/delete/idempotency/reconcile.
- `#190/#192`, `#198/#201`, `#208/#210/#211/#216/#222/#273/#307` — Weblink -> Image target/cardinality, lifecycle, real-host and direct-enrichment coverage.
- `#195/#200/#202` — alias-aware Relation candidate/picker behavior.
- historical migration coverage keeps canonical Relation bootstrap separate from legacy Bookmark relation-like tables.
- `#351` indirectly exercises target ObjectType validation during Board grouped creation without changing Relation semantics.

## Validation / CI
- Earlier Relation PR `#386` (`Cover canonical Bookmark Images mirror lifecycle`) completed Flutter CI `#1412` successfully, but its old base became non-mergeable after Object `#387` introduced the stronger single-cover contract.
- First refreshed PR `#398` was built from `8f044c9` but Object `#396` merged during the run and advanced `main` again; it is superseded by this v2 latest-main branch rather than force-integrating stale bases.
- Current branch validation should run through the focused PR Flutter CI; fix only failures caused by this test/handoff slice.

## Open PR ownership audited
At this checkpoint:
- `#394` — Object Photo file-deletion ownership policy; no Relation persistence change.
- `#397` — Refactor presentation resolver construction guard; tests-only, no Relation change.
- stale Relation `#386` and first refreshed `#398` are superseded by this latest-main branch.

No shared presentation hotspot was edited by this Relation run; work is tests + Relation handoff only.

## Exact next Relation actions
1. Let the current focused Cover Image lifecycle PR validate; fix only failures caused by this test/handoff slice.
2. If Object adds a direct user-facing Bookmark `Cover Image` editor/write path distinct from legacy bridge sync, cover attach/retarget/detach/retry through that real host boundary if generic Relation editor coverage is insufficient.
3. When `#245` introduces Person -> Image production Relation migration, add target/cardinality/backlink/delete/detach/idempotency coverage before legacy `profilePhotoId` retirement.
4. Watch for explicit `Related images` population, batch Relation writes, or new Relation Property creation paths and add focused regressions only where existing canonical lifecycle tests do not cover the workflow.
5. Audit actual changes touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, integrity or reconcile behavior.
6. Never invent Object merge/dedup Relation rewriting without explicit product policy.

## Risks / sequencing notes
- Legacy `bookmark_photos` remains compatibility data during #245 migration; Relation tests do not authorize destructive legacy-table cleanup.
- After Relation-safe deletion of a canonical Image, a stale legacy Photo mapping may require Object-owned migration policy before another bridge sync; do not repair that ambiguity inside Relation services.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Presentation-only resolver work is not a Relation trigger unless its diff starts writing Relation state.

## Stop reason
A new Relation-producing workflow existed, so this run added focused lifecycle coverage on latest main. After the PR is opened, no further independent Relation implementation is safe/necessary until CI feedback arrives or Object lane introduces another real Relation-producing Bookmark/Image or Person/Image path. Avoid speculative abstractions and duplicate generic lifecycle tests.
