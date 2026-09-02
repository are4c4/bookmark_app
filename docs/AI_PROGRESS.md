# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow. Issue #56 is the product/design contract and contains Milestones A–D.

## Current implementation position
Most Object/Relation primitives and many reusable Flutter presentation/editing components now exist. The highest-value remaining work is **real-host integration** in `GenericDatabasePage`, the actual Object detail/navigation host, and Daily Note navigation.

Do not keep expanding parallel foundations merely because hotspot integration is inconvenient. Prefer consuming existing services/widgets in real hosts. New foundation slices are justified when they unblock concrete integration, close a correctness gap, or can safely proceed while a required hotspot is unavailable.

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
- #101/#103/#105/#106/#107/#108: safe Body block mutation/persistence, rich/reference block contracts, presentation metadata, reusable Flutter rendering/editing, insert/remove/move/insert-after actions, typed Object/Database/View/Image/File reference insertion, deterministic block-id allocation, payload-preserving duplication, and shared reference action chrome.
- #102/#104/#106: Daily Note previous/today/next navigation services plus shared navigation widget.

PR #83 remains closed/unmerged and is not active.

PR #110 was closed unmerged after the latest Issue/handoff refresh showed that its loader replay duplicated already-integrated #86/#87/#96 functionality.

### Latest Object integration
- PR #108 passed Flutter CI #590 on its functional head and was squash-merged as `273578d94f272e9e37169f02afafcf1d60c60082`.
- There is currently no active Object implementation PR; the next Object work is real-host integration rather than another foundation branch.

### Integrated Relation foundations on `main`
#62/#66/#69/#73/#74/#75/#80/#81 provide canonical Relation validation/mutation/read/index lifecycle, integrity audit, deterministic index reconciliation, neighborhood reads, picker candidates/selection diagnostics, safe deletion, and core Image/Tag lifecycle migration.

Relation PR #109 is active tests-only work around the canonical editor integration boundary and remains Relation-lane owned.

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
Core services exist. Remaining emphasis is real `GenericDatabasePage` consumption of collection-aware reload/create/Board create/Relation editing/collection settings plus integrated regression coverage.

### Milestone B — Multi-View Database UX
Core View creation/management/overflow is integrated. Remaining emphasis is end-to-end use in the real Database host and preserving sidebar Database navigation vs top-tab View navigation.

### Milestone C — Object Knowledge System
Reusable Weblink/Image flows, Value promotion, shared Object detail, opening-mode persistence/settings/resolution, typed Value editing, Daily Note services/widgets are integrated. Remaining emphasis is real side/center/full-page navigation and host consumption.

### Milestone D — Document / Knowledge Layer
Safe block persistence/editing, rich/reference contracts, shared rendering/action/reference chrome are substantially implemented through #108. Remaining emphasis is real Object Body host integration, target-selection flows, `RichText/Document Property`, embedded Database/View behavior, and higher-level note compositions.

## Integration-first sequencing rule
1. Prefer wiring existing services/widgets into real user-facing hosts over creating another parallel abstraction.
2. `GenericDatabasePage`, Object detail/navigation, and Daily Note host integration outrank speculative new Object/Body foundations.
3. Use a patch-capable environment for broad changes to large hotspot files; avoid whole-file replacement risk.
4. Finish Milestone A/B real-host integration and begin active app use before adding manual membership complexity.
5. Let real usage drive the next Milestone C/D expansions.

## Next repository-wide actions
1. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage` for Database-first collection reload, collection-aware normal/Board creation, canonical Relation picker/editor, and collection settings.
2. Add page/widget regression coverage proving Database membership resolves before View projection and new Objects target the configured ObjectType.
3. Integrate shared `ObjectDetailPropertyView` and `ObjectBodyDocumentView` into the real Object detail host, including #107/#108 block actions/reference insertion while preserving rich/unknown payloads.
4. Consume `ObjectOpenPresentationService` in real navigation and implement side peek / center peek / full page while preserving Database/View context.
5. Wire `DailyNoteNavigationBar` to `DailyNoteDetailNavigationService` in shared Object navigation.
6. Implement `RichText/Document Property` only in a patch-capable environment because of broad enum/query/group/Board/detail impact.
7. Manual include/exclude remains deferred until dynamic collection + multi-View behavior is proven in real use.

## Validation status
- #107 Flutter CI #574 succeeded before squash merge as `39fdc54b276a5241eb2fd07214b868d1abb0e466`.
- #108 functional head Flutter CI #590 succeeded before squash merge as `273578d94f272e9e37169f02afafcf1d60c60082`.
- Earlier merged Object and Relation slices passed their relevant PR CI as recorded in lane history.

## Known risks / sequencing constraints
- `GenericDatabasePage` is the main integration hotspot; avoid parallel broad Object/Relation edits.
- Legacy page logic still assumes Database id and ObjectType id are identical in places; use merged collection adapters to remove this incrementally.
- Broad direct replacement of `GenericDatabasePage`, `ObjectInspectorPage`, or other large navigation/detail surfaces is an avoidable corruption/merge risk; prefer patch-capable editing.
- `RichText/Document Property` has broad exhaustive-switch and UI/query impact.
- User-facing Relation writes must use `RelationMutationService`; picker loading must not silently rewrite legacy/corrupt state; Relation display should use canonical resolved Objects rather than persisted ids.
- Rich Body documents must never be flattened by the paragraph-safe editor.
