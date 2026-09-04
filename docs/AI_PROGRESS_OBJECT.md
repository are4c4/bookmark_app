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
The generic Object/Database/View foundation is integrated into real hosts. Current work is product exposure, rich presentation, identity-safe creation UX, and legacy consolidation rather than new parallel abstractions.

Important `main` state before the current PR:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and Representative-image Relations in the real app host;
- Bookmark detail consumes the managed visual resolver (#199);
- Weblinks / Images / Daily Notes are exposed through the existing generic sidebar/Database path (#203/#213);
- generic Daily Notes creation uses `DailyNoteService.openOrCreate(...)` and preserves one Object per local date (#214);
- Gallery fixed/masonry persistence, renderer, toolbar and real `GenericDatabasePage` integration are merged (#204/#206/#212);
- managed Image pixel dimensions are persisted for future media geometry (#207);
- shared `WeblinkVisualResolver` is merged and reused by `BookmarkVisualResolver` (#209);
- deterministic shared six-dot Property handle/grid is merged (#205).

## Current branch / PR
- Branch: `feature/object-system-create-guard-56`
- PR: #215 — `Guard generic Weblink and Image creation invariants`
- Base at branch creation: `4a4aef63b2e8814ef216d8561f99d9e8910ad039`
- Current implementation head before this handoff update: `3060731588d3c49affa47d921ec20a3fb72f99e2`
- Flutter CI #884 is the active validation run for that head.

## Latest run checkpoints
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, latest PRs/commits and CI before editing.
2. Reconfirmed Relation PR #211 remains Relation-owned tests-only work; no Relation lifecycle/index/backlink implementation was changed.
3. Audited the now-user-facing Weblinks / Images generic create path after #213/#214 and identified a concrete identity-invariant gap: title-only `GenericDatabaseObjectCreateService.create(...)` could create Weblink or Image Objects without canonical URL/file identity.
4. Added fail-closed guards in the existing generic creation service. Daily Notes still route through `DailyNoteService`; ordinary/custom Database creation remains unchanged. System Weblink creation now refuses paths that bypass canonical URL normalization/reuse, and system Image creation refuses paths that bypass managed file/image identity.
5. Applied the same guard before generic Board grouped creation can create Weblink/Image Objects, so Board cannot bypass those identity rules.
6. Added focused service regressions proving generic create and generic Board create leave Weblink/Image collections unmodified.
7. Added real `GenericDatabasePage` widget regressions that press the visible `新規ページ` affordance for Weblinks and Images, verify no invalid Object is created, and verify the fail-closed error is surfaced to the user.
8. Opened PR #215. Compare audit against its base shows only three Object-owned files changed: `generic_database_object_create_service.dart`, its focused service test, and the new real-host system-create guard test. No Relation files are touched.
9. Initial CI #883 started on the earlier head; after adding the Board guard regressions the current head moved to `3060731588d3c49affa47d921ec20a3fb72f99e2` and Flutter CI #884 was queued.
10. Re-audited the next legacy visual target. `bookmark_reverse_lookup_dialog.dart` is small, but migrating it to `BookmarkVisualImage` requires threading `BookmarkRepository` through Tag/Photo/People management callers; those callers are larger hotspot files, so a patch-capable runtime remains the safe way to make that real-host change.

## Exact next actions
1. **Finish #215 validation/integration**
   - inspect Flutter CI #884;
   - fix any failure caused by the new guards/tests;
   - merge only after relevant checks are green;
   - after merge, update repository-wide `docs/AI_PROGRESS.md` and Issue #56 because the exposed system-collection creation contract changed.
2. **#155 remaining Bookmark visual host migration**
   - in a patch-capable runtime, thread existing `BookmarkRepository` into `showBookmarkReverseLookupDialog(...)` and replace `_BookmarkLookupThumbnail` with `BookmarkVisualImage`;
   - migrate `NotionBookmarkCard` + real Stage1 caller to `BookmarkVisualImage` without changing hover/card semantics;
   - remove direct legacy thumbnail rendering only after each real host is covered.
3. **#156 media-driven masonry sizing**
   - reuse #207 Image `Pixel width` / `Pixel height` and #209 shared Weblink visual resolution;
   - feed actual managed media aspect ratio into real Gallery cards without eager full-resolution decoding;
   - add mixed portrait/landscape real-host regression and stable no-media fallback height.
4. **#155 Weblink/Image daily-use create UX**
   - #215 deliberately fails closed rather than inventing a parallel creation model;
   - follow with dedicated real URL-entry and managed Image-import affordances that call the existing canonical Object services, when a patch-capable host edit can wire them safely.
5. **#149**
   - #205 implementation is merged; close only after real-host screenshot/visual validation confirms alignment.

## Cross-lane boundaries
- Relation lane owns #211. Avoid broad Relation lifecycle/index/backlink edits while it is active.
- Object presentation/navigation remains read-only with respect to Relations unless a genuinely new Relation-producing workflow is introduced.
- Any Relation mutation/deletion continues through canonical Relation services only.

## Validation
- #214 Flutter CI #878 — Drift generation, `flutter analyze`, full tests success; merged as `bc99383b29aa1b436ae2bde0c80c7eb81b4575fb`.
- #213 Flutter CI #874 — Drift generation, analyze and full tests success; merged as `1e18884d02bc54454a696fda5d88b54432cdf23d`.
- #212 Flutter CI #862 — success.
- #209 Flutter CI #857 — success.
- #206 Flutter CI #846 — success.
- #215 Flutter CI #884 — pending at this checkpoint.
- This runtime does not have a checked-out Flutter workspace, so GitHub Actions is the executable validation source for pushed implementation branches.

## Risks / blockers
- Remaining Stage1 Bookmark visual migration needs small edits inside large real-host files. The current connector replaces whole files rather than applying patch hunks; do not reconstruct large hotspots for a small dependency thread.
- Reverse-lookup migration likewise requires small changes in several larger management-page callers.
- #156 media-driven masonry must be wired into the existing real Gallery/card path, not another disconnected resolver/renderer.
- #215 is a safety contract only: Weblink/Image real creation affordances still need explicit URL/file input UX before generic `新規ページ` can become a useful creator for those system collections.
- No Relation semantic blocker is active.

## Stop condition if this run must end
Do not stop for CI pending alone. Continue with independent safe Object work where possible. If no patch-capable host edit is available, finish CI/merge/handoff work and stop only because the next high-priority real-host changes require small patches inside large hotspot callers that are unsafe to whole-file reconstruct through the current connector.
