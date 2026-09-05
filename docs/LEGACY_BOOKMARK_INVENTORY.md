# Legacy Bookmark production inventory

Issue #225 tracks retirement of Bookmark-era dependencies without deleting still-live behavior prematurely. This inventory classifies **production** consumers; tests are evidence/coverage and are not migration targets by themselves.

Classification meanings:

- **canonical product behavior** — still owns a real Bookmark feature today; do not delete until an Object-first replacement has parity.
- **compatibility bridge** — intentionally connects a live Bookmark host to newer Object/Weblink/Image/Relation infrastructure; narrow it, then remove only when the old host disappears.
- **migration-only** — historical/import/export compatibility that may legitimately understand legacy storage but should not leak into new product paths.
- **superseded duplicate** — duplicate presentation/read logic for which a canonical replacement already exists; highest-value deletion/migration target.

This is a living inventory. Re-run code search before deletion because the Object lane is active.

## `BookmarkItem` / `BookmarkRepository` ownership map

| Consumer | Classification | Why it still exists / retirement condition |
| --- | --- | --- |
| `lib/data/bookmark_repository.dart` | canonical product behavior | Root repository for existing Bookmark lifecycle/query/metadata flows. Shrink only as callers move to Object-first services; do not add new Object-feature methods here. |
| `lib/data/app_database_schema.dart` (`BookmarkItem`) | canonical product behavior | Active compatibility/domain shape for still-live Bookmark rows. Storage/model deletion is explicitly deferred until production callers are gone. |
| `lib/data/app_database.dart` (`watchBookmarkItems`) | canonical product behavior, architecture hotspot | Still produces screen-ready Bookmark aggregates. Candidate to move behind Repository/Store ownership without changing returned semantics. |
| `lib/views/bookmark_query_engine.dart` | canonical product behavior | Current Bookmark-specific filtering/query behavior. Replace only when generic Database/View querying covers the same user-facing host. |
| `lib/views/bookmark_lifecycle_page.dart` | canonical product behavior | Inbox/archive/trash remain live Bookmark UX. Do not remove before equivalent Object-first lifecycle behavior is proven. |
| `lib/views/global_search_page.dart` | canonical product behavior | Current global search consumes Bookmark aggregates. Migration target once Object-first global search has feature parity. |
| `lib/services/auto_organize_service.dart` | canonical product behavior | Bookmark automation still accepts Bookmark aggregates. Avoid extending this API for new Object-only features. |
| `lib/services/bookmark_transfer_service.dart` | migration-only / compatibility | Import/export must understand persisted Bookmark data. This is a legitimate legacy boundary; keep it isolated from new Object presentation. |
| `lib/data/saved_view_extensions.dart` | compatibility bridge | Saved Bookmark-era view duplication hangs off `BookmarkRepository`. Candidate for ownership cleanup when saved-view behavior is fully Database/View-native. |
| `lib/repositories/full_text_search_repository.dart` | compatibility bridge | Uses the Bookmark repository as a root/composition handle. Candidate for narrower database/search dependency, but behavior should remain unchanged. |
| `lib/repositories/backlink_repository.dart` | compatibility bridge | Bookmark-facing backlink model remains while canonical Relation backlinks are already mature. Retire presentation callers before deleting bridge behavior. |
| `lib/widgets/bookmark_relation_section.dart` | compatibility bridge | Bookmark detail UI still exposes relations/backlinks through Bookmark-centric inputs. Do not redesign Relation semantics here. |
| `lib/widgets/person_role_properties.dart` | canonical product behavior / compatibility | Bookmark-specific person-role presentation remains live; migrate only when equivalent generic Object Property/Relation rendering covers the host. |
| `lib/widgets/bookmark_detail_panel.dart` | canonical product behavior / compatibility | Still-live Bookmark detail. Managed visual migration is already partly integrated; continue removing direct legacy metadata reads without changing detail behavior. |
| `lib/widgets/bookmark_visual_image.dart` | compatibility bridge | Shared Bookmark host widget that delegates visual choice to canonical managed visual resolution with legacy fallback. Keep until all old Bookmark visual hosts disappear. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility bridge | Explicit bridge: user cover -> canonical Bookmark→Weblink→Image managed visual -> legacy thumbnail fallback. Do not bypass it with new direct thumbnail reads. |
| `lib/widgets/global_file_drop_layer.dart` | canonical product behavior / composition | Receives `BookmarkRepository` for current import/drop flows. Narrow composition later; not a deletion target by itself. |
| `lib/views/settings_page.dart` | canonical product behavior / composition | Repository is used for backup/export/settings operations. Prefer narrower application services when those flows are touched. |
| `lib/views/tag_management_page.dart` | canonical product behavior | Current management host still depends on Bookmark repository capabilities. Migrate incrementally only where Object-first parity exists. |
| `lib/views/people_management_page.dart` | canonical product behavior | Current management host combines people and Bookmark aggregates. Large hotspot; avoid broad rewrite while pursuing smaller ownership extractions. |
| `lib/views/photo_management_page.dart` | canonical product behavior / legacy host | Current photo-management host remains live even though Image Objects now exist. Treat duplicate image presentation as migration candidates, not the whole page as deletable. |
| `lib/views/collection_management_page.dart` | canonical product behavior | Current collection management still consumes Bookmark data. Remove only after generic Database collection behavior covers the same workflow. |
| `lib/views/app_shell.dart` | composition hotspot | Passes `BookmarkRepository` through many legacy/current screens. This is a future composition-boundary target, but broad edits require an open-PR conflict check. |
| `lib/main.dart` | composition root | Constructing the root Bookmark repository is expected while live Bookmark features remain. New Object features should not use this as justification to deepen Bookmark coupling. |

