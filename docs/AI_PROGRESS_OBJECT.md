# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Read latest GitHub Issue/PR/CI state before acting; PR numbers below are checkpoints, not substitutes for live status.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail/opening presentation, Body/block model, Daily Notes, reusable system Object types, system-collection product UX, and Object-owned presentation. Relation persistence/integrity stays in the Relation lane; behavior-preserving cleanup stays in Refactor #225.

## Active issues
- #56 — generic Object/Database/View daily-use integration.
- #155 — reusable Weblink + managed Image presentation and legacy compatibility retirement.
- #247 — Bookmark opening-mode implementation #344 merged; real-host validation remains.
- #249 — Bookmark Gallery/List parity; one-Person-per-chip is merged, List readability is actively converging, Bookmark fixed/masonry remains.
- #252 — Notion-like Property-add UX; shared popover + generic Table/detail + one Bookmark person-role surface are merged; `BookmarkReorderableProperties` still has a second legacy person-role add modal.
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
- Bookmark List semantic chips are width-bounded and long labels ellipsize instead of stretching rows (#354).

## Completed — #350 / #252
PR #350 `Use shared Property add popover for Bookmark person roles` passed Flutter CI run #1331 and was squash-merged as `399bad597d33de7e35ece5468ebffe010041f71d`.

Merged behavior:
- removes the Bookmark-specific `人物プロパティを追加` modal path from `PersonRoleProperties`;
- unused default person roles appear as searchable existing candidates;
- custom role creation stays in the same compact flow and uses existing normalization;
- actual Person picker/create and role assignment remain on existing repository paths;
- no Relation persistence moved into the popover.

## Completed — #352 / #249
PR #352 `Separate Bookmark List secondary metadata from chips` passed Flutter CI run #1330 and was squash-merged as `5095d4d7a65214ad8af4fc46621dec0e28abbc43`.

Merged behavior:
- URL/description/date/rating/history render as secondary metadata;
- status/tag/person/role/favorite remain semantic wrapping chips;
- explicit vertical separation replaces the previous single dense Wrap;
- canonical URL and one-Person-per-chip behavior are preserved.

## Completed this run — #354 / #249 bounded semantic chips
PR #354 `Bound Bookmark List semantic chip width` passed Flutter CI run #1337 and was squash-merged as `20a37c31e330d5806c6505c6d1d4746aee4331a1`.

Merged behavior:
- semantic Bookmark List chips are capped at 190px;
- long Person/Tag/status/favorite labels ellipsize inside the chip rather than stretching the whole row;
- wrapping, icons and one-Person-per-chip semantics are unchanged;
- focused widget regression covers a deliberately long Person label and verifies bounded width.

## #252 follow-up audit
`PersonRoleProperties` is converged, but `lib/widgets/bookmark_reorderable_properties.dart` still contains a second `showDialog<String>` / `AlertDialog` path titled `人物プロパティを追加`. The safe next #252 slice is to reuse the existing `PropertyAddPopover` there as well, preserving `_selectPeople`, `normalizePersonRole`, property-order insertion, and repository-owned Person assignment semantics.

Do not duplicate Relation persistence or person-picking semantics inside the popover.

## #245 audit note
`CoreObjectBridge` already provides the legacy Photo -> Image Object compatibility bridge with `photo_object_links` and the canonical system Image key. Do not build a second bridge. Remaining #245 work is product-semantic convergence: Bookmark cover/image semantics, generic Images parity, Person profile image migration, path/dedup safety where needed, and eventual legacy `写真` caller retirement.

## Exact next actions
1. Continue #252 by replacing the remaining `BookmarkReorderableProperties._addRole()` modal with the already-merged shared `PropertyAddPopover`; preserve property-order insertion and existing repository picker/write paths.
2. Continue #249 with a separate Stage1 List host slice for stable vertical padding/minimum height/title ellipsis/trailing alignment after rechecking hotspot ownership.
3. Continue #249 Bookmark Gallery parity: reuse the existing `DatabaseViewGalleryAdapter` / `ObjectGalleryView` fixed/masonry contract; do not create Bookmark-only settings.
4. Reassess #252 acceptance after both Bookmark person-role add surfaces converge. Only add advanced compact types where existing canonical Relation/computed services can be reused without duplicating semantics.
5. Validate #247 and #149 in the actual Bookmark host before closing those issues.
6. Continue #155 legacy URL/thumbnail retirement only after proven canonical replacement and caller-zero; keep import/export compatibility data meanwhile.
7. Continue #245 from the existing bridge; no destructive Photo table removal.
8. Defer broad #242 Vault work unless it becomes a direct dependency.

## Cross-lane coordination
### Relation
Current Object slices are presentation/interaction only. Person role assignment continues through existing repository/canonical behavior; do not move Relation storage/index/backlink logic into UI widgets.

### Refactor
At the latest ownership check open Refactor PRs are #336/#353/#355/#356/#357, focused on failure/privacy/rollback behavior. They do not own `bookmark_unified_stage1_page.dart`, `bookmark_list_metadata.dart`, or `bookmark_reorderable_properties.dart`. Recheck before edits because the shared-host ownership can change between runs. Refactor owns behavior-preserving extraction/deletion after Object parity is proven.

## Risks / blockers
- large shared hosts are conflict-prone; keep Stage1 changes patch-sized and sequence them;
- `BookmarkReorderableProperties` is a several-hundred-line existing Widget; do not hand-reconstruct the whole file merely because the available GitHub write action is full-file replacement. Use a patch-capable edit path when available;
- the next #249 Stage1 row geometry slice also belongs in the large `bookmark_unified_stage1_page.dart` hotspot and must remain patch-sized;
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
- #354 CI #1337 green, merged as `20a37c31e330d5806c6505c6d1d4746aee4331a1`.

## Stop / continuation condition
This run verified #354 full CI green and integrated it. The next concrete Object slices are identified (#252 remaining Bookmark add-modal convergence, then #249 Stage1 row geometry / Gallery parity), and current Refactor ownership does not conflict. This run stops because those edits require patch-sized changes to existing several-hundred/1500-line Widgets while the current GitHub write path available here only replaces complete files; hand-reconstructing those shared files would violate the repository's safe-edit guidance. Resume with a patch-capable edit path rather than broad whole-file replacement.
