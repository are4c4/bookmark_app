# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is now past the main real-host Database/View opening integration. `main` contains collection-aware `GenericDatabasePage`, canonical Relation editing, shared Object Property/Body inspector content, Body actions and Object/Database/View references, Daily Note navigation, Multi-View management, and persisted Object opening modes.

PR #135 completes the key navigation path: Gallery/List/Table/Board Object selection in the real `GenericDatabasePage` now routes through `ObjectOpenPresentationHost.openResolved(...)`, so `View > Database > ObjectType > app` opening precedence is canonical. `sidePeek` preserves the contextual right-hand pane; `centerPeek` and `fullPage` reuse `ObjectInspectorPage` and reload the Database after returning.

PR #136 adds real-host coverage proving a View-specific `fullPage` mode survives navigation away and back: the originating active View remains selected and its opening override still applies when the Object is reopened.

## Active branch / PR
- No active implementation PR after #135 and #136 were merged.
- Latest integrated main checkpoint: `fe177885dd1ac7b759029d3786790322c4d22eea` (#136 squash merge).

## Checkpoints completed in the latest run
1. **Completed real Database/View opening integration**
   - PR #135 routed Gallery/List/Table/Board Object selection through one `_openDatabaseObject(...)` method.
   - The method delegates persisted opening-mode resolution to `ObjectOpenPresentationHost.openResolved(...)`.
   - Side peek remains contextual; center/full use the shared `ObjectInspectorPage` detail implementation.
   - Production diff was limited to opening imports/host/method plus the four layout selection callbacks; no Relation/schema/migration changes.

2. **Expanded real-host opening regressions across layouts**
   - ObjectType `centerPeek` default is exercised from the real page.
   - View `fullPage` override winning over ObjectType `centerPeek` is exercised from the real page.
   - Table and Board Object entry points are explicitly covered in addition to Gallery/List behavior.
   - PR #135 head `76000b31cad1f4b7b1f566f9b05dbb069919f1f6` passed Flutter CI #676 and squash-merged as `ae974e2cb962a346971ecd062488e23a044ae3dd`.

3. **Locked originating View context across full-page navigation**
   - PR #136 uses two real Views so accidental fallback to the first View is observable.
   - After opening an Object through a `fullPage` View override, returning, and reopening the Object, the same View override still wins.
   - PR #136 head `4a692829473be486c9871cbe9a0be63e110d747e` passed Flutter CI #678 and squash-merged as `fe177885dd1ac7b759029d3786790322c4d22eea`.

## Exact next actions
1. Add an explicit **side peek → full page** promotion action, as required by Issue #56, reusing the existing `ObjectOpenPresentationHost` and `ObjectInspectorPage` rather than inventing another navigation path.
2. Add a real-host regression proving promotion opens the same global Object and returning preserves the active Database/View context.
3. Incrementally converge the legacy side-pane `_detail(...)` implementation toward the shared Object detail content. Avoid a broad rewrite: preserve contextual pane sizing/close behavior while removing duplicated Property/detail logic in reviewable slices.
4. Begin active-use polish on Milestone A/B flows once contextual opening is complete; prioritize observed regressions over new abstractions.
5. Keep Image/File Body-reference actions hidden until concrete reusable asset selectors exist.
6. Implement `RichText/Document Property` only after navigation/detail convergence is stable because it affects exhaustive Property/query/group/Board/detail paths.
7. Keep manual include/exclude membership deferred until dynamic collection + Multi-View behavior is proven in real use.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must continue through canonical Relation mutation/editor APIs.
- Body Object/Database/View references remain document references, not Relation Property writes.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and Multi-View UX remain Object-owned.
- No active Relation dependency blocks the current opening/detail work.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` remains a large hotspot and the connector replaces existing files as whole files. Any next production edit there must use the exact current blob and verify a narrowly scoped diff; do not broadly rewrite the file merely to progress.
- The right-side pane still uses legacy `_detail(...)` content while center/full use `ObjectInspectorPage`; this is the remaining shared-detail convergence gap.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Opening modes and explicit promotion must reuse the same global Object/detail data rather than fork editors.

## Validation
- #135 Flutter CI #676: success; squash merge `ae974e2cb962a346971ecd062488e23a044ae3dd`.
- #136 Flutter CI #678: success; squash merge `fe177885dd1ac7b759029d3786790322c4d22eea`.
- #134 locks default real side-peek behavior on latest pre-#135 main.
- Earlier merged Object/Relation slices passed their relevant CI as recorded in prior handoffs.
- Connector runtime has no local Flutter SDK; executable validation for connector-only changes relies on GitHub Actions.

## Stop reason
No architectural or product blocker is active. The next production task is the small side-peek-to-full-page promotion slice. This run stopped after integrating #135/#136 and refreshing durable handoff state; the next run should first inspect current PRs/main to avoid overlapping another Object agent before editing the `GenericDatabasePage` hotspot.
