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
Latest audited `main`: `a566ae28516b0ee46639666465e6ffad9cebb1e4` — #362 `Preserve profile restore failure during cleanup`.

Latest Relation implementation merge on `main`: `6a14c778602bdb89d51e53dfe9206f10199213a8` — PR #307 `Cover Relation lifecycle for direct Weblink enrichment`.

That regression protects the production path:

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

## Latest repository audit — 2026-09-06 14:37 JST
Latest `main`, current issues and open PRs were re-audited.

Recent merged Object/Refactor changes relevant to Relation boundaries:
- `#344` — Bookmark opening-mode convergence; presentation-only, no Relation mutation.
- `#346/#349/#350` — shared Property-add popover and Bookmark person-role UX convergence. Relation/computed Property creation remains on existing canonical/advanced paths; no new Relation persistence path was introduced.
- `#351` — rollback/failure-policy coverage around Board grouped preset creation. It triggers existing canonical Relation target-type validation but does not alter mutation/index/backlink behavior.
- `#352/#354` — Bookmark List readability and one-Person-per-chip presentation; no Relation persistence changes.
- `#358` — Image-import rollback cleanup; no Relation persistence changes.
- `#360` — Bookmark List URL metadata now routes through the read-only canonical URL resolver; no Relation write/index change.
- `#362` — profile restore cleanup preserves the primary failure; profile/backup-only and unrelated to Relation semantics.

Current open non-Relation PRs:
- `#363` — ProfileManager diagnostic privacy rebuilt from current main; explicitly no Object/Relation behavior change and supersedes stale #357.
- `#355` — stable bootstrap failure boundary.
- `#336` — attachment failure handling.

These open Refactor PRs do not touch Relation persistence, `ObjectStore`, normalized edges, backlink semantics, or the canonical mutation/read services.

Issue `#245` still has not reached the first production Bookmark -> Image or Person -> Image Relation migration slice. Phase 3 remains the explicit trigger for Relation lifecycle ownership; no speculative Bookmark/Image Relation schema or migration should be invented in this lane before Object owns that product contract.

The current default-branch call-site audit still shows feature Relation writes going through canonical `RelationMutationService` boundaries (`ObjectRelationEditorService`, Bookmark/Weblink bridge, Weblink preview pipeline, Tag bridge, Board grouped creation and value-promotion execution). No new direct serialized-id Relation mutation path or alternate `object_relation_edges` writer was found.

## Exact next Relation actions
1. Watch `#245` for the first real Bookmark -> Image or Person -> Image Relation-producing migration/workflow. When it lands, add focused lifecycle coverage for attach/idempotency/backlink/delete/detach and cover-cardinality semantics.
2. Watch Object work for a genuinely new explicit `Related images` population, retarget, detach, batch Relation mutation, or new Relation Property creation path.
3. Audit any change touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, `RelationIntegrityService`, or reconcile behavior.
4. If an identity change materially changes the Relation target chosen by a production workflow, add integration coverage only where the existing lifecycle suite does not already protect it.
5. Do not invent automatic Object merge/dedup Relation rewriting without explicit product policy.
6. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Future Object merge/dedup requires an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` are compatibility-era Bookmark tables, not canonical generic Object Relations.
- `#245` Photo/Image migration must preserve explicit cover semantics and use canonical Relation APIs once it reaches production Relation writes.
- Presentation-only Person chips/person-role popovers must not be mistaken for generic Relation migration; current Bookmark person-role persistence remains a compatibility path.

## Validation / audit result
No production Relation change was made in this run because the latest Object/Refactor changes do not introduce a new Relation-producing workflow or canonical Relation storage/index change. `#362` was reviewed directly and only changes profile-backup cleanup failure handling. The current `setRelation(` call-site audit found no new low-level product writer. The correct Relation-lane action was to refresh and integrate this durable handoff rather than add speculative code or duplicate tests.

## Stop reason
The active Relation lane currently has no remaining independent actionable implementation work. Latest merged/open Object and Refactor changes preserve canonical Relation semantics, and `#245` has not yet entered the production Bookmark/Image or Person/Image Relation migration phase. Stop to avoid duplicate lifecycle coverage or crossing into presentation/refactor ownership. Resume immediately when a new Relation-producing workflow, Relation storage/index change, or concrete correctness regression appears.
