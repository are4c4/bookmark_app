# Legacy Bookmark production inventory

Issue #225 tracks retirement of Bookmark-era dependencies without deleting still-live behavior prematurely. This inventory classifies **production** consumers and compatibility data. Tests are evidence, not migration targets by themselves.

Classification meanings:
- **canonical product behavior** — still owns a real Bookmark feature today; do not delete until Object-first replacement has parity;
- **compatibility bridge** — intentionally connects a live Bookmark host to newer Object/Weblink/Image/Relation infrastructure;
- **migration-only / compatibility data** — historical/import/export/backup compatibility that may remain even after runtime APIs disappear;
- **superseded duplicate** — duplicate presentation/read logic for which a canonical replacement already exists;
- **retired caller-zero path** — production reference count reached zero and the path was removed instead of retained as a speculative wrapper.

Re-run code search and inspect current files before deletion. Parallel Object/Database/View/Primitive/Search/Storage work changes these classifications quickly, and GitHub code-search indexing can lag behind current `main`.

## `BookmarkItem` / `BookmarkRepository` ownership map

| Consumer | Classification | Current ownership / retirement condition |
| --- | --- | --- |
| `lib/data/bookmark_repository.dart` | canonical product behavior | Root repository for still-live Bookmark lifecycle/query/metadata flows. New Object-only features must not expand it. |
| `lib/data/app_database_schema.dart` (`BookmarkItem`) | canonical product behavior / compatibility shape | Live Bookmark aggregate/domain shape. Delete only after production callers disappear and migration/import/export handling is explicit. |
| `lib/data/bookmark_read_store.dart` | canonical product behavior / compatibility read boundary | Owns screen-ready Bookmark aggregation formerly implemented by `AppDatabase.watchBookmarkItems()`. |
| `lib/views/bookmark_query_engine.dart` | canonical product behavior | Bookmark-specific filtering remains live until generic Database/View querying covers the same host. |
| `lib/views/bookmark_lifecycle_page.dart` | canonical product behavior / compatibility host | Inbox/archive/trash remain live. Canonical visual/URL presentation is preferred with legacy fallback. |
| `lib/views/global_search_page.dart` | compatibility entrypoint | Live surface delegates to canonical Object search; wrapper remains composition debt while `AppShell` passes Bookmark context. |
| `lib/services/auto_organize_service.dart` | canonical product behavior | Bookmark automation remains live; do not extend it for Object-only workflows. |
| `lib/services/bookmark_transfer_service.dart` | migration-only / compatibility | Import/export legitimately understands persisted Bookmark data. |
| `lib/repositories/backlink_repository.dart` | compatibility bridge | Bookmark-facing backlink model remains live through Bookmark Relation presentation. |
| `lib/widgets/bookmark_relation_section.dart` | compatibility bridge | Bookmark detail exposes Relation/backlink information through Bookmark-centric inputs. Do not redesign canonical Relation here. |
| `lib/widgets/bookmark_reorderable_properties.dart` | canonical product behavior / compatibility | Still-live Bookmark Property/Person-role host. |
| `lib/widgets/bookmark_detail_panel.dart` | canonical product behavior / compatibility | Still-live Bookmark detail; canonical Weblink URL is preferred while Bookmark editing compatibility remains. |
| `lib/widgets/bookmark_visual_image.dart` | compatibility bridge | Shared Bookmark-host visual boundary: user cover -> canonical managed visual -> legacy thumbnail fallback. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility bridge | Read-only canonical/legacy visual precedence resolver. |
| `lib/services/bookmark_url_resolver.dart` | compatibility bridge | Read-only canonical Bookmark -> Weblink URL preference with legacy fallback. |
| `lib/widgets/global_file_drop_layer.dart` | canonical product behavior / composition | Current import/drop composition still receives `BookmarkRepository`. Narrow only with a real focused replacement. |
| `lib/widgets/bookmark_attachment_section.dart` | canonical product behavior / compatibility | Attachment/PDF enrichment remains Bookmark-owned. |
| `lib/views/settings_page.dart` | canonical product behavior / composition | Backup/export/settings still use repository capabilities. |
| `lib/views/tag_management_page.dart` | canonical product behavior | Current Tag management remains live; canonical Tag Object work does not make the legacy management surface caller-zero by itself. |
| `lib/views/people_management_page.dart` | canonical product behavior | Large management hotspot combining Person/Bookmark compatibility behavior. |
| `lib/views/photo_management_page.dart` | canonical product behavior / legacy host | Photo management remains live; read/path aggregation is behind `PhotoReadStore`. |
| `lib/views/collection_management_page.dart` | canonical product behavior | Collection management still consumes Bookmark capabilities. |
| `lib/views/app_shell.dart` | composition hotspot | Passes `BookmarkRepository` through multiple live/compatibility screens. Always check open PR ownership. |
| `lib/main.dart` | composition root | Root Bookmark repository construction remains expected while live Bookmark features exist. |

