# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #247 — Bookmark opening-mode implementation #344 merged; real-host validation remains.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip #301 merged, List hierarchy and Bookmark fixed/masonry remain.
- #252 — Notion-like Property-add UX; shared popover #346 and generic Table/detail integration #349 merged, Bookmark/person-role convergence in progress.
- #149 — Bookmark Property handle convergence #348 merged; real-host visual confirmation remains.
- #245 — legacy Photos -> canonical Image Objects; managed import and Photo->Image bridge exist, broader product migration remains.
- #242 — Vault folders designed but lower priority while presentation parity is actionable.

#156 fixed/masonry generic Gallery is complete/closed.

## Current merged state — 2026-09-06
- canonical Bookmark -> Weblink -> managed Representative Image flows are live;
- Weblinks / Images / Daily Notes use generic Database/sidebar hosts;
- canonical Weblink URL entry and managed Image import are live (#286/#291);
- fixed/masonry generic Gallery and managed Weblink/Image media are integrated, including fixed mode (#334);
- Weblink/Image daily-use defaults, enriched titles, site/favicon metadata and clickable URL Properties are integrated (#293/#298/#302/#309/#311/#339);
- direct Weblink creation performs fail-soft metadata/preview enrichment (#303), with Relation lifecycle coverage #307;
- Bookmark canonical visual presentation covers Notion card, reverse lookup, lifecycle and Stage1 List/Table (#294/#299/#296/#324);
- Bookmark canonical URL presentation covers lifecycle, reverse lookup, Notion card and Stage1 (#317/#320/#322/#341);
- Bookmark Stage1 honors View opening mode through shared presentation host (#344);
- Bookmark Property rows use shared deterministic six-dot layout (#348);
- one semantic chip per Bookmark Person role assignment is merged (#301);
- shared anchored `PropertyAddPopover` is merged (#346);
- generic Table and side-detail now use the shared anchored add flow for reveal/simple typed Property creation (#349, merge `7493bda4c011fe167244542f19c4d49f4c4d1913`). Advanced Relation/formula/rollup creation remains on existing canonical services.

## Completed this run — #349 / #252
PR #349 `Use anchored Property add flow in generic detail and Table` passed Flutter CI run #1325 and was squash-merged as `7493bda4c011fe167244542f19c4d49f4c4d1913`.

Merged behavior:
- Table `+` and side-detail Property add reuse `PropertyAddPopover`;
- hidden Properties can be revealed directly while preserving View visibility/order semantics;
- text/number/checkbox/date/URL/rating can be created in the compact flow;
- advanced types remain on existing advanced/canonical paths to avoid duplicating Relation/computed semantics.

## In progress — #350 / #252 Bookmark person-role add convergence
Branch: `feature/object-person-role-add-popover-252`
Head before this handoff update: `21169d41413986b54ff8f0717db39ec4e24a00d6`
PR: #350 `Use shared Property add popover for Bookmark person roles`
CI: Flutter CI #1328 in progress at handoff.

Implemented:
- removed the Bookmark-specific `人物プロパティを追加` AlertDialog from `PersonRoleProperties`;
- reuses shared anchored `PropertyAddPopover`;
- unused default person roles appear as searchable existing Property candidates;
- custom role creation stays in the same compact flow and uses `normalizePersonRole`;
- actual Person picker/create and role assignment remain on existing repository paths; no Relation persistence moved into the popover;
- per-role `+` editing is unchanged;
- focused architecture guard prevents the old modal title path from returning.

## In progress — #352 / #249 Bookmark List hierarchy
Branch: `feature/object-bookmark-list-hierarchy-249`
Head: `0b8dedae65fdd57d81775070d2cc673aa98d2ef5`
PR: #352 `Separate Bookmark List secondary metadata from chips`
CI: Flutter CI #1330 in progress at handoff.

Implemented:
- `BookmarkListMetadata` now renders URL/description/date/rating/history as a secondary-text row;
- status/tag/person/role/favorite remain semantic wrapping chips on a separate row;
- adds explicit vertical separation instead of one dense Wrap;
- canonical URL resolution and one-Person-per-chip semantics are unchanged;
- focused widget regression verifies secondary metadata appears above chips.

This is the first small #249 List-density slice. Stage1 host padding/min-height/title/trailing-control changes remain separate to avoid a broad hotspot rewrite.

## #245 audit note
`CoreObjectBridge` already provides the legacy Photo -> Image Object compatibility bridge with `photo_object_links` and the canonical system Image key. Do not build a second bridge. Remaining #245 work is product-semantic convergence: Bookmark cover/image semantics, generic Images parity, Person profile image migration, path/dedup safety where needed, and eventual legacy `写真` caller retirement.

## Exact next actions
1. Resolve #350 CI; merge only after Generate + Analyze + full Test are green. Fix only scoped compile/test failures.
2. Resolve #352 CI; merge only after full green. If green, continue #249 with a separate Stage1 List host slice for stable vertical padding/minimum height/title ellipsis/trailing alignment.
3. Continue #249 Bookmark Gallery parity after rechecking shared-hotspot ownership: reuse the existing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` fixed/masonry contract; do not create Bookmark-only settings.
4. Continue #252 by converging the second Bookmark/person-role add implementation (`bookmark_reorderable_properties.dart`) on the same shared popover after #350 proves the interaction.
5. Validate #247 and #149 in the actual Bookmark host before closing those issues.
6. Continue #155 legacy URL/thumbnail retirement only after proven canonical replacement and caller-zero; keep import/export compatibility data meanwhile.
7. Continue #245 from the existing bridge; no destructive Photo table removal.
8. Defer broad #242 Vault work unless it becomes a direct dependency.

## Cross-lane coordination
### Relation
Current Object slices are presentation/interaction only. Person role assignment continues through existing repository/canonical behavior; do not move Relation storage/index/backlink logic into UI widgets.

### Refactor
At this checkpoint open Refactor PRs include #336/#340/#342/#343/#347 and do not own `PersonRoleProperties`, `BookmarkListMetadata`, or the Stage1 hotspot. Recheck before any Stage1/generic host edit. Refactor owns behavior-preserving extraction/deletion after Object parity is proven.

## Risks / blockers
- large shared hosts are conflict-prone; keep Stage1 changes patch-sized and sequence them;
- #350 and #352 are CI-gated and must not merge while checks are pending/failing;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- #149/#247 require real-host confirmation before closure.

## Validation checkpoint
- #341 CI #1305 green, merged.
- #344 CI #1311 green, merged.
- #346 CI #1318 green, merged.
- #348 CI #1322 green, merged.
- #349 CI #1325 green, merged as `7493bda4c011fe167244542f19c4d49f4c4d1913`.
- #350 CI #1328 in progress.
- #352 CI #1330 in progress.

## Stop / continuation condition
This run merged the prior #252 real-host slice and opened two additional safe, non-conflicting Object slices (#350 and #352). Continue with their CI results, then Stage1 List host spacing or Bookmark Gallery fixed/masonry parity depending on current PR ownership. No product clarification is required.
