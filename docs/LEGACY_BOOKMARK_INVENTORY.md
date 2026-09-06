# Legacy Bookmark production inventory

Issue #225 tracks retirement of Bookmark-era dependencies without deleting still-live behavior prematurely. This inventory classifies **production** consumers; tests are evidence, not migration targets by themselves.

Classification meanings:
- **canonical product behavior** — still owns a real Bookmark feature today; do not delete until Object-first replacement has parity.
- **compatibility bridge** — intentionally connects a live Bookmark host to newer Object/Weblink/Image/Relation infrastructure.
- **migration-only** — historical/import/export compatibility that may legitimately understand legacy storage.
- **superseded duplicate** — duplicate presentation/read logic for which a canonical replacement already exists; delete/migrate first.
- **retired caller-zero module** — production reference count reached zero and the module was removed rather than kept as a speculative wrapper.

Re-run code search and inspect current files before deletion because the Object lane is active and GitHub Code Search can lag recent merges.

## `BookmarkItem` / `BookmarkRepository` ownership map

| Consumer | Classification | Current ownership / retirement condition |
| --- | --- | --- |
| `lib/data/bookmark_repository.dart` | canonical product behavior | Root repository for still-live Bookmark lifecycle/query/metadata flows. New Object-only features should not expand it. |
| `lib/data/app_database_schema.dart` (`BookmarkItem`) | canonical product behavior | Compatibility/domain shape for live Bookmark rows. Delete only after production callers disappear and migration/import/export handling is explicit. |
| `lib/data/bookmark_read_store.dart` | canonical product behavior / compatibility read boundary | Owns the screen-ready Bookmark aggregation formerly implemented by `AppDatabase.watchBookmarkItems()`. Keep while Bookmark hosts need the aggregate shape; do not move joins back into AppDatabase. |
| `lib/views/bookmark_query_engine.dart` | canonical product behavior | Bookmark-specific filtering remains live until generic Database/View querying covers the same host. |
| `lib/views/bookmark_lifecycle_page.dart` | canonical product behavior / compatibility host | Inbox/archive/trash remain live. Visual rendering is canonicalized; canonical Weblink URL is preferred with legacy fallback. |
| `lib/views/global_search_page.dart` | canonical product behavior | Current global search still consumes Bookmark aggregates. Retire after Object-first global search parity. Failure UI is already stable/privacy-safe. |
| `lib/services/auto_organize_service.dart` | canonical product behavior | Bookmark automation remains live; do not extend for Object-only workflows. |
| `lib/services/bookmark_transfer_service.dart` | migration-only / compatibility | Import/export legitimately understands persisted Bookmark data. Keep isolated. |
| `lib/repositories/full_text_search_repository.dart` | compatibility bridge | Still provides Bookmark global search. #422 centralizes its Bookmark -> FTS projection; do not treat SQL deduplication as search-semantic retirement. Issue #414 separately tracks possible stale focused-refresh tokens. |
| `lib/repositories/backlink_repository.dart` | compatibility bridge | Bookmark-facing backlink model remains live. #408 removed direct database reach-through and whole-table watch, but the compatibility model still exists until its presentation callers retire. |
| `lib/widgets/bookmark_relation_section.dart` | compatibility bridge | Bookmark detail exposes Relation/backlink information through Bookmark-centric inputs; do not redesign Relation here. |
| `lib/widgets/person_role_properties.dart` | canonical product behavior / compatibility | Shared Property-add flow is integrated; Person assignment remains on existing semantics. |
| `lib/widgets/bookmark_reorderable_properties.dart` | canonical product behavior / compatibility | Still-live Bookmark Property host; UI convergence is not retirement. |
| `lib/widgets/bookmark_detail_panel.dart` | canonical product behavior / compatibility | Still-live Bookmark detail. Managed visual migration is integrated; move metadata/URL responsibilities only with proven replacement parity. |
| `lib/widgets/bookmark_visual_image.dart` | compatibility bridge | Shared Bookmark-host visual boundary: user cover -> canonical managed visual -> legacy thumbnail fallback. Keep until Bookmark compatibility hosts disappear. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility bridge | Read-only canonical/legacy visual precedence resolver. New presentation must not bypass it. |
| `lib/services/bookmark_url_resolver.dart` | compatibility bridge | Read-only canonical Bookmark→Weblink URL preference with legacy fallback. Keep while compatibility hosts still need fallback. |
| `lib/widgets/global_file_drop_layer.dart` | canonical product behavior / composition | Current import/drop composition still receives BookmarkRepository. Narrow only with a real focused replacement. |
| `lib/widgets/bookmark_attachment_section.dart` | canonical product behavior / compatibility | Attachment/PDF enrichment remains Bookmark-owned. Stable failure/privacy behavior does not make the host removable. |
| `lib/views/settings_page.dart` | canonical product behavior / composition | Backup/export/settings still use repository capabilities. |
| `lib/views/tag_management_page.dart` | canonical product behavior | Current management host still uses Bookmark capabilities; reverse-lookup image presentation is canonical. |
| `lib/views/people_management_page.dart` | canonical product behavior | Large management hotspot combining People/Bookmark behavior. |
| `lib/views/photo_management_page.dart` | canonical product behavior / legacy host | Photo management remains live; read/path aggregation has moved to `PhotoReadStore`. |
| `lib/views/collection_management_page.dart` | canonical product behavior | Collection management still consumes Bookmark data. |
| `lib/views/app_shell.dart` | composition hotspot | Passes BookmarkRepository through many live/compatibility screens. Always check open PR ownership. |
| `lib/main.dart` | composition root | Root Bookmark repository construction remains expected while live Bookmark features exist. |

## Retired caller-zero modules

### `lib/data/saved_view_extensions.dart` — removed by #417
`SavedViewDuplication.duplicateSavedView(...)` had **zero production callers**. Its only remaining caller was a test dedicated to the extension itself, while Saved View persistence/read behavior was independently covered elsewhere.

#417 therefore removed the extension instead of preserving a speculative compatibility wrapper:
- 25 production LOC removed;
- 59 dead-API-only test LOC removed;
- no active Saved View UI, persistence schema, Database/View behavior or migration behavior changed.

Do not reintroduce a duplicate-Saved-View BookmarkRepository extension unless a real product caller and ownership contract appear.

## Retired AppDatabase responsibilities

These architecture-cleanup candidates from the original inventory are complete:
- `AppDatabase.watchBookmarkItems()` -> **removed** by #281; `BookmarkReadStore` owns Bookmark aggregate reads.
- profile-relative path conversion -> **removed from AppDatabase** by #282; `ProfilePathResolver` owns it.
- `AppDatabase.watchSavedViewConfigs()` / saved-view tag aggregation -> **removed** by #283; `SavedViewReadStore` owns it.
- `AppDatabase.watchAllPhotos()` and duplicate Photo path reconstruction -> **removed** by #289; `PhotoReadStore` owns it.
- historical migration bodies v2-v16 -> **extracted** to migration helpers; AppDatabase keeps migration sequencing/wiring.

Do not reintroduce these responsibilities into the database root.

## Superseded duplicate visual presentation paths — original inventory complete

All four direct Bookmark visual duplicates identified in the original audit are retired:

| Path | Status | Canonical replacement / constraint |
| --- | --- | --- |
| `lib/widgets/notion_bookmark_card.dart` | **retired duplicate** — #294 | Uses `BookmarkVisualImage`; preserve card sizing/selection/open behavior. |
| `lib/widgets/bookmark_reverse_lookup_dialog.dart` | **retired duplicate** — #299 | Uses `BookmarkVisualImage`; management hosts pass repository explicitly. |
| `lib/views/bookmark_lifecycle_page.dart` visual rows | **retired duplicate** — Object #296 | Uses canonical Bookmark visual component. |
| `lib/views/bookmark_unified_stage1_page.dart` List/Table image helper | **retired duplicate** — #324 | Delegates to `BookmarkVisualImage`; deterministic guard preserves host geometry. |

The whole files above are **not** superseded. Only their duplicated visual-resolution slices are retired until remaining host behavior has Object-first parity.

`BookmarkVisualImage` legitimately retains a legacy remote-thumbnail fallback. That fallback is a compatibility boundary, not another duplicate presentation path.

## Canonical URL adoption status

