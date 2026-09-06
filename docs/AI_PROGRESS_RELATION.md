# AI Progress — Relation Lane

> Durable handoff for Relation/backlink lifecycle and integrity work. Update before every Relation-lane run ends.

## Lane scope
Own canonical Relation mutation/read/index/backlink/audit/reconcile behavior, target ObjectType/cardinality validation, Relation-safe delete/detach/retarget/retry/idempotency, picker candidate/selection behavior, and focused regressions for new Object-owned Relation-producing workflows.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink + managed Image workflow
- `#245` — legacy Photo -> canonical Image convergence

Cross-lane coordination:
- Object lane owns Bookmark/Image and Person/Image product semantics and UI.
- Refactor `#225` owns behavior-preserving cleanup; it must not redesign Relation semantics.
- `#166` alias-aware Relation picker is complete/closed.

## Canonical contract
- Feature writes go through `RelationMutationService`.
- Reads/backlinks use `RelationReadService` / canonical ObjectStore projections.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index drift only.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- Ambiguous damage, missing targets, cardinality conflicts, or stale metadata are not guessed/auto-repaired from editor paths.
- No feature may introduce a parallel serialized-id Relation writer or alternate Relation edge/index store.
- Low-level `ObjectStore.setRelation` remains storage-internal/test-facing rather than a normal product mutation path.

## Current checkpoint — 2026-09-06 17:32 JST
Latest audited `main`: `df1e30d3a6486ef6cdbc0366615e3750cef99d2f` (`#401 Guard Bookmark resolver presentation composition`), after Refactor `#400` and Object `#394`.

Latest merged production Relation-producing Object workflow:
- Object `#387` merged as `5a3cab0847664f2e2a7579dfa6de801223b0d4d5` and added system Bookmark `Cover Image` as a **single Relation** targeting canonical Image Objects.
- `CoreObjectBridge` mirrors legacy `bookmark_photos.is_cover` through the existing canonical `RelationMutationService.setRelation(...)` path.
- The existing Bookmark `Images` multi-Relation remains in parallel during migration.
- Object-side coverage proves schema/cardinality, initial attach, retarget, detach, multi-Image preservation, and fail-closed handling for ambiguous/missing cover mapping.
- Object `#391` consumes canonical Bookmark `Cover Image` in the real presentation read path before the legacy explicit-cover fallback.

This was the first real `#245` Bookmark -> Image Relation-producing production workflow and therefore triggered Relation-lane lifecycle coverage.

## Current Relation implementation slice
Branch: `test/relation-bookmark-cover-image-lifecycle-245-v3`

Added `test/core_object_bridge_bookmark_cover_relation_lifecycle_test.dart` directly from current main. The focused integration regression exercises the real `CoreObjectBridge` compatibility write path and verifies:
- `Cover Image` targets the canonical system Image ObjectType and has single cardinality;
- initial attach resolves through canonical outgoing Relation reads;
- normalized Relation edges contain exactly one cover edge;
- cover backlinks resolve exactly once;
- repeated `CoreObjectBridge.syncAll(...)` is idempotent and does not duplicate Relation/index/backlink state;
- retarget moves the single cover edge/backlink from Image A to Image B while preserving the Bookmark `Images` multi-Relation;
- Relation-safe deletion of Image B through `RelationMutationService.deleteObject(...)` detaches both `Cover Image` and the matching `Images` entry while preserving Image A;
- workspace Relation integrity remains healthy across attach/retry/retarget/delete.

No production Relation code, schema, Object identity, presentation, filesystem policy, or alternate edge/index path is changed by this Relation slice.

## Superseded Relation attempts / validation history
- Relation `#386` (`Cover canonical Bookmark Images mirror lifecycle`) completed Flutter CI `#1412` successfully, but its multi-Relation-only contract became stale when Object `#387` introduced the stronger single `Cover Image` contract.
- Relation `#398` was the first Cover Image lifecycle refresh, but Object `#396` advanced `main` before it could be integrated.
- Relation `#399` replayed the focused Cover Image lifecycle test and handoff. Flutter CI `#1447` completed **successfully** (Analyze + full Test), but subsequent Object/Refactor merges advanced `main` again and made its old-base branch non-mergeable.
- The current v3 branch is a clean replay from latest main rather than force-merging stale Relation branches.

