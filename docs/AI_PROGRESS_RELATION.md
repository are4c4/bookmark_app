# AI Progress — Relation Lane

> Durable handoff for the Relation implementation lane. Update this file before every Relation-lane run ends.

## Lane scope
Own Relation/backlink lifecycle, bidirectional Relation integrity, Relation write validation, target/cardinality constraints, stale/inconsistent metadata handling, deterministic index reconciliation, Relation-safe deletion/detach, Relation picker candidate/selection behavior, and focused regressions for Object-owned workflows that consume the canonical Relation boundary.

Primary issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink Object + managed Image workflow

Cross-lane coordination:
- `#225` — Refactor lane maintainability/legacy cleanup; Relation lane does not co-own unrelated refactors.
- `#245` — legacy Photo -> Image consolidation; Relation lane owns lifecycle correctness once Bookmark/Image or Person/Image migration becomes a real Relation-producing production workflow.

`#166` alias-aware Relation picker is complete/closed.

## Current goal / active work
A new Relation-producing Object workflow appeared in open Object PR **#303 `Enrich Weblinks created from the generic collection`**.

#303 changes direct generic Weblink creation from identity-only creation into:

`GenericDatabaseObjectCreateService.createWeblinkFromUrl()`
→ `WeblinkCreateEnrichmentService`
→ existing `WeblinkPreviewImagePipeline.ingestIfMissing()`
→ canonical `RelationMutationService.setRelation(...)`
→ `Weblink -> Representative image -> Image`.

This satisfies the Relation-lane resume condition because a newly exposed user-facing creation flow now produces a canonical Relation.

Active Relation branch / PR:
- branch: `test/relation-weblink-create-enrichment-155`
- stacked base: `feature/object-weblink-create-enrichment-155` (Object PR #303)
- PR **#305 `Cover Relation lifecycle for direct Weblink enrichment`**
- latest Relation commit: `c3b3be2ccfbcdc97d976984e3fa78d946b5c49d0`

#305 is tests-only. It deliberately does not modify #303 production code or any shared UI hotspot.

## Checkpoint completed in this run
Added `test/generic_database_weblink_create_enrichment_relation_test.dart` exercising the new #303 composition-root path with deterministic in-memory DB + mock remote image storage.

The regression proves:
- two normalized-equivalent direct Weblink creations reuse one canonical Weblink Object;
- enrichment metadata supplies a preview URL;
- the real `WeblinkPreviewImagePipeline` creates one managed Image and attaches it as `Representative image`;
- the second enrichment is Relation-idempotent and does not re-download/create/attach a duplicate;
- canonical `RelationReadService.outgoing(...)` resolves exactly one Representative Image;
- normalized `object_relation_edges` contains exactly one corresponding edge;
- canonical `RelationReadService.backlinks(...)` resolves exactly one backlink from the Image;
- `RelationIntegrityService.auditWorkspace(...)` remains healthy.

Existing pipeline-specific coverage already proves replacement, deterministic index reconcile and Relation-safe Image deletion. #305 therefore covers only the newly exposed composition-root boundary rather than duplicating all lower-level pipeline cases.

## Canonical Relation contract
- `RelationMutationService` is the feature-facing mutation boundary.
- `RelationReadService` resolves canonical outgoing/backlink state.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs only deterministic index drift from persisted Relation values.
- `RelationMutationService.deleteObject(...)` detaches surviving sources before target deletion.
- ambiguous missing-target/cardinality/bidirectional corruption is never auto-repaired from editor paths.
- no feature may introduce its own serialized-id Relation path or alternate edge/index store.
- low-level `ObjectStore.setRelation` is storage-internal/test-facing, not a normal product mutation path.

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

Latest Relation merge on `main` remains `f01597fb596e03b7f19ab56048c84d4a55f8810d` (#280). Relation implementation itself has not needed redesign since then; recent work has been integration guardrails for newly exposed product flows.

## Latest repository audit
Latest observed `main` before this Relation slice: `61b90b4132452f5cbecf9334b0e35131bf62f9bc`.

Recent Object/Refactor changes through #288–#304 were audited. Presentation/default/title/read-store/legacy-visual changes do not change Relation persistence semantics. The material new Relation boundary is #303 only, because its direct Weblink creation enrichment delegates to the production preview pipeline.

Open PR ownership at this checkpoint:
- #303 Object — Weblink create enrichment; owns the production workflow this regression is stacked on.
- #304 Refactor — Stage1 visual resolver cleanup; no Relation semantics.
- #305 Relation — tests-only lifecycle guardrail for #303.

No Relation edits should be made to `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, or #303 production files while those lanes own them.

## Validation
Local tool execution is not available through the GitHub connector in this chat, so validation is delegated to the repository PR CI.

Expected targeted coverage in #305:
- `test/generic_database_weblink_create_enrichment_relation_test.dart`

Relevant lower-level green coverage already exists in:
- `test/weblink_preview_image_pipeline_relation_lifecycle_test.dart`
- `test/generic_database_page_services_relation_create_integration_test.dart`

CI for #305 should be checked and any compile/test failure fixed before integration.

## Exact next Relation actions
1. Check #305 CI and fix any regression caused by the new test.
2. Monitor #303 integration. Once #303 merges, retarget #305 from `feature/object-weblink-create-enrichment-155` to `main` and refresh from latest main if necessary.
3. Merge #305 after relevant CI passes and the stacked dependency is integrated.
4. Re-audit subsequent Object work for additional Relation-producing workflows, especially explicit `Related images` population.
5. Watch #245 for the first real legacy Photo -> Bookmark/Image Relation migration slice; add lifecycle/backlink/delete/idempotency coverage only when that production workflow exists.
6. Do not invent Object merge/dedup Relation rewriting without an explicit product policy.
7. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- #305 is intentionally stacked on #303; merging it before #303 would pull Object production changes into a Relation PR and violate lane ownership.
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Future Object merge/dedup requires an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` are not canonical generic Object Relations.
- #245 Photo/Image migration must preserve explicit cover semantics and use canonical Relation APIs when it reaches production Relation writes.

## Stop reason
This run resumed because #303 introduced a genuine new Relation-producing workflow. The focused Relation regression is implemented and opened as stacked PR #305. Further integration is currently sequenced behind Object PR #303 and #305 CI; no second independent Relation implementation slice is justified at this exact checkpoint without duplicating existing pipeline lifecycle coverage or entering Object/Refactor-owned production files.
