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

## Current checkpoint — 2026-09-06 17:40 JST
Latest audited `main`: `c8f00b25f38e6bc3523fba524798b1f7200f326a` — Relation PR `#403 Cover Bookmark Cover Image Relation lifecycle from latest main`.

Latest production Relation-producing Object workflow:
- Object `#387` merged as `5a3cab0847664f2e2a7579dfa6de801223b0d4d5` and added system Bookmark `Cover Image` as a **single Relation** targeting canonical Image Objects.
- `CoreObjectBridge` mirrors legacy `bookmark_photos.is_cover` through canonical `RelationMutationService.setRelation(...)`.
- Bookmark `Images` remains a multi-Relation in parallel during migration.
- Object-side coverage proves schema/cardinality, attach, retarget, detach, multi-Image preservation, and fail-closed handling for ambiguous/missing cover mapping.
- Object `#391` consumes canonical Bookmark `Cover Image` in the real presentation read path before legacy explicit-cover fallback.

This was the first real `#245` Bookmark -> Image Relation-producing workflow and triggered the Relation work completed in `#403`.

## Completed Relation slice — #403
Merged to `main` as `c8f00b25f38e6bc3523fba524798b1f7200f326a`.

Added `test/core_object_bridge_bookmark_cover_relation_lifecycle_test.dart`, exercising the real `CoreObjectBridge` compatibility write path. It proves:
- `Cover Image` targets the canonical system Image ObjectType and is single-cardinality;
- initial attach resolves through canonical outgoing Relation reads;
- normalized Relation edges contain exactly one cover edge;
- cover backlinks resolve exactly once;
- repeated `CoreObjectBridge.syncAll(...)` is idempotent and does not duplicate Relation/index/backlink state;
- retarget moves the single cover edge/backlink from Image A to Image B while preserving Bookmark `Images`;
- Relation-safe deletion of Image B through `RelationMutationService.deleteObject(...)` detaches both `Cover Image` and the matching `Images` entry while preserving Image A;
- workspace Relation integrity remains healthy across attach/retry/retarget/delete.

No production Relation code, schema, Object identity, presentation, filesystem policy, or alternate edge/index path changed in #403.

## Validation / superseded attempts
- `#386` covered the earlier Bookmark `Images` multi-Relation contract and passed Flutter CI `#1412`, but became stale when #387 introduced the stronger `Cover Image` contract.
- `#398` was the first Cover Image lifecycle refresh but became stale after Object #396 advanced main.
- `#399` carried the correct Cover Image lifecycle regression and passed Flutter CI `#1447` (Analyze + full Test), but later main movement made it non-mergeable. It was closed in favor of a clean replay.
- `#403` latest-main replay passed Flutter CI `#1457`: Drift generation **success**, Analyze **success**, full Test **success**; then merged as `c8f00b25f38e6bc3523fba524798b1f7200f326a`.

## Stable Relation coverage on main
Important guardrails include:
- `#174–#177`, `#182/#184/#188` — Bookmark -> Weblink integrity, retarget/detach/delete/idempotency/reconcile.
- `#190/#192`, `#198/#201`, `#208/#210/#211/#216/#222/#273/#307` — Weblink -> Image target/cardinality, lifecycle, real-host and direct-enrichment coverage.
- `#195/#200/#202` — alias-aware Relation candidate/picker behavior.
- `#264/#266/#271/#280` — canonical Relation bootstrap remains separate from compatibility-era Bookmark relation-like tables across historical migrations.
- `#351` — target ObjectType validation during Board grouped creation while preserving the original Relation validation failure.
- `#403` — real Bookmark `Cover Image` attach/retry/retarget/backlink/index/delete/integrity lifecycle while preserving `Images` multi-Relation.

## Latest repository audit
Recent Object/Refactor work was classified as follows:
- `#387` — **Relation trigger**: production Bookmark `Images` + `Cover Image` canonical Relation mirror; now covered by #403.
- `#391` — read-side product consumption of canonical Bookmark cover Relation; no new write semantics.
- `#394` — legacy Photo physical-file deletion ownership policy; read-only with respect to canonical Relation state.
- `#396` — missing legacy Photo file promotion guard; no Relation persistence/schema change.
- `#400` — backup service composition refactor; no Relation behavior.
- `#401` — resolver presentation architecture guard; tests-only, no Relation behavior.
- open Refactor `#404` — remote Image dimension-probe diagnostic privacy; no Weblink/Image Relation behavior.
- open Object `#402` — managed Image filesystem cleanup after canonical deletion. It wraps page-services `RelationMutationService` with an Object-owned cleanup adapter but calls `super.deleteObject(...)` before any physical file deletion.

`#402` was audited specifically because it changes the page-services deletion composition boundary. Existing `test/generic_database_page_services_test.dart` already exercises `services.relationMutations.deleteObject(...)` with an incoming Relation and asserts the surviving source is detached. Therefore the #402 adapter remains covered by the existing canonical Relation-safe deletion regression when it replaces the service implementation; adding a duplicate Relation test is not justified unless the actual merged semantics diverge.

No new direct serialized-id writer, alternate `object_relation_edges` writer, or canonical Relation service bypass was identified.

## Exact next Relation actions
1. Re-audit Object `#402` after merge only if its final diff changes the `super.deleteObject(...)` ordering or bypasses canonical Relation-safe deletion; otherwise existing page-services deletion coverage is sufficient.
2. If Object adds a distinct user-facing Bookmark `Cover Image` / `Images` editor-write path beyond the compatibility bridge, cover that real host boundary only where generic Relation editor coverage is insufficient.
3. When `#245` introduces Person -> Image production Relation migration, add target/cardinality/backlink/delete/detach/idempotency coverage before legacy `profilePhotoId` retirement.
4. Watch for explicit `Related images` population, batch Relation writes, or genuinely new Relation Property creation paths and add focused regressions only where existing canonical lifecycle tests do not already protect them.
5. Audit actual changes touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, integrity or reconcile behavior.
6. Never invent Object merge/dedup Relation rewriting without explicit product policy.

## Risks / sequencing notes
- Legacy `bookmark_photos` remains compatibility data during `#245`; Relation tests do not authorize destructive legacy-table cleanup.
- After Relation-safe deletion of a canonical Image, any stale legacy Photo -> Image mapping requires Object-owned migration policy before another bridge sync; do not repair that ambiguity inside Relation services.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Presentation-only resolver, diagnostics, or filesystem cleanup work is not a Relation trigger unless its actual diff starts writing Relation state or bypassing canonical lifecycle APIs.
- Person profile Image migration remains deferred until Object lane establishes the first-class Person/Image product contract.

## Stop reason
Relation #403 is merged and green. Current open #402/#404 do not introduce an uncovered Relation-producing workflow or change canonical Relation persistence/index semantics; #402's deletion adapter still delegates to `RelationMutationService.deleteObject(...)` and is already exercised by the existing page-services Relation-safe deletion regression. No further independent Relation implementation is currently justified without duplicating coverage or crossing into Object/Refactor ownership. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, Relation storage/index changes, or a concrete lifecycle correctness regression.
