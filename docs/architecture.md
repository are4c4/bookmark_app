# bookmark_app architecture

This document defines the default placement rules for new code and the target direction of the ongoing database UI refactor.

## Goals

- Keep database-like screens visually and behaviorally consistent.
- Avoid implementing Gallery / List / Table / detail-pane behavior separately for every feature.
- Make it obvious where a new data operation belongs.
- Keep the architecture simple enough for a single-developer Flutter application.

## Data-layer boundaries

### Store

A Store performs direct Drift / SQLite reads and writes for one data area.

Examples:
- `DatabaseViewStore`
- `PersonGroupStore`
- `TagGroupStore`

A Store should not own file-system, HTTP, image-processing, or presentation behavior.

### Repository

A Repository exposes application-level data operations and may coordinate multiple Stores.

Examples:
- creating a bookmark and its relations
- changing tags and people for a bookmark
- combining database records into a screen-ready domain object

Presentation code should prefer Repository APIs instead of composing raw Store calls when an application operation already exists.

### Service

A Service owns operations that are not primarily database CRUD or that cross external boundaries.

Examples:
- file import and storage
- metadata fetching
- image editing
- backup / restore
- profile directory migration

A Service may be coordinated by a Repository when a single user action requires both file and database work.

## Presentation structure

New shared database presentation code belongs under:

```text
lib/features/database/presentation/
```

Feature-specific presentation code should gradually move toward:

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
 │   └─ Table
 └─ DatabaseDetailPane
```

Feature-specific code should provide data and behavior through adapters / render specifications instead of reimplementing the shell.

The toolbar follows these UI rules:
- view tabs own their adjacent `+` create-view action;
- filter / sort / property controls describe the active view;
- layout selection uses one current-layout menu instead of three permanently visible buttons;
- search is collapsed until requested or until a saved non-empty query is restored;
- low-frequency actions such as multi-selection belong under the overflow menu when possible.

## Property model target

Property UI should converge on four concepts:

```text
PropertyDefinition
PropertyValue
PropertyRenderer
PropertyEditor
```

A property should use the same renderer/editor in detail, list, gallery, and table contexts wherever practical.

Detail rows use a stable four-column geometry:

```text
drag handle | property label | value | trailing action
```

This keeps drag handles, labels, values, and `+` / dropdown affordances aligned across property types.

## Widget lifetime rule

Text editing controllers and focus nodes belong to the State object that owns the editable widget. Do not create a controller outside a dialog and dispose it immediately after `showDialog` returns when IME composition or route teardown can still reference it.

## Migration rule

- Existing migrations are never rewritten in a way that risks installed user data.
- Migration bodies should live in dedicated helpers instead of making `AppDatabase.migration` continually larger.
- v15 and v16 are now extracted into `app_database_migrations.dart`; future schema versions should follow the same pattern.
- Every schema bump requires a migration regression test from the previous schema version when feasible.

## Refactor rule

Refactor PRs should preserve behavior unless the PR explicitly contains an agreed UI change. Prefer small extraction steps with passing Analyze/Test over a large folder move.
