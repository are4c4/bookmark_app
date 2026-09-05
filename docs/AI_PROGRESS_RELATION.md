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
Latest Relation merge on `main`: `6a14c778602bdb89d51e53dfe9206f10199213a8` — PR #307 `Cover Relation lifecycle for direct Weblink enrichment`.

Object PR #303 `Enrich Weblinks created from the generic collection` is also merged. It introduced the new production Relation-producing path that triggered this Relation-lane run:

`GenericDatabaseObjectCreateService.createWeblinkFromUrl()`
→ `WeblinkCreateEnrichmentService`
→ `WeblinkPreviewImagePipeline.ingestIfMissing()`
→ canonical `RelationMutationService.setRelation(...)`
→ `Weblink -> Representative image -> Image`.

The canonical Relation subsystem itself remains mature; #307 adds integration protection for this newly exposed workflow rather than redesigning Relation internals.

## Checkpoint completed in this run
Merged #307 adds `test/generic_database_weblink_create_enrichment_relation_test.dart`.

The regression exercises the real page-services creator plus the real preview pipeline with deterministic in-memory DB, mock HTTP response, and temporary managed image storage. It proves:
- normalized-equivalent direct URL creations reuse one canonical Weblink Object;
- metadata enrichment supplies the preview URL;
- the real preview pipeline creates exactly one managed Image;
- exactly one `Representative image` Relation is attached through the canonical mutation boundary;
- repeating the same direct creation/enrichment does not redownload, duplicate the Image, or duplicate the Relation;
- `RelationReadService.outgoing(...)` resolves exactly one Representative Image;
- normalized `object_relation_edges` contains exactly one matching edge;
- `RelationReadService.backlinks(...)` resolves exactly one matching backlink;
- `RelationIntegrityService.auditWorkspace(...)` remains healthy.

Existing lower-level pipeline lifecycle coverage already proves replacement, deterministic index reconciliation, and Relation-safe Image deletion, so #307 intentionally covers only the new composition-root boundary.

An earlier stacked PR #305 was closed unmerged after #303 merged because retargeting exposed Object-lane commits through the old merge base. The test was replayed cleanly from latest `main` as #307, preserving lane ownership.

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

## Latest repository audit
After #307 merge, open work was re-audited:
- #304 Refactor — Stage1 canonical visual presentation cleanup; no Relation persistence/mutation semantics.
- #306 Object — managed Image source URL identity normalization; changes Object reuse semantics only and introduces no new Relation write/index path.

The default Relation mutation call-site audit still shows feature writes going through canonical `RelationMutationService` paths such as Relation editor, Bookmark/Weblink bridge, preview Image pipeline, Tag bridge and value-promotion execution. No new direct serialized-id write path or alternate relation index was found.

No new independent Relation-producing workflow is currently open beyond the now-covered #303 path.

## Validation
- Object dependency #303 CI run #1196: **success**.
- Relation #307 CI run #1203: **success**.
  - Drift generation: success.
  - Analyze: success.
  - Full Test: success.
- #307 merged to `main` as `6a14c778602bdb89d51e53dfe9206f10199213a8`.

Relevant existing lower-level regressions:
- `test/weblink_preview_image_pipeline_relation_lifecycle_test.dart`
- `test/generic_database_page_services_relation_create_integration_test.dart`

## Exact next Relation actions
1. Monitor Object work for the next genuinely new Relation-producing flow, especially explicit `Related images` population or a new attach/retarget/detach path.
2. Watch #245 for the first real legacy Photo -> Bookmark/Image Relation migration slice; add lifecycle/idempotency/backlink/delete coverage when that production workflow exists.
3. Audit future changes to Image/Weblink identity when they materially change the Relation target selected by a production Relation workflow; do not add duplicate tests for identity-only changes without an integration risk.
4. Audit any change that moves persisted Relation values, `object_relation_edges`, `ObjectStore`, or the canonical Relation service boundary.
5. Do not invent automatic Object merge/dedup Relation rewriting without an explicit product policy.
6. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Future Object merge/dedup requires an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` are compatibility-era Bookmark tables, not canonical generic Object Relations.
- #245 Photo/Image migration must preserve explicit cover semantics and use canonical Relation APIs once it reaches production Relation writes.

## Stop reason
This run resumed because #303 introduced a genuine new Relation-producing workflow. The required focused lifecycle/idempotency/backlink/index/audit regression was implemented, passed full CI, and merged as #307. Subsequent open PRs #304/#306 do not add or move Relation persistence/mutation semantics, and no additional independent Relation slice is currently justified without duplicating existing coverage or entering another lane's ownership. Resume when a new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression appears.
