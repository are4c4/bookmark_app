# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current implementation position
The generic Object/Relation foundations are substantially wired into real user-facing hosts. `GenericDatabasePage` consumes collection-aware services and canonical Relation editing; `ObjectInspectorPage` consumes shared Property presentation, rich Body editing/actions, Daily Note navigation, and explicit Object plus Database/View Body references.

Milestone A/B real-host behavior is broadly integrated and regression-covered. Contextual Object opening is wired end-to-end: Gallery/List/Table/Board record selection resolves persisted opening behavior through canonical `View > Database > ObjectType > app` precedence and presents side peek / center peek / full page. Full-page return preserves the originating active View and its override. Side peek can explicitly promote the same global Object to full page and reload edits back into the originating Database context.

PR #146 passed Flutter CI #710 and squash-merged as `60ed7a273e513e8494d5e5cfbc4b296b88578563`. The real Database side peek now consumes shared `ObjectDetailPropertyPresenter` + `ObjectDetailPropertyView` presentation instead of maintaining a duplicate manual Property row, while preserving reorder, editable Value behavior, computed read-only behavior, canonical Relation chips, backlinks, pane sizing, title edit, and full-page promotion.

PR #147 is the active Object host slice. It replaces the remaining low-level side-peek Object deletion callback with the stable canonical `RelationMutationService.deleteObject(...)` boundary and adds a real-host regression proving incoming Relations are detached when the selected Object is deleted.

## Integrated Object / database foundations on `main`
- Object/ObjectType/Property semantics, defaults, Formula/Rollup, canonical Relations, Database collection semantics, Gallery/List/Table/Board, and Multi-View management are integrated.
- #111 wires real `GenericDatabasePage` collection-aware load/create/Board create, collection settings, and canonical Relation editing.
- #112/#113/#115 integrate shared Property/Body rendering and Body actions in the real Object inspector.
- #117 integrates real Daily Note navigation and editable Daily Note Body.
- #120/#121/#124/#125/#126/#128/#130 establish explicit Object and Database/View Body-reference target selection, candidate loading, and real insertion.
- #127/#122 verify real Multi-View management and creation behavior without Object duplication/deletion.
- #131/#132 provide the shared Object opening presentation host and canonical resolve-and-present entry point.
- #134 locks existing real side-peek behavior before routing changes.
- #135/#136 integrate real side/center/full opening and active-View preservation.
- #138/#139 integrate side-peek → full-page promotion and prove the same global Object state refreshes back into the contextual pane.
- #141 locks side-peek Value editing before detail convergence.
- #143 prepares the shared Property row for contextual host chrome/edit interaction.
- #146 passes CI #710 and integrates the shared Property row into the real Database side peek.

## Integrated Relation foundations on `main`
Canonical Relation validation/mutation/read/index lifecycle, backlinks, bidirectional integrity, target/source validation, integrity audit/reconciliation, Relation-safe Object deletion, picker diagnostics, and real-host Relation regression coverage are integrated through #109/#114. `GenericDatabasePage` Relation writes go through the canonical Object-owned editor/mutation facade. PR #146 additionally exposes the same stable `RelationMutationService` instance through `GenericDatabasePageServices` so Object-owned hosts can consume Relation-safe Object deletion without duplicating lifecycle logic.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = how to narrow/present a Database collection.
- Database collection filtering and View filtering are separate persistence/query stages.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Value, Object Relation, and Computed remain distinct.
- Tags are Objects; Select/MultiSelect remain lightweight local options.
- Date is a Value; Daily Note is an Object keyed by date.
- Shared Object detail content should be reused across side peek, center peek, and full page.
- User-facing Relation writes and deletions that affect Relation lifecycle must use canonical Relation APIs; Body document references are separate from Relation Property lifecycle.

## Delivery milestones
### Milestone A — Usable Object Database
Core real-host collection loading, creation, Board grouped creation, collection settings, canonical Relation editing, and lifecycle safety are integrated. Remaining work is active-use polish.

### Milestone B — Multi-View Database UX
Duplicate-current, blank creation, rename/delete/reorder/overflow, creation behavior, and View-context preservation through Object navigation are verified in the real Database host. Remaining work is active-use polish.

### Milestone C — Object Knowledge System
Shared detail, Weblink/Image flows, Value promotion, Daily Notes, Relation context, opening-mode persistence/resolution, real side/center/full Object opening, explicit side-peek → full-page promotion, and shared Property presentation in the real side peek are integrated. Remaining detail work should continue as small convergence slices, not a broad host rewrite.

### Milestone D — Document / Knowledge Layer
Rich Body persistence/editing/actions and explicit Object/Database/View reference insertion are integrated in the real inspector. Later work includes asset selectors, richer embedded content, RichText/Document Property, and higher-level time-based compositions driven by real usage.

## Next repository-wide actions
1. Validate and merge PR #147 when latest-head Flutter CI is green; this closes the real side-peek Object deletion lifecycle gap without changing Relation implementation.
2. Continue incremental side-pane/shared-detail convergence with one focused duplicated element at a time, using real-host regressions before each change.
3. Preserve contextual pane sizing/close behavior, canonical Relation lifecycle, rich Body safety, same-global-Object navigation, and Value editing while converging detail presentation.
4. Begin active use of Milestone A/B flows and prioritize concrete regressions/polish over speculative abstractions.
5. Add Image/File Body selectors only when concrete reusable asset pickers exist.
6. Implement `RichText/Document Property` only after navigation/detail convergence stabilizes because of broad enum/query/group/Board/detail impact.
7. Keep manual include/exclude deferred until dynamic collection + Multi-View behavior is proven in active use.

## Validation status
- #146 head `05bc1e91b176b867e4df8d1d4a9a8e78347d581a`: Flutter CI #710 — success; squash merge `60ed7a273e513e8494d5e5cfbc4b296b88578563`.
- #147 production compare from #146 main: `GenericDatabasePage` delete callback only (`+22/-5`) plus one new real-host incoming-Relation deletion regression; latest CI is tracked in `docs/AI_PROGRESS_OBJECT.md`.
- Earlier merged Object and Relation slices passed their relevant CI as recorded in lane handoffs.

## Known risks / sequencing constraints
- `GenericDatabasePage` remains a large integration hotspot; keep further detail edits focused, reconstruct only from exact current blob when whole-file replacement is required, and compare-audit every change.
- User-facing Relation writes and Object deletions with possible incoming Relations must remain on canonical mutation/editor APIs.
- Rich Body documents must never be flattened by paragraph-only editing.
- Side/center/full opening and promotion must operate on the same global Object and shared detail logic rather than fork editors.
- Remaining side-pane detail duplication should be converged incrementally rather than by rewriting the whole host.
- Reference actions must remain hidden until concrete target selectors exist.
- `RichText/Document Property` has broad exhaustive-switch and UI/query impact.
