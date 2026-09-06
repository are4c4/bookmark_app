# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip and several List-readability slices are merged, Bookmark fixed/masonry remains.
- #245 — legacy Photos -> canonical Image Objects; managed import and Photo->Image bridge exist, broader product migration remains.
- #242 — Vault folders designed but lower priority while presentation parity is actionable.

Completed/closed during current convergence:
- #247 — Bookmark opening-mode parity; #344 merged and user validated real center-peek behavior.
- #149 — shared deterministic six-dot Property handle; #348 converged Bookmark host and user validated real-host alignment.
- #252 — Notion-like Property-add UX; shared popover, generic Table/detail, `PersonRoleProperties`, and `BookmarkReorderableProperties` are converged through #346/#349/#350/#366.
- #156 — generic fixed/masonry Gallery support is complete/closed.

## Current merged state — 2026-09-06
Latest main observed before PR #370 work: `49282154dbc6bc5db5e403d2902fa94d5e0d13fd` (docs refresh #369), with Object #366 immediately before it.

- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live (#286/#291);
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated, including fixed mode (#334);
- Weblink/Image daily-use defaults, enriched titles, site/favicon/content-type/published-date metadata and clickable URL Properties are integrated;
- direct Weblink creation performs fail-soft metadata/preview enrichment (#303), with Relation lifecycle coverage #307;
- Bookmark canonical visual presentation covers Notion card, reverse lookup, lifecycle and Stage1 List/Table (#294/#299/#296/#324);
- Bookmark canonical URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and List metadata (#317/#320/#322/#341/#360);
- Bookmark Stage1 honors View opening mode through shared presentation host (#344), real-host validated;
- Bookmark Property rows use shared deterministic six-dot layout (#348), real-host validated;
- one semantic chip per Bookmark Person role assignment is merged (#301);
- shared anchored `PropertyAddPopover` is merged (#346);
- generic Table and side-detail use the shared anchored add flow (#349);
- both Bookmark person-role add surfaces reuse the shared popover (#350/#366);
- Bookmark List metadata is split into secondary metadata and semantic-chip rows (#352);
- Bookmark List semantic chips are width-bounded and long labels ellipsize (#354);
- Bookmark List URL metadata no longer directly reads legacy `bookmark.url` (#360).

## Work in progress — PR #370
Branch: `feature/object-bookmark-list-description-hierarchy-249`
Latest implementation commit at handoff: `373c1dd6e35efb32b6b4d8323a8cf570aac712e4` before this documentation commit.

PR #370 `Improve Bookmark List description hierarchy`:
- keeps the existing Bookmark List host and query/opening behavior unchanged;
- moves visible Bookmark description out of the compact URL/date/history Wrap into its own secondary line;
- allows description up to two lines with ellipsis so it remains readable without taking over the row;
- preserves URL/date/rating/history as compact secondary metadata;
- preserves semantic status/tag/person/favorite chips in their separate row;
- slightly increases vertical separation before semantic chips;
- adds widget regression for description -> compact metadata -> chip visual hierarchy and two-line bounding.

This is a focused #249 product-presentation slice in the small `BookmarkListMetadata` component, intentionally avoiding the Stage1 hotspot while CI is pending.

## #245 audit note
`CoreObjectBridge` already provides the legacy Photo -> Image Object compatibility bridge with `photo_object_links` and the canonical system Image key. Do not build a second bridge. Remaining #245 work is product-semantic convergence: Bookmark cover/image semantics, generic Images parity, Person profile image migration, path/dedup safety where needed, and eventual legacy `写真` caller retirement.

## Exact next actions
1. Check PR #370 Flutter CI. If green and current with main, merge it; if main advances with overlapping files, refresh/rebuild rather than force-merging stale work.
2. Continue #249 with a separate Stage1 List host slice for stable vertical padding/minimum height/title max-lines+ellipsis/trailing alignment after rechecking hotspot ownership.
3. Continue #249 Bookmark Gallery parity: reuse the existing generic `DatabaseViewGalleryAdapter` / `ObjectGalleryView` fixed/masonry contract and persisted `galleryMode`; do not create Bookmark-only settings.
4. Add/retain Bookmark real-host/widget regression for fixed/masonry switching and independent per-View persistence.
5. Reassess #155 acceptance against actual production callers: Stage1 Gallery/List/Table already render through canonical `BookmarkVisualImage`, and URL presentation has converged through #360. Keep compatibility storage/import/export until caller-zero/migration policy is proven.
6. Continue #245 from the existing Photo -> Image bridge; no destructive Photo table removal.
7. Defer broad #242 Vault work unless it becomes a direct dependency.

## Cross-lane coordination
### Relation
Current #249 work is presentation-only. Do not move Relation storage/index/backlink logic into Bookmark widgets. New image/cover Relation production work under #245 must continue using canonical Relation APIs and should request focused Relation-lane lifecycle coverage when it becomes a real new write path.

### Refactor
At this run's ownership check, the only open PR was docs-only #369, which subsequently merged before #370 opened. No open Refactor production PR owned `bookmark_unified_stage1_page.dart` or `bookmark_list_metadata.dart` at the implementation checkpoint. Recheck live PR ownership immediately before any Stage1 edit because ownership can change between runs. Refactor owns behavior-preserving extraction/deletion after Object parity is proven.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` remains a large conflict-prone shared hotspot; keep future changes patch-sized and sequence them after ownership checks;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- Gallery parity should reuse generic persisted `galleryMode` and renderer contracts rather than fork a Bookmark-only variant.

## Validation checkpoint
- #341/#344/#346/#348/#349/#350/#352/#354/#360/#366 are merged after green Flutter CI.
- #149/#247 real-host behavior was subsequently validated by the user and both issues are closed.
- #252 is closed after #366 converged the remaining reorderable person-role add path.
- PR #370 opened with two product/test files; Flutter CI #1372 was in progress at the latest check.

## Stop / continuation condition
This run has an active safe #249 slice under CI. Do not stop solely because CI is pending: continue with independent audits/documentation or another non-conflicting Object slice. Stop only if the next meaningful implementation requires editing a currently owned shared hotspot, requires unsafe whole-file reconstruction, or external CI/infrastructure becomes the only remaining dependency.
