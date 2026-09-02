# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow. Issue #56 is the product/design contract and contains Milestones A–D.

## Current implementation position

The active phase is Database/View integration and user-facing UX. Most Object/Relation primitives are already available and should be consumed rather than reimplemented.

### Integrated Object / database foundations on `main`

- #61/#64/#65/#68/#71/#76/#77/#78: Property semantics, Body/defaults, Daily Notes, reusable Weblink/Image, shared detail, canonical Relation neighborhood consumption, safe Value promotion.
- #79: grouped Board Object creation with Relation-safe presets.
- #82: Database = target ObjectType + collectionFilter foundation and Database-first/View-second projection contract.
- #85/#86/#87: collection settings UI, collection-aware page loader, collection-aware normal/Board creation, canonical Object-owned Relation editor adapter.
- #88/#89: duplicate-current/blank View creation and scoped rename/reorder/delete.
- #90/#92: persisted View Object opening modes and real settings UI.
- #91: reversible URL -> reusable Weblink promotion in Object inspector.
- #93/#95: shared Object inspector editing and typed checkbox/select/multi-select/date/rating mutation contracts.
- #94 merged as `d316b84fe0849c6ce6567c6cc5466be7076bce1f`: View tab overflow policy and `その他` handling; head passed Flutter CI #514.
- #96: `GenericDatabasePageServices` composition root for collection loader/config, collection-aware create/Board create and canonical Relation editor.

Active Object PRs:
- #97 shared typed `ObjectDetailValueEditor` contract; CI #516 in progress.
- #98 `ObjectOpenPresentationService` for persisted View/ObjectType opening-mode resolution; CI pending/starting.

PR #83 remains closed/unmerged and is not an active implementation path.

### Integrated Relation foundations on `main`

#62/#66/#69/#73/#74/#75/#80/#81 provide canonical Relation validation/mutation/read/index lifecycle, integrity audit, deterministic index reconciliation, neighborhood reads, picker candidates/selection diagnostics, safe deletion, and core Image/Tag lifecycle migration.

## Repository-wide design contract

- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = how to narrow/present a Database collection.
- Database collection filtering and View filtering are separate pipeline stages and persistence concerns.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = structured Properties + Body designed for blocks.
- Value, Object Relation and Computed semantics remain distinct.
- Tags are Objects; Select/MultiSelect remain lightweight local option sets.
- Date is a Value; Daily Note is an Object keyed by date.
- Object detail content is shared across side peek, center peek and full page.

## Delivery milestones

### Milestone A — Usable Object Database
Collection semantics in the real page, collection-aware creation, Board create-in-group UI, canonical Relation editor integration, and consistent layouts/query controls.

### Milestone B — Multi-View Database UX
Multiple independent Views, top tabs, duplicate-current/blank creation, rename/reorder/delete, independent config and overflow handling. Core management and overflow are now integrated.

### Milestone C — Object Knowledge System
Reusable Tag/Weblink/Image flows, Value -> Object affordances, richer Relations/backlinks, shared contextual Object detail/opening, stronger Daily Notes. Opening-mode persistence/settings and URL promotion are integrated; real contextual navigation remains.

### Milestone D — Document / Knowledge Layer
Real block editing, RichText/Document Property, media/file blocks, embedded Objects/Database Views and higher-level time-based note compositions.

## Next repository-wide actions

1. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage` for collection-aware reload/create/Board create/Relation edit/collection settings.
2. Add page/widget regression coverage proving Database membership resolves before View projection and new Objects target the configured ObjectType.
3. Validate/land Object PR #97 and #98.
4. Consume the resolved Object opening presentation in real View navigation, then implement side peek / center peek / full page while preserving Database/View context.
5. Wire typed Value editor descriptors/dispatch into shared Object detail presentation.
6. Continue Milestone C/D only after Milestone A page integration is coherent. Manual include/exclude remains deferred until dynamic collection + multi-View behavior is stable.

## Validation status

- #94 Flutter CI #514: success before merge.
- #97 Flutter CI #516: in progress.
- #98: CI pending/starting.
- Earlier merged #82/#86/#87/#88/#89/#90/#91/#92/#93/#95/#96 passed their relevant PR CI as recorded in lane history.

## Known risks / sequencing constraints

- `GenericDatabasePage` is the main integration hotspot; avoid parallel broad Object/Relation edits.
- Legacy page logic still assumes Database id and ObjectType id are identical in places; use merged collection adapters to remove this incrementally.
- The current GitHub connector replaces existing files as a whole. Broad direct replacement of `GenericDatabasePage` is an avoidable corruption/merge risk; prefer a patch-capable environment.
- User-facing Relation writes must use `RelationMutationService`; picker loading must not silently rewrite legacy/corrupt state.
- Board Relation-group creation must stay on the safe mutation facade.
- Opening-mode persistence/settings/resolution exist, but actual navigation still needs wiring.
- Rich Body documents must not be flattened by the paragraph-safe editor.
