# AI Progress — Database, View & Schema UX Lane

> Durable Lane C handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Make Database/View/schema UX generic enough that Person, Weblink, Tag and user-defined ObjectTypes can use ordinary Object/Database workflows rather than dedicated management engines.

## Architecture contract
- Objects are global and are not owned/duplicated by Databases or Views.
- Database defines an Object set/query context; View defines layout/filter/sort/group/visible Properties/opening configuration.
- Removing from a Database is distinct from Object archive/trash/permanent deletion.
- `Bookmark` is not a permanent ObjectType or Database concept. Saved URLs should be normal Weblink Objects used through generic Database/View/Inbox contexts.
- Person is a generic ObjectType; dedicated People UI is transitional.
- Tag/TagGroup use generic persistence with specialized hierarchy-aware query/picker/tree UX.
- C owns presentation/configuration/query UX, not native Weblink/Image/File identity or Relation integrity.

## Active focused issues

### #1053 — hierarchy-aware Tag filter/query UX
Required semantics for a direct child/grandchild assignment:
- exact parent => no match;
- `is-or-below` parent => match;
- below-only and exclude-branch remain distinct typed predicates;
- no automatic ancestor Tag assignment is persisted.

Scope:
- stable saved query/filter serialization;
- reusable UI mode such as `完全一致` / `配下を含む`;
- consume B/#1052 canonical hierarchy reader/integrity contract rather than creating a second traversal/tree store;
- preserve View round-trip and existing exact filtering.

### #1043 — replace Stage1 normal ownership
Move ordinary saved-URL use to canonical Weblink Objects through generic Database/View/navigation and capture-first/Inbox organization. Preserve useful list/table/gallery/filter/sort/opening behavior through generic contracts. Retire Stage1 routing only after #1041/#1042/#1054 and daily-use parity make it caller-zero.

### #1046 — replace dedicated People management
Expose Person Objects through ordinary Database/View/Inspector flows. Preserve Profile Image Relation, search/filter/group/opening and inline Relation picker creation. Remove `PeopleManagementPage` only after #1044/#1045 and daily-use parity.

## Integrated foundation that remains authoritative
- generic Database/ObjectType separation;
- persisted Table/List/Gallery/Board Views;
- filter/sort/group/layout/visible-Property persistence;
- relation-aware Property authoring/schema editing through canonical services;
- generic Gallery cover sources and media rendering;
- generic Database sidebar/command-palette navigation;
- canonical Images/Weblinks/Daily Notes system collection defaults;
- shared Object opening/Inspector/Body composition.

Older statements that “Lane C is idle after #949” are obsolete because #1043/#1046/#1053 are now focused open C issues.

## Cross-lane boundaries
- **A:** Object/ObjectType identity/lifecycle, Body, Person/Bookmark migration authority.
- **B:** Relation integrity, Tag Parent/group cycle/cardinality correctness, Bookmark/Person relationship migration.
- **D:** Weblink/Image/File native behavior and direct URL capture.
- **E:** FTS/search architecture; C owns Database/View typed query/filter semantics, not global FTS persistence.
- **F:** Vault/storage lifecycle.
- **G:** behavior-preserving shared-host reduction and caller-zero dedicated-page retirement after parity.

## Shared hotspots
`generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart` and `people_management_page.dart` are conflict-prone. Recheck live PR ownership before editing. Prefer reusable query/domain/presentation components and small host-composition hunks over broad rewrites.

## Validation
Changed-Dart format, Analyze, full Flutter Test and focused serialization/widget/real-host regressions are required for primary flows. UI acceptance includes click/key count, inline creation/editing, predictable focus, empty/error/loading states and clear remove-vs-delete semantics.

## Resume sequence
1. re-read live #1053/#1043/#1046 and dependency status;
2. choose one focused Issue and one owner branch/PR;
3. avoid broad shared-host edits until the underlying contract is testable in reusable components;
4. prove persisted View/query round-trip and interaction behavior;
5. update this handoff with durable implementation facts;
6. do not reintroduce Bookmark/People-specific view engines or a parallel Tag tree store.