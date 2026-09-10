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

## Completed Tag hierarchy query checkpoint

### #1053 — hierarchy-aware Tag filter/query UX (completed)
#1157 integrated the canonical runtime completion for #1053. The durable semantics are:
- exact parent does not match a directly assigned descendant;
- `is-or-below`, below-only and exclude-branch remain distinct typed predicates;
- no automatic ancestor Tag assignment is persisted;
- saved query/filter serialization preserves hierarchy mode;
- C consumes B's validated canonical `TagHierarchySnapshot.isStrictDescendant` reader rather than creating a second traversal/tree store;
- hierarchy capability is enabled only for Relation Properties targeting the canonical Tag system ObjectType;
- unavailable or malformed canonical Parent state removes hierarchy capability so non-exact hierarchy predicates fail closed;
- Database collection filters, saved View projection and reusable query UI share the same canonical hierarchy capability.

#1052 and #1105 are completed B integrity/read checkpoints; #1053 is a completed C query/UX checkpoint. Broader #1050 Tag picker/tree/management UX may still contain unfinished product work, but fresh C runs must not reopen #1053 as an implementation queue.

## Active focused issues

### #1061 — Home/start UX
Home converges on Inbox / Recent / Favorites / Pinned Databases without making legacy Bookmark/People modules permanent navigation authority.

Integrated first slice (#1111):
- Home is the normal shell start destination while Bookmark / People / Tag / Collection transition navigation remains available until their parity/caller-zero gates complete;
- Recent is derived from canonical Objects across ObjectTypes using `updatedAt` descending with Object id as deterministic tie-breaker;
- transition-only mirrored Bookmark Objects are excluded by canonical `system_key = bookmark` identity, without excluding user-facing system ObjectTypes such as Weblink/Image/Tag/Daily Note;
- Recent opens through the shared `ObjectInspectorPage` and refreshes after returning;
- Home has loading, empty, error/retry and pull-to-refresh behavior;
- no Home-only Recent index, recently-opened history, Favorites state or Pinned Database state is persisted by this slice.

Focused interaction slice (#1125):
- Home Recent focus traversal is explicitly ordered by the same visible deterministic Recent order;
- the first Recent row receives autofocus so desktop keyboard users can resume work without crossing transition-only domain navigation first;
- Enter, Space and pointer/touch activation converge on the same shared `ObjectInspectorPage` opening path;
- Material row semantics/touch targets remain intact, and empty Home keyboard traversal does not create a focus trap;
- this interaction layer adds no Home selection persistence, recently-opened history or alternate Object-opening authority.

Next #1061 action: split Inbox / Favorites / Pinned Databases into focused contracts only when their canonical persistence/query semantics are explicit. Do not reuse legacy Bookmark `storageState`/favorite state as Home authority, and do not fake durable user state in presentation memory merely to fill the Home surface.

### #1043 — replace Stage1 normal ownership
Move ordinary saved-URL use to canonical Weblink Objects through generic Database/View/navigation and capture-first/Inbox organization. Preserve useful list/table/gallery/filter/sort/opening behavior through generic contracts. Retire Stage1 routing only after completed #1041/#1054, B/#1042 Relation convergence, and daily-use parity make it caller-zero.

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
- shared Object opening/Inspector/Body composition;
- Home start routing with canonical recently-changed Object projection and transition-only Bookmark mirror suppression;
- completed canonical hierarchy-aware Tag Database/View query runtime from #1053/#1157 using B's #1052/#1105 integrity/read contracts.

Older statements that “Lane C is idle after #949” are obsolete because #1043/#1046/#1061 and broader #1050 product UX contain C work or dependencies that must be re-audited live. Completed #1053 is not an active work source.

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
1. re-read live #1043/#1046/#1061 and broader #1050 acceptance/dependency status; treat #1053 as a completed checkpoint unless it is explicitly reopened;
2. choose one focused Issue and one owner branch/PR;
3. avoid broad shared-host edits until the underlying contract is testable in reusable components;
4. prove persisted View/query round-trip and interaction behavior;
5. update this handoff with durable implementation facts;
6. do not reintroduce Bookmark/People-specific view engines, Home-only fake durable state, or a parallel Tag tree store.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane C must refresh dependencies because #1043/#1046/#1061 and broader #1050 work may become actionable as A/B/D work lands; a dependency that was blocked earlier is not a durable idle reason. Stop only after the final resume audit finds no independent safe C work, and record the exact shared stop category plus evidence in this handoff.
