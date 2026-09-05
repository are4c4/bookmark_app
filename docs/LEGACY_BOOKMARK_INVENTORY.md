# Legacy Bookmark production inventory

Issue #225 tracks retirement of Bookmark-era dependencies without deleting still-live behavior prematurely. This inventory classifies **production** consumers; tests are evidence, not migration targets by themselves.

Classification meanings:
- **canonical product behavior** — still owns a real Bookmark feature today; do not delete until Object-first replacement has parity.
- **compatibility bridge** — intentionally connects a live Bookmark host to newer Object/Weblink/Image/Relation infrastructure.
- **migration-only** — historical/import/export compatibility that may legitimately understand legacy storage.
- **superseded duplicate** — duplicate presentation/read logic for which a canonical replacement already exists; delete/migrate first.

Re-run code search before deletion because the Object lane is active.

## `BookmarkItem` / `BookmarkRepository` ownership map

| Consumer | Classification | Current ownership / retirement condition |
| --- | --- | --- |
| `lib/data/bookmark_repository.dart` | canonical product behavior | Root repository for still-live Bookmark lifecycle/query/metadata flows. New Object-only features should not expand it. |
| `lib/data/app_database_schema.dart` (`BookmarkItem`) | canonical product behavior | Compatibility/domain shape for live Bookmark rows. Delete only after production callers disappear. |
| `lib/data/bookmark_read_store.dart` | canonical product behavior / compatibility read boundary | Owns the screen-ready Bookmark aggregation formerly implemented by `AppDatabase.watchBookmarkItems()`. Keep while Bookmark hosts need the aggregate shape; do not move the joins back into AppDatabase. |
| `lib/views/bookmark_query_engine.dart` | canonical product behavior | Bookmark-specific filtering remains live until generic Database/View querying covers the same host. |
| `lib/views/bookmark_lifecycle_page.dart` | canonical product behavior / compatibility host | Inbox/archive/trash remain live. Visual rendering is canonicalized; Object #312 is moving displayed/opened URL preference toward canonical Weblink data while legacy URL remains fallback. |
| `lib/views/global_search_page.dart` | canonical product behavior | Current global search consumes Bookmark aggregates. Retire after Object-first global search parity. |
| `lib/services/auto_organize_service.dart` | canonical product behavior | Bookmark automation remains live; do not extend for Object-only workflows. |
| `lib/services/bookmark_transfer_service.dart` | migration-only / compatibility | Import/export legitimately understands persisted Bookmark data. Keep isolated. |
| `lib/data/saved_view_extensions.dart` | compatibility bridge | Saved Bookmark-era view behavior still hangs off BookmarkRepository; candidate once Database/View-native behavior has parity. |
| `lib/repositories/full_text_search_repository.dart` | compatibility bridge | Repository is still a composition handle. Narrow when a real caller can use a focused search dependency. |
| `lib/repositories/backlink_repository.dart` | compatibility bridge | Bookmark-facing backlink model remains while canonical Relation backlinks are mature. Retire presentation callers first. |
| `lib/widgets/bookmark_relation_section.dart` | compatibility bridge | Bookmark detail exposes Relation/backlink information through Bookmark-centric inputs; do not redesign Relation here. |
| `lib/widgets/person_role_properties.dart` | canonical product behavior / compatibility | Bookmark-specific person-role presentation remains live. |
| `lib/widgets/bookmark_detail_panel.dart` | canonical product behavior / compatibility | Still-live Bookmark detail. Managed visual migration is integrated; continue retiring direct legacy metadata reads only when canonical replacement exists. |
| `lib/widgets/bookmark_visual_image.dart` | compatibility bridge | Shared Bookmark host widget delegating visual choice to canonical managed visual resolution with legacy fallback. Keep until old Bookmark visual hosts disappear. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility bridge | Explicit precedence bridge: user cover -> canonical Bookmark→Weblink→Image visual -> legacy thumbnail fallback. New presentation must not bypass it. |
| `lib/widgets/global_file_drop_layer.dart` | canonical product behavior / composition | Current import/drop composition still receives BookmarkRepository. Narrow only with a real focused replacement. |
| `lib/views/settings_page.dart` | canonical product behavior / composition | Backup/export/settings still use repository capabilities. |
| `lib/views/tag_management_page.dart` | canonical product behavior | Current management host still uses Bookmark capabilities; reverse-lookup image presentation is now canonical. |
| `lib/views/people_management_page.dart` | canonical product behavior | Large management hotspot combining People/Bookmark behavior; reverse-lookup image presentation is now canonical. |
| `lib/views/photo_management_page.dart` | canonical product behavior / legacy host | Photo-management remains live; read/path aggregation has moved to `PhotoReadStore`, and reverse-lookup visual is canonical. |
| `lib/views/collection_management_page.dart` | canonical product behavior | Collection management still consumes Bookmark data. |
| `lib/views/app_shell.dart` | composition hotspot | Passes BookmarkRepository through many live/compatibility screens. Future boundary target; always check open PR ownership. |
| `lib/main.dart` | composition root | Root Bookmark repository construction remains expected while live Bookmark features exist. |

## Retired AppDatabase responsibilities

These were architecture-cleanup candidates in the original inventory and are now complete:
- `AppDatabase.watchBookmarkItems()` -> **removed** by #281; `BookmarkReadStore` owns Bookmark aggregate reads.
- profile-relative path conversion -> **removed from AppDatabase** by #282; `ProfilePathResolver` owns it.
- `AppDatabase.watchSavedViewConfigs()` / saved-view tag aggregation -> **removed** by #283; `SavedViewReadStore` owns it.
- `AppDatabase.watchAllPhotos()` and duplicate Photo path reconstruction -> **removed** by #289; `PhotoReadStore` owns it.
- historical migration bodies v2-v16 -> **extracted** to migration helpers; AppDatabase keeps migration sequencing/wiring.

Do not reintroduce these responsibilities into the database root.

## Superseded duplicate presentation/read paths

The original direct Bookmark visual duplicates have been retired or are in the final active slice:

| Path | Status | Canonical replacement / constraint |
| --- | --- | --- |
| `lib/widgets/notion_bookmark_card.dart` | **retired duplicate** — #294 merged | Uses `BookmarkVisualImage`; preserve card sizing/selection/click behavior. |
| `lib/widgets/bookmark_reverse_lookup_dialog.dart` | **retired duplicate** — #299 merged | Uses `BookmarkVisualImage`; Tag/Photo/People hosts pass repository explicitly. |
| `lib/views/bookmark_lifecycle_page.dart` visual rows | **retired duplicate** — Object #296 merged | Uses canonical Bookmark visual component. |
| `lib/views/bookmark_unified_stage1_page.dart` List/Table image helper | **active final duplicate** — PR #304 | Production helper is replaced by `BookmarkVisualImage`; current blocker is the focused full-page widget test lifecycle/hang, not known production behavior. |

The whole files above are **not** superseded. Only the duplicated visual-resolution slices are retired until their remaining host behavior has Object-first parity.

## Remaining architecture cleanup candidates

### Repository-as-service-locator usage
Several consumers obtain lower-level database/store capabilities through `BookmarkRepository`. Replacing every constructor at once would create churn. Fix only when a real caller can be simplified and a responsibility can be deleted or moved behind an existing focused boundary.

### GenericDatabasePage hotspot
Refactor #310 moved read/projection loading into `GenericDatabasePageStateLoader`. Continue as small focused slices: mutation/composition/rendering responsibilities can move only when tests preserve existing Object/Database/View behavior. Avoid monolithic controller rewrites and coordinate with Object-lane edits to the same host.

### Remaining legacy URL compatibility
Legacy `bookmarks.url` remains compatibility data. Object #312 is adding a read-only canonical Weblink URL preference for Bookmark lifecycle presentation/opening, with legacy fallback. Do not delete the legacy column/value until every production read/write and import/export path has a proven replacement and migration policy.

## No-new-dependency review checklist

Before merging new Object/Database/View work, search the diff for newly added production references to:
- `BookmarkItem`
- `BookmarkRepository`
- `bookmark_repository.dart`
- direct legacy `thumbnail` / `coverPhoto` rendering
- direct `bookmarks.url` reads/writes outside an explicit compatibility/migration path

A match is not automatically wrong, but the PR must classify it and state the retirement condition.

## Next removal order
1. Finish #304 or replace its hanging heavyweight regression with a deterministic smaller test; do not alter production semantics to satisfy the test.
2. Re-run production search for direct `thumbnail` / `coverPhoto` presentation after #304 and delete only genuinely duplicated rendering.
3. Follow Object-first URL/presentation parity (including #312) and narrow legacy URL reads only after canonical Weblink resolution is proven in each live host.
4. Continue GenericDatabasePage P1 decomposition and repository/composition cleanup as measurable responsibility reductions.
5. Delete whole legacy modules only when production reference count reaches zero and import/migration requirements are explicitly handled.
