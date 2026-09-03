# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is past the main real-host Database/View opening integration. `main` contains collection-aware `GenericDatabasePage`, canonical Relation editing, shared Object Property/Body inspector content, Body actions and Object/Database/View references, Daily Note navigation, Multi-View management, persisted Object opening modes, and contextual side/center/full Object opening.

PR #138 passed Flutter CI #684 and squash-merged as `9b67b5deca256e45de136b7bc0568a6165dcf6d2`. The real side-peek header now exposes an explicit `フルページで開く` action that opens the same Object in the shared `ObjectInspectorPage`, then reloads the Database page when the full-page route returns. The active Database/View remains intact.

PR #139 is active tests-only coverage proving edits made after side-peek → full-page promotion persist on the same global Object and are refreshed back into the originating contextual side pane.

## Active branch / PR
- Active tests-only PR: #139 `test/object-side-peek-shared-object-state`, head `8dc78f8a4d367519e6b5209ac6cade6892cc988f`.
- Latest integrated main checkpoint: `9b67b5deca256e45de136b7bc0568a6165dcf6d2` (#138 squash merge).

## Checkpoints completed in the latest run
1. **Integrated explicit side-peek → full-page promotion**
   - Confirmed PR #138 production diff is limited to the existing real side-peek header plus its real-host regression test.
   - Confirmed Flutter CI #684 succeeded on head `ac094e33625c50bd731fa1a84c66d8529cde4287`.
   - Squash-merged #138 as `9b67b5deca256e45de136b7bc0568a6165dcf6d2`.
   - Promotion reuses existing `_openObject(...)` / shared `ObjectInspectorPage`; no new navigation abstraction, schema, migration, or Relation lifecycle path was added.

2. **Added shared-global-Object promotion regression**
   - Opened PR #139 with a real `GenericDatabasePage` test.
   - The test starts in side peek, promotes the same Object to full page, edits its title through the shared inspector, returns, and requires the contextual side pane to show the updated title.
   - The test also verifies the persisted Object id is unchanged, locking the Object-centric identity contract across presentation modes.
   - Flutter CI #686 was queued at the latest check; do not treat pending CI alone as a blocker.

3. **Re-audited the next side-pane convergence boundary**
   - The right-side `_detail(...)` remains legacy duplicated title/Property/backlink UI, while center/full use `ObjectInspectorPage` and shared `ObjectDetailPropertyView` / Body content.
   - The next production work should remove this duplication incrementally, preserving pane sizing, delete/close controls, active View context, canonical Relation writes, and rich Body safety.
   - No other active Object PR was present after #138 merge except the tests-only #139 branch.

## Exact next actions
1. Check #139 Flutter CI #686. Fix only failures caused by the new test; merge when green.
2. Incrementally converge the real side-pane `_detail(...)` content toward shared Object detail content. Prefer the smallest reviewable host slice rather than a broad `GenericDatabasePage` rewrite.
3. First convergence target: shared title/Property presentation/edit behavior while retaining the contextual pane header, sizing, close/delete actions, and originating View state.
4. Add real-host regression coverage for each convergence slice, including Relation rendering/writes remaining canonical and rich Body documents never being flattened.
5. Begin active-use polish on Milestone A/B flows once side/center/full detail behavior is materially unified; prioritize observed regressions over new abstractions.
6. Keep Image/File Body-reference actions hidden until concrete reusable asset selectors exist.
7. Implement `RichText/Document Property` only after navigation/detail convergence is stable because it affects exhaustive Property/query/group/Board/detail paths.
8. Keep manual include/exclude membership deferred until dynamic collection + Multi-View behavior is proven in real use.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must continue through canonical Relation mutation/editor APIs.
- Body Object/Database/View references remain document references, not Relation Property writes.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and Multi-View UX remain Object-owned.
- No active Relation dependency blocks the current opening/detail work.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` remains a large hotspot and the connector replaces existing files as whole files. Any next production edit there must use the exact current blob and verify a narrowly scoped diff; avoid broad whole-file rewrites.
- The right-side pane still uses legacy `_detail(...)` content while center/full use `ObjectInspectorPage`; this is now the primary shared-detail convergence gap.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Opening modes and explicit promotion must reuse the same global Object/detail data rather than fork editors.

## Validation
- #138 Flutter CI #684: success; squash merge `9b67b5deca256e45de136b7bc0568a6165dcf6d2`.
- #139 Flutter CI #686: queued at latest check on head `8dc78f8a4d367519e6b5209ac6cade6892cc988f`.
- #135 Flutter CI #676: success; squash merge `ae974e2cb962a346971ecd062488e23a044ae3dd`.
- #136 Flutter CI #678: success; squash merge `fe177885dd1ac7b759029d3786790322c4d22eea`.
- Earlier merged Object/Relation slices passed their relevant CI as recorded in prior handoffs.
- Connector runtime has no local Flutter SDK; executable validation for connector-only changes relies on GitHub Actions.

## Stop reason
No stopping criterion is currently met. Continue by checking #139 CI and then taking the smallest safe side-pane/shared-detail convergence slice. If the connector cannot safely perform that hotspot edit without whole-file replacement risk, continue with independent real-host regression/polish work and leave the exact hotspot dependency documented rather than inventing parallel abstractions.
