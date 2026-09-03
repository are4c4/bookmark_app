# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is in real-host completion. `main` now includes the major Database/Object-detail/Body/Daily Note integrations plus real Multi-View management verification and real Database/View Body-reference insertion through PR #130.

Key real-host milestones integrated on `main` include #111 GenericDatabasePage collection-aware integration, #112/#113 shared Object Property/Body inspector integration, #115 Body actions, #117 Daily Note navigation, #120/#121/#124/#125/#126 Object and Database/View reference-selection foundations, #127 Multi-View management verification, #128 Database/View candidate loading, and #130 real Database/View reference insertion.

The current production priority is contextual Object opening: consume persisted opening-mode resolution in real Database/View navigation for side peek / center peek / full page while reusing shared detail content.

## Active branch / PR
- Branch: `feature/object-open-presentation-host`
- PR: #131 — `Add shared Object opening presentation host`
- Latest functional head before this handoff update: `df93163ac1570521efe97612fc68d979be8f5524`
- Flutter CI #661 is pending on that functional head.

## Checkpoints completed in this run
1. **Validated and merged real Database/View Body reference insertion**
   - PR #130 latest head `29aa338817b6ba0f3806e3aba63e256df6d62210` passed Flutter CI #657.
   - Squash-merged as `0e0ea6e628d238f7861adc06a3ff730ed001f396`.
   - Real Object inspector now supports explicit Database-only or specific-View reference insertion after an anchor and as the first Body block.

2. **Added concrete Object opening presentation host**
   - Added `ObjectOpenPresentationHost` as the Flutter presentation layer for already-resolved `ObjectOpenMode` values.
   - `sidePeek` delegates to the contextual-pane callback, `centerPeek` opens a modal dialog, and `fullPage` pushes a route.
   - Center/full-page reuse the same supplied detail builder so presentation modes do not fork detail rendering.

3. **Added presentation-host regression coverage**
   - Side peek performs no navigation and delegates exactly once.
   - Center peek renders shared detail content in a dialog.
   - Full page pushes the same shared detail builder as a route.

4. **Exposed canonical opening resolution from `GenericDatabasePageServices`**
   - The page composition root now assembles `ObjectOpenPresentationService` from `DatabaseViewOpenModeService`, `DatabaseViewStore`, and `ObjectTypeDefaultsStore`.
   - This keeps the upcoming real-host patch small and preserves `View > Database > ObjectType > app` resolution in the existing service.
   - Added in-memory coverage proving View override precedence and ObjectType-default fallback through the composition root.

## Exact next actions
1. Inspect PR #131 latest-head CI; fix branch-caused failures and merge when green/mergeable.
2. On latest `main`, make a focused `GenericDatabasePage` patch that calls `services.openPresentation.resolve(...)` on real record/card selection and delegates to `ObjectOpenPresentationHost`.
3. Preserve side peek as contextual Database work, use shared `ObjectInspectorPage` detail for center/full page, and keep originating Database/View context where practical.
4. Add real-host tests for side/center/full-page selection and View override precedence across Gallery/List/Table/Board entry points where practical.
5. After contextual opening lands, prioritize active-use regressions/polish before broader model expansion.
6. Keep Image/File Body reference actions hidden until concrete selectors exist; keep manual include/exclude deferred.
7. Implement `RichText/Document Property` only after navigation work is stable because of its broad enum/query/group/Board/detail impact.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must continue through canonical Relation mutation/editor APIs.
- Body Object/Database/View references remain document references, not Relation Property writes.
- GenericDatabasePage, Object detail/navigation, Body editing/reference insertion, Daily Notes, and multi-View UX remain Object-owned.
- No active Relation dependency blocks the current opening-mode work.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` remains a large hotspot. This connector still replaces existing files as whole files, so the actual host wiring must be a narrowly controlled edit with exact current blob SHA/diff verification; PR #131 deliberately reduces that future patch surface.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Opening modes must reuse shared detail content rather than creating separate editors.

## Validation
- #130 Flutter CI #657: success; squash merge `0e0ea6e628d238f7861adc06a3ff730ed001f396`.
- #131 functional head `df93163ac1570521efe97612fc68d979be8f5524`: Flutter CI #661 pending at this handoff checkpoint.
- Connector runtime has no local Flutter SDK; executable validation relies on GitHub Actions for connector-only changes.

## Stop reason
This run completed four coherent checkpoints: #130 validation/merge, concrete opening presentation UI, its widget regressions, and page-composition-root opening resolution. The next production step is a focused edit to the large real `GenericDatabasePage`; PR #131 intentionally minimizes the code that must be added there. Continue once #131 CI resolves, repairing any branch-caused failure first. Pending CI alone is not the conceptual blocker; the remaining host change requires a carefully controlled large-file edit in this connector runtime.