## Superseded duplicate presentation/read paths

These are the first deletion/migration candidates because the canonical managed visual infrastructure already exists.

| Path | Duplicate behavior | Canonical replacement / constraint |
| --- | --- | --- |
| `lib/widgets/notion_bookmark_card.dart` | Directly renders `coverPhoto` / remote `thumbnail`. | Consume `BookmarkVisualImage` / `BookmarkVisualResolver`; preserve card sizing, selection and click behavior. |
| `lib/widgets/bookmark_reverse_lookup_dialog.dart` | Direct `Image.file(bookmark.coverPhoto...)` then `Image.network(bookmark.thumbnail...)`. | Use the same managed visual component/resolver; preserve best-effort visual fallback. |
| `lib/views/bookmark_unified_stage1_page.dart` image helper(s) | Contains direct legacy cover rendering in addition to the newer shared visual path elsewhere. | Replace only the duplicate image-resolution slice; do not broadly rewrite the 50+ KB page in the same PR. |

The entire files above are **not** automatically superseded. Only the duplicated visual-resolution paths are classified as superseded until the rest of their host behavior has Object-first parity.

## Architecture cleanup candidates that are not yet deletions

### `AppDatabase.watchBookmarkItems()`

`AppDatabase` still builds `BookmarkItem` composites. The behavior is live, but the ownership is wrong for the target architecture. Move the aggregation behind Repository/Store code in a semantics-preserving slice with focused tests; keep schema/migration wiring in `AppDatabase`.

### Repository-as-service-locator usage

Several consumers obtain lower-level database/store capabilities through `BookmarkRepository` rather than receiving a focused dependency. This is a composition smell, but replacing every constructor at once would create churn. Fix it only when a real caller can be simplified without adding an abstraction used by only one host.

## No-new-dependency review checklist

Before merging new Object/Database/View work, search the diff for newly added production references to:

- `BookmarkItem`
- `BookmarkRepository`
- `bookmark_repository.dart`
- direct legacy `thumbnail` / `coverPhoto` rendering
- direct `bookmarks.url` reads/writes outside an explicit compatibility/migration path

A match is not automatically wrong, but the PR must be able to classify it using the categories above and state the retirement condition.

## Next removal order

1. Replace direct legacy visual rendering in the smallest non-conflicting host with `BookmarkVisualImage` / canonical managed resolution.
2. Remove the now-unused duplicate helper/imports and add a focused regression test.
3. Repeat for reverse lookup / Stage1 only after checking active Object PR ownership.
4. Separately move `AppDatabase` Bookmark aggregation behind existing Repository/Store ownership.
5. Re-run this inventory and delete whole legacy modules only when production reference count reaches zero.
