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

`#166` alias-aware Relation picker and `#156` generic fixed/masonry Gallery are complete/closed.

## Current checkpoint
Latest genuine Relation-producing integration merge on `main` remains PR #307 `Cover Relation lifecycle for direct Weblink enrichment`.

That regression protects the current production composition path:

`GenericDatabaseObjectCreateService.createWeblinkFromUrl()`
→ `WeblinkCreateEnrichmentService`
→ `WeblinkPreviewImagePipeline.ingestIfMissing()`
→ canonical `RelationMutationService.setRelation(...)`
→ `Weblink -> Representative image -> Image`.

It proves normalized URL reuse, one managed Image, Relation idempotency, canonical outgoing read, normalized edge/backlink uniqueness, and healthy workspace Relation integrity. The canonical Relation subsystem itself remains mature; new Relation work should protect only genuinely new production workflows, storage/index changes, or concrete correctness regressions.

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

## Latest repository audit — 2026-09-06 13:13 JST
Latest observed `main`: `dc496643a200d8eb4c61d3ab9d0a2241b2b394c8` (`Preserve Image import failure during rollback cleanup (#358)`).

Since the previous Relation audit at `399bad597d33de7e35ece5468ebffe010041f71d`, `main` advanced by five commits. The changed production files were limited to Board rollback cleanup, Image-import rollback cleanup, and Bookmark List semantic-chip presentation. No persisted Relation-value schema, `object_relation_edges`, canonical Relation service, or Relation read/index implementation moved.

Cross-lane review:
- **#354 merged — Bookmark List semantic chip width**: presentation only; no Relation persistence/mutation semantics.
- **#358 merged — Image import rollback cleanup**: preserves the original Image import/create failure if managed-file cleanup also fails. The Image import path still creates canonical Image Objects but does not introduce a new Relation-producing workflow.
- **Board rollback cleanup merged in the same interval**: `ObjectBoardCreateService` still writes grouped object-Relation presets through the existing canonical `RelationMutationService.setRelation(...)`. The change only makes orphan-Object cleanup best-effort so a secondary delete failure cannot mask the original preset-write/Relation validation failure. Relation target/cardinality semantics are unchanged and existing Board integration coverage remains the correct protection.
- **#359 open — profile restore cleanup**: Refactor rollback/failure-policy only; explicitly states no Object/Relation behavior changes.
- **#345 open — Relation handoff audit**: this lane artifact has been refreshed from latest `main` rather than spawning another docs-only PR.

The current open/merged work therefore exposes no new independent Relation-producing production path, no direct serialized-id Relation write, and no alternate Relation index implementation.

## Issue #245 trigger status
The legacy Photo -> Image consolidation issue still has not reached its planned production Relation migration phases. Canonical Image import is live, but there is no production Bookmark -> Cover Image / Images Relation migration and no Person -> Image Relation migration yet.

When #245 introduces one of those workflows, Relation lane should immediately add focused coverage for:
- canonical mutation boundary use;
- idempotent mirroring/retry;
- single-cover cardinality and retarget behavior;
- multi-image attach/detach semantics where applicable;
- backlinks/index integrity;
- Relation-safe Image deletion;
- coexistence with legacy `BookmarkPhotos` / `profilePhotoId` until caller-zero.

## Validation / audit result
No production Relation code or Relation regression was changed in this run because no new Relation behavior needs protection. Adding another lifecycle test now would duplicate existing coverage.

The open Relation handoff PR #345 is kept as the durable lane artifact and was rebased-by-reset to latest `main` before this refresh, avoiding stale-base drift.

## Exact next Relation actions
1. Monitor #245 for the first production Bookmark/Image or Person/Image canonical Relation migration.
2. Monitor Object work for new `Related images`, attach/retarget/detach, value-promotion, Board/Property creation, or picker flows that add or materially alter a canonical Relation write.
3. Audit any change touching persisted Relation values, `object_relation_edges`, `ObjectStore`, `RelationMutationService`, `RelationReadService`, reconciliation, audit, deletion or backlink semantics.
4. If Object identity/reuse changes can alter the Relation target selected by a production workflow, add an integration regression only where target selection materially changes.
5. Do not invent automatic Object merge/dedup Relation rewriting without explicit product policy.
6. Keep deterministic index reconciliation separate from ambiguous user-data repair.

## Risks / notes
- Automatic repair of missing targets/cardinality conflicts remains prohibited.
- Future Object merge/dedup requires an explicit Relation policy before edge/value rewrites.
- Legacy `bookmark_people` / `bookmark_relations` and current Bookmark person-role assignment are compatibility-era Bookmark behavior, not canonical generic Object Relation storage.
- #245 Photo/Image migration must preserve explicit cover semantics and use canonical Relation APIs once it reaches production Relation writes.
- Board create already uses canonical Relation validation; rollback/failure-policy refactors must never weaken that validation merely to make cleanup succeed.

## Stop reason
The latest-main/open-PR/cross-lane audit found no genuinely new Relation-producing workflow, canonical Relation storage/index change, or concrete correctness regression. Recent changes #354/#358 and open #359 are presentation or rollback/failure-policy work and preserve existing canonical Relation semantics. Per lane policy, no speculative abstraction or duplicate Relation regression was added. Resume when a new production Relation workflow, canonical storage/index change, or correctness regression appears.
