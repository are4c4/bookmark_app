# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow. Issue #56 is the product/design contract and contains Milestones A–D.

## Current implementation position
The active phase is Database/View and shared Object-detail UI integration. Most Object/Relation primitives and many reusable Flutter presentation components now exist and should be consumed rather than reimplemented. The remaining highest-value gaps sit in the large real page/detail/navigation hosts, which need patch-capable editing.

### Integrated Object / database foundations on `main`
- #61/#64/#65/#68/#71/#76/#77/#78: Property semantics, Body/defaults, Daily Notes, reusable Weblink/Image, shared detail, canonical Relation neighborhood consumption, safe Value promotion.
- #79: grouped Board Object creation with Relation-safe presets.
- #82: Database = target ObjectType + collectionFilter foundation and Database-first/View-second projection contract.
- #85/#86/#87: collection settings UI, collection-aware page loader, collection-aware normal/Board creation, canonical Object-owned Relation editor adapter.
- #88/#89/#94: multi-View creation/management/overflow.
- #90/#92/#98: persisted View Object opening modes, settings UI, and effective presentation resolution.
- #91: reversible URL -> reusable Weblink promotion in Object inspector.
- #93/#95/#97/#99/#100: shared Object inspector/detail editing, typed mutation/input contracts, and shared Property presentation.
- #96: `GenericDatabasePageServices` composition root.
- #101: immutable + persisted Object Body block operations preserving unknown/future block payloads.
- #102: Daily Note previous/today/next calendar navigation using canonical open-or-create semantics.
- #103: rich Body block factories/contracts, known-payload validation, and embedded Object/Database/View/asset reference indexing while retaining unknown-block forward compatibility.
- #104: Daily Note calendar navigation composed directly into shared `ObjectDetailContent`.
- #105: widget-independent shared Body block presentation metadata for text/heading/checklist/code/reference/Database View/asset/unknown blocks.
- #106: reusable Flutter Body/document/Property/Daily Note widgets and safe latest-read Body text/checklist mutations.
- #107 merged as `39fdc54b276a5241eb2fd07214b868d1abb0e466`: generic Body insert kinds, latest-read relative move/atomic insert-after persistence, persisted block action controller, shared insert/action chrome, and `ObjectBodyDocumentView` action injection.

PR #83 remains closed/unmerged and is not active.

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
- Object detail content, Property rendering/editing, Body rendering/editing, and Daily Note navigation should be shared across side peek, center peek and full page rather than forked per presentation.

## Delivery milestones
### Milestone A — Usable Object Database
Collection semantics in the real page, collection-aware creation, Board create-in-group UI, canonical Relation editor integration, and consistent layouts/query controls.

### Milestone B — Multi-View Database UX
Multiple independent Views, top tabs, duplicate-current/blank creation, rename/reorder/delete, independent config and overflow handling. Core management and overflow are integrated.

### Milestone C — Object Knowledge System
Reusable Tag/Weblink/Image flows, Value -> Object affordances, richer Relations/backlinks, shared contextual Object detail/opening, stronger Daily Notes. Opening-mode persistence/settings/resolution, URL promotion, typed Value editor/input normalization, shared Property presentation, Daily Note navigation/services, plus shared Flutter Property and Daily Note navigation widgets are integrated; real host/navigation consumption remains.

### Milestone D — Document / Knowledge Layer
Real block editing, RichText/Document Property, media/file blocks, embedded Objects/Database Views and higher-level time-based note compositions. Safe block mutation/persistence, typed rich-block/reference contracts, reference indexing, presentation metadata, reusable Flutter rendering/editing, and generic insert/remove/move chrome are integrated through #101/#103/#105/#106/#107. Host integration and reference-target insertion UX remain.

## Next repository-wide actions
1. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage` for collection-aware reload/create/Board create/Relation edit/collection settings.
2. Add page/widget regression coverage proving Database membership resolves before View projection and new Objects target the configured ObjectType.
3. Integrate shared `ObjectDetailPropertyView` and `ObjectBodyDocumentView` into the real Object detail/inspector host; wire text/checklist edits plus #107 insert/remove/move chrome while preserving rich/unknown blocks.
4. Consume `ObjectOpenPresentationService` in real View navigation, then implement side peek / center peek / full page while preserving Database/View context.
5. Wire `DailyNoteNavigationBar` to `DailyNoteDetailNavigationService` in shared Object navigation.
6. Complete explicit reference-bearing Body insertion flows without ever persisting unresolved placeholder blocks.
7. Implement `RichText/Document Property` in a patch-capable environment because the Property enum member affects exhaustive switches in query/group/Board/detail paths and `GenericDatabasePage`.
8. Manual include/exclude remains deferred until dynamic collection + multi-View behavior is stable.

## Validation status
- #103 Flutter CI #541 succeeded before merge.
- #104 Flutter CI #542 succeeded before merge.
- #105 Flutter CI #547 succeeded before merge.
- #106 corrected Flutter CI #559 succeeded before merge.
- #107 Flutter CI #574 succeeded before squash merge as `39fdc54b276a5241eb2fd07214b868d1abb0e466`.
- Earlier merged Object and Relation slices passed their relevant PR CI as recorded in lane history.

## Known risks / sequencing constraints
- `GenericDatabasePage` is the main integration hotspot; avoid parallel broad Object/Relation edits.
- Legacy page logic still assumes Database id and ObjectType id are identical in places; use merged collection adapters to remove this incrementally.
- The current GitHub connector replaces existing files as a whole. Broad direct replacement of `GenericDatabasePage`, `ObjectInspectorPage`, or other large navigation/detail surfaces is an avoidable corruption/merge risk; prefer a patch-capable environment.
- `RichText/Document Property` has broad exhaustive-switch and UI/query impact, including `GenericDatabasePage`, so it should be sequenced in a patch-capable environment.
- User-facing Relation writes must use `RelationMutationService`; picker loading must not silently rewrite legacy/corrupt state; Relation display should use canonical resolved Objects rather than persisted ids.
- Board Relation-group creation must stay on the safe mutation facade.
- Rich Body documents must not be flattened by the paragraph-safe editor.
