# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, and Object-owned presentation.

## Active issues
- `#56` — generic Object/Database/View product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#156` — fixed/masonry Gallery View modes; real host integrated, media-driven sizing remains.
- `#149` — Property-row visual polish; implementation landed, pending real-host visual validation.

## Current integration state
The generic Object/Database/View foundation is integrated into real hosts. Current work is product exposure, rich presentation, identity-safe system-Object creation UX, and legacy consolidation rather than new parallel abstractions.

Important `main` state:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and Representative-image Relations in the real app host;
- Bookmark detail consumes the managed visual resolver (#199);
- Weblinks / Images / Daily Notes are exposed through the existing generic sidebar/Database path (#203/#213);
- generic Daily Notes creation uses `DailyNoteService.openOrCreate(...)` and preserves one Object per local date (#214);
- generic Weblink/Image title-only and Board creation now fail closed instead of bypassing canonical URL/file identity (#215);
- Gallery fixed/masonry persistence, renderer, toolbar and real `GenericDatabasePage` integration are merged (#204/#206/#212);
- managed Image pixel dimensions are persisted for future media geometry (#207);
- shared `WeblinkVisualResolver` is merged and reused by `BookmarkVisualResolver` (#209);
- deterministic shared six-dot Property handle/grid is merged (#205).

## Latest integrated checkpoint
- PR #215 `Guard generic Weblink and Image creation invariants` was squash-merged as `5816a9a521f0b510e0665a460d25d2a49e85f4a6`.
- Flutter CI #885 passed Drift generation, `flutter analyze` and all 546 tests.

## Latest run checkpoints
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, latest PRs/commits and CI before editing.
2. Reconfirmed Relation PR #211 remains Relation-owned tests-only work; no Relation lifecycle/index/backlink implementation was changed.
3. Audited the now-user-facing Weblinks / Images generic create path after #213/#214 and identified a concrete identity-invariant gap: title-only `GenericDatabaseObjectCreateService.create(...)` could create Weblink or Image Objects without canonical URL/file identity.
4. Added fail-closed guards in the existing generic creation service. Daily Notes still route through `DailyNoteService`; ordinary/custom Database creation remains unchanged. Weblink creation refuses paths that bypass canonical URL normalization/reuse, and Image creation refuses paths that bypass managed file/image identity.
5. Applied the same guard before generic Board grouped creation can create Weblink/Image Objects, so Board cannot bypass those identity rules.
6. Added focused service regressions proving generic create and Board create leave Weblink/Image collections unmodified.
7. Added real `GenericDatabasePage` widget regressions that press the visible `新規ページ` affordance for Weblinks and Images, verify no invalid Object is created, and verify the fail-closed error is surfaced.
8. Compare-audited the implementation: Object-owned creation service + focused service test + real-host guard test; no Relation files were touched.
9. Flutter CI #885 completed green: Drift generation success, `flutter analyze` reported no issues, all 546 tests passed.
10. Squash-merged #215 into `main` as `5816a9a521f0b510e0665a460d25d2a49e85f4a6`.
11. Re-audited the next legacy visual target. `bookmark_reverse_lookup_dialog.dart` is small, but migrating it to `BookmarkVisualImage` requires threading `BookmarkRepository` through Tag/Photo/People management callers; those are larger hotspot files, so a patch-capable runtime remains the safe way to make that real-host change.
12. Reconfirmed #156's shared `ObjectGalleryView` is already consumed by the real `GenericDatabasePage`; remaining masonry work is media geometry/presentation input, not another renderer.

## Exact next actions
1. **#155 remaining Bookmark visual host migration — highest priority**
   - in a patch-capable runtime, thread existing `BookmarkRepository` into `showBookmarkReverseLookupDialog(...)` and replace `_BookmarkLookupThumbnail` with `BookmarkVisualImage`;
   - migrate `NotionBookmarkCard` + real Stage1 caller to `BookmarkVisualImage` without changing hover/card semantics;
   - remove direct legacy thumbnail rendering only after each real host is covered.
2. **#156 media-driven masonry sizing**
   - reuse #207 Image `Pixel width` / `Pixel height` and #209 shared Weblink visual resolution;
   - feed actual managed media aspect ratio into real Gallery cards without eager full-resolution decoding;
   - add mixed portrait/landscape real-host regression and stable no-media fallback height.
3. **#155 Weblink/Image daily-use create UX**
   - #215 deliberately fails closed rather than inventing a parallel creation model;
   - add dedicated real URL-entry and managed Image-import affordances that call existing canonical Object services when a safe host patch can wire them;
   - only then replace the generic create error with useful identity-aware creation UI.
4. **#155 generic Weblink/Image collection presentation**
   - improve default Table/Gallery/List presentation through existing ObjectType/View/default contracts only;
   - keep the shared generic destinations and Object detail/opening-mode host.
5. **#149**
   - #205 implementation is merged; close only after real-host screenshot/visual validation confirms alignment.

## Cross-lane boundaries
- Relation lane owns #211. Avoid broad Relation lifecycle/index/backlink edits while it is active.
- Object presentation/navigation remains read-only with respect to Relations unless a genuinely new Relation-producing workflow is introduced.
- Any Relation mutation/deletion continues through canonical Relation services only.

## Validation
- #215 Flutter CI #885 — Drift generation success, `flutter analyze` success, 546 tests passed; merged as `5816a9a521f0b510e0665a460d25d2a49e85f4a6`.
- #214 Flutter CI #878 — Drift generation, `flutter analyze`, full tests success; merged as `bc99383b29aa1b436ae2bde0c80c7eb81b4575fb`.
- #213 Flutter CI #874 — Drift generation, analyze and full tests success; merged as `1e18884d02bc54454a696fda5d88b54432cdf23d`.
- #212 Flutter CI #862 — success.
- #209 Flutter CI #857 — success.
- #206 Flutter CI #846 — success.
- This runtime does not have a checked-out Flutter workspace, so GitHub Actions is the executable validation source for pushed implementation branches.

## Risks / blockers
- Remaining Stage1 Bookmark visual migration needs small edits inside large real-host files. The current connector replaces whole files rather than applying patch hunks; do not reconstruct large hotspots for a small dependency thread.
- Reverse-lookup migration likewise requires small changes in several larger management-page callers.
- #156 media-driven masonry must be wired into the existing real Gallery/card path, not another disconnected resolver/renderer.
- Weblink/Image real creation affordances still need explicit URL/file input UX; #215 intentionally protects identity until that user-facing flow exists.
- No Relation semantic blocker is active.

## Stop reason
This run completed and integrated the identity-safety slice with green full CI. The next highest-priority Object work requires small patches in large real-host callers (remaining Bookmark visual hosts) or equivalent careful host wiring for media/create UX. Reconstructing those hotspots through whole-file connector replacement would violate the repository guidance, so resume from the exact actions above in a patch-capable implementation environment.
