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
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, latest PRs and current CI before editing.
2. Confirmed Relation PR #211 remains open/tests-only and avoided Relation lifecycle/index/backlink implementation changes.
3. Opened Object PR #213 (`feature/object-image-sidebar-collection-56`) to extend the already-proven generic system-collection navigation path rather than creating new pages.
4. Exposed the canonical system `image` ObjectType as `Images` through `GenericDatabaseStore.listDatabases(...)`, keeping Tag and other internal system ObjectTypes hidden and preserving generic AppShell/`GenericDatabasePage` routing.
5. Exposed the canonical `dailyNote` ObjectType as `Daily Notes` through the same path and added `DailyNoteService.ensureDefinition(...)` to normal `ObjectSyncService` workspace sync so the destination exists before the first Daily Note is opened.
6. Extended `system_object_visibility_test.dart` to lock deterministic navigation ordering (`Weblinks`, `Images`, `Daily Notes`, custom Databases), labels/icons, hidden Tag behavior, and Daily Notes availability after real workspace Object sync.
7. Compare-audited PR #213 against `main`: only `generic_database_store.dart`, `object_sync_service.dart`, and `system_object_visibility_test.dart` changed; no Relation implementation files changed. Latest compare is `+81/-11` across those three files.
8. PR #213 is open and mergeable. Flutter CI #872 was pending/in progress at the last check; do not merge until its relevant checks succeed.

## Exact next actions
1. **Finish PR #213**
   - inspect Flutter CI #872 for head `cb6c513f1070d13a113195ac2075c2adc5996dbf`;
   - fix any Object-lane regression caused by the slice;
   - when green, squash-merge #213 and update `docs/AI_PROGRESS.md` because repository-wide navigation state changed.
2. **#155 remaining Bookmark visual host migration**
   - in a patch-capable runtime, thread the existing `BookmarkRepository` into `showBookmarkReverseLookupDialog(...)` and replace `_BookmarkLookupThumbnail` with `BookmarkVisualImage`, preserving cover-photo precedence and legacy remote fallback through the canonical resolver;
   - migrate `NotionBookmarkCard` + the real Stage1 caller to `BookmarkVisualImage` without changing hover controls/card semantics;
   - remove direct `Image.network(bookmark.thumbnail)` presentation only after each real host is migrated and covered.
3. **#156 media-driven masonry sizing**
   - reuse #207 persisted Image `Pixel width` / `Pixel height` and #209 `WeblinkVisualResolver`;
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
- PR #213 compare audit: only 3 expected Object-owned files changed, `+81/-11`.
- PR #213 Flutter CI #872 is the executable validation source for the current branch; status was pending/in progress at handoff.
- #209 Flutter CI #857 — success; merged as `881f65cfd5af78f42fe5be24705163f9cda30900`.
- #212 Flutter CI #862 — success; merged as `232b55bc5677c5415dd49db361a902a2f2f454b6`.
- #206 Flutter CI #846 — success.
- This runtime cannot run local Flutter from a checked-out repository, so GitHub Actions remains the executable validation source for pushed implementation branches.

## Risks / blockers
- Remaining Stage1 Bookmark visual migration still needs a small patch inside large real-host files. Avoid broad whole-file reconstruction merely to thread an existing visual dependency.
- Daily Notes sidebar exposure in #213 intentionally ensures only the existing generic Daily Note ObjectType/defaults during Object sync; it does not introduce a second note model or create a note automatically.
- No product/design blocker and no Relation semantic blocker is active.

## Stop reason
This run completed multiple safe Object-lane checkpoints: Images generic navigation exposure, Daily Notes generic navigation exposure plus real workspace definition availability, and regression/compare validation in PR #213. The PR is awaiting its current Flutter CI result; independent high-value work after this point returns to the known large-host Bookmark visual patches or masonry media integration, which should be performed in a patch-capable runtime rather than broad connector-only whole-file reconstruction.
