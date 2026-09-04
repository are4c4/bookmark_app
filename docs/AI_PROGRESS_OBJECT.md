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
- generic Weblink/Image title-only and Board creation fail closed instead of bypassing canonical URL/file identity (#215);
- Gallery fixed/masonry persistence, renderer, toolbar and real `GenericDatabasePage` integration are merged (#204/#206/#212);
- managed Image pixel dimensions are persisted for future media geometry (#207);
- shared `WeblinkVisualResolver` is merged and reused by `BookmarkVisualResolver` (#209);
- deterministic shared six-dot Property handle/grid is merged (#205).

## Latest integrated checkpoint
- PR #215 `Guard generic Weblink and Image creation invariants` was squash-merged as `5816a9a521f0b510e0665a460d25d2a49e85f4a6`.
- Flutter CI #885 passed Drift generation, `flutter analyze` and all 546 tests.
- Latest main handoff commit before this run: `5e66f2af01f1d7ecff2677f040a7f00d1c977ae4`.

## Latest run checkpoints
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, latest PRs/commits and CI before editing.
2. Confirmed main remains at the post-#215 integration state; no newer Object PR is open.
3. Rechecked Relation PR #211. It remains Relation-owned, tests-only, and open. Flutter CI #859 completed with Drift generation and `flutter analyze` successful; only the test step failed. No Relation implementation was changed from Object lane.
4. Re-audited the highest-priority #155 legacy visual paths. `bookmark_reverse_lookup_dialog.dart` still directly renders cover files / legacy remote thumbnails; its real callers are Tag/Photo/People management pages. `NotionBookmarkCard` still directly renders legacy thumbnail state and has a single production caller in `bookmark_unified_stage1_page.dart`.
5. Re-read `BookmarkVisualImage`: it already provides the correct user-cover -> managed Representative Image -> legacy remote fallback semantics. No new resolver/abstraction is needed.
6. Reconfirmed the safe migration shape is therefore small dependency-threading patches in the existing real hosts, not another presentation service or duplicate card path.
7. Re-audited #156. `ObjectGalleryView` is already the real GenericDatabasePage renderer; the remaining work is to feed managed Image geometry into the existing card path, which again requires a focused patch in the large GenericDatabasePage/card host rather than a disconnected renderer.
8. Verified the current connector only supports whole-file replacement for existing files. The required next edits are a few lines inside large hotspot files (`bookmark_unified_stage1_page.dart`, Tag/Photo/People management pages, and later `generic_database_page.dart`). Reconstructing those whole files for tiny dependency-threading changes would create avoidable regression risk and violate the AGENTS.md hotspot/sequencing guidance.
9. No repository-wide integration state changed in this run, so `docs/AI_PROGRESS.md` was intentionally not modified.

## Exact next actions
1. **#155 remaining Bookmark visual host migration — highest priority**
   - in a patch-capable runtime, thread existing `BookmarkRepository` into `showBookmarkReverseLookupDialog(...)` and replace `_BookmarkLookupThumbnail` with `BookmarkVisualImage`;
   - update the real Tag/Photo/People management callers with only the repository argument;
   - migrate `NotionBookmarkCard` + its single real Stage1 caller to `BookmarkVisualImage` without changing hover/card/menu semantics;
   - add focused widget/real-host regressions and remove direct legacy thumbnail rendering only after each real host is covered.
2. **#156 media-driven masonry sizing**
   - reuse #207 Image `Pixel width` / `Pixel height` and #209 shared Weblink visual resolution;
   - feed actual managed media aspect ratio into the existing real GenericDatabasePage Gallery card path without eager full-resolution decoding;
   - add mixed portrait/landscape real-host regression and stable no-media fallback height.
3. **#155 Weblink/Image daily-use create UX**
   - #215 deliberately fails closed rather than inventing a parallel creation model;
   - add dedicated real URL-entry and managed Image-import affordances that call existing canonical Object services;
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
- Relation-owned #211 Flutter CI #859 — Drift generation/analyze success, test step failure; left untouched by Object lane.
- This runtime does not have a checked-out Flutter workspace, so GitHub Actions remains the executable validation source for pushed implementation branches.

## Risks / blockers
- Remaining Stage1 Bookmark visual migration needs small edits inside a large real-host file. The current connector replaces whole files rather than applying patch hunks; do not reconstruct the hotspot for a small dependency thread.
- Reverse-lookup migration likewise requires small changes in several larger management-page callers.
- #156 media-driven masonry must be wired into the existing real Gallery/card path, not another disconnected resolver/renderer; that real host is also a large hotspot requiring a small patch.
- Weblink/Image real creation affordances still need explicit URL/file input UX; #215 intentionally protects identity until that user-facing flow exists.
- No Relation semantic blocker is active.

## Stop reason
A genuine tooling blocker now prevents the next safe Object-lane implementation: every highest-priority remaining slice requires small patch edits in large real-host files, while this runtime exposes only whole-file replacement for repository writes and has no checked-out patch-capable workspace. Reconstructing those hotspots would be materially riskier than the requested scoped changes and conflicts with `AGENTS.md`. Resume in a patch-capable implementation environment from the exact actions above.