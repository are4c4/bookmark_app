# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip and several List-readability slices are merged, Bookmark fixed/masonry and Stage1 host spacing remain.
- #245 — legacy Photos -> canonical Image Objects; managed import and Photo->Image bridge exist, broader product migration remains.
- #242 — Vault folders designed but lower priority while presentation/Image parity is actionable.

Completed/closed during current convergence:
- #247 — Bookmark opening-mode parity; #344 merged and user validated real center-peek behavior.
- #149 — shared deterministic six-dot Property handle; #348 converged Bookmark host and user validated real-host alignment.
- #252 — Notion-like Property-add UX; shared popover, generic Table/detail, `PersonRoleProperties`, and `BookmarkReorderableProperties` are converged through #346/#349/#350/#366.
- #156 — generic fixed/masonry Gallery support is complete/closed.

## Current merged state — 2026-09-06
Latest main observed during PR #379 work: `d2ea6499e58720de8f90e385f455e0aae784e8fc` after Object #378.

- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live (#286/#291);
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated, including fixed mode (#334);
- Weblink/Image daily-use defaults, enriched titles, site/favicon/content-type/published-date metadata and clickable URL Properties are integrated;
- direct Weblink creation performs fail-soft metadata/preview enrichment (#303), with Relation lifecycle coverage #307;
- Bookmark canonical visual presentation covers Notion card, reverse lookup, lifecycle and Stage1 List/Table (#294/#299/#296/#324);
- Bookmark canonical URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and List metadata (#317/#320/#322/#341/#360/#371);
- Bookmark Stage1 honors View opening mode through shared presentation host (#344), real-host validated;
- Bookmark Property rows use shared deterministic six-dot layout (#348), real-host validated;
- one semantic chip per Bookmark Person role assignment is merged (#301);
- shared anchored `PropertyAddPopover` is merged (#346);
- generic Table and side-detail use the shared anchored add flow (#349);
- both Bookmark person-role add surfaces reuse the shared popover (#350/#366);
- Bookmark List metadata is split into description, compact secondary metadata and semantic-chip rows (#352/#370);
- Bookmark List semantic chips are width-bounded and long labels ellipsize (#354);
- Bookmark List URL metadata no longer directly reads legacy `bookmark.url` (#360);
- generic Image Gallery file resolution now honors profile-relative managed paths (#375);
- legacy Photo mirrors now reuse the canonical `ImageObjectService.ensureDefinition()` Image schema while retaining legacy-only compatibility Properties (#378).

## Work in progress — PR #379
Branch: `feature/object-image-file-identity-dedupe-245`
Latest implementation commit: `9292d4433ac1d691de49ed3d0429962f298009e6` before handoff documentation commits.

PR #379 `Deduplicate managed Images by stable file identity`:
- keeps normalized source URL as the preferred Image reuse identity;
- also treats an exact trimmed managed file path as stable fallback identity even when a later caller presents different provenance;
- preserves the first non-empty source/file metadata instead of silently replacing provenance;
- keeps URL query/fragment distinctions meaningful when managed files differ;
- adds regression coverage proving one managed file cannot fan out into duplicate Image Objects across provenance changes.

This directly advances #245 Phase 1/2 duplicate-control requirements without changing Relation behavior, deleting legacy Photo data, or moving files. It is file-disjoint from merged #378 production changes: #378 changed `core_object_bridge.dart`, while #379 changes `image_object_service.dart` and its focused test.

## #245 audit note
`CoreObjectBridge` already provides the legacy Photo -> Image Object compatibility bridge with `photo_object_links` and the canonical system Image key. #378 now makes that bridge reuse the same canonical Image definition instead of maintaining a partial duplicate schema. Do not build a second bridge.

Remaining #245 work is product-semantic convergence: deterministic reimport/storage identity, Bookmark cover/image semantics, generic Images parity, Person profile image migration, path/dedup safety where needed, and eventual legacy `写真` caller retirement.

`PhotoStorageService.importPaths()` currently copies every selected source to a timestamped managed path before Image creation. Therefore #379 prevents duplicate Objects for the same already-managed file, but re-importing the same external source can still create a new managed copy/path. Treat deterministic reimport as a separate storage/import slice; do not silently change legacy Photo storage semantics without focused tests because the same storage service is still used by legacy Photo workflows.

## Exact next actions
1. Check PR #379 Flutter CI on the latest documentation-updated head. If green and mergeable against current main, merge it; if main advances with overlapping Image service files, refresh/rebuild rather than force-merging stale work.
2. Continue #245 with a focused deterministic reimport/import-storage identity design and regression. Prefer a content/source-safe policy that does not collapse unrelated files, break legacy unique-path assumptions, or leak absolute external paths into user-facing metadata.
3. Continue #249 with a separate Stage1 List host slice for stable vertical padding/minimum height/title max-lines+ellipsis/trailing alignment after rechecking hotspot ownership.
4. Continue #249 Bookmark Gallery parity: reuse the existing generic `DatabaseViewGalleryAdapter` / `ObjectGalleryView` fixed/masonry contract and persisted `galleryMode`; do not create Bookmark-only settings.
5. Add/retain Bookmark real-host/widget regression for fixed/masonry switching and independent per-View persistence.
6. Reassess #155 acceptance against actual production callers; keep compatibility storage/import/export until caller-zero/migration policy is proven.
7. Continue #245 from the existing Photo -> Image bridge; no destructive Photo table removal.
8. Defer broad #242 Vault work unless it becomes a direct dependency.

## Cross-lane coordination
### Relation
Current #245 Image identity work does not add a new Relation-producing workflow. Do not move Relation storage/index/backlink logic into Image services. New Bookmark -> Image or Person -> Image production writes must use canonical Relation APIs and should request focused Relation-lane lifecycle coverage once they become real write paths.

### Refactor
Open Refactor PRs at this checkpoint are #376/#377 and do not own `image_object_service.dart`, `image_object_service_test.dart`, or `bookmark_unified_stage1_page.dart`. Recheck live PR ownership before Stage1 or storage-service edits because ownership can change between runs. Refactor owns behavior-preserving extraction/deletion after Object parity is proven.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` remains a large conflict-prone shared hotspot; keep future changes patch-sized and sequence them after ownership checks;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- Gallery parity should reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant;
- timestamped legacy image import paths mean external reimport dedupe is not solved solely by Image Object file-path fallback identity;
- changing `PhotoStorageService` reuse semantics can affect the still-live legacy Photo table's unique-path assumptions, so that next slice needs focused compatibility coverage.

## Validation checkpoint
- #341/#344/#346/#348/#349/#350/#352/#354/#360/#366/#370/#371/#375 are merged after green Flutter CI.
- #378 full Flutter CI #1392 passed and the PR merged as `d2ea6499e58720de8f90e385f455e0aae784e8fc`.
- #149/#247 real-host behavior was subsequently validated by the user and both issues are closed.
- #252 is closed after #366 converged the remaining reorderable person-role add path.
- PR #379 latest Flutter CI is pending/running after the handoff refresh.

## Stop / continuation condition
This run has an active safe #245 slice under CI. Do not stop solely because CI is pending: continue with independent audits/documentation or another non-conflicting Object slice. Stop only if the next meaningful implementation requires editing a currently owned shared hotspot, requires unsafe whole-file reconstruction, requires an unresolved product/storage identity decision, or external CI/infrastructure becomes the only remaining dependency.
