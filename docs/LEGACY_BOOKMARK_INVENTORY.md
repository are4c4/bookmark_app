# Legacy Bookmark production inventory

Issue #225 tracks retirement of Bookmark-era dependencies without deleting still-live behavior prematurely. This inventory classifies **production** consumers; tests are evidence, not migration targets by themselves.

Classification meanings:
- **canonical product behavior** — still owns a real Bookmark feature today; do not delete until Object-first replacement has parity.
- **compatibility bridge** — intentionally connects a live Bookmark host to newer Object/Weblink/Image/Relation infrastructure.
- **migration-only** — historical/import/export compatibility that may legitimately understand legacy storage.
- **superseded duplicate** — duplicate presentation/read logic for which a canonical replacement already exists; delete/migrate first.

Re-run code search and inspect current files before deletion because the Object lane is active and GitHub Code Search can lag recent merges.

## `BookmarkItem` / `BookmarkRepository` ownership map

| Consumer | Classification | Current ownership / retirement condition |
| --- | --- | --- |
| `lib/data/bookmark_repository.dart` | canonical product behavior | Root repository for still-live Bookmark lifecycle/query/metadata flows. New Object-only features should not expand it. |
| `lib/data/app_database_schema.dart` (`BookmarkItem`) | canonical product behavior | Compatibility/domain shape for live Bookmark rows. Delete only after production callers disappear. |
| `lib/data/bookmark_read_store.dart` | canonical product behavior / compatibility read boundary | Owns the screen-ready Bookmark aggregation formerly implemented by `AppDatabase.watchBookmarkItems()`. Keep while Bookmark hosts need the aggregate shape; do not move joins back into AppDatabase. |
| `lib/views/bookmark_query_engine.dart` | canonical product behavior | Bookmark-specific filtering remains live until generic Database/View querying covers the same host. |
| `lib/views/bookmark_lifecycle_page.dart` | canonical product behavior / compatibility host | Inbox/archive/trash remain live. Visual rendering is canonicalized; Object #317 now prefers canonical Weblink URL for display/opening while legacy Bookmark URL remains compatibility fallback. |
| `lib/views/global_search_page.dart` | canonical product behavior | Current global search consumes Bookmark aggregates. Retire after Object-first global search parity. It still renders raw caught error text and is a focused stable-error-boundary candidate. |
| `lib/services/auto_organize_service.dart` | canonical product behavior | Bookmark automation remains live; do not extend for Object-only workflows. |
| `lib/services/bookmark_transfer_service.dart` | migration-only / compatibility | Import/export legitimately understands persisted Bookmark data. Keep isolated. |
| `lib/data/saved_view_extensions.dart` | compatibility bridge | Saved Bookmark-era view behavior still hangs off BookmarkRepository; candidate once Database/View-native behavior has parity. |
| `lib/repositories/full_text_search_repository.dart` | compatibility bridge | Repository is still a composition handle. Narrow when a real caller can use a focused search dependency. |
| `lib/repositories/backlink_repository.dart` | compatibility bridge | Bookmark-facing backlink model remains while canonical Relation backlinks are mature. Retire presentation callers first. |
| `lib/widgets/bookmark_relation_section.dart` | compatibility bridge | Bookmark detail exposes Relation/backlink information through Bookmark-centric inputs; do not redesign Relation here. |
| `lib/widgets/person_role_properties.dart` | canonical product behavior / compatibility | Bookmark-specific person-role presentation remains live. |
| `lib/widgets/bookmark_detail_panel.dart` | canonical product behavior / compatibility | Still-live Bookmark detail. Managed visual migration is integrated; continue retiring direct legacy metadata reads only when canonical replacement exists. |
| `lib/widgets/bookmark_visual_image.dart` | compatibility bridge | Shared Bookmark-host visual boundary: user cover -> canonical managed Bookmark→Weblink→Image visual -> legacy thumbnail fallback. Keep until old Bookmark hosts disappear. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility bridge | Read-only canonical/legacy precedence resolver. New presentation must not bypass it; remove only with the Bookmark compatibility hosts. |
| `lib/services/bookmark_url_resolver.dart` | compatibility bridge | Read-only canonical Bookmark→Weblink URL preference with legacy Bookmark URL fallback. Object #317/#320 consume it; Object #322 is the current Notion-card adoption slice. |
| `lib/widgets/global_file_drop_layer.dart` | canonical product behavior / composition | Current import/drop composition still receives BookmarkRepository. Narrow only with a real focused replacement. |
| `lib/views/settings_page.dart` | canonical product behavior / composition | Backup/export/settings still use repository capabilities. |
| `lib/views/tag_management_page.dart` | canonical product behavior | Current management host still uses Bookmark capabilities; reverse-lookup image presentation is canonical. |
| `lib/views/people_management_page.dart` | canonical product behavior | Large management hotspot combining People/Bookmark behavior; reverse-lookup image presentation is canonical. |
| `lib/views/photo_management_page.dart` | canonical product behavior / legacy host | Photo-management remains live; read/path aggregation has moved to `PhotoReadStore`, and reverse-lookup visual is canonical. |
| `lib/views/collection_management_page.dart` | canonical product behavior | Collection management still consumes Bookmark data. |
| `lib/views/app_shell.dart` | composition hotspot | Passes BookmarkRepository through many live/compatibility screens. Future boundary target; always check open PR ownership. |
| `lib/main.dart` | composition root | Root Bookmark repository construction remains expected while live Bookmark features exist. |

