# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is past the main real-host Database/View opening integration. `main` contains collection-aware `GenericDatabasePage`, canonical Relation editing, shared Object Property/Body inspector content, Body actions and Object/Database/View references, Daily Note navigation, Multi-View management, persisted Object opening modes, contextual side/center/full Object opening, and explicit side-peek → full-page promotion.

PR #138 passed Flutter CI #684 and squash-merged as `9b67b5deca256e45de136b7bc0568a6165dcf6d2`. The real side-peek header exposes `フルページで開く`, reusing the shared `ObjectInspectorPage` route while preserving active Database/View context.

PR #139 passed Flutter CI #686 and squash-merged as `6354bfb28167fc4c6b5163513b4501dfe5809d6d`. Its real-host regression proves a title edit made after side-peek → full-page promotion updates the same global Object and refreshes back into the originating contextual side pane without changing Object identity.

PR #141 passed Flutter CI #689 and squash-merged as `57109c6c2cbf5f80a78230d6c3eabee9d5ded5fd`. It locks existing simple Value editing from the real side peek before shared-detail convergence.

## Active branch / PR
- No open Object implementation PR remains after #141 merge.
- Prepared empty branch `feature/object-side-peek-shared-property-view` is based on latest main and reserved for the next production slice; no production commit has been made there yet.
- Latest integrated main checkpoint: `57109c6c2cbf5f80a78230d6c3eabee9d5ded5fd` (#141 squash merge).

## Checkpoints completed in the latest run
1. **Integrated explicit side-peek → full-page promotion**
   - Re-read #138 diff and confirmed the production change is only the additive side-pane promotion action.
   - Confirmed Flutter CI #684 succeeded.
   - Squash-merged #138 as `9b67b5deca256e45de136b7bc0568a6165dcf6d2`.

2. **Locked shared global Object state across promotion**
   - Added real `GenericDatabasePage` regression #139.
   - The test opens a side peek, promotes the same Object, edits its title through shared `ObjectInspectorPage`, returns, and requires the originating side pane to display the updated title.
   - It verifies persisted Object identity remains unchanged.
   - Flutter CI #686 succeeded; #139 squash-merged as `6354bfb28167fc4c6b5163513b4501dfe5809d6d`.

3. **Locked existing side-peek Value editing before convergence**
   - Added real `GenericDatabasePage` regression #141 for a simple text Value.
   - The test edits the Value from the contextual side pane and verifies the same Object persists the new Value.
   - Flutter CI #689 succeeded; #141 squash-merged as `57109c6c2cbf5f80a78230d6c3eabee9d5ded5fd`.

4. **Defined the smallest safe production convergence slice**
   - Re-audited `GenericDatabasePage._detail(...)`, `ObjectDetailContent`, `ObjectDetailPropertyPresenter`, and `ObjectDetailPropertyView`.
   - The next production change should replace only the side-pane Property presentation rows with `ObjectDetailPropertyPresenter` + `ObjectDetailPropertyView`.
   - Keep the existing contextual pane header, title edit, property reordering, `_editValue`, canonical `_editRelation` / `_relationValue`, backlinks, delete/close actions, and active View context unchanged in this first slice.
   - This lets side peek start consuming the same Property presentation contract as center/full without a broad host rewrite or new abstraction.

5. **Rechecked Relation ownership boundary**
   - `docs/AI_PROGRESS_RELATION.md` still reports the Relation lane stable with no active independent Relation work.
   - Existing real-host Relation lifecycle regression #114 already protects bidirectional save, missing-target/cardinality diagnostics, and stale target fail-closed behavior.
   - The side-pane convergence must continue using those canonical Relation APIs; no Relation-lane broad edit is required.

## Exact next actions
1. On `feature/object-side-peek-shared-property-view`, refresh the exact current `lib/views/generic_database_page.dart` blob before writing.
2. Make a narrowly scoped production diff only:
   - import `ObjectDetailContent`, `ObjectDetailPropertyPresenter`, and `ObjectDetailPropertyView`;
   - construct shared detail content for the selected Object from `_objects`, `_objectType`, and `_computedValues`;
   - render each visible side-pane Property through `ObjectDetailPropertyView` while preserving existing edit/reorder callbacks and canonical Relation child rendering.
3. Add a real-host regression asserting the side pane actually contains `ObjectDetailPropertyView` and that the #141 Value-edit behavior still works.
4. Compare the production diff carefully because the connector updates existing files as whole files; reject/rebuild the change if unrelated `GenericDatabasePage` lines move.
5. Run GitHub Flutter CI (Drift generation, `flutter analyze`, full tests), fix only regressions caused by the slice, and merge when green.
6. After Property presentation converges, take the next smallest shared-detail slice: title presentation/edit behavior, then Body/backlink convergence where practical. Preserve pane sizing/header/navigation context.
7. Begin active-use polish on Milestone A/B flows once side/center/full detail behavior is materially unified; prioritize observed regressions over new abstractions.
8. Keep Image/File Body-reference actions hidden until concrete reusable asset selectors exist.
9. Implement `RichText/Document Property` only after navigation/detail convergence is stable because it affects exhaustive Property/query/group/Board/detail paths.
10. Keep manual include/exclude membership deferred until dynamic collection + Multi-View behavior is proven in real use.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must continue through canonical Relation mutation/editor APIs.
- Body Object/Database/View references remain document references, not Relation Property writes.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and Multi-View UX remain Object-owned.
- No active Relation dependency blocks the current side-pane convergence work.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` remains a large hotspot and the current connector replaces existing files as whole files. The next production edit is technically possible but must be reconstructed from the exact latest blob and verified as a narrow diff; do not trade safety for speed.
- The right-side pane still uses legacy duplicated Property/detail UI while center/full use `ObjectInspectorPage`; this is now the primary shared-detail convergence gap.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Opening modes and explicit promotion must reuse the same global Object/detail data rather than fork editors.

## Validation
- #141 Flutter CI #689: success; squash merge `57109c6c2cbf5f80a78230d6c3eabee9d5ded5fd`.
- #139 Flutter CI #686: success; squash merge `6354bfb28167fc4c6b5163513b4501dfe5809d6d`.
- #138 Flutter CI #684: success; squash merge `9b67b5deca256e45de136b7bc0568a6165dcf6d2`.
- #135 Flutter CI #676: success; squash merge `ae974e2cb962a346971ecd062488e23a044ae3dd`.
- #136 Flutter CI #678: success; squash merge `fe177885dd1ac7b759029d3786790322c4d22eea`.
- Earlier merged Object/Relation slices passed their relevant CI as recorded in prior handoffs.
- Connector runtime has no local Flutter SDK; executable validation for connector-only changes relies on GitHub Actions.

## Stop reason
This run completed multiple coherent real-host checkpoints and reached the next large-hotspot write boundary. No product blocker exists; the exact next production slice is fully specified. Continue on the prepared latest-main branch with the narrowly scoped side-pane shared Property presentation edit, using exact-blob reconstruction and diff verification before PR/merge.
