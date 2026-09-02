# AI Progress — Object / Relation Lane

> Durable handoff for the Object / Relation implementation lane. Update this file before every run in this lane ends.

## Lane scope

Own Object/ObjectType architecture, Property types, Value vs Relation semantics, Tags, reusable Object types, Object detail content, Body/block model, Daily Notes, and related lifecycle rules.

## Current goal

Complete the Object / Relation side of Issue #56 using the adopted Object-centric architecture while preserving existing bookmark behavior.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

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

## Next actions

1. Inspect current `main`, Issue #56, and recent Object/Relation PR state before coding.
2. Identify the smallest safe model change needed to formalize Value vs Object Relation semantics without breaking existing data.
3. Define/extend ObjectType defaults and inheritance contracts where current models are insufficient.
4. Plan and implement Tag-as-Object migration compatibly with the current hierarchical tag UX.
5. Establish reusable Object detail content so Database/View surfaces can host it in side/center/full-page containers.
6. Establish a forward-compatible Body/block persistence model before building a large editor UI.
7. Add Daily Note as a normal ObjectType/template pattern with unique date semantics and today open-or-create behavior.
8. Add tests for relation lifecycle, migrations, uniqueness, and backward compatibility.

## Cross-lane boundaries

- Do not independently redesign Database/View navigation or query toolbar behavior.
- Expose reusable Object-detail and relation APIs for the Database / View lane to consume.
- If embedded dynamic Views are introduced in Body/Daily Note, reuse the Database/View query/projection abstractions rather than cloning them.
- Coordinate any shared persistence/schema migration through Issue #56 and the repository-wide handoff.

## Completed

- Two-lane handoff structure established.
- Product/design decisions above recorded as implementation contract context.

## In progress

- Resume from current GitHub state after inspecting latest `main`.

## Validation

- Documentation-only lane split at creation time.

## Blockers / risks

- Tag migration and Value-to-Object promotion must preserve existing bookmark/tag data.
- Full block editor scope can expand rapidly; prioritize persistence architecture and a thin usable slice before rich editing features.
- Avoid concurrent broad edits to database page code owned by the other lane.