## Retired caller-zero modules / paths

### Saved View runtime compatibility API — #944 / #952
Legacy Saved View **runtime API** is retired, but legacy Saved View **data** is not.

#944 removed caller-zero Saved View read/write facade responsibilities from `BookmarkRepository` and caller-zero Workspace convenience APIs. #952 then removed the now-caller-zero:
- `lib/data/saved_view_read_store.dart`;
- `lib/data/saved_view_write_store.dart`;
- `SavedViewConfig` runtime DTO;
- Store-only tests that no longer represented a production boundary.

The following remain intentionally live compatibility contracts:
- `SavedViews`, `SavedViewTags`, `SavedViewWorkspaces` schema/tables;
- historical migrations and backup inclusion;
- `WorkspaceStore` initialization/delete reassignment for legacy Saved View workspace rows;
- `DatabaseViewStore.importLegacyBookmarkViews(...)`, which migrates persisted legacy Bookmark Saved Views into canonical Database Views;
- `TagGroupStore` accounting/rewrites for legacy Saved View tag references.

Do not recreate a legacy Saved View runtime Store/facade merely to manipulate old rows. New View behavior belongs to the canonical Database View model.

### Workspace convenience/observer helpers — #944 / #957
Caller-zero Workspace convenience APIs removed across the two slices include Saved View workspace helpers plus `renameWorkspace(...)`, synchronous `bookmarkIds(...)`, `WorkspaceInfo.copyWith(...)`, and `watchWorkspaces()`.

Live Workspace list/create/update/reorder/delete, active Workspace state, `watchBookmarkIds(...)`, Bookmark assignment/moves, and legacy Saved View workspace compatibility remain.

### Person-group single-membership helpers — #958
`PersonGroupStore.addPerson(...)` / `removePerson(...)` had no production callers. Fixtures moved to the canonical set-based `setGroupsForPerson(...)` boundary. Group/member schema and People UI behavior remain unchanged.

### Person-role reverse/removal paths — #940 / #962
#940 removed caller-zero reverse Person-role query APIs. #962 removed caller-zero `BookmarkRepository.removePersonFromBookmark(...)` and its sole downstream `AppDatabasePersonRoles.removePersonRole(...)`.

Still live and intentionally retained:
- `BookmarkRepository.watchPersonRoles(...)`;
- `AppDatabasePersonRoles.watchPersonRoleAssignments(...)`;
- `setPeopleForRole(...)`;
- Stage1 `batchAddPeople(...)` / `batchRemovePeople(...)`.

### `lib/data/saved_view_extensions.dart` — #417
`SavedViewDuplication.duplicateSavedView(...)` had zero production callers; the extension and dead-only test were removed.

### `lib/widgets/person_role_properties.dart` — #472
`PersonRoleProperties` reached zero production callers after Bookmark detail/property behavior converged on `BookmarkReorderableProperties` plus canonical Property-row components.

### Plain-text Object Body edit path — #586
After universal block-oriented Body editing landed, `ObjectDetailEditService.setPlainTextBody(...)` and its dead adapter path were removed. Do not reintroduce a parallel paragraph/plain-text Body mutation route.

### Legacy Bookmark-only FTS — #654
Search #629 routed live Global Search through canonical Object search. #654 removed the caller-zero Bookmark-only `FullTextSearchRepository` and its dead-only tests. Do not recreate a Bookmark-only FTS index as a compatibility layer.

### Database presentation re-export shims — completed by #899
The historical `lib/widgets/` Database presentation shims are fully retired. Current intended state is:
- legacy Database-presentation shim imports: **0**;
- Database-presentation re-export shim files: **0**.

Earlier steps included #672 (`detail_property_row`), #735 (`database_page_toolbar`), #868 (Stage1 canonical imports), and #899 (final Generic imports/shims). Historical names remain guarded so compatibility shims cannot silently return.

## Retired `AppDatabase` / root-repository responsibilities

