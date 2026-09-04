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
- real `GenericDatabasePage` Gallery consumes persisted fixed/masonry mode through `ObjectGalleryView` (#212);
- reusable system Image and Daily Note collections are exposed as `Images` / `Daily Notes` through the same generic sidebar/Database path (#213), while Tag/internal system types remain hidden there;
- normal Object sync ensures the Daily Note ObjectType/defaults before the first note is opened (#213);
- generic `Daily Notes` creation now reuses the canonical date-keyed `DailyNoteService.openOrCreate(...)` path instead of creating unregistered/date-less Objects (#214).

## Latest run checkpoints
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, current PR/branch/commit state and CI before changing repository state.
2. Inspected Object PR #213 CI. Flutter CI #873 failed only because an old Daily Note test still expected system ObjectTypes to be absent from navigation; Drift generation and `flutter analyze` were green and 536/537 tests passed.
3. Fixed that stale expectation on #213 so it now verifies the intentionally exposed `Daily Notes` destination/name/icon rather than expecting an empty navigation list.
4. Flutter CI #874 then passed Drift generation, `flutter analyze`, and the full test suite. Squash-merged #213 as `1e18884d02bc54454a696fda5d88b54432cdf23d`.
5. Updated repository-wide `docs/AI_PROGRESS.md` and Issue #56 because first-class navigation state changed: generic navigation now exposes `Weblinks`, `Images`, and `Daily Notes` without feature-specific pages.
6. Audited the newly exposed Daily Notes real host and found a concrete invariant gap: the generic `新規ページ` path used `GenericDatabaseObjectCreateService.create(...)`, which would otherwise create a date-less Daily Note outside `DailyNoteService`'s one-object-per-local-date registry.
7. Opened Object PR #214 (`feature/object-daily-note-generic-create-56`) and routed Daily Note collection creation through the existing `DailyNoteService.openOrCreate(...)` contract. Ordinary/custom Database creation stays generic; generic Board grouped creation for Daily Notes fails closed rather than creating invalid identity state.
8. Added focused service regressions for repeated-today reuse / Date Property population / Board fail-closed behavior, plus a real `GenericDatabasePage` widget regression proving the visible `新規ページ` affordance creates a canonical date-keyed Daily Note.
9. Flutter CI #878 passed Drift generation, `flutter analyze`, and the full test suite. Squash-merged #214 as `bc99383b29aa1b436ae2bde0c80c7eb81b4575fb`.
10. Compare-audited #214: only `generic_database_object_create_service.dart`, `generic_database_page_services.dart`, the focused creator test, and the real-host Daily Note creation test changed; no Relation implementation files were touched.
11. Re-audited the next #155 legacy visual hosts. `bookmark_reverse_lookup_dialog.dart`, `notion_bookmark_card.dart`, and the Stage1 Bookmark host still render direct legacy thumbnail/cover paths instead of `BookmarkVisualImage`. Their canonical migration requires small edits in large real-host caller files.
12. Reconfirmed #156's shared `ObjectGalleryView` is already consumed by the real `GenericDatabasePage`; remaining masonry work is media geometry/presentation input, not another Gallery renderer.
13. Relation PR #211 remains Relation-owned tests-only work; Object lane did not modify Relation lifecycle/index/backlink code.

## Exact next actions
1. **#155 remaining Bookmark visual host migration — highest priority**
   - in a patch-capable runtime, thread the existing `BookmarkRepository` into `showBookmarkReverseLookupDialog(...)` and replace `_BookmarkLookupThumbnail` with `BookmarkVisualImage`, preserving user cover > managed Representative Image > legacy remote fallback;
   - migrate `NotionBookmarkCard` + the real Stage1 caller to `BookmarkVisualImage` without changing hover controls/card semantics;
   - remove direct `Image.network(bookmark.thumbnail)` presentation only after each real host is migrated and covered.
2. **#156 media-driven masonry sizing**
   - reuse #207 persisted Image `Pixel width` / `Pixel height` and #209 shared `WeblinkVisualResolver`;
   - feed actual managed cover/media aspect ratio into real Gallery cards without eager full-resolution decode;
   - add a real-host portrait + landscape regression and stable no-media fallback height;
   - converge with #155 rich Weblink/Image presentation rather than adding parallel media lookup plumbing.
3. **#155 generic Weblink/Image collection polish**
   - improve default Table/Gallery/List presentation through existing ObjectType/View/default contracts only;
   - keep the shared generic destinations and Object detail/opening-mode host;
   - audit generic `新規ページ` behavior for system Weblink/Image collections before treating those collections as fully daily-usable. Weblink creation in particular must not bypass canonical URL normalization/reuse; choose a URL-entry host or fail-closed behavior in a dedicated product slice rather than silently creating invalid identity state.
4. **#149**
   - #205 implementation is merged; close only after a real-host screenshot/visual validation confirms alignment.

## Cross-lane boundaries
- Relation lane owns #211. Avoid broad Relation lifecycle/index/backlink edits while it is active.
- Object presentation/navigation remains read-only with respect to Relations unless a genuinely new Relation-producing workflow is introduced.
- Any Relation mutation/deletion continues through canonical Relation services only.

## Validation
- #213 Flutter CI #873 — Drift generation/analyze green, full test suite had one stale expectation caused by intentional Daily Notes navigation exposure.
- #213 Flutter CI #874 — Drift generation, `flutter analyze`, full tests success; merged as `1e18884d02bc54454a696fda5d88b54432cdf23d`.
- #214 Flutter CI #878 — Drift generation, `flutter analyze`, full tests success; merged as `bc99383b29aa1b436ae2bde0c80c7eb81b4575fb`.
- #209 Flutter CI #857 — success; merged as `881f65cfd5af78f42fe5be24705163f9cda30900`.
- #212 Flutter CI #862 — success; merged as `232b55bc5677c5415dd49db361a902a2f2f454b6`.
- #206 Flutter CI #846 — success.
- This runtime cannot run local Flutter from a checked-out repository, so GitHub Actions remains the executable validation source for pushed implementation branches.

## Risks / blockers
- Remaining Stage1 Bookmark visual migration needs small edits inside large real-host files. The current connector supports whole-file replacement rather than patch hunks; avoid reconstructing large hotspots merely to thread an existing visual dependency.
- Reverse-lookup migration is small locally but requires passing `BookmarkRepository` through several larger management-page callers; do this in a patch-capable runtime.
- #156 media-driven masonry must be wired into the existing real Gallery/card path, not implemented as another disconnected media resolver/renderer.
- Exposed Weblink/Image collections still need explicit creation-UX audit. Daily Note had an unambiguous canonical creation service and is now fixed; Weblink/Image creation behavior needs a dedicated product-safe decision before changing the visible generic create affordance.
- No Relation semantic blocker is active.

## Stop reason
This run completed multiple coherent integration checkpoints and merged both #213 and #214 with green full Flutter CI. The highest-priority remaining implementation requires small patches in large real-host files (Bookmark visual hosts) or a product-safe media/create-UX decision. Broad whole-file hotspot reconstruction through the current connector would violate the repository guidance, so the next run should resume in a patch-capable environment from the exact actions above.
