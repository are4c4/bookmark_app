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

## Current checkpoint — 2026-09-06 18:09 JST
Latest `main` audited: `66464b8e83cf7787dcf26b3318be2166286ffd12` — Refactor `#407 Refresh Refactor handoff after resolver and privacy convergence`.

Latest production Relation-producing Object workflow remains Object `#387`, which added system Bookmark `Cover Image` as a **single Relation** targeting canonical Image Objects. `CoreObjectBridge` mirrors legacy `bookmark_photos.is_cover` through canonical `RelationMutationService.setRelation(...)`, while Bookmark `Images` remains a multi-Relation during migration. Object `#391` consumes canonical `Cover Image` in presentation before legacy explicit-cover fallback.

Relation lifecycle coverage for that workflow is already merged in `#403` as `c8f00b25f38e6bc3523fba524798b1f7200f326a` and passed Flutter CI `#1457`.

## Completed Relation slice — #403
`test/core_object_bridge_bookmark_cover_relation_lifecycle_test.dart` exercises the real `CoreObjectBridge` compatibility write path and proves:
- `Cover Image` targets the canonical system Image ObjectType and is single-cardinality;
- initial attach resolves through canonical outgoing Relation reads;
- normalized Relation edges contain exactly one cover edge;
- cover backlinks resolve exactly once;
- repeated `CoreObjectBridge.syncAll(...)` is idempotent and does not duplicate Relation/index/backlink state;
- retarget moves the single cover edge/backlink from Image A to Image B while preserving Bookmark `Images`;
- Relation-safe deletion through `RelationMutationService.deleteObject(...)` detaches both `Cover Image` and the matching `Images` entry while preserving unrelated Images;
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

## Latest repository audit
Fresh audit after `main` `66464b8e...`:

- `#406` merged — generic Weblink enrichment diagnostic privacy cleanup. It explicitly preserves Weblink creation and Relation semantics; no Relation trigger.
- `#407` merged — Refactor docs-only handoff refresh; no Relation behavior.
- open `#408` — delegates **legacy Bookmark `bookmark_relations`** backlink reads through `BookmarkRepository.watchRelationsForBookmark(...)`. This is the old Bookmark relation-like subsystem, not canonical Object Relation storage/index. The PR explicitly preserves mutation/backlink semantics and does not touch `object_relation_edges`, `RelationMutationService`, `RelationReadService`, integrity, or reconcile behavior. No Relation-lane implementation is justified.
- open `#409` — allows Image title/Note editing in shared Object detail while keeping Image identity/provenance read-only. No Relation mutation or schema change.
- open `#410` — deduplicates Bookmark FTS projection. Search-only; no Relation behavior.
- open Object `#402` — canonical Image deletion/file cleanup adapter. Final audited production patch still computes optional file-cleanup ownership first, then calls `await super.deleteObject(...)`, and only after successful canonical Relation-safe Object deletion attempts best-effort physical file cleanup. It does not bypass canonical Relation lifecycle.

### #402 CI audit
Flutter CI `#1469` for open `#402` completed with Analyze success and Test failure. The failure is **not a Relation correctness failure**:
- 695 tests passed;
- canonical Relation tests, including `core_object_bridge_bookmark_cover_relation_lifecycle_test`, `relation_object_delete_lifecycle_test`, `generic_database_page_services_test` Relation-safe deletion, Weblink/Image Relation lifecycle, integrity and reconcile tests all passed;
- the only failure was `generic_database_image_delete_file_host_test.dart`, which timed out after 10 minutes in the Object-owned real Images host filesystem-cleanup test.

Therefore Relation lane must not patch production Relation semantics or add duplicate lifecycle coverage in response to #402 CI. Re-audit only if Object changes the deletion adapter ordering, stops delegating to `super.deleteObject(...)`, or a canonical Relation test starts failing.

No new direct serialized-id Relation writer, alternate `object_relation_edges` writer, or canonical Relation service bypass was identified in this audit.

## Exact next Relation actions
1. Re-audit Object `#402` only if its implementation changes after the current host-test timeout fix; verify `super.deleteObject(...)` remains the canonical lifecycle boundary before filesystem cleanup.
2. If Object adds a distinct user-facing Bookmark `Cover Image` / `Images` editor-write path beyond the compatibility bridge, cover that real host boundary only where generic Relation editor coverage is insufficient.
3. When `#245` introduces Person -> Image production Relation migration, add target/cardinality/backlink/delete/detach/retry/idempotency coverage before legacy `profilePhotoId` retirement.
4. Watch for explicit `Related images` population, batch Relation writes, or genuinely new Relation Property creation paths and add focused regressions only where existing canonical lifecycle tests do not already protect them.
5. Audit actual changes touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, integrity or reconcile behavior.
6. Never invent Object merge/dedup Relation rewriting without explicit product policy.

## Risks / sequencing notes
- Legacy `bookmark_photos` and legacy `bookmark_relations` remain compatibility data during migration; canonical Relation tests do not authorize destructive legacy-table cleanup.
- After Relation-safe deletion of a canonical Image, stale legacy Photo -> Image mapping repair is Object-owned migration policy, not a Relation-service responsibility.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Presentation-only, diagnostics, FTS, legacy Bookmark repository-boundary, or filesystem cleanup work is not a Relation trigger unless the actual diff writes canonical Relation state or bypasses canonical lifecycle APIs.
- Person profile Image migration remains deferred until Object lane establishes the first-class Person/Image product contract.

## Stop reason
No uncovered canonical Relation-producing workflow or concrete Relation correctness regression exists after auditing current `main`, Issues `#56/#245`, open PRs `#402/#408/#409/#410`, and CI `#1469`. The #402 failure is isolated to an Object-owned host filesystem-cleanup test while canonical Relation lifecycle/integrity tests pass. Additional Relation code would duplicate coverage or cross into Object/Refactor ownership. Resume immediately for Person -> Image, a distinct Bookmark Image write/edit producer, Relation storage/index changes, or an actual canonical lifecycle regression.