## Stable Relation coverage on main
Important existing guardrails include:
- `#174–#177`, `#182/#184/#188` — Bookmark -> Weblink integrity, retarget/detach/delete/idempotency/reconcile.
- `#190/#192`, `#198/#201`, `#208/#210/#211/#216/#222/#273/#307` — Weblink -> Image target/cardinality, lifecycle, real-host and direct-enrichment coverage.
- `#195/#200/#202` — alias-aware Relation candidate/picker behavior.
- `#264/#266/#271/#280` — canonical Relation bootstrap remains separate from compatibility-era Bookmark relation-like tables across historical migrations.
- `#351` — target ObjectType validation during Board grouped creation while preserving the original Relation validation failure.

## Latest repository audit
Recent work after the previous Relation handoff was classified as follows:
- `#387` — **Relation trigger**: production Bookmark `Images` + `Cover Image` canonical Relation mirror.
- `#391` — read-side product consumption of canonical Bookmark cover Relation; no new write semantics.
- `#394` — legacy Photo physical-file deletion ownership policy; read-only with respect to canonical Relation state.
- `#396` — missing legacy Photo file promotion guard; no Relation persistence/schema change.
- `#400` — backup service composition refactor; no Relation behavior.
- `#401` — resolver presentation architecture guard; tests-only, no Relation behavior.
- open Object `#402` — managed Image filesystem cleanup after successful canonical Relation-safe deletion. It explicitly continues to call `RelationMutationService.deleteObject(...)`; filesystem ownership/cleanup is Object-owned and does not alter Relation persistence semantics.

No new direct serialized-id writer, alternate `object_relation_edges` writer, or Relation service bypass was identified in this audit.

## Exact next Relation actions
1. Validate and integrate the current Cover Image lifecycle regression on latest main; if concurrent merges make the branch stale, replay only this test + handoff from the new main rather than force-merging.
2. If Object adds a distinct user-facing Bookmark `Cover Image` / `Images` editor-write path beyond the compatibility bridge, cover that real host boundary only where generic Relation editor coverage is insufficient.
3. When `#245` introduces Person -> Image production Relation migration, add target/cardinality/backlink/delete/detach/idempotency coverage before legacy `profilePhotoId` retirement.
4. Watch for explicit `Related images` population, batch Relation writes, or genuinely new Relation Property creation paths and add focused regressions only where existing canonical lifecycle tests do not already protect them.
5. Audit actual changes touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, integrity or reconcile behavior.
6. Never invent Object merge/dedup Relation rewriting without explicit product policy.

## Risks / sequencing notes
- Legacy `bookmark_photos` remains compatibility data during `#245`; Relation tests do not authorize destructive legacy-table cleanup.
- After Relation-safe deletion of a canonical Image, any stale legacy Photo -> Image mapping requires Object-owned migration policy before another bridge sync; do not repair that ambiguity inside Relation services.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Presentation-only resolver or filesystem cleanup work is not a Relation trigger unless its actual diff starts writing Relation state or bypassing canonical lifecycle APIs.
- Person profile Image migration remains deferred until Object lane establishes the first-class Person/Image product contract.

## Validation checkpoint
- Previous identical Cover Image lifecycle regression on Relation `#399`: Flutter CI `#1447` **success** (Analyze + full Test).
- Current v3 branch is based on `df1e30d3a6486ef6cdbc0366615e3750cef99d2f`; run its PR CI before merge because current-main integration is the relevant final validation.

## Stop reason
The active Relation slice is the focused lifecycle coverage required by Object `#387`. Once this latest-main replay is integrated and no newer Relation-producing workflow has appeared, the lane returns to the AGENTS stop condition of no remaining independent actionable Relation work. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, Relation storage/index changes, or a concrete lifecycle correctness regression.
