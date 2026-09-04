# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, and Object-owned presentation.

## Active issues
- `#56` — generic Object/Database/View product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#156` — fixed/masonry Gallery View modes.
- `#149` — Property-row visual polish; implementation landed, pending real-host visual validation.

## Current integration state
The generic Object/Database/View foundation is integrated into real hosts. Current work is product exposure, rich presentation, and legacy consolidation rather than new parallel abstractions.

Important current `main` state:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and Representative-image Relations in the real app host;
- Bookmark detail consumes the managed visual resolver (#199);
- Weblinks are exposed through the existing generic sidebar/Database navigation list (#203);
- Gallery View mode persistence is on `main` (#204);
- deterministic shared six-dot Property handle/grid is on `main` (#205);
- shared fixed/masonry Gallery renderer + toolbar control is on `main` (#206);
- managed Image pixel dimensions for media geometry are on `main` (#207);
- shared `WeblinkVisualResolver` is on `main` and `BookmarkVisualResolver` reuses it (#209);
- real `GenericDatabasePage` Gallery consumes persisted fixed/masonry mode through `ObjectGalleryView` (#212).

## Latest run checkpoints
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, current open PRs and CI state before changing repository state.
2. Confirmed the only open PR is Relation-owned #211 (`test/relation-weblink-sidebar-backlink-host-155`). It is tests-only, currently not mergeable against the advanced `main`, and its head has no combined status entries. Object lane did not touch Relation lifecycle or the PR.
3. Re-read Issue #156. Contrary to the stale summary still embedded in Issue #56, #156 is already integrated through #212: persisted `fixed | masonry`, shared renderer/toolbar, Image dimensions, and real `GenericDatabasePage` consumption are all merged. Remaining work is only media-driven masonry sizing + mixed portrait/landscape real-host coverage.
4. Re-audited the remaining direct legacy Bookmark thumbnail hosts. `bookmark_reverse_lookup_dialog.dart`, `notion_bookmark_card.dart`, and `bookmark_unified_stage1_page.dart` still render legacy cover/remote thumbnail paths directly instead of `BookmarkVisualImage`.
5. Verified `bookmark_reverse_lookup_dialog.dart` is a small host but its canonical migration requires threading `BookmarkRepository` from the Photo/People/Tag callers. Those caller files are large and this connector only supports whole-file replacement, so changing them here would create an avoidable broad-hotspot rewrite.
6. Re-inspected the shared Gallery implementation. `ObjectGalleryView` already provides masonry geometry and the real host consumes it; the next #156 slice must feed persisted managed Image aspect ratio into the existing card/media path, not add another Gallery-specific media identity abstraction.

## Exact next actions
1. **#155 remaining Bookmark visual host migration — highest priority**
   - in a patch-capable runtime, thread the existing `BookmarkRepository` into `showBookmarkReverseLookupDialog(...)` and replace `_BookmarkLookupThumbnail` with `BookmarkVisualImage`, preserving cover-photo precedence and legacy remote fallback through the canonical resolver;
   - migrate `NotionBookmarkCard` + the real Stage1 caller to `BookmarkVisualImage` without changing hover controls/card semantics;
   - remove direct `Image.network(bookmark.thumbnail)` presentation only after each real host is migrated and covered.
2. **#156 media-driven masonry sizing**
   - reuse #207 persisted Image `Pixel width` / `Pixel height` and #209 `WeblinkVisualResolver`;
   - feed actual managed cover/media aspect ratio into real Gallery cards without eager full-resolution decode;
   - add a real-host portrait + landscape regression and stable no-media fallback height;
   - converge with #155 rich Weblink/Image presentation rather than adding parallel media lookup plumbing.
3. **#155 generic Weblink collection polish**
   - improve default Table/Gallery/List presentation through existing ObjectType/View/default contracts only;
   - keep the existing `Weblinks` sidebar destination and shared Object detail/opening-mode host.
4. **#149**
   - #205 implementation is merged; close only after a real-host screenshot/visual validation confirms alignment.

## Cross-lane boundaries
- Relation lane owns #211. Avoid broad Relation lifecycle/index/backlink edits while it is active.
- Object presentation/navigation remains read-only with respect to Relations unless a genuinely new Relation-producing workflow is introduced.
- Any Relation mutation/deletion continues through canonical Relation services only.

## Validation
- #209 Flutter CI #857 — success; merged as `881f65cfd5af78f42fe5be24705163f9cda30900`.
- #212 Flutter CI #862 — success; merged as `232b55bc5677c5415dd49db361a902a2f2f454b6`.
- #206 Flutter CI #846 — success.
- #211 head `84790612a97a1651f789f2647620cabe741fa4da`: no combined status entries were returned during this run; PR is currently not mergeable against latest main.
- This runtime cannot clone GitHub over the container network, so local Flutter validation is unavailable; GitHub Actions remains the executable validation source for pushed implementation branches.

## Risks / blockers
- The highest-value remaining #155 host migrations require small edits inside large real-host files. The GitHub connector exposes whole-file replacement rather than a patch operation, and the container cannot reach github.com to clone the repository.
- Reconstructing those large hosts only to thread an existing visual dependency would violate the repository guidance against broad hotspot replacement and create unnecessary regression risk.
- No product/design blocker and no Relation semantic blocker is active.

## Stop reason
This run completed repository/Issue/PR/CI revalidation, corrected the durable handoff around the now-integrated #156 real host, and re-audited the exact remaining legacy visual hosts. The next safe implementation requires a small patch to large real-host files, but the available runtime has neither patch-capable repository access nor container network access to clone the repo. Broad whole-file reconstruction is intentionally avoided under the AGENTS.md runtime/tool-limit stopping criterion.
