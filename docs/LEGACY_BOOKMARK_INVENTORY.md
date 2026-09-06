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
| `lib/data/app_database_schema.dart` (`BookmarkItem`) | canonical product behavior | Compatibility/domain shape for live Bookmark rows. Delete only after production callers disappear and migration/import/export handling is explicit. |
| `lib/data/bookmark_read_store.dart` | canonical product behavior / compatibility read boundary | Owns the screen-ready Bookmark aggregation formerly implemented by `AppDatabase.watchBookmarkItems()`. Keep while Bookmark hosts need the aggregate shape; do not move joins back into AppDatabase. |
| `lib/views/bookmark_query_engine.dart` | canonical product behavior | Bookmark-specific filtering remains live until generic Database/View querying covers the same host. |
| `lib/views/bookmark_lifecycle_page.dart` | canonical product behavior / compatibility host | Inbox/archive/trash remain live. Visual rendering is canonicalized; #317 prefers canonical Weblink URL with legacy fallback. |
| `lib/views/global_search_page.dart` | canonical product behavior | Current global search still consumes Bookmark aggregates. Retire after Object-first global search parity. Failure UI is already stable/privacy-safe via #331; it is no longer a raw-error cleanup candidate. |
| `lib/services/auto_organize_service.dart` | canonical product behavior | Bookmark automation remains live; do not extend for Object-only workflows. |
| `lib/services/bookmark_transfer_service.dart` | migration-only / compatibility | Import/export legitimately understands persisted Bookmark data. Keep isolated. |
| `lib/data/saved_view_extensions.dart` | compatibility bridge | Saved Bookmark-era view behavior still hangs off BookmarkRepository; candidate once Database/View-native behavior has parity. |
| `lib/repositories/full_text_search_repository.dart` | compatibility bridge | Repository is still a composition handle. Narrow when a real caller can use a focused search dependency. |
| `lib/repositories/backlink_repository.dart` | compatibility bridge | Bookmark-facing backlink model remains while canonical Relation backlinks are mature. Retire presentation callers first. |
| `lib/widgets/bookmark_relation_section.dart` | compatibility bridge | Bookmark detail exposes Relation/backlink information through Bookmark-centric inputs; do not redesign Relation here. |
| `lib/widgets/person_role_properties.dart` | canonical product behavior / compatibility | Shared Property add flow is integrated (#350); Person assignment still belongs to existing repository/canonical semantics. |
| `lib/widgets/bookmark_reorderable_properties.dart` | canonical product behavior / compatibility | Remaining person-role Property-add convergence is Object-owned. PR #366 has green CI but needs refresh after main advanced; Refactor must not overlap this host while that slice is active. |
| `lib/widgets/bookmark_detail_panel.dart` | canonical product behavior / compatibility | Still-live Bookmark detail. Managed visual migration is integrated; direct metadata/URL responsibilities should move only when a proven canonical replacement preserves editing/opening behavior. |
| `lib/widgets/bookmark_visual_image.dart` | compatibility bridge | Shared Bookmark-host visual boundary: user cover -> canonical managed Bookmark→Weblink→Image visual -> legacy thumbnail fallback. Keep until old Bookmark hosts disappear. |
| `lib/services/bookmark_visual_resolver.dart` | compatibility bridge | Read-only canonical/legacy visual precedence resolver. New presentation must not bypass it; remove only with Bookmark compatibility hosts. |
| `lib/services/bookmark_url_resolver.dart` | compatibility bridge | Read-only canonical Bookmark→Weblink URL preference with legacy fallback. Used across lifecycle #317, reverse lookup #320, Notion card #322, Stage1 #341 and Bookmark List metadata #360. Keep while compatibility hosts still need fallback. |
| `lib/widgets/global_file_drop_layer.dart` | canonical product behavior / composition | Current import/drop composition still receives BookmarkRepository. Narrow only with a real focused replacement. |
| `lib/widgets/bookmark_attachment_section.dart` | canonical product behavior / compatibility | Attachment/PDF enrichment remains Bookmark-owned. #364 stabilized failure/privacy behavior; this does not make the host removable. |
| `lib/views/settings_page.dart` | canonical product behavior / composition | Backup/export/settings still use repository capabilities. |
| `lib/views/tag_management_page.dart` | canonical product behavior | Current management host still uses Bookmark capabilities; reverse-lookup image presentation is canonical. |
| `lib/views/people_management_page.dart` | canonical product behavior | Large management hotspot combining People/Bookmark behavior; reverse-lookup image presentation is canonical. |
| `lib/views/photo_management_page.dart` | canonical product behavior / legacy host | Photo-management remains live; read/path aggregation has moved to `PhotoReadStore`, and reverse-lookup visual is canonical. |
| `lib/views/collection_management_page.dart` | canonical product behavior | Collection management still consumes Bookmark data. |
| `lib/views/app_shell.dart` | composition hotspot | Passes BookmarkRepository through many live/compatibility screens. Future boundary target; always check open PR ownership. |
| `lib/main.dart` | composition root | Root Bookmark repository construction remains expected while live Bookmark features exist. #368 only stabilized bootstrap/Profile-switch failure UI; it did not change repository ownership. |

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
| `lib/widgets/bookmark_reverse_lookup_dialog.dart` | **retired duplicate** — #299 | Uses `BookmarkVisualImage`; Tag/Photo/People hosts pass repository explicitly. |
| `lib/views/bookmark_lifecycle_page.dart` visual rows | **retired duplicate** — Object #296 | Uses canonical Bookmark visual component. |
| `lib/views/bookmark_unified_stage1_page.dart` List/Table image helper | **retired duplicate** — #324 | `_image(...)` delegates to `BookmarkVisualImage`; deterministic guard preserves List `60x44` / Table `58x38`. |

The whole files above are **not** superseded. Only their duplicated visual-resolution slices are retired until remaining host behavior has Object-first parity.

`BookmarkVisualImage` legitimately retains a legacy remote-thumbnail fallback. That fallback is a compatibility boundary, not another duplicate presentation path.

## Canonical URL adoption status

Legacy `bookmarks.url` remains compatibility data. Canonical presentation has advanced host by host through `BookmarkUrlResolver`:

- **#317 merged** — lifecycle URL display/opening prefers canonical Weblink URL and retains legacy fallback;
- **#320 merged** — reverse lookup uses the same canonical preference;
- **#322 merged** — Notion bookmark-card URL display/open behavior uses the canonical resolver;
- **#341 merged** — Stage1 URL presentation/opening uses the canonical path;
- **#360 merged** — Bookmark List metadata stopped reading legacy `bookmark.url` directly; when no resolver is supplied it omits URL metadata rather than reintroducing a local fallback.

This is substantial presentation convergence, **not storage retirement**. Remaining direct legacy URL reads/writes can still be legitimate in editing, lifecycle persistence, import/export, backup/migration or unconverted compatibility hosts. Before deleting/narrowing the column or write path, prove all production reads/writes and data portability requirements have replacements.

Ambiguous/malformed Relation state must continue to fail closed to compatibility fallback rather than being repaired from presentation code.

## Remaining architecture cleanup candidates

### Repository-as-service-locator usage
Several consumers still obtain lower-level capabilities through `BookmarkRepository`. Replacing every constructor at once would create churn. Fix only when a real caller can be simplified and a responsibility can be deleted or moved behind an existing focused boundary.

### GenericDatabasePage hotspot
Refactor progress includes:
- #310 — read/projection state loading -> `GenericDatabasePageStateLoader`;
- #323 — low-level Store/Service graph construction -> `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflow orchestration, and layout-specific host code. Continue as small focused slices only. Avoid monolithic controller rewrites and do not hand-reconstruct the large host merely to work around tooling limitations.

### User-visible failure boundaries
GlobalSearch, Settings, attachment import and bootstrap/Profile-switch raw-error boundaries are already stabilized (#331–#335/#364/#368). Re-audit before assuming an old raw-error candidate still exists. Prefer a small independently testable host; do not overlap Object-owned shared hotspots.

### Profile recovery policy
`ProfileManager` intentionally fails soft when persisted profile-registry metadata cannot be decoded, but the fallback can affect which data location is selected. #363 sanitized diagnostics only. Any behavior change still requires an explicit recovery/data-safety policy.

## No-new-dependency review checklist

Before merging new Object/Database/View work, search the diff for newly added production references to:
- `BookmarkItem`
- `BookmarkRepository`
- `bookmark_repository.dart`
- direct legacy `thumbnail` / `coverPhoto` rendering
- direct `bookmarks.url` reads/writes outside an explicit compatibility/migration path

A match is not automatically wrong, but the PR must classify it and state the retirement condition.

## Next removal order
1. Re-audit remaining direct Bookmark URL presentation/edit/write callers after #317/#320/#322/#341/#360; migrate only when an existing canonical replacement preserves the host contract.
2. Continue Object-first Photo/Image and Bookmark/Image convergence from the existing bridges; do not create a second compatibility bridge or destructively remove legacy Photo storage.
3. Re-audit Bookmark query/search/backlink/detail presentation only where generic Object/Database/Relation behavior has proven parity; do not replace live behavior just to reduce reference counts.
4. Continue GenericDatabasePage P1 decomposition and repository/composition cleanup as measurable responsibility/LOC reductions.
5. Delete whole legacy modules only when production reference count reaches zero and import/migration/backup requirements are explicitly handled.