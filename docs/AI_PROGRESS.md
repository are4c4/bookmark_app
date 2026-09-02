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
- #94: View tab overflow policy and `その他` handling.
- #96: `GenericDatabasePageServices` composition root for collection loader/config, collection-aware create/Board create and canonical Relation editor.
- #97 merged as `8aeba4da7fc8a093eb20b16afe87aea426eee22d`: shared typed `ObjectDetailValueEditor` descriptor/dispatch contract.
- #98 merged as `123c8aabc6ab8913e30b657023953cd03ec8a9cb`: persisted View/ObjectType opening-mode resolution through `ObjectOpenPresentationService`.
- #100 merged as `09802d5aaef8d1f4ae6d3e9f8e4d7e46a6b6c498`: container-agnostic Object-detail Property presentation and canonical Relation-renderer separation.
- #99 merged as `96b15bae63299a6dc566558066e2d5902e5a6f3f`: shared typed text-input normalization for Object-detail number/select/multi-select/date/rating editing.
- #101 merged as `e7a8f6aec9e9631f01e486a5f7671df7b3cd5010`: immutable + persisted Object Body block operations that preserve unknown/future block payloads instead of flattening rich documents.

PR #83 remains closed/unmerged and is not an active implementation path. PR #102 is the active additive Daily Note navigation slice.

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
- Object detail content and Property/editor contracts are shared across side peek, center peek and full page.

## Delivery milestones

### Milestone A — Usable Object Database
Collection semantics in the real page, collection-aware creation, Board create-in-group UI, canonical Relation editor integration, and consistent layouts/query controls.

### Milestone B — Multi-View Database UX
Multiple independent Views, top tabs, duplicate-current/blank creation, rename/reorder/delete, independent config and overflow handling. Core management and overflow are integrated.

### Milestone C — Object Knowledge System
Reusable Tag/Weblink/Image flows, Value -> Object affordances, richer Relations/backlinks, shared contextual Object detail/opening, stronger Daily Notes. Opening-mode persistence/settings/resolution, URL promotion, shared typed Value editor/input normalization and shared Property presentation are integrated; real contextual navigation/UI consumption remains. Daily Note previous/today/next navigation is in active PR #102.

### Milestone D — Document / Knowledge Layer
Real block editing, RichText/Document Property, media/file blocks, embedded Objects/Database Views and higher-level time-based note compositions. Safe block-level mutation/persistence primitives are integrated via #101; real block UI remains.

## Next repository-wide actions

1. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage` for collection-aware reload/create/Board create/Relation edit/collection settings.
2. Add page/widget regression coverage proving Database membership resolves before View projection and new Objects target the configured ObjectType.
3. Consume `ObjectOpenPresentationService` in real View navigation, then implement side peek / center peek / full page while preserving Database/View context.
4. Consume `ObjectDetailPropertyPresenter`, `ObjectDetailValueEditor`, and `ObjectDetailValueInputCodec` in shared Object detail UI so typed Value behavior is consistent across presentations.
5. Merge PR #102 when latest-head CI is green, then expose Daily Note previous/today/next through shared Object navigation when a patch-capable UI environment is available.
6. Build real block UI incrementally on `ObjectBodyBlockEditService`; never flatten unknown/rich blocks through the paragraph adapter.
7. Manual include/exclude remains deferred until dynamic collection + multi-View behavior is stable.

## Validation status

- #97 corrected Flutter CI #520: success before merge.
- #98 Flutter CI #517: success before merge.
- #100 Flutter CI #525: Drift generation, `flutter analyze`, and tests succeeded before merge.
- #99 corrected head passed Flutter CI #526 with `No issues found!` and 305 tests passed before merge.
- #101 head `33ba0a9cd42ac031d9a0100dfe52a543ff02ca4a`: Flutter CI #531 succeeded before merge.
- #102 corrected head `b4034236a8abdf66ec807d15cabd9df2aeeab8f5`: latest Flutter CI #533 running.
- Earlier merged #82/#86/#87/#88/#89/#90/#91/#92/#93/#94/#95/#96 passed their relevant PR CI as recorded in lane history.

## Known risks / sequencing constraints

- `GenericDatabasePage` is the main integration hotspot; avoid parallel broad Object/Relation edits.
- Legacy page logic still assumes Database id and ObjectType id are identical in places; use merged collection adapters to remove this incrementally.
- The current GitHub connector replaces existing files as a whole. Broad direct replacement of `GenericDatabasePage` or large Object detail/navigation surfaces is an avoidable corruption/merge risk; prefer a patch-capable environment.
- The execution container cannot currently resolve GitHub directly, so it cannot obtain a patchable clone as a workaround.
- User-facing Relation writes must use `RelationMutationService`; picker loading must not silently rewrite legacy/corrupt state.
- Board Relation-group creation must stay on the safe mutation facade.
- Opening-mode persistence/settings/resolution and shared detail contracts exist, but actual contextual navigation/detail UI still needs wiring.
- Rich Body documents must not be flattened by the paragraph-safe editor; #101 provides narrow block-level mutation primitives for future UI.
