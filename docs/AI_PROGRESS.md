# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current implementation position
The generic Object/Relation foundations are substantially wired into real user-facing hosts. `GenericDatabasePage` consumes collection-aware services and canonical Relation editing; `ObjectInspectorPage` consumes shared Property presentation, rich Body editing/actions, Daily Note navigation, and explicit Object plus Database/View Body references.

Milestone A/B real-host behavior is broadly integrated and regression-covered. Contextual Object opening is now also wired end-to-end: Gallery/List/Table/Board record selection resolves persisted opening behavior through the canonical `View > Database > ObjectType > app` precedence and presents side peek / center peek / full page through the shared opening host. Full-page return preserves the originating active View and its override.

## Integrated Object / database foundations on `main`
- Object/ObjectType/Property semantics, defaults, Formula/Rollup, canonical Relations, Database collection semantics, Gallery/List/Table/Board, and Multi-View management are integrated.
- #111 wires real `GenericDatabasePage` collection-aware load/create/Board create, collection settings, and canonical Relation editing.
- #112/#113/#115 integrate shared Property/Body rendering and Body actions in the real Object inspector.
- #117 integrates real Daily Note navigation and editable Daily Note Body.
- #120/#121/#124/#125/#126/#128/#130 establish explicit Object and Database/View Body-reference target selection, candidate loading, and real insertion.
- #127/#122 verify real Multi-View management and creation behavior without Object duplication/deletion.
- #131/#132 provide the shared Object opening presentation host and canonical resolve-and-present entry point.
- #134 locks existing real side-peek behavior before routing changes.
- #135 passed Flutter CI #676 and squash-merged as `ae974e2cb962a346971ecd062488e23a044ae3dd`, routing Gallery/List/Table/Board Object selection through canonical side/center/full opening behavior.
- #136 passed Flutter CI #678 and squash-merged as `fe177885dd1ac7b759029d3786790322c4d22eea`, proving full-page navigation returns to the originating active View and retains its View-specific opening override.

## Integrated Relation foundations on `main`
Canonical Relation validation/mutation/read/index lifecycle, backlinks, bidirectional integrity, target/source validation, integrity audit/reconciliation, safe deletion, picker diagnostics, and real-host Relation regression coverage are integrated through #109/#114. `GenericDatabasePage` Relation writes go through the canonical Object-owned editor/mutation facade.

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
- User-facing Relation writes must use canonical Relation APIs; Body document references are separate from Relation Property lifecycle.

## Delivery milestones
### Milestone A — Usable Object Database
Core real-host collection loading, creation, Board grouped creation, collection settings, canonical Relation editing, and lifecycle safety are integrated. Remaining work is active-use polish.

### Milestone B — Multi-View Database UX
Duplicate-current, blank creation, rename/delete/reorder/overflow, creation behavior, and View-context preservation through Object navigation are verified in the real Database host. Remaining work is active-use polish.

### Milestone C — Object Knowledge System
Shared detail, Weblink/Image flows, Value promotion, Daily Notes, Relation context, opening-mode persistence/resolution, and real side/center/full Object opening are integrated. Remaining opening work is explicit side-peek → full-page promotion and incremental convergence of the legacy side-pane detail content with the shared inspector.

### Milestone D — Document / Knowledge Layer
Rich Body persistence/editing/actions and explicit Object/Database/View reference insertion are integrated in the real inspector. Later work includes asset selectors, richer embedded content, RichText/Document Property, and higher-level time-based compositions driven by real usage.

## Next repository-wide actions
1. Add explicit side-peek → full-page promotion using the existing opening host and shared `ObjectInspectorPage` while preserving Database/View context.
2. Add real-host regression coverage for that promotion and return path.
3. Incrementally converge the legacy side-pane `_detail(...)` content toward shared Object detail content without a broad `GenericDatabasePage` rewrite.
4. Begin active use of Milestone A/B flows and prioritize concrete regressions/polish.
5. Add Image/File Body selectors only when concrete reusable asset pickers exist.
6. Implement `RichText/Document Property` only after navigation/detail convergence stabilizes because of broad enum/query/group/Board/detail impact.
7. Keep manual include/exclude deferred until dynamic collection + Multi-View behavior is proven in active use.

## Validation status
- #135 Flutter CI #676: success; squash merge `ae974e2cb962a346971ecd062488e23a044ae3dd`.
- #136 Flutter CI #678: success; squash merge `fe177885dd1ac7b759029d3786790322c4d22eea`.
- Earlier merged Object and Relation slices passed their relevant CI as recorded in lane handoffs.

## Known risks / sequencing constraints
- `GenericDatabasePage` remains a large integration hotspot; keep further opening/detail edits focused and verify exact current blob/diff.
- User-facing Relation writes must remain on canonical mutation/editor APIs.
- Rich Body documents must never be flattened by paragraph-only editing.
- Side/center/full opening and promotion must operate on the same global Object and shared detail logic rather than fork editors.
- The right-side pane still contains legacy duplicate detail/Property UI; converge it incrementally rather than rewriting the whole host.
- Reference actions must remain hidden until concrete target selectors exist.
- `RichText/Document Property` has broad exhaustive-switch and UI/query impact.