Completed architecture-cleanup slices include:
- `AppDatabase.watchBookmarkItems()` -> removed by #281; `BookmarkReadStore` owns Bookmark aggregate reads;
- profile-relative path conversion -> removed from `AppDatabase` by #282; `ProfilePathResolver` owns it;
- `AppDatabase.watchSavedViewConfigs()` / Saved View tag aggregation -> removed by #283, followed by retirement of the later caller-zero Saved View runtime Store layer in #952;
- `AppDatabase.watchAllPhotos()` and duplicate Photo path reconstruction -> removed by #289; `PhotoReadStore` owns resolved Photo reads;
- historical migration bodies v2-v16 -> extracted to migration helpers; `AppDatabase` retains migration sequencing/wiring;
- Bookmark favorite/status/rating/open-history mutations -> moved to `BookmarkEngagementStore` by #579;
- caller-zero Bookmark People batch methods plus `_peopleForBookmark` -> removed by #637;
- duplicate Tag hierarchy mutation -> removed by #705; `TagGroupStore.moveTag(...)` owns hierarchy mutation;
- unreachable `updateBookmarkFields(... personNames ...)` branch -> removed by #728; live People edits remain role-aware;
- legacy Bookmark Photo forwarding/mutation seams -> repeatedly narrowed by #903/#915/#938 after canonical Image Relation writers replaced them;
- caller-zero Bookmark/Workspace Saved View facade -> removed by #944;
- caller-zero Person-role removal seam -> removed by #962.

Do not reintroduce these responsibilities into the database root or Bookmark root repository.

## Retired Bookmark lifecycle / Repository seams

#642 removed caller-zero `BookmarkLifecycleState`, `states()`, `watchStates()` and synchronous `genre()`.

#731 removed caller-zero `BookmarkRepository.setBookmarkPeopleFromDatabase(...)`, empty `BookmarkLifecycleStore.remove(...)`, and the sole no-op permanent-delete call. Permanent deletion still performs attachment cleanup before deleting the Bookmark row.

`BookmarkLifecycleStore.dispose()` is **not** caller-zero. #736 attempted to retire it, but CI exposed live production callers in bootstrap code. Treat it as a live lifecycle contract until a naturally scoped composition cleanup proves otherwise.

## Superseded duplicate visual presentation paths

Direct Bookmark visual duplicates from the original audit are retired:

| Path | Status | Canonical replacement / constraint |
| --- | --- | --- |
| `lib/widgets/notion_bookmark_card.dart` | retired duplicate slice — #294 | Uses `BookmarkVisualImage`; preserve card sizing/selection/open behavior. |
| `lib/widgets/bookmark_reverse_lookup_dialog.dart` | retired duplicate slice — #299 | Uses `BookmarkVisualImage`; management hosts pass repository explicitly. |
| `lib/views/bookmark_lifecycle_page.dart` visual rows | retired duplicate slice — #296 | Uses canonical Bookmark visual component. |
| `lib/views/bookmark_unified_stage1_page.dart` List/Table image helper | retired duplicate slice — #324 | Delegates to `BookmarkVisualImage`; host geometry remains guarded. |

The whole host files remain live. `BookmarkVisualImage` intentionally retains legacy remote-thumbnail fallback as a compatibility boundary.

## Canonical URL adoption status

Legacy `bookmarks.url` remains compatibility data. Canonical presentation has advanced host by host through `BookmarkUrlResolver` / shared presentation resolution, including lifecycle, reverse lookup, Notion bookmark card, Stage1, list metadata, People-related Bookmark presentation, Bookmark detail, and PDF metadata flows.

This is presentation convergence, **not storage retirement**. Direct legacy URL reads/writes may still be legitimate in editing, lifecycle persistence, import/export, backup/migration, or unconverted compatibility hosts. Before narrowing the column/write path, prove all production reads/writes and data portability requirements have replacements.

Malformed/ambiguous Relation state must continue to fail closed to compatibility fallback rather than being repaired from presentation code.

## Recent compatibility-boundary cleanup

### Bookmark backlinks — #408
`BacklinkRepository` delegates focused reads through `BookmarkRepository.watchRelationsForBookmark(bookmarkId)` while preserving Bookmark-facing mapping/sorting and link/unlink semantics.

`BookmarkRepository.addRelation/removeRelation` are **live** through this path. #931 attempted a deletion and Analyze caught the missed production route. Do not repeat that mistake or reinterpret Relation compatibility as permission to redesign canonical Relation storage.

