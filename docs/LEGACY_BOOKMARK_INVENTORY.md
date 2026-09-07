# Legacy Bookmark production inventory

Issue #225 tracks retirement of Bookmark-era dependencies without deleting still-live behavior prematurely. This inventory classifies **production** consumers; tests are evidence, not migration targets by themselves.

Classification meanings:
- **canonical product behavior** — still owns a real Bookmark feature today; do not delete until Object-first replacement has parity.
- **compatibility bridge** — intentionally connects a live Bookmark host to newer Object/Weblink/Image/Relation infrastructure.
- **migration-only** — historical/import/export compatibility that may legitimately understand legacy storage.
- **superseded duplicate** — duplicate presentation/read logic for which a canonical replacement already exists; delete/migrate first.
- **retired caller-zero module** — production reference count reached zero and the module was removed rather than kept as a speculative wrapper.

Re-run code search and inspect current files before deletion because parallel Object/Database/View/Primitive/Search/Storage work can make old classifications stale quickly.

## `BookmarkItem` / `BookmarkRepository` ownership map

| Consumer | Classification | Current ownership / retirement condition |
| --- | --- | --- |
| `lib/data/bookmark_repository.dart` | canonical product behavior | Root repository for still-live Bookmark lifecycle/query/metadata flows. New Object-only features must not expand it. |
| `lib/data/app_database_schema.dart` (`BookmarkItem`) | canonical product behavior | Compatibility/domain shape for live Bookmark rows. Delete only after production callers disappear and migration/import/export handling is explicit. |
| `lib/data/bookmark_read_store.dart` | canonical product behavior / compatibility read boundary | Owns screen-ready Bookmark aggregation formerly implemented by `AppDatabase.watchBookmarkItems()`. Keep while Bookmark hosts need the aggregate shape. |
| `lib/views/bookmark_query_engine.dart` | canonical product behavior | Bookmark-specific filtering remains live until generic Database/View querying covers the same host. |
| `lib/views/bookmark_lifecycle_page.dart` | canonical product behavior / compatibility host | Inbox/archive/trash remain live. Visual rendering is canonicalized and canonical Weblink URL is preferred with legacy fallback. |
| `lib/views/global_search_page.dart` | compatibility entrypoint | Since Search #629, the live surface delegates to canonical `ObjectGlobalSearchPage` / `ObjectGlobalSearchService`. The wrapper still accepts `BookmarkRepository` from `AppShell`; retire only when composition can pass the canonical search context directly without hotspot churn. |
| `lib/services/auto_organize_service.dart` | canonical product behavior | Bookmark automation remains live; do not extend it for Object-only workflows. |
| `lib/services/bookmark_transfer_service.dart` | migration-only / compatibility | Import/export legitimately understands persisted Bookmark data. Keep isolated. |
| `lib/repositories/backlink_repository.dart` | compatibility bridge | Bookmark-facing backlink model remains live through Bookmark Relation presentation. Delete only after its production presentation callers retire. |
| `lib/widgets/bookmark_relation_section.dart` | compatibility bridge | Bookmark detail exposes Relation/backlink information through Bookmark-centric inputs; do not redesign canonical Relation here. |
| `lib/widgets/bookmark_reorderable_properties.dart` | canonical product behavior / compatibility | Still-live Bookmark Property/Person-role host after #472 retired the unused `PersonRoleProperties` duplicate. |
| `lib/widgets/bookmark_detail_panel.dart` | canonical product behavior / compatibility | Still-live Bookmark detail. Move metadata/URL responsibilities only with proven replacement parity. |
| `lib/widgets/bookmark_visual_image.dart` | compatibility bridge | Shared Bookmark-host visual boundary: user cover -> canonical managed visual -> legacy thumbnail fallback. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility bridge | Read-only canonical/legacy visual precedence resolver. New presentation must not bypass it. |
| `lib/services/bookmark_url_resolver.dart` | compatibility bridge | Read-only canonical Bookmark→Weblink URL preference with legacy fallback. |
| `lib/widgets/global_file_drop_layer.dart` | canonical product behavior / composition | Current import/drop composition still receives `BookmarkRepository`. Narrow only with a real focused replacement. |
| `lib/widgets/bookmark_attachment_section.dart` | canonical product behavior / compatibility | Attachment/PDF enrichment remains Bookmark-owned. |
| `lib/views/settings_page.dart` | canonical product behavior / composition | Backup/export/settings still use repository capabilities. |
| `lib/views/tag_management_page.dart` | canonical product behavior | Current management host still uses Bookmark capabilities; reverse-lookup image presentation is canonical. |
| `lib/views/people_management_page.dart` | canonical product behavior | Large management hotspot combining People/Bookmark behavior. |
| `lib/views/photo_management_page.dart` | canonical product behavior / legacy host | Photo management remains live; read/path aggregation has moved to `PhotoReadStore`. #695 removed only its temporary Database-presentation shim imports, not Photo/Bookmark behavior or persistence authority. |
| `lib/views/collection_management_page.dart` | canonical product behavior | Collection management still consumes Bookmark data; #687 removed only its temporary Database-presentation shim imports, not Bookmark behavior. |
| `lib/views/app_shell.dart` | composition hotspot | Passes `BookmarkRepository` through multiple live/compatibility screens. Always check open PR ownership. |
| `lib/main.dart` | composition root | Root Bookmark repository construction remains expected while live Bookmark features exist. |

