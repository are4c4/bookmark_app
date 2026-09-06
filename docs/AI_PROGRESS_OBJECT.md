# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #247 — Bookmark opening-mode implementation #344 merged; real-host validation remains.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip is merged, List readability is actively converging, Bookmark fixed/masonry remains.
- #252 — Notion-like Property-add UX; shared popover + generic Table/detail + Bookmark person-role convergence are merged.
- #149 — Bookmark Property handle convergence #348 merged; real-host visual confirmation remains.
- #245 — legacy Photos -> canonical Image Objects; managed import and Photo->Image bridge exist, broader product migration remains.
- #242 — Vault folders designed but lower priority while presentation parity is actionable.

#156 fixed/masonry generic Gallery is complete/closed.

## Current merged state — 2026-09-06
- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live (#286/#291);
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated, including fixed mode (#334);
- Weblink/Image daily-use defaults, enriched titles, site/favicon/content-type/published-date metadata and clickable URL Properties are integrated (#293/#298/#302/#309/#311/#339);
- direct Weblink creation performs fail-soft metadata/preview enrichment (#303), with Relation lifecycle coverage #307;
- Bookmark canonical visual presentation covers Notion card, reverse lookup, lifecycle and Stage1 List/Table (#294/#299/#296/#324);
- Bookmark canonical URL presentation covers lifecycle, reverse lookup, Notion card and Stage1 (#317/#320/#322/#341);
- Bookmark Stage1 honors View opening mode through shared presentation host (#344);
- Bookmark Property rows use shared deterministic six-dot layout (#348);
- one semantic chip per Bookmark Person role assignment is merged (#301);
- shared anchored `PropertyAddPopover` is merged (#346);
- generic Table and side-detail use the shared anchored add flow (#349);
- Bookmark person-role Property addition now reuses that same shared popover (#350);
- Bookmark List metadata is split into secondary metadata and semantic-chip rows (#352).

## Completed this run — #350 / #252
PR #350 `Use shared Property add popover for Bookmark person roles` passed Flutter CI run #1331 and was squash-merged as `399bad597d33de7e35ece5468ebffe010041f71d`.

Merged behavior:
- removes the Bookmark-specific `人物プロパティを追加` modal path from `PersonRoleProperties`;
- unused default person roles appear as searchable existing candidates;
- custom role creation stays in the same compact flow and uses existing normalization;
- actual Person picker/create and role assignment remain on existing repository paths;
- no Relation persistence moved into the popover.

## Completed this run — #352 / #249
PR #352 `Separate Bookmark List secondary metadata from chips` passed Flutter CI run #1330 and was squash-merged as `5095d4d7a65214ad8af4fc46621dec0e28abbc43`.

Merged behavior:
- URL/description/date/rating/history render as secondary metadata;
- status/tag/person/role/favorite remain semantic wrapping chips;
- explicit vertical separation replaces the previous single dense Wrap;
- canonical URL and one-Person-per-chip behavior are preserved.

## In progress — #354 / #249 bounded semantic chips
Branch: `feature/object-bookmark-list-chip-width-249`
Head before this handoff commit: `2559cf38855087e955863c6fd406c3eae5ffe807`
PR: #354 `Bound Bookmark List semantic chip width`
CI: Flutter CI #1336 queued at handoff.

Implemented:
- semantic Bookmark List chips are capped at 190px;
- long Person/Tag/status/favorite labels ellipsize inside the chip rather than stretching the whole row;
- wrapping, icons and one-Person-per-chip semantics are unchanged;
- focused widget regression covers a deliberately long Person label and verifies bounded width.

## #245 audit note
`CoreObjectBridge` already provides the legacy Photo -> Image Object compatibility bridge with `photo_object_links` and the canonical system Image key. Do not build a second bridge. Remaining #245 work is product-semantic convergence: Bookmark cover/image semantics, generic Images parity, Person profile image migration, path/dedup safety where needed, and eventual legacy `写真` caller retirement.

## Exact next actions
1. Resolve #354 CI; merge only after Generate + Analyze + full Test are green. Fix only scoped widget/layout failures.
2. Continue #249 with a separate Stage1 List host slice for stable vertical padding/minimum height/title ellipsis/trailing alignment after rechecking hotspot ownership.
3. Continue #249 Bookmark Gallery parity: reuse the existing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` fixed/masonry contract; do not create Bookmark-only settings.
4. Reassess #252 acceptance after #350. Only add advanced compact types where existing canonical Relation/computed services can be reused without duplicating semantics.
5. Validate #247 and #149 in the actual Bookmark host before closing those issues.
6. Continue #155 legacy URL/thumbnail retirement only after proven canonical replacement and caller-zero; keep import/export compatibility data meanwhile.
7. Continue #245 from the existing bridge; no destructive Photo table removal.
8. Defer broad #242 Vault work unless it becomes a direct dependency.

## Cross-lane coordination
### Relation
Current Object slices are presentation/interaction only. Person role assignment continues through existing repository/canonical behavior; do not move Relation storage/index/backlink logic into UI widgets.

### Refactor
At the latest ownership check open Refactor PRs are focused rollback/failure/privacy work (#336/#340/#342/#351/#353) and do not own `bookmark_unified_stage1_page.dart` or `bookmark_list_metadata.dart`. Recheck before any shared-host edit. Refactor owns behavior-preserving extraction/deletion after Object parity is proven.

## Risks / blockers
- large shared hosts are conflict-prone; keep Stage1 changes patch-sized and sequence them;
- #354 is CI-gated and must not merge while checks are pending/failing;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- #149/#247 require real-host confirmation before closure.

## Validation checkpoint
- #341 CI #1305 green, merged.
- #344 CI #1311 green, merged.
- #346 CI #1318 green, merged.
- #348 CI #1322 green, merged.
- #349 CI #1325 green, merged.
- #350 CI #1331 green, merged as `399bad597d33de7e35ece5468ebffe010041f71d`.
- #352 CI #1330 green, merged as `5095d4d7a65214ad8af4fc46621dec0e28abbc43`.
- #354 CI #1336 queued at handoff.

## Stop / continuation condition
This run merged two already-green Object slices (#350/#352), continued #249 with a new bounded-chip PR (#354), and refreshed the durable handoff. Continue from #354 CI, then move to the Stage1 row padding/title/trailing slice or Bookmark fixed/masonry parity depending on current PR ownership. No product clarification is required.
