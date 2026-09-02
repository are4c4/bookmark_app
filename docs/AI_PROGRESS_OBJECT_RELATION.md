# AI Progress — Object / Relation Lane

> Durable handoff for the Object / Relation implementation lane. Update this file before every run in this lane ends.

## Lane scope

Own Object/ObjectType architecture, Property types, Value vs Relation semantics, Tags, reusable Object types, Object detail content, Body/block model, Daily Notes, and related lifecycle rules.

## Current goal

Complete the Object / Relation side of Issue #56 using the adopted Object-centric architecture while preserving existing bookmark behavior.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current branches

- Relation integrity slice: `feature/relation-source-integrity`
  - latest commit: `51c88d1576dafce5b5532b11960dbfa369b92cbd`
- A concurrent Object-semantics slice also exists on `feature/object-property-semantics`; avoid overwriting it and refresh from `main` before either branch is integrated if both remain active.

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
- Relation integrity slice hardens `BidirectionalRelationStore.pairFor` so corrupted reciprocal metadata is not treated as a valid pair:
  - inverse property must itself still be marked bidirectional;
  - inverse property must target the source ObjectType;
  - reciprocal inverse-property id validation remains required.
- Added regression tests covering a missing inverse bidirectional flag and an inverse Relation pointing at the wrong ObjectType.

## In progress

- Relation integrity PR preparation and CI validation.
- The Object property semantic categorization is being handled on the separate `feature/object-property-semantics` branch; do not duplicate that work here.

## Next actions

1. Open the Relation integrity PR against latest `main` and inspect CI/analyzer/test results.
2. Fix only failures caused by the Relation integrity slice, then merge when green/acceptable.
3. After the concurrent Object-semantics slice is integrated or stabilized, refresh from latest `main` before the next Relation slice.
4. Add source-side relation integrity to `ObjectStore.setRelation`/`setPropertyValue`: a Relation Property must belong to the source Object's ObjectType; keep this backward-compatible and add regression coverage.
5. Validate Relation property creation targets (target ObjectType existence/workspace compatibility) without introducing destructive migrations.
6. Continue strengthening backlink/pair lifecycle guarantees before starting broader Tag-as-Object migration work.
7. Plan Tag-as-Object migration compatibly with the current hierarchical tag UX.
8. Establish reusable Object detail content, then Body/block persistence and Daily Note patterns in later focused slices.

## Cross-lane boundaries

- Do not independently redesign Database/View navigation or query toolbar behavior.
- Expose reusable Object-detail and relation APIs for the Database / View lane to consume.
- If embedded dynamic Views are introduced in Body/Daily Note, reuse the Database/View query/projection abstractions rather than cloning them.
- Coordinate any shared persistence/schema migration through Issue #56 and the repository-wide handoff.
- The user currently has separate Object-focused and Relation-focused implementation chats despite the repository grouping them in one lane. Prefer separate focused branches and avoid simultaneous edits to the same model/store files.

## Validation

- Added `test/bidirectional_relation_pair_integrity_test.dart` with two targeted regression tests.
- No local Flutter runtime is available through the GitHub connector session, so `flutter analyze` / `flutter test` have not been executed locally in this run.
- CI should be used as the executable validation source after the PR is opened. GitHub Actions usage limits may still affect availability.

## Blockers / risks

- Concurrent Object and Relation work can collide in `object_model.dart`, `object_store.dart`, and this shared handoff file; refresh before integration and keep slices narrow.
- Tag migration and Value-to-Object promotion must preserve existing bookmark/tag data.
- Full block editor scope can expand rapidly; prioritize persistence architecture and a thin usable slice before rich editing features.
- Avoid concurrent broad edits to database page code owned by the Database / View lane.
