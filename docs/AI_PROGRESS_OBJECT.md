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

## Latest sustained-run checkpoints
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, current PRs/commits and CI before changing state.
2. Inspected Object PR #209 (`feature/object-weblink-visual-resolver-155`). Flutter CI #857 was green. Squash-merged as `881f65cfd5af78f42fe5be24705163f9cda30900`.
   - `WeblinkVisualResolver` now owns canonical Weblink -> Representative image -> managed Image.File presentation resolution through `RelationReadService`.
   - `BookmarkVisualResolver` reuses the same Weblink visual path, avoiding a second media lookup implementation.
   - Resolution remains read-only/fail-closed and verifies the local file exists before presentation.
3. Inspected Object PR #212 (`feature/object-gallery-real-host-156`). Flutter CI #862 was green.
   - Real `GenericDatabasePage` now replaces only Gallery geometry with `ObjectGalleryView`.
   - Active persisted mode is decoded through the existing `DatabaseViewGalleryAdapter`.
   - Existing item builder, semantic Property rendering, create-card flow, selected state and Object opening callback stay unchanged.
   - Real-host regression verifies toolbar switch -> persisted masonry mode -> real renderer change without changing Object ids/titles.
4. Squash-merged #212 as `232b55bc5677c5415dd49db361a902a2f2f454b6` after GitHub recomputed it mergeable on latest main.
5. Refreshed Issue #156 to mark real-host fixed/masonry integration complete and narrow remaining work to actual media-driven aspect-ratio sizing using #207 Image dimensions + #209 shared Weblink visual resolution.
6. Re-audited legacy Bookmark visual hosts. Remaining direct legacy thumbnail presentation includes `NotionBookmarkCard`, `bookmark_reverse_lookup_dialog.dart`, and the Stage1 Bookmark view. These should migrate to the existing `BookmarkVisualImage`/resolver path in small host slices rather than adding another visual abstraction.

## Exact next actions
1. **#155 remaining Bookmark visual host migration — highest priority**
   - migrate `NotionBookmarkCard` and its real Stage1 caller to `BookmarkVisualImage` / `BookmarkVisualResolver` while preserving explicit cover-photo precedence, hover controls and existing card semantics;
   - then migrate `bookmark_reverse_lookup_dialog.dart` by threading the existing repository/resolver context from its callers;
   - keep legacy remote thumbnail only as the resolver fallback; do not remove compatibility data yet.
2. **#156 media-driven masonry sizing**
   - reuse #207 persisted Image `Pixel width` / `Pixel height` and #209 `WeblinkVisualResolver`;
   - feed actual managed cover/media aspect ratio into real Gallery cards without eager full-resolution decode;
   - add a real-host portrait + landscape regression and stable no-media fallback height;
   - converge with #155 Weblink/Image rich presentation rather than adding Gallery-only media identity plumbing.
3. **#155 Weblink generic collection polish**
   - improve default generic Weblink Table/Gallery/List presentation using existing ObjectType defaults/View contracts;
   - keep the existing `Weblinks` sidebar destination and shared Object detail/opening-mode host.
4. **#149**
   - #205 implementation is merged; close only after real-host screenshot/visual validation confirms the deterministic handle is aligned. Do not resume Material glyph pixel tuning.

## Cross-lane boundaries
- Relation lane currently has PR #211 tests-only coverage for backlinks in the exposed Weblink host. Avoid broad edits to Relation lifecycle while it is active.
- Object presentation/navigation work remains read-only with respect to Relations unless a genuinely new Relation-producing workflow is introduced.
- Any Relation mutation/deletion continues through canonical Relation services only.
- #156 Gallery geometry and #149 visual alignment are Object-owned presentation work.

## Validation
- #209 head `8d57e7d364a0b7b80a7a142a1c7ba9a87559a8a6`: Flutter CI #857 — success; squash merge `881f65cfd5af78f42fe5be24705163f9cda30900`.
- #212 head `2eb39104a26b6e35ab5fbec3c0ed332b3361252b`: Flutter CI #862 — success; squash merge `232b55bc5677c5415dd49db361a902a2f2f454b6`.
- #206 Flutter CI #846 — success; merged earlier.
- #205 deterministic Property handle merged as `dbc30cd054f86bcc2db5dbd207aac4265cdb3150`.
- This connector-only runtime cannot run local Flutter commands; GitHub Actions is the executable validation source.

## Risks / blockers
- The next highest-value #155 migrations touch large real-host files (`bookmark_unified_stage1_page.dart` in particular). The available GitHub connector writes existing files by whole-file replacement and does not expose a small patch operation.
- Reconstructing a large host file merely to thread one existing `BookmarkVisualImage` dependency would violate the repository guidance to avoid broad hotspot replacement and creates avoidable regression risk.
- A patch-capable runtime should perform those host migrations next. No product/design blocker and no Relation semantic blocker is active.

## Stop reason
This run completed multiple coherent checkpoints: #209 CI validation/merge, #212 real-host Gallery CI validation/merge, Issue #156 synchronization, and an audit of the next legacy visual hosts. The next exact Object task requires a small patch to a large Stage1 real-host file, but this connector exposes only whole-file replacement. Broad reconstruction would be unnecessarily risky, so the run stops on the runtime/tool-limit criterion with the next patch precisely recorded above.
