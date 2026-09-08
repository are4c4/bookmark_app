# bookmark_app architecture

This document defines default code-placement and dependency rules. Product semantics live in `docs/product_architecture.md`; implementation must not contradict that constitution without an explicit product-design decision.

## Goals

- Keep Object/Database/Body experiences visually and behaviorally consistent.
- Avoid implementing Gallery / List / Table / detail-pane behavior separately for every ObjectType.
- Keep native Weblink/Image/File capabilities composable with the generic Object model.
- Make it obvious where a new data operation belongs.
- Reduce shared hotspots so parallel AI implementation can proceed through stable contracts rather than broad file ownership.
- Keep the architecture understandable for a single-developer Flutter application even when several AI agents work concurrently.

## Product boundary

New product work follows these architectural constraints:
- every durable user-facing entity is an Object with one primary ObjectType;
- ObjectType defines what an Object is; Properties describe characteristics; Relations describe relationships/roles; Tag provides reusable hierarchical classification; Database provides collection/query context; View provides presentation/query configuration; Body provides free-form block content;
- Objects are global within a Vault and are not owned or duplicated by Databases or Views;
- Weblink/Image/File are Objects with native capabilities;
- Person/Book/Paper/Project/Tag/TagGroup/etc. use generic ObjectType contracts;
- `Bookmark` is legacy compatibility, not a final ObjectType/product domain;
- saving a URL creates/reuses Weblink; richer semantic Objects may point to Weblink through Relations such as `Source`;
- legacy storage/schema remains until replacement parity, caller-zero proof and preservation-safe migration.

See `docs/product_architecture.md` for the full product constitution and UX/query/migration contracts.

## Data-layer boundaries

### Store

A Store performs direct Drift / SQLite reads and writes for one data area.

Examples:
- `DatabaseViewStore`
- `ObjectStore`
- `ObjectBodyStore`

A Store should not own file-system, HTTP, image-processing, or presentation behavior.

Legacy stores such as Person/Tag/Bookmark-specific stores may remain only while they own real compatibility behavior. Replacement work should move semantics into generic Object/Relation/Database contracts rather than rename the old store.

### Repository / application boundary

A Repository, controller, or focused application service exposes application-level operations and may coordinate multiple Stores.

Examples:
- creating/reusing a Weblink from a captured URL;
- changing generic Properties/Relations on an Object;
- resolving a Database/View snapshot for presentation;
- applying an Object lifecycle transition.

Presentation code should prefer the narrowest application-facing boundary instead of composing raw Stores when an application operation already exists.

### Service

A Service owns operations that are not primarily database CRUD or that cross external/native boundaries.

Examples:
- Weblink metadata fetching;
- file import and managed storage;
- image editing;
- backup / restore;
- profile/Vault directory migration.

A Service may be coordinated by an application boundary when one user action requires both native and database work.

## Dependency boundary

Presentation should depend on the narrowest application-facing Repository, Service, controller, or facade that already owns the operation. A Widget/Page should not reach through another dependency to obtain `AppDatabase` and construct a graph of low-level Stores/Services when an application operation already exists.

Constructor injection remains the default. Do not introduce a DI framework solely to satisfy this rule; extract a focused application boundary only when a real host needs it.

For new Object / ObjectType / Database / View work, do not add new `BookmarkItem`, `BookmarkRepository`, legacy Bookmark-table, dedicated People-store, or Photo-specific product dependencies merely for convenience. Legacy dependencies are permitted only for an explicitly required compatibility bridge, migration/import/export path, or staged replacement with a clear retirement condition. See `docs/MAINTAINABILITY.md` and `docs/product_architecture.md`.

Relation behavior remains behind the canonical Relation APIs. Presentation/application refactors must not create parallel serialized-id, index, backlink, tree, role, or repair paths.

## Presentation structure

New shared database presentation code belongs under:

```text
lib/features/database/presentation/
```

Shared Object/Body presentation belongs under:

```text
lib/features/object/presentation/
```

Feature/native-capability presentation code should gradually move toward:

```text
lib/features/<feature>/presentation/
```

The migration is incremental. Existing files under `lib/views` and `lib/widgets` remain valid until their responsibilities are extracted.

## Target database screen structure

```text
DatabasePage
 ├─ DatabaseViewTabs
 ├─ DatabasePageToolbar
 ├─ DatabaseContent
 │   ├─ Gallery / Masonry
 │   ├─ List
 │   ├─ Table
 │   └─ Board
 └─ DatabaseDetailPane / Object Inspector
```

ObjectType-specific code should provide data/native behavior through generic render/edit contracts instead of reimplementing the shell.