Legacy `bookmarks.url` remains compatibility data. Canonical presentation has advanced host by host through `BookmarkUrlResolver`:
- #317 lifecycle URL display/opening;
- #320 reverse lookup;
- #322 Notion bookmark card;
- #341 Stage1 URL presentation/opening;
- #360 Bookmark List metadata.

This is substantial presentation convergence, **not storage retirement**. Remaining direct legacy URL reads/writes can still be legitimate in editing, lifecycle persistence, import/export, backup/migration or unconverted compatibility hosts. Before deleting/narrowing the column or write path, prove all production reads/writes and data portability requirements have replacements.

Ambiguous/malformed Relation state must continue to fail closed to compatibility fallback rather than being repaired from presentation code.

## Recent compatibility-boundary cleanup

### Bookmark backlinks — #408
`BacklinkRepository` no longer reaches through `BookmarkLifecycleStore` to `AppDatabase` or watches the complete legacy Bookmark relation table. It delegates focused reads through `BookmarkRepository.watchRelationsForBookmark(bookmarkId)` while preserving existing Bookmark-facing mapping/sorting and link/unlink semantics.

This is a boundary reduction, not permission to redesign or delete canonical Relation infrastructure.

### Bookmark FTS — #422
`FullTextSearchRepository.rebuild()` and `refreshBookmark()` no longer duplicate the complete Bookmark -> FTS projection SQL. One private insert implementation now owns title/url/description/tags/people/collections projection.

This is responsibility/duplication cleanup only. FTS schema, ranking, prefix query, transaction boundaries and trash filtering were intentionally preserved. **Issue #414** tracks a separate possible stale-token correctness problem after focused refresh.

## Remaining architecture cleanup candidates

### Repository-as-service-locator usage
Several consumers still obtain lower-level capabilities through `BookmarkRepository`. Replacing every constructor at once would create churn. Fix only when a real caller can be simplified and a responsibility can be deleted or moved behind an existing focused boundary.

Attachment UI has multiple direct `BookmarkAttachmentStore` constructions through repository-owned database access. Do not solve this by making `BookmarkRepository` a broader service locator; wait for a focused boundary that removes real responsibility.

### GenericDatabasePage hotspot
Refactor progress includes:
- #310 — read/projection state loading -> `GenericDatabasePageStateLoader`;
- #323 — low-level Store/Service graph construction -> `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflow orchestration and layout-specific host code. Continue as small focused slices only. Avoid monolithic controller rewrites and do not hand-reconstruct the large host merely to work around tooling limitations.

### User-visible failure boundaries
GlobalSearch, Settings, attachment import and bootstrap/Profile-switch raw-error boundaries are already stabilized. Re-audit before assuming an old raw-error candidate still exists. Prefer a small independently testable host; do not overlap active Object-owned shared hotspots.

### Profile recovery policy
`ProfileManager` intentionally fails soft when persisted profile-registry metadata cannot be decoded, but the fallback can affect which data location is selected. Diagnostic privacy is already sanitized; any fallback-selection behavior change still requires an explicit recovery/data-safety policy.

## No-new-dependency review checklist

Before merging new Object/Database/View work, search the diff for newly added production references to:
- `BookmarkItem`
- `BookmarkRepository`
- `bookmark_repository.dart`
- direct legacy `thumbnail` / `coverPhoto` rendering
- direct `bookmarks.url` reads/writes outside an explicit compatibility/migration path

A match is not automatically wrong, but the PR must classify it and state the retirement condition.

## Next removal order
1. Continue true production caller-zero audits and delete whole shims/modules only when independent behavior coverage exists.
2. Re-audit remaining direct Bookmark URL presentation/edit/write callers; migrate only when an existing canonical replacement preserves the host contract.
3. Continue Object-first Photo/Image and Bookmark/Image convergence from existing bridges; do not create a second compatibility bridge or destructively remove legacy Photo storage.
4. Re-audit Bookmark query/search/backlink/detail presentation only where generic Object/Database/Relation behavior has proven parity; do not replace live behavior just to reduce reference counts.
5. Continue GenericDatabasePage P1 decomposition and repository/composition cleanup as measurable responsibility/LOC reductions.
6. Treat #414 as search correctness work, not as a pretext for changing behavior inside Issue #225 refactors.