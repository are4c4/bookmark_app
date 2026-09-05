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
Latest observed `main`: `897be7aa620baa261a78c412ec49ebc62b71a267` (Object #303 merged on top of the latest main line).

Latest Relation implementation merge on `main` remains `f01597fb596e03b7f19ab56048c84d4a55f8810d` (#280). The canonical Relation subsystem itself remains mature; current Relation work is focused on new production integration boundaries rather than redesign.

## Active Relation work — direct Weblink create enrichment
Object PR #303 `Enrich Weblinks created from the generic collection` introduced a genuinely new Relation-producing workflow and triggered the Relation lane resume condition.

The new production path is:

`GenericDatabaseObjectCreateService.createWeblinkFromUrl()`
→ `WeblinkCreateEnrichmentService`
→ existing `WeblinkPreviewImagePipeline.ingestIfMissing()`
→ canonical `RelationMutationService.setRelation(...)`
→ `Weblink -> Representative image -> Image`.

#303 is now merged. Its CI run #1196 passed.

Active Relation branch / PR:
- branch: `test/relation-weblink-create-enrichment-155-v2`
- PR **#307 `Cover Relation lifecycle for direct Weblink enrichment`**
- latest Relation code commit: `e9ea6e3c9fd34b97cbe8a19bb9b99ae490f571f1`

An earlier stacked PR #305 was closed unmerged after #303 merged because retargeting exposed Object-lane commits in the diff due the merge-base shape. #307 was replayed cleanly from latest `main` and contains only the Relation regression plus this handoff update.

## Checkpoint completed in this run
Added `test/generic_database_weblink_create_enrichment_relation_test.dart`.

The regression exercises the real page-services creator plus the real preview pipeline with deterministic in-memory DB, mock HTTP response, and temporary managed image storage. It proves:
- normalized-equivalent direct URL creations reuse one canonical Weblink Object;
- metadata enrichment supplies the preview URL;
- `WeblinkPreviewImagePipeline` creates exactly one managed Image;
- the pipeline attaches exactly one `Representative image` Relation through the canonical mutation boundary;
- repeating the same direct creation/enrichment does not redownload, duplicate the Image, or duplicate the Relation;
- `RelationReadService.outgoing(...)` resolves exactly one Representative Image;
- normalized `object_relation_edges` contains exactly one matching edge;
- `RelationReadService.backlinks(...)` resolves exactly one backlink from the Image;
- `RelationIntegrityService.auditWorkspace(...)` remains healthy.

Existing lower-level pipeline lifecycle coverage already proves canonical replacement, index-only reconciliation, and Relation-safe Image deletion. #307 intentionally covers only the newly exposed composition-root path instead of duplicating those cases.

## Canonical Relation contract
- `RelationMutationService` is the feature-facing mutation boundary.
- `RelationReadService` resolves canonical outgoing/backlink state.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs only deterministic index drift from persisted Relation values.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- ambiguous missing-target/cardinality/bidirectional corruption is never auto-repaired from editor paths.
- no feature may introduce its own serialized-id Relation path or alternate edge/index store.
- low-level `ObjectStore.setRelation` remains storage-internal/test-facing rather than a normal product mutation path.

## Stable Relation coverage already on main
Important merged guardrails include:
- `#174–#177` Bookmark/Weblink and Weblink/Image boundary integrity.
- `#182/#184/#188` Bookmark -> Weblink retarget, detach/delete, shared targets and index reconcile.
- `#190/#192` production Weblink -> Image target/cardinality/lifecycle.
- `#195/#200/#202` alias-aware Relation candidate search and real picker.
- `#198/#201` preview pipeline / real ObjectSync retry, replacement, backlink/index/audit and delete lifecycle.
- `#208/#210/#211/#216/#222` exposed Weblink/Image real-host edit/backlink/delete/composite-delete lifecycle.
- `#273` real page-services creation + explicit Relation editor attach for Representative/Related Images.
- `#264/#266/#271/#280` canonical Relation bootstrap remains separate from legacy Bookmark relation-like tables across historical migrations, including real v1 -> current.

## Latest repository audit
Recent Object/Refactor work through #288–#304 was re-audited. Gallery/media/default/title/chip/read-store/legacy visual changes do not change canonical Relation persistence semantics. #303 is the material new Relation boundary because direct user-facing Weblink creation can now produce a managed Representative Image Relation.

Open PR ownership at this checkpoint:
- #304 Refactor — Stage1 visual resolver cleanup; no Relation semantics.
- #307 Relation — tests-only lifecycle guardrail for merged #303.

Relation must continue to avoid broad edits to Object/Refactor-owned shared hotspots.

## Validation
- Object dependency #303 CI run #1196: **success**.
- #307 targets `main`, so normal PR Analyze/Test CI should run from the clean branch.
- Local Flutter execution is not available through the GitHub connector in this chat.

Relevant existing lower-level regressions:
- `test/weblink_preview_image_pipeline_relation_lifecycle_test.dart`
- `test/generic_database_page_services_relation_create_integration_test.dart`

## Exact next Relation actions
1. Check #307 CI and fix any compile/test failure caused by the new regression.
2. Merge #307 after relevant CI passes.
3. Re-audit subsequent Object work for new Relation-producing flows, especially explicit `Related images` population.
4. Watch #245 for the first real legacy Photo -> Bookmark/Image Relation migration slice; add lifecycle/idempotency/backlink/delete coverage only when that production workflow exists.
5. Do not invent automatic Object merge/dedup Relation rewriting without an explicit product policy.
6. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Future Object merge/dedup requires an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` are compatibility-era Bookmark tables, not canonical generic Object Relations.
- #245 Photo/Image migration must preserve explicit cover semantics and use canonical Relation APIs once it reaches production Relation writes.

## Stop reason
This run resumed because #303 introduced a genuine new Relation-producing workflow. The focused composition-root Relation regression is implemented in clean PR #307 and the lane handoff is updated. Continue immediately if #307 CI exposes a failure; otherwise the next safe integration step is merging #307 after green CI. No second independent Relation slice is currently justified without duplicating existing preview-pipeline lifecycle coverage or entering another lane's production ownership.
