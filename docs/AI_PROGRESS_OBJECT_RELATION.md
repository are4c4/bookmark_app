# AI Progress — Object / Relation Lane

> Durable handoff for the Object / Relation implementation lane. Update this file before every run in this lane ends.

## Lane scope

Own Object/ObjectType architecture, Property types, Value vs Relation semantics, Tags, reusable Object types, Object detail content, Body/block model, Daily Notes, and related lifecycle rules.

## Current goal

Complete the Object / Relation side of Issue #56 using the adopted Object-centric architecture while preserving existing bookmark behavior.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Active branch

`feature/object-property-semantics`

Latest implementation commits on this branch:
- `60563b7` — define explicit Object Property semantic categories
- `88a88b8` — add regression coverage for semantic classification

## Adopted design decisions

- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType defines schema plus defaults. Effective configuration precedence is:
  `View override > Database override > ObjectType default > app default`.
- Object content is two-layered:
  - structured Properties
  - free Body, designed as a block model even if the initial editor UI is simple.
- Property architecture distinguishes:
  - Value properties for lightweight values
  - Object Relation properties for reusable/independently meaningful entities
  - computed properties such as Formula/Rollup
- Value-like formats should not become separate persistence types unless their storage/computation semantics truly differ.
- Values may later be promoted to Objects, e.g. text author -> Person Object, URL value -> Weblink Object, place text -> Place Object.
- Tags should be Objects, supporting parent/child relations, aliases, descriptions, backlinks, etc. Select/MultiSelect remain for property-local options such as status.
- Date remains a Value.
- Daily Note is an Object with a unique `date` value per day.
- Opening “today's note” should open the existing Daily Note or create it if missing.
- Daily Notes should combine explicit Relations with dynamic date-based views of Tasks, Books, Weblinks, Photos, etc.
- Daily Note must be implemented through general Object/Property/Relation/View/Block mechanisms rather than as a one-off special data silo.
- Object detail presentation should support side peek, center peek, and full page while reusing one underlying detail/content component.

## Completed

- Two-lane handoff structure established.
- Product/design decisions above recorded as implementation contract context.
- Added `ObjectPropertySemantics` as a domain-level distinction independent from concrete `ObjectPropertyType` formatting.
- Classified current types as:
  - Value: title/text/number/checkbox/date/url/select/multiSelect/image/file/rating/createdTime/updatedTime
  - Object Relation: objectRelation
  - Computed: formula/rollup
- Kept existing storage type strings and persisted data unchanged, so this slice requires no schema/data migration.
- Added `isValue`, `isRelation`, and `isComputed` helpers to centralize semantic checks.
- Added domain regression tests covering every current Property type.

## In progress

- Open/validate the focused Property-semantics PR against latest `main`.
- Keep the change intentionally model-only before using the semantic category in mutation/promotion APIs.

## Exact next actions

1. Run/inspect CI for the Property-semantics PR and fix any failures caused by this slice.
2. After merge, add the smallest safe API contract that uses semantic categories instead of ad-hoc type lists where the Object lane owns the behavior.
3. Define a forward-compatible value-to-Object promotion contract (conversion plan/result first, destructive UI later), preserving original values when conversion is ambiguous/lossy.
4. Define/extend ObjectType defaults and inheritance contracts where current models are insufficient, coordinating persistence fields with the Database/View lane.
5. Continue Tag-as-Object compatibility work without replacing the current hierarchical tag source of truth until read/write parity is proven.
6. Establish reusable Object detail content and a forward-compatible Body/block persistence model before building a large editor UI.
7. Add Daily Note as a normal ObjectType/template pattern with unique date semantics and today open-or-create behavior after Object Body/default foundations are stable.

## Cross-lane boundaries

- Do not independently redesign Database/View navigation or query toolbar behavior.
- PR #60 (`feature/object-board-create-in-group`) is Database/View interaction work despite using Object services; avoid editing its GenericDatabasePage integration path from this lane.
- Expose reusable Object-detail and relation APIs for the Database / View lane to consume.
- If embedded dynamic Views are introduced in Body/Daily Note, reuse the Database/View query/projection abstractions rather than cloning them.
- Coordinate shared persistence/schema migrations through Issue #56 and the repository-wide handoff.

## Validation

- Added `test/object_property_semantics_test.dart` with exhaustive classification coverage for all current `ObjectPropertyType` values.
- No local Flutter runtime is available through the GitHub connector; PR CI is the executable validation source for this run.

## Blockers / risks

- Tag migration and Value-to-Object promotion must preserve existing bookmark/tag data.
- Full block editor scope can expand rapidly; prioritize persistence architecture and a thin usable slice before rich editing features.
- Avoid concurrent broad edits to database page code owned by the other lane.
- If new Property types are added, the semantic classification test should force an explicit decision about Value vs Object Relation vs Computed semantics.