The toolbar follows these UI rules:
- view tabs own their adjacent `+` create-view action;
- filter / sort / property controls describe the active view;
- layout selection uses one current-layout menu instead of permanently visible mode buttons;
- search is collapsed until requested or until a saved non-empty query is restored;
- low-frequency actions belong under overflow/context menus when possible;
- high-frequency creation/editing actions should stay close to the affected Object/Property/Tag context.

## Database/query model target

Database selects an Object set/context; View refines/presents it.

Database membership may be:
- manual;
- query-derived;
- manual with View filters.

The query model should converge on a typed composable representation capable of AND/OR/NOT, Property predicates, Relation predicates, Tag hierarchy predicates and lifecycle predicates. Do not introduce a long-term domain-specific filter engine for each ObjectType.

## Property model target

Property architecture separates stable definition identity, value type, constraints/semantics and presentation.

UI should converge on reusable concepts such as:

```text
PropertyDefinition
PropertyValue
PropertyRenderer
PropertyEditor
QueryOperator
```

A Property should use the same underlying renderer/editor/query contract in Inspector, List, Gallery and Table contexts wherever practical.

Do not identify a Property by its display name. Rename must not break values, formulas, views or filters.

Prefer a small set of strong value types plus constraints/presentation over one closed enum entry for every visual variant. Formula/Rollup are derived typed capabilities and should not become ad-hoc canonical columns.

Detail rows use a stable geometry where practical:

```text
drag handle | property label | value | trailing action
```

## Tag architecture target

Tag and TagGroup use generic Object/Relation persistence with specialized query/UX semantics.

- Tag hierarchy uses canonical `Tag -> Parent Tag` Relation.
- Object assignments store only direct Tags; ancestors are derived.
- hierarchy-aware filtering distinguishes exact from `is-or-below`/descendant semantics.
- hierarchy mutation must reject cycles/invalid targets through Relation integrity.
- picker/tree/group UX may be specialized even though persistence is generic.

Do not create a second tag-tree persistence model merely for convenience.

## Body editor target

Body remains versioned block content owned by Object Core, but the editing surface should behave like a document.

- normal paragraph creation/splitting is keyboard-first;
- block actions are contextual rather than permanent toolbar rows;
- focus order and keyboard behavior are acceptance criteria;
- persisted Body compatibility remains unchanged while editor UX evolves;
- native/media/Object-reference blocks compose existing Object capabilities rather than creating Body-only duplicate asset identity.

## Widget lifetime rule

Text editing controllers and focus nodes belong to the State object that owns the editable widget. Do not create a controller outside a dialog/editor and dispose it while IME composition or route teardown can still reference it.

## UX implementation rule

For user-facing work, functional acceptance is necessary but not sufficient. Focused Issues should also define relevant interaction acceptance:
- click/key count for the normal path;
- inline creation/editing;
- keyboard/focus behavior;
- empty/loading/error states;
- Undo/reversibility where appropriate;
- desktop/mobile interaction differences;
- accessibility/focus/touch-target behavior.

Generalizing the data model does **not** require one generic UI for every task. Native and high-value specialized UX (Image editing, Weblink preview, Tag tree, Body editor) should sit on top of generic persistence/contracts.

## Migration rule

- Existing migrations are never rewritten in a way that risks installed user data.
- Migration bodies should live in dedicated helpers instead of making `AppDatabase.migration` continually larger.
- v15 and v16 are extracted into `app_database_migrations.dart`; future schema versions should follow the same pattern.
- Every schema bump requires a migration regression test from the previous schema version when feasible.
- Schema/migration changes use a single-writer ownership lease.
- Replacement UI does not justify destructive schema deletion by itself.

The normal retirement sequence is:

```text
replacement contract
→ parity
→ caller-zero proof
→ legacy code/UI retirement
→ preservation validation
→ explicit destructive schema migration
```

## Parallel AI implementation rule

Parallel throughput comes from stable contracts and small ownership surfaces, not simply more agents.

- one focused Issue has one active implementation owner/branch/PR;
- contract-first interfaces/tests should precede broad parallel implementations when practical;
- shared semantic tests are contracts between agents;
- reduce shared hotspots structurally rather than only adding overlap guards;
- re-read live `main`, open PRs and hotspot ownership before broad edits;
- combined-state/merge-queue CI is the desired final integration gate once repository settings permit it;
- durable handoffs store completed contracts, validation and next safe actions, not ephemeral live-state claims.

## Refactor rule

Refactor PRs should preserve behavior unless the PR explicitly contains an agreed product/UX change. Prefer deletion and small responsibility extraction with passing Analyze/Test over a broad folder move or abstraction added solely for aesthetics.