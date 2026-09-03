# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current implementation position
The generic Object/Relation foundations are substantially wired into real user-facing hosts. `GenericDatabasePage` consumes collection-aware services and the canonical Relation editor. `ObjectInspectorPage` consumes shared Property presentation, rich Body rendering/editing/actions, Daily Note navigation, and explicit Object plus Database/View Body-reference insertion.

Milestone A/B real-host behavior is broadly integrated and regression-covered. Milestone C opening-mode persistence/resolution plus the concrete side/center/full-page presentation host are now on `main` through #131. The remaining high-value navigation step is making real Database/View record/card selection call that canonical opening path.

## Integrated Object / database foundations on `main`
- Object/ObjectType/Property semantics, defaults, Formula/Rollup, canonical Relations, Database collection semantics, Gallery/List/Table/Board, and Multi-View management are integrated.
- #111 wires real `GenericDatabasePage` collection-aware load/create/Board create, collection settings, and canonical Relation editing.
- #112/#113/#115 integrate shared Property/Body rendering and Body actions in the real Object inspector.
- #117 integrates real Daily Note navigation and editable Daily Note Body.
- #120/#121/#124/#125/#126/#128 establish explicit Object and Database/View Body-reference target selection and candidate loading.
- #127/#122 verify real Multi-View management and creation behavior without Object duplication/deletion.
- #130 completes real Database/View Body-reference insertion after an anchor and into an empty Body.
- #131 passed Flutter CI #663 and squash-merged as `da8c2906b6eda363db5906a8f1d61c93fd567f1b`, adding the shared Object opening presentation host and canonical opening resolver composition.

PR #83 remains closed/unmerged. PR #110 was closed redundant. PR #129 was closed as a stacked ancestry artifact and superseded by #130.

## Active Object integration
- PR #132 — `Resolve and present Object opening in one host call`.
- Adds `ObjectOpenPresentationHost.openResolved(...)`, which delegates `View > Database > ObjectType > app` precedence to `ObjectOpenPresentationService` and immediately presents side/center/full behavior through the existing host.
- The goal is to keep the eventual large `GenericDatabasePage` patch to one canonical opening call instead of duplicating precedence/routing logic.
- Functional head before the handoff update: `95f7d6851a8191d1698938e23bfb245e31afb6ec`; Flutter CI #665 running at that checkpoint.

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
- Shared Object detail content must be reused across side peek, center peek, and full page.
- User-facing Relation writes must use canonical Relation APIs; Body document references are separate from Relation Property lifecycle.

## Delivery milestones
### Milestone A — Usable Object Database
Core real-host collection loading, creation, Board grouped creation, collection settings, canonical Relation editing, and lifecycle safety are integrated. Remaining work is active-use polish.

### Milestone B — Multi-View Database UX
Duplicate-current, blank creation, rename/delete/reorder/overflow, and creation behavior are verified through the real Database host. Remaining work is active-use polish.

### Milestone C — Object Knowledge System
Shared detail, Weblink/Image flows, Value promotion, Daily Notes, Relation context, opening-mode persistence/resolution, and concrete side/center/full presentation exist. Remaining priority is wiring real Database/View selection to that host.

### Milestone D — Document / Knowledge Layer
Rich Body persistence/editing/actions and explicit Object/Database/View reference insertion are integrated in the real inspector. Later work includes asset selectors, richer embedded content, RichText/Document Property, and higher-level time-based compositions driven by real usage.

## Next repository-wide actions
1. Finish PR #132 CI/merge, repairing any branch-caused failure.
2. Make a tightly controlled `GenericDatabasePage` patch that sends Gallery/List/Table/Board Object selection through one canonical opening method using `ObjectOpenPresentationHost.openResolved(...)`.
3. Preserve current right-hand `ResizableDetailPane` for side peek and reuse `ObjectInspectorPage` for center/full page.
4. Add real-host tests for side/center/full-page selection and View override precedence while preserving Database/View context.
5. Begin active use of Milestone A/B flows and prioritize concrete regressions/polish.
6. Add Image/File Body selectors only when concrete reusable asset pickers exist.
7. Implement `RichText/Document Property` only after navigation stabilizes because of broad enum/query/group/Board/detail impact.
8. Keep manual include/exclude deferred until dynamic collection + Multi-View behavior is proven in active use.

## Validation status
- #124 Flutter CI #640: success; merged.
- #130 Flutter CI #657: success; squash merge `0e0ea6e628d238f7861adc06a3ff730ed001f396`.
- #131 Flutter CI #663: success; squash merge `da8c2906b6eda363db5906a8f1d61c93fd567f1b`.
- #132 functional head `95f7d6851a8191d1698938e23bfb245e31afb6ec`: Flutter CI #665 running at the recorded checkpoint.
- Earlier merged Object and Relation slices passed their relevant CI as recorded in lane handoffs.

## Known risks / sequencing constraints
- `GenericDatabasePage` remains a large integration hotspot; keep opening-mode edits focused and verify exact diff/current blob SHA.
- User-facing Relation writes must remain on canonical mutation/editor APIs.
- Rich Body documents must never be flattened by paragraph-only editing.
- Opening modes must reuse shared detail content rather than fork editors.
- Reference actions must remain hidden until concrete target selectors exist.
- `RichText/Document Property` has broad exhaustive-switch and UI/query impact.
