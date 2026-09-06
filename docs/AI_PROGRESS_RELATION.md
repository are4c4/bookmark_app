# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional Relation integrity, Relation write validation, target/cardinality constraints, stale/inconsistent metadata handling, deterministic index reconciliation, Relation-safe deletion/detach, Relation picker candidate/selection behavior, and focused regressions for Object-owned workflows that consume the canonical Relation boundary.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink Object + managed Image workflow

Cross-lane coordination:
- `#225` — Refactor lane maintainability/legacy cleanup; Relation lane does not co-own unrelated refactors.
- `#245` — legacy Photo -> Image consolidation; Relation owns lifecycle correctness once Bookmark/Image or Person/Image migration becomes a real Relation-producing workflow.

`#166` alias-aware Relation picker is complete/closed.

## Current checkpoint
Latest audited `main`: `49282154dbc6bc5db5e403d2902fa94d5e0d13fd` — PR #369 `Refresh Refactor and repository handoff after current convergence`.

Latest Relation implementation merge on `main`: `6a14c778602bdb89d51e53dfe9206f10199213a8` — PR #307 `Cover Relation lifecycle for direct Weblink enrichment`.

The production path protected by #307 remains:

`GenericDatabaseObjectCreateService.createWeblinkFromUrl()`
→ `WeblinkCreateEnrichmentService`
→ `WeblinkPreviewImagePipeline.ingestIfMissing()`
→ canonical `RelationMutationService.setRelation(...)`
→ `Weblink -> Representative image -> Image`.

The canonical Relation subsystem remains mature. Independent Relation implementation work is intentionally idle unless a new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression appears.

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
- `#351` indirectly exercises canonical target ObjectType validation during Board grouped-preset failure and confirms cleanup failure does not replace the original Relation validation error; it does not change Relation semantics.

## Latest repository audit — 2026-09-06 15:12 JST
The Relation lane re-read `AGENTS.md`, Issue #56, Issue #245, repository-wide handoff, this Relation handoff, latest `main`, and current open PR ownership.

Changes since the previous Relation handoff audit:
- `#366` merged the remaining Bookmark person-role Property-add flow onto the shared Property popover. It keeps existing Bookmark person-role persistence and does not create a new generic Relation writer.
- `#367` refreshed Relation handoff only; no production Relation code changed.
- `#368` merged bootstrap/Profile-switch stable failure handling; no Object Relation persistence/index/read semantics changed.
- `#369` refreshed repository/Refactor handoffs only.
- current open `#370` improves Bookmark List description hierarchy and explicitly does not change Relation semantics.

Current `#245` still has not entered Phase 3 production Bookmark -> Image Relation migration or Phase 5 Person -> Image Relation migration. Its contract still requires those future writes to use canonical `RelationMutationService` and canonical Relation reads, with Relation lane owning lifecycle correctness once the Object lane establishes the product schema/workflow.

No new direct serialized-id Relation mutation path, alternate `object_relation_edges` writer, canonical Relation storage/index change, or concrete Relation correctness regression was identified in this run.

## Validation / audit result
- Relation #307 CI remains the latest implementation validation: Analyze + full Test success before merge.
- Current audit found no code slice that would add non-duplicative Relation value beyond existing coverage.
- No production Relation code or tests were changed in this run to avoid speculative abstraction or duplicate lifecycle tests.

## Exact next Relation actions
1. Watch `#245` for the first real Bookmark -> Image or Person -> Image Relation-producing migration/workflow. When it lands, add focused lifecycle coverage for attach/idempotency/backlink/delete/detach and single-cover cardinality semantics.
2. Watch Object work for a genuinely new explicit `Related images` population, retarget, detach, batch Relation mutation, or new Relation Property creation path.
3. Audit any change touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, `RelationIntegrityService`, or reconcile behavior.
4. If an identity change materially changes the Relation target selected by a production workflow, add integration coverage only where the existing lifecycle suite does not already protect it.
5. Do not invent automatic Object merge/dedup Relation rewriting without explicit product policy.
6. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Future Object merge/dedup requires an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` are compatibility-era Bookmark tables, not canonical generic Object Relations.
- `#245` Photo/Image migration must preserve explicit cover semantics and use canonical Relation APIs once it reaches production Relation writes.
- Presentation-only Person chips/person-role popovers must not be mistaken for generic Relation migration; current Bookmark person-role persistence remains a compatibility path.

## Stop reason
The active Relation lane currently has no remaining independent actionable implementation work. Latest merged and open Object/Refactor work preserves canonical Relation semantics, and `#245` has not yet entered the production Bookmark/Image or Person/Image Relation migration phase. Stop to avoid duplicate lifecycle coverage or crossing into presentation/refactor ownership. Resume immediately when a new Relation-producing workflow, Relation storage/index change, or concrete correctness regression appears.
