# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #247 — Bookmark opening-mode implementation #344 merged; real-host validation remains.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip and several List-readability slices are merged, Bookmark fixed/masonry remains.
- #252 — Notion-like Property-add UX; shared popover + generic Table/detail + `PersonRoleProperties` are merged; `BookmarkReorderableProperties` still has one legacy person-role add modal.
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
- `PersonRoleProperties` reuses that same shared popover (#350);
- Bookmark List metadata is split into secondary metadata and semantic-chip rows (#352);
- Bookmark List semantic chips are width-bounded and long labels ellipsize (#354).

## Work completed in this run — PR #360
Branch: `feature/object-bookmark-list-url-resolver-155`
Latest implementation commit before this handoff: `ac73b799b0bfd737c32ac4f985cae4425cbf61eb`.

PR #360 `Stop Bookmark List from reading legacy URL directly`:
- removes `BookmarkListMetadata`'s local `_compactUrl(bookmark.url)` fallback;
- URL metadata now renders only through the existing `BookmarkResolvedUrlText` / `BookmarkUrlResolver` path;
- when a resolver is not supplied, the widget omits URL metadata instead of introducing another direct legacy Bookmark URL presentation read;
- real Stage1 behavior is unchanged because the host already passes `_resolveBookmarkUrl`;
- focused widget coverage now supplies the canonical resolver for URL-bearing List metadata;
- no URL storage, import/export, Relation, filtering/sorting, opening, or Stage1 hotspot semantics changed.

This is intentionally a presentation-boundary retirement slice for #155/#249, not deletion of legacy Bookmark URL compatibility data.

## #252 follow-up audit
`PersonRoleProperties` is converged, but `lib/widgets/bookmark_reorderable_properties.dart` still contains a second `showDialog<String>` / `AlertDialog` path titled `人物プロパティを追加`. The safe next #252 slice is to reuse the existing `PropertyAddPopover` there as well, preserving `_selectPeople`, `normalizePersonRole`, property-order insertion, and repository-owned Person assignment semantics.

Do not duplicate Relation persistence or person-picking semantics inside the popover.

## #245 audit note
`CoreObjectBridge` already provides the legacy Photo -> Image Object compatibility bridge with `photo_object_links` and the canonical system Image key. Do not build a second bridge. Remaining #245 work is product-semantic convergence: Bookmark cover/image semantics, generic Images parity, Person profile image migration, path/dedup safety where needed, and eventual legacy `写真` caller retirement.

## Exact next actions
1. Check PR #360 CI. If green and still current with main, merge it; if main advanced, refresh/rebuild rather than force-merging stale work.
2. Continue #252 by replacing `BookmarkReorderableProperties._addRole()` modal with the already-merged shared `PropertyAddPopover`; preserve property-order insertion and existing repository picker/write paths.
3. Continue #249 with a separate Stage1 List host slice for stable vertical padding/minimum height/title ellipsis/trailing alignment after rechecking hotspot ownership.
4. Continue #249 Bookmark Gallery parity: reuse the existing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` fixed/masonry contract; do not create Bookmark-only settings.
5. Reassess #252 acceptance after both Bookmark person-role add surfaces converge.
6. Validate #247 and #149 in the actual Bookmark host before closing those issues.
7. Continue #155 legacy URL/thumbnail retirement only after proven canonical replacement and caller-zero; keep import/export compatibility data meanwhile.
8. Continue #245 from the existing bridge; no destructive Photo table removal.
9. Defer broad #242 Vault work unless it becomes a direct dependency.

## Cross-lane coordination
### Relation
Current Object slices are presentation/interaction only. Person role assignment continues through existing repository/canonical behavior; do not move Relation storage/index/backlink logic into UI widgets.

### Refactor
At this run's ownership check open Refactor PRs include #355/#357/#359 and are focused on failure/privacy/rollback behavior. They do not own `bookmark_unified_stage1_page.dart`, `bookmark_list_metadata.dart`, or `bookmark_reorderable_properties.dart`. Recheck before edits because ownership can change between runs. Refactor owns behavior-preserving extraction/deletion after Object parity is proven.

## Risks / blockers
- large shared hosts are conflict-prone; keep Stage1 changes patch-sized and sequence them;
- `BookmarkReorderableProperties` is a several-hundred-line existing Widget; only change the focused add-role path, never reconstruct unrelated code;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data until caller-zero/migration policy is proven;
- identity-sensitive Weblink/Image creation must never fall back to raw title-only creation;
- ambiguous Relation state must fail closed; presentation must not repair it;
- #149/#247 require real-host confirmation before closure.

## Validation checkpoint
- #341 CI green, merged.
- #344 CI green, merged.
- #346/#348/#349/#350 CI green, merged.
- #352/#354 CI green, merged.
- #360 opened with 2 implementation/test files plus this handoff update; CI pending at the time of this checkpoint.

## Stop / continuation condition
This run produced a safe independent #155/#249 slice while avoiding shared-hotspot conflicts. Continue with #360 CI handling first, then the focused #252 `BookmarkReorderableProperties` add-role convergence when a safe patch-sized edit path is available. Do not stop merely because #360 is open if another non-conflicting Object slice is safely editable.
