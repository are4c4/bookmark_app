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
- normal Object sync ensures the Daily Note ObjectType/defaults before the first note is opened (#213).

## Latest run checkpoints
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, current PR/branch/commit state and CI before changing repository state.
2. Inspected Object PR #213 CI. Flutter CI #873 failed only because an old Daily Note test still expected system ObjectTypes to be absent from navigation; Drift generation and `flutter analyze` were green and 536/537 tests passed.
3. Fixed that stale expectation on #213 so it now verifies the intentionally exposed `Daily Notes` destination/name/icon rather than expecting an empty navigation list.
4. Flutter CI #874 then passed Drift generation, `flutter analyze`, and the full test suite. Squash-merged #213 as `1e18884d02bc54454a696fda5d88b54432cdf23d`.
5. Updated repository-wide `docs/AI_PROGRESS.md` and Issue #56 because first-class navigation state changed: generic navigation now exposes `Weblinks`, `Images`, and `Daily Notes` without feature-specific pages.
6. Audited the newly exposed Daily Notes real host and found a concrete invariant gap: the generic `新規ページ` path used `GenericDatabaseObjectCreateService.create(...)`, which would otherwise create a date-less Daily Note outside `DailyNoteService`'s one-object-per-local-date registry.
7. Opened Object PR #214 (`feature/object-daily-note-generic-create-56`) to route Daily Note collection creation through the existing `DailyNoteService.openOrCreate(...)` contract. Ordinary/custom Database creation stays generic; generic Board grouped creation for Daily Notes fails closed rather than creating invalid identity state.
8. Added focused service regressions for repeated-today reuse / Date Property population / Board fail-closed behavior, plus a real `GenericDatabasePage` widget regression proving the visible `新規ページ` affordance creates a canonical date-keyed Daily Note.
9. Compare-audited #214 against current main: only `generic_database_object_create_service.dart`, `generic_database_page_services.dart`, the focused creator test, and the new real-host Daily Note creation test are changed. No Relation implementation files are touched.
10. Relation PR #211 remains Relation-owned tests-only work; Object lane did not modify Relation lifecycle/index/backlink code.

## Exact next actions
1. **Finish PR #214 — current highest priority**
   - inspect Flutter CI #878 for head `e8ec4649dc64b4a1543876ee1c96b26a2b543339`;
   - fix any Object-lane regression from the date-keyed generic creation slice;
   - when green, squash-merge #214 and update this handoff to record the merged SHA/CI.
2. **#155 remaining Bookmark visual host migration**
   - in a patch-capable runtime, thread the existing `BookmarkRepository` into `showBookmarkReverseLookupDialog(...)` and replace `_BookmarkLookupThumbnail` with `BookmarkVisualImage`, preserving user cover > managed Representative Image > legacy remote fallback;
   - migrate `NotionBookmarkCard` + the real Stage1 caller to `BookmarkVisualImage` without changing hover controls/card semantics;
   - remove direct `Image.network(bookmark.thumbnail)` presentation only after each real host is migrated and covered.
3. **#156 media-driven masonry sizing**
   - reuse #207 persisted Image `Pixel width` / `Pixel height` and #209 shared `WeblinkVisualResolver`;
   - feed actual managed cover/media aspect ratio into real Gallery cards without eager full-resolution decode;
   - add a real-host portrait + landscape regression and stable no-media fallback height;
   - converge with #155 rich Weblink/Image presentation rather than adding parallel media lookup plumbing.
4. **#155 generic Weblink/Image collection polish**
   - improve default Table/Gallery/List presentation through existing ObjectType/View/default contracts only;
   - keep the shared generic destinations and Object detail/opening-mode host.
5. **#149**
   - #205 implementation is merged; close only after a real-host screenshot/visual validation confirms alignment.

## Cross-lane boundaries
- Relation lane owns #211. Avoid broad Relation lifecycle/index/backlink edits while it is active.
- Object presentation/navigation remains read-only with respect to Relations unless a genuinely new Relation-producing workflow is introduced.
- Any Relation mutation/deletion continues through canonical Relation services only.

## Validation
- #213 Flutter CI #873 — Drift generation/analyze green, full test suite had one stale expectation caused by the intentional Daily Notes navigation exposure.
- #213 Flutter CI #874 — Drift generation, `flutter analyze`, full tests success; merged as `1e18884d02bc54454a696fda5d88b54432cdf23d`.
- #214 compare audit — 4 Object-owned files relative to current main; no Relation implementation changes. Flutter CI #878 is the executable validation source for the active branch.
- #209 Flutter CI #857 — success; merged as `881f65cfd5af78f42fe5be24705163f9cda30900`.
- #212 Flutter CI #862 — success; merged as `232b55bc5677c5415dd49db361a902a2f2f454b6`.
- #206 Flutter CI #846 — success.
- This runtime cannot run local Flutter from a checked-out repository, so GitHub Actions remains the executable validation source for pushed implementation branches.

## Risks / blockers
- Remaining Stage1 Bookmark visual migration still needs a small patch inside large real-host files. Avoid broad whole-file reconstruction merely to thread an existing visual dependency.
- Exposing system ObjectTypes through the generic host also exposes generic creation UI. #214 explicitly closes this for Daily Note's date-keyed identity contract instead of weakening Daily Note semantics.
- Generic Board create-in-group is intentionally rejected for Daily Notes in #214 until a concrete date-aware Board creation UX exists; silently producing an invalid Daily Note is not acceptable.
- No product/design blocker and no Relation semantic blocker is active.

## Stop reason
Work is still active in PR #214. If this run must end before its CI completes, resume by checking #214 CI first; CI waiting alone is not a blocker, but the next independent high-value implementation after #214 returns to known large Bookmark visual-host patches or media-driven masonry integration, which should avoid broad hotspot reconstruction in a connector-only runtime.