### Global Search — Search #629, Refactor #654
Live Global Search uses canonical Object search. The remaining `GlobalSearchPage(repository: ...)` wrapper is composition debt, not a second search implementation.

## Remaining architecture cleanup candidates

### Repository-as-service-locator usage
Several consumers still obtain lower-level capabilities through `BookmarkRepository`. Replacing every constructor at once would create churn. Fix only when a real caller can be simplified **and** a responsibility can be deleted/moved behind an existing focused boundary.

### GenericDatabasePage hotspot
Refactor progress includes:
- #310 — read/projection state loading -> `GenericDatabasePageStateLoader`;
- #323 — low-level Store/Service graph construction -> `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflow orchestration, and layout-specific host code. Continue only as small focused slices coordinated with Database/View ownership. Do not reconstruct the whole file to improve a metric.

### Presentation/database reach-through
Direct `repository.workspaceStore.database` composition still exists in compatibility hosts. Narrow only where a focused application boundary removes low-level construction or responsibility; do not add one-line forwarding facades.

### User-visible failure boundaries
Broad presentation caught-error privacy cleanup is complete and guarded at zero allowlist. Reopen only for a concrete failure/privacy/observability defect.

### Profile recovery policy
`ProfileManager` fail-soft recovery can affect selected data location. Diagnostic privacy is sanitized, but behavior changes require explicit Storage/Vault recovery policy.

## Current caller-zero audit exclusions

Fresh post-#962 audit confirmed these are still live; do not treat them as cleanup candidates without new evidence:
- `BookmarkRepository.watchPersonRoles(...)` / `watchPersonRoleAssignments(...)`;
- `setPeopleForRole(...)`, `batchAddPeople(...)`, `batchRemovePeople(...)`;
- `watchBookmarksForPerson(...)`, `watchBookmarksForPhoto(...)`, `watchBookmarksForCollection(...)`;
- `findDuplicateUrl(...)`;
- Person CRUD used by People management;
- Collection CRUD / `setBookmarkCollections(...)` used by management/transfer/property UI;
- Tag creation used by Stage1 / Bookmark Property UI, with lower-level Tag persistence also used by the canonical Tag Object bridge;
- engagement methods such as `recordOpen`, lifecycle methods, and Stage1 batch delete/status/rating/favorite flows;
- `PhotoReadStore.resolveRecord(...)` used by `BookmarkReadStore`; Photo CRUD/read paths remain live;
- `BookmarkAttachmentStore.initialize()/dispose()` as live lifecycle contracts;
- `BookmarkRepository.addRelation/removeRelation` through Bookmark backlink UI.

## No-new-dependency review checklist

Before merging new Object/Database/View work, search the diff for newly added production references to:
- `BookmarkItem`;
- `BookmarkRepository` / `bookmark_repository.dart`;
- direct legacy `thumbnail` / `coverPhoto` rendering;
- direct `bookmarks.url` reads/writes outside explicit compatibility/migration paths;
- direct feature-presentation `AppDatabase` imports;
- presentation `workspaceStore.database` reach-through;
- direct caught-error string interpolation under canonical feature presentation;
- recreated legacy Database presentation shim imports/files;
- recreated Saved View runtime Store/facade APIs.

A match is not automatically wrong outside explicitly guarded boundaries, but the PR must classify it and state the retirement condition.

## Next removal order

1. Continue true production caller-zero audits and delete whole modules/helpers only when wrapper-to-real-host tracing and Analyze/full Test prove zero callers.
2. Do **not** spend work on Database presentation shims or broad error allowlists; both tracks are already at zero and should remain guarded.
3. Re-audit Bookmark URL/detail/backlink/Photo compatibility only where owning Object/Primitive/Relation work proves replacement parity.
4. Continue `GenericDatabasePage` P1 decomposition only as measurable patch-sized responsibility reductions coordinated with Database/View ownership.
5. Reduce presentation/database reach-through only when a focused boundary eliminates real construction/ownership rather than adding pass-through APIs.
6. Keep legacy Saved View tables and Photo/Bookmark compatibility data until migration/import/export/backup and owning-lane retirement conditions are explicitly satisfied.
7. Treat bootstrap lifecycle seams such as `BookmarkLifecycleStore.dispose()` and `BookmarkAttachmentStore.initialize()/dispose()` as live until current production callers are intentionally migrated in a naturally scoped composition cleanup.