## Retired AppDatabase responsibilities

These architecture-cleanup candidates from the original inventory are complete:
- `AppDatabase.watchBookmarkItems()` -> **removed** by #281; `BookmarkReadStore` owns Bookmark aggregate reads.
- profile-relative path conversion -> **removed from AppDatabase** by #282; `ProfilePathResolver` owns it.
- `AppDatabase.watchSavedViewConfigs()` / saved-view tag aggregation -> **removed** by #283; `SavedViewReadStore` owns it.
- `AppDatabase.watchAllPhotos()` and duplicate Photo path reconstruction -> **removed** by #289; `PhotoReadStore` owns it.
- historical migration bodies v2-v16 -> **extracted** to migration helpers; AppDatabase keeps migration sequencing/wiring.

Do not reintroduce these responsibilities into the database root.

## Superseded duplicate visual presentation paths — original inventory complete

All four direct Bookmark visual duplicates identified in the original audit are now retired:

| Path | Status | Canonical replacement / constraint |
| --- | --- | --- |
| `lib/widgets/notion_bookmark_card.dart` | **retired duplicate** — #294 merged | Uses `BookmarkVisualImage`; preserve card sizing/selection/open behavior. |
| `lib/widgets/bookmark_reverse_lookup_dialog.dart` | **retired duplicate** — #299 merged | Uses `BookmarkVisualImage`; Tag/Photo/People hosts pass repository explicitly. |
| `lib/views/bookmark_lifecycle_page.dart` visual rows | **retired duplicate** — Object #296 merged | Uses canonical Bookmark visual component. |
| `lib/views/bookmark_unified_stage1_page.dart` List/Table image helper | **retired duplicate** — #324 merged | `_image(...)` delegates to `BookmarkVisualImage`; deterministic architecture guard preserves List `60x44` / Table `58x38` and prevents direct `Image.file` / `Image.network` reintroduction in the helper. |

The whole files above are **not** superseded. Only their duplicated visual-resolution slices are retired until their remaining host behavior has Object-first parity.

`BookmarkVisualImage` itself legitimately retains a legacy remote-thumbnail fallback. That fallback is a compatibility boundary, not another duplicate presentation path.

## Canonical URL adoption status

Legacy `bookmarks.url` remains compatibility data. Canonical presentation is being migrated host by host through `BookmarkUrlResolver`:

- **#317 merged** — Bookmark lifecycle URL display/opening prefers canonical Weblink URL and retains legacy Bookmark URL fallback;
- **#320 merged** — reverse lookup uses the same canonical preference;
- **#322 open at this checkpoint** — Notion bookmark-card URL display/opening is the active Object-owned slice.

Do not delete the legacy URL column/value until every production read/write plus import/export/backup requirement has a proven replacement and migration policy. Ambiguous/malformed Relation state must continue to fail closed to compatibility fallback rather than being repaired from presentation code.

## Remaining architecture cleanup candidates

### Repository-as-service-locator usage
Several consumers still obtain lower-level capabilities through `BookmarkRepository`. Replacing every constructor at once would create churn. Fix only when a real caller can be simplified and a responsibility can be deleted or moved behind an existing focused boundary.

### GenericDatabasePage hotspot
Refactor progress now includes:
- #310 — read/projection state loading -> `GenericDatabasePageStateLoader`;
- #323 — low-level Store/Service graph construction -> `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibilities include schema/database actions, Property-create/edit dialogs, and layout-specific host code. Continue as small focused slices only. Avoid monolithic controller rewrites and do not hand-reconstruct the 70+ KB host merely to work around tooling limitations.

### Raw user-visible implementation errors
`GlobalSearchPage` currently stores caught search/index errors and renders the caught Object directly as text. This is not a legacy-removal blocker but is a #225 failure-policy candidate: introduce a focused, testable stable-error state before replacing the raw message.

### Profile recovery policy
`ProfileManager` intentionally fails soft when persisted profile-registry metadata cannot be decoded, but the fallback can affect which data location is selected. Do not treat this as an ordinary silent-catch cleanup. Any behavior change requires an explicit recovery/data-safety policy.

## No-new-dependency review checklist

Before merging new Object/Database/View work, search the diff for newly added production references to:
- `BookmarkItem`
- `BookmarkRepository`
- `bookmark_repository.dart`
- direct legacy `thumbnail` / `coverPhoto` rendering
- direct `bookmarks.url` reads/writes outside an explicit compatibility/migration path

A match is not automatically wrong, but the PR must classify it and state the retirement condition.

## Next removal order
1. Follow Object-first canonical URL parity host by host: #317/#320 are merged, #322 is the current Notion-card slice.
2. Re-audit remaining Bookmark query/search/backlink/detail presentation only where generic Object/Database/Relation behavior has proven parity; do not replace live behavior just to reduce reference counts.
3. Continue GenericDatabasePage P1 decomposition and repository/composition cleanup as measurable responsibility/LOC reductions.
4. Replace raw user-visible implementation errors with focused stable error states where tests can preserve retry/failure behavior.
5. Delete whole legacy modules only when production reference count reaches zero and import/migration/backup requirements are explicitly handled.