## Retired caller-zero modules / paths

### `lib/data/saved_view_extensions.dart` — #417
`SavedViewDuplication.duplicateSavedView(...)` had zero production callers; #417 removed the extension and its dead-only test instead of keeping a speculative wrapper.

### `lib/widgets/person_role_properties.dart` — #472
`PersonRoleProperties` reached zero production callers after Bookmark detail/property behavior converged on `BookmarkReorderableProperties` plus canonical Property-row components. #472 removed the widget and dead-only architecture test. Legacy Person-role persistence remains live elsewhere.

### Plain-text Object Body edit path — #586
After universal block-oriented Body editing landed, `ObjectDetailEditService.setPlainTextBody(...)` had no production caller and `ObjectBodyPlainTextAdapter` existed only for that dead method/tests. #586 removed the chain. Do not reintroduce paragraph/plain-text Body mutation beside the canonical block-oriented path.

### Legacy Bookmark-only FTS — #654
Search #629 routed live Global Search through canonical Object search. Current `GlobalSearchPage` is only a compatibility wrapper around `ObjectGlobalSearchPage`; `FullTextSearchRepository` had no production caller.

#654 therefore removed:
- `lib/repositories/full_text_search_repository.dart` (163 LOC);
- `test/full_text_search_query_test.dart`;
- `test/repositories/full_text_search_repository_projection_test.dart`;
- only the old Bookmark-FTS smoke test/import from `test/data_integrity_test.dart`.

PR #654 passed maintainability guards, Drift generation, Analyze and full Test. Canonical Object search retains focused stale-token/index regressions for title/aliases, Body, typed Properties, Relations, derived text and Weblink metadata.

Do not recreate a Bookmark-only FTS index as a compatibility layer. If a search capability is missing, add it to the canonical Object search path under Search ownership.

### `lib/widgets/detail_property_row.dart` re-export shim — #672
The legacy `DetailPropertyRow` shim reached zero production/test imports after Bookmark callers and widget tests moved to `lib/features/database/presentation/widgets/detail_property_row.dart`.

#672 removed the one-line re-export and lowered the CI shim-file ceiling from **5 to 4**. The historical `detail_property_row` name remains in the guard scanner intentionally so a future reintroduction is detected rather than silently recreating compatibility debt.

### `lib/widgets/database_page_toolbar.dart` re-export shim — #735
After Collection, Photo and People management moved to the canonical Database toolbar, repository-wide exact import audit found no remaining legacy toolbar-shim caller. #735 deleted the one-line re-export and lowered the shim-file ceiling **4 → 3**. The historical name remains guarded so the compatibility path cannot silently return.

## Retired AppDatabase responsibilities

