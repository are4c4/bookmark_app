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

## Current checkpoint — 2026-09-06 19:09 JST
Latest `main` audited: `853d5839d46ccdd2d40183a1c5074b961945a3f4` — Object `#418 Cover Bookmark reverse lookup through canonical Image backlinks`.

Latest production Relation-producing Object workflow remains Object `#387`:
- system Bookmark `Cover Image` is a **single Relation** targeting canonical Image Objects;
- `CoreObjectBridge` mirrors legacy `bookmark_photos.is_cover` through canonical `RelationMutationService.setRelation(...)`;
- Bookmark `Images` remains a multi-Relation in parallel during migration;
- Object `#391` consumes canonical `Cover Image` in presentation before legacy explicit-cover fallback.

Relation lifecycle coverage for this workflow is already merged in `#403`.

## Completed Relation slice — #403
Merged to `main` as `c8f00b25f38e6bc3523fba524798b1f7200f326a`.

`test/core_object_bridge_bookmark_cover_relation_lifecycle_test.dart` exercises the real compatibility write path and proves:
- `Cover Image` targets the canonical system Image ObjectType and is single-cardinality;
- initial attach resolves through canonical outgoing Relation reads;
- normalized Relation edges contain exactly one cover edge;
- cover backlinks resolve exactly once;
- repeated `CoreObjectBridge.syncAll(...)` is idempotent;
- retarget moves the cover edge/backlink while preserving Bookmark `Images`;
- Relation-safe Image deletion detaches both `Cover Image` and the matching `Images` entry while preserving surviving Images;
- workspace Relation integrity remains healthy across attach/retry/retarget/delete.

No production Relation code, schema, Object identity, presentation, filesystem policy, or alternate edge/index path changed in #403.

## Stable Relation coverage on main
Important guardrails include:
- `#174–#177`, `#182/#184/#188` — Bookmark -> Weblink integrity, retarget/detach/delete/idempotency/reconcile.
- `#190/#192`, `#198/#201`, `#208/#210/#211/#216/#222/#273/#307` — Weblink -> Image target/cardinality, lifecycle, real-host and direct-enrichment coverage.
- `#195/#200/#202` — alias-aware Relation candidate/picker behavior.
- `#264/#266/#271/#280` — canonical Relation bootstrap remains separate from compatibility-era Bookmark relation-like tables across historical migrations.
- `#351` — target ObjectType validation during Board grouped creation while preserving the original Relation validation failure.
- `#403` — real Bookmark `Cover Image` attach/retry/retarget/backlink/index/delete/integrity lifecycle while preserving `Images` multi-Relation.
- `#418` — Object-owned tests-only real generic Images host coverage proving legacy Bookmark cover mirroring yields canonical `Images` + `Cover Image` backlinks and that both semantic backlink labels render through the shared Object detail path.

## Latest repository audit
Recent Object/Refactor work was classified as follows:
- `#409` / `#415` — Image title/Note editing boundaries; no Relation writes.
- `#413` — managed Image physical-file cleanup after canonical deletion. Final merged implementation retains `RelationMutationService.deleteObject(...)` as the canonical deletion path and performs filesystem cleanup only after successful canonical deletion. Existing page-services Relation-safe deletion coverage remains the appropriate lifecycle guard; no duplicate Relation regression needed.
- `#416` open — canonical Image detail preview presentation only; no Relation behavior.
- `#417` — dead Saved View duplication shim removal; no Relation behavior.
- `#418` — tests-only canonical Image backlink/reverse-lookup parity. Changed file is only `test/image_bookmark_backlink_host_test.dart`; it introduces no production Relation writer, schema, index, or lifecycle change. It usefully confirms the already-covered `Images` + `Cover Image` edges are sufficient for generic reverse lookup.
- `#419` open — Bookmark FTS projection deduplication; explicitly no Object/Relation change.

No new direct serialized-id writer, alternate `object_relation_edges` writer, canonical Relation service bypass, or new Relation-producing workflow was identified after #403.

## Validation / CI notes
- `#403` passed Flutter CI `#1457`: Drift generation success, Analyze success, full Test success before merge.
- Earlier equivalent stale PR `#399` passed Flutter CI `#1447` (Analyze + full Test).
- `#413` replaced failed/stale `#402` and merged after narrowing the redundant hanging host+filesystem harness. Its product contract still delegates Object deletion through canonical Relation-safe deletion before best-effort file cleanup.
- `#418` is merged and tests-only; no production Relation code changed.

## Exact next Relation actions
1. If Object adds a distinct user-facing Bookmark `Cover Image` / `Images` editor-write path beyond the compatibility bridge, cover that real host boundary only where generic Relation editor coverage is insufficient.
2. When `#245` introduces Person -> Image production Relation migration, add target ObjectType/cardinality/backlink/delete/detach/retarget/retry/idempotency coverage before legacy `profilePhotoId` retirement.
3. Watch for explicit Weblink `Related images` population, batch Relation writes, or genuinely new Relation Property creation paths and add focused regressions only where existing canonical lifecycle tests do not already protect them.
4. Audit actual changes touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, integrity or reconcile behavior.
5. Never invent Object merge/dedup Relation rewriting without explicit product policy.

## Risks / sequencing notes
- Legacy `bookmark_photos` remains compatibility data during `#245`; Relation tests do not authorize destructive legacy-table cleanup.
- After Relation-safe deletion of a canonical Image, any stale legacy Photo -> Image mapping requires Object-owned migration policy before another bridge sync; do not repair that ambiguity inside Relation services.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Presentation-only resolver, diagnostics, preview, reverse-lookup rendering, or filesystem cleanup work is not a Relation trigger unless its actual diff starts writing Relation state or bypassing canonical lifecycle APIs.
- Person profile Image migration remains deferred until Object lane establishes the first-class Person/Image product contract.

## Stop reason
Latest main through #418 and open #416/#419 were audited. #413 preserves canonical Relation-safe delete ordering, and #418 is tests-only confirmation of existing canonical Image backlinks rather than a new write path. No new Relation-producing workflow, Relation storage/index change, or concrete correctness regression is currently present. Additional Relation changes would duplicate existing coverage or cross into Object/Refactor ownership. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, explicit Related-images writes, Relation storage/index/service changes, or a concrete lifecycle correctness regression.