These architecture-cleanup candidates are complete:
- `AppDatabase.watchBookmarkItems()` -> **removed** by #281; `BookmarkReadStore` owns Bookmark aggregate reads.
- profile-relative path conversion -> **removed from AppDatabase** by #282; `ProfilePathResolver` owns it.
- `AppDatabase.watchSavedViewConfigs()` / Saved View tag aggregation -> **removed** by #283; `SavedViewReadStore` owns it.
- `AppDatabase.watchAllPhotos()` and duplicate Photo path reconstruction -> **removed** by #289; `PhotoReadStore` owns it.
- historical migration bodies v2-v16 -> **extracted** to migration helpers; `AppDatabase` keeps migration sequencing/wiring.
- Bookmark favorite/status/rating/open-history mutations -> **moved** to `BookmarkEngagementStore` by #579.
- caller-zero Bookmark People batch methods plus `_peopleForBookmark` -> **removed** by #637.
- duplicate Tag hierarchy mutation -> **removed** by #705; `TagGroupStore.moveTag(...)` owns hierarchy mutation.
- unreachable `updateBookmarkFields(... personNames ...)` parameter/branch -> **removed** by #728; live People edits remain role-aware.

Do not reintroduce these responsibilities into the database root.

## Retired Bookmark lifecycle / Repository seams
#642 removed caller-zero `BookmarkLifecycleState`, `states()`, `watchStates()` and synchronous `genre()`. Live lifecycle mutations and `watchGenre()` remain.

#731 removed caller-zero `BookmarkRepository.setBookmarkPeopleFromDatabase(...)`, empty `BookmarkLifecycleStore.remove(...)`, and the sole no-op permanent-delete call. Permanent deletion still performs attachment cleanup before the actual Bookmark row deletion, and `data_integrity_test.dart` covers attachment bytes, attachment rows and Bookmark row removal.

`BookmarkLifecycleStore.dispose()` is **not** caller-zero: #736 initially attempted to retire the empty method, but CI exposed eight production callers in `lib/main.dart`. #736 was closed without merge. Treat the method as a live bootstrap/lifecycle contract until a naturally scoped composition cleanup proves otherwise.

## Superseded duplicate visual presentation paths — original inventory complete

All four direct Bookmark visual duplicates identified in the original audit are retired:

| Path | Status | Canonical replacement / constraint |
| --- | --- | --- |
| `lib/widgets/notion_bookmark_card.dart` | **retired duplicate slice** — #294 | Uses `BookmarkVisualImage`; preserve card sizing/selection/open behavior. |
| `lib/widgets/bookmark_reverse_lookup_dialog.dart` | **retired duplicate slice** — #299 | Uses `BookmarkVisualImage`; management hosts pass repository explicitly. |
| `lib/views/bookmark_lifecycle_page.dart` visual rows | **retired duplicate slice** — Object #296 | Uses canonical Bookmark visual component. |
| `lib/views/bookmark_unified_stage1_page.dart` List/Table image helper | **retired duplicate slice** — #324 | Delegates to `BookmarkVisualImage`; deterministic guard preserves host geometry. |

The whole files above are not superseded. Only duplicated visual-resolution slices are retired until remaining host behavior has Object-first parity.

`BookmarkVisualImage` legitimately retains a legacy remote-thumbnail fallback. That fallback is a compatibility boundary, not another duplicate presentation path.

## Canonical URL adoption status
Legacy `bookmarks.url` remains compatibility data. Canonical presentation has advanced host by host through `BookmarkUrlResolver`, including lifecycle, reverse lookup, Notion bookmark card, Stage1 and Bookmark list metadata.

This is substantial presentation convergence, **not storage retirement**. Direct legacy URL reads/writes may still be legitimate in editing, lifecycle persistence, import/export, backup/migration or unconverted compatibility hosts. Before deleting/narrowing the column or write path, prove all production reads/writes and data portability requirements have replacements.

Ambiguous/malformed Relation state must continue to fail closed to compatibility fallback rather than being repaired from presentation code.

## Recent compatibility-boundary cleanup

### Bookmark backlinks — #408
`BacklinkRepository` no longer reaches through `BookmarkLifecycleStore` to `AppDatabase` or watches the complete legacy Bookmark relation table. It delegates focused reads through `BookmarkRepository.watchRelationsForBookmark(bookmarkId)` while preserving existing Bookmark-facing mapping/sorting and link/unlink semantics.

This is boundary reduction, not permission to redesign/delete canonical Relation infrastructure.

### Global Search — Search #629, Refactor #654
#629 switched live Global Search from Bookmark-only FTS to canonical Object search while retaining a thin `GlobalSearchPage(repository: ...)` compatibility entrypoint for the shell. #654 then retired the now-caller-zero Bookmark FTS implementation and dead-only tests.

The remaining `GlobalSearchPage` wrapper is composition debt, not a second search implementation.

## Remaining architecture cleanup candidates

### Repository-as-service-locator usage
Several consumers still obtain lower-level capabilities through `BookmarkRepository`. Replacing every constructor at once would create churn. Fix only when a real caller can be simplified and a responsibility can be deleted or moved behind an existing focused boundary.

Attachment UI still has lower-level store/service composition tied to Bookmark hosts. Do not solve this by making `BookmarkRepository` broader; wait for a focused boundary that removes responsibility.

### Temporary Database-presentation re-export shims
Three legacy re-export shim files remain under `lib/widgets/`:
- `database_view_tabs.dart`;
- `database_create_tiles.dart`;
- `resizable_detail_pane.dart`.

Canonical implementations live under `lib/features/database/presentation/widgets/`. #687 moved Collection management off four shim imports (**17 → 13**), #695 did the same for Photo management (**13 → 9**), and #707 moved People management off its four shim imports (**9 → 5**). #735 then deleted the caller-zero toolbar shim and lowered the shim-file ceiling **4 → 3**.

The remaining five shim imports are concentrated in two large/shared hosts: `GenericDatabasePage` has create-tiles, view-tabs and resizable-pane imports; Stage1 has create-tiles and view-tabs imports. Do not reconstruct either host solely to lower a metric. Retire each shim only when all callers can be moved naturally through patch-sized edits.

### GenericDatabasePage hotspot
Refactor progress includes:
- #310 — read/projection state loading -> `GenericDatabasePageStateLoader`;
- #323 — low-level Store/Service graph construction -> `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflow orchestration and layout-specific host code. Continue as small focused slices coordinated with Database/View work.

### User-visible failure boundaries
Global Search, Settings, attachment import, bootstrap/Profile-switch and Database Property-add raw-error boundaries have been stabilized in focused slices. #745 additionally guards canonical `lib/features/**/presentation/` from directly interpolating caught exception variables into strings while allowing typed forwarding such as `onError(error)`.

Legacy `lib/views/` / `lib/widgets/` still contain raw-error debt. Re-audit before assuming an old candidate still exists, and prefer naturally scoped regression-backed edits rather than reconstructing large shared hosts solely to replace one string.

### Profile recovery policy
`ProfileManager` intentionally fails soft when persisted profile-registry metadata cannot be decoded, but fallback can affect selected data location. Diagnostic privacy is sanitized; behavior changes still require explicit Storage/Vault recovery policy.

## No-new-dependency review checklist
Before merging new Object/Database/View work, search the diff for newly added production references to:
- `BookmarkItem`;
- `BookmarkRepository` / `bookmark_repository.dart`;
- direct legacy `thumbnail` / `coverPhoto` rendering;
- direct `bookmarks.url` reads/writes outside explicit compatibility/migration paths;
- direct feature-presentation `AppDatabase` imports;
- presentation `workspaceStore.database` reach-through;
- direct caught-error string interpolation under canonical feature presentation.

A match is not automatically wrong outside the explicitly guarded feature boundaries, but the PR must classify it and state the retirement condition. `lib/features/**` is additionally protected by the feature legacy-dependency and feature-presentation error-privacy guards.

## Next removal order
1. Continue true production caller-zero audits and delete whole modules/shims only when independent canonical coverage exists.
2. Ratchet the remaining Database-presentation shim imports below **5** only through naturally patch-sized caller changes; delete a shim only at true caller-zero.
3. Re-audit remaining Bookmark URL/detail/backlink presentation only where Object/Database/Relation parity is proven.
4. Continue GenericDatabasePage P1 decomposition as measurable responsibility/LOC reductions, coordinated with Database/View lane ownership.
5. Continue Object-first Photo/Image and Bookmark/Image convergence through existing bridges; do not destructively remove legacy Photo storage.
6. Treat bootstrap lifecycle seams such as `BookmarkLifecycleStore.dispose()` as live until current production callers are intentionally migrated in a naturally scoped composition cleanup.
