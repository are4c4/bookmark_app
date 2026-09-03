# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is past the main real-host Database/View opening integration. `main` contains collection-aware `GenericDatabasePage`, canonical Relation editing, shared Object Property/Body inspector content, Body actions and Object/Database/View references, Daily Note navigation, Multi-View management, persisted Object opening modes, contextual side/center/full Object opening, explicit side-peek → full-page promotion, and regression coverage that promotion/editing continues to operate on the same global Object.

PR #143 passed Flutter CI #695 and squash-merged as `da1f0851481ab147b9179a8901169ae605f9a936`. The existing shared `ObjectDetailPropertyView` now accepts optional host-owned `leading` chrome and `onTap` behavior while staying read-oriented by default. This specifically allows the contextual Database side peek to preserve its drag handle and edit-on-tap interaction when its legacy Property rows are replaced with the same shared Property row already used by center/full Object detail. Hidden Properties suppress their host chrome and interaction as well as their content.

The production `GenericDatabasePage._detail(...)` Property rows are still legacy/manual at this checkpoint. #143 is a concrete preparatory integration step, not a claim that the real side pane has already converged.

## Active branch / PR
- PR #143 is merged; no Object production PR is currently open.
- Latest integrated main checkpoint: `da1f0851481ab147b9179a8901169ae605f9a936` (#143 squash merge).
- The next production work should start from fresh latest `main` on a focused branch such as `feature/object-side-peek-shared-property-host` rather than continuing a stale pre-merge branch.

## Checkpoints completed in the latest run
1. **Re-synchronized the Object lane from durable GitHub state**
   - Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this handoff, recent PRs, current main, the reserved Object branch, and relevant CI.
   - Confirmed #141 side-peek Value-edit regression remained CI-green and integrated.
   - Re-read the Relation handoff and confirmed no active Relation dependency or conflicting broad host work.

2. **Re-audited the exact side-pane convergence gap**
   - Inspected current `GenericDatabasePage._detail(...)`, `ObjectDetailContent`, `ObjectDetailPropertyPresenter`, `ObjectDetailPropertyView`, and `ObjectInspectorPage`.
   - Confirmed side peek still manually renders Property label/value/computed/relation rows while center/full use `ObjectDetailPropertyPresenter` + `ObjectDetailPropertyView`.
   - Confirmed title editing, Property reordering, `_editValue`, canonical `_editRelation`/`_relationValue`, backlinks, pane sizing, delete/close, and full-page promotion can remain unchanged for the first convergence slice.

3. **Prepared the existing shared Property row for the real side-peek host**
   - Added optional `leading` to `ObjectDetailPropertyView` so the side pane can keep its `ReorderableDragStartListener`/drag chrome without reimplementing the Property row.
   - Added optional `onTap` so the side pane can preserve its current edit-on-row-tap behavior while the shared row remains read-only by default elsewhere.
   - No parallel detail abstraction was introduced.

4. **Added shared-widget regression coverage**
   - Covered host-owned leading/trailing chrome.
   - Covered optional tap delegation.
   - Covered hidden Properties suppressing content, host chrome, and interaction.
   - Existing canonical Relation-child behavior remains covered and unchanged.

5. **Validated and integrated PR #143**
   - Audited the PR diff: only `ObjectDetailPropertyView` and its focused widget test changed; no hotspot, schema, migration, or Relation lifecycle files moved.
   - Flutter CI #695 succeeded: Drift generation, `flutter analyze`, and full tests passed.
   - Squash-merged PR #143 as `da1f0851481ab147b9179a8901169ae605f9a936`.

6. **Prepared the exact real-host follow-up**
   - Read the current `GenericDatabasePage` in bounded chunks from the exact branch blob to avoid guessing around the large hotspot.
   - Confirmed the next diff can be limited to imports/presenter/content mapping plus the existing Property row builder; no navigation, collection, Relation lifecycle, Body, schema, or migration rewrite is required.

## Exact next actions
1. Create a fresh Object production branch from latest `main` (suggested: `feature/object-side-peek-shared-property-host`).
2. Refresh the exact latest blob for `lib/views/generic_database_page.dart` immediately before writing.
3. Make the smallest real-host Property convergence diff:
   - import `ObjectDetailContent`, `ObjectDetailPropertyPresenter`, and `ObjectDetailPropertyView`;
   - add/reuse a const `ObjectDetailPropertyPresenter`;
   - resolve the selected `AppObject` and current `AppObjectType` already loaded by the page;
   - build `ObjectDetailContent` with the current Object and `_computedValues[record.id]`;
   - for each existing visible/reordered `GenericPropertyRecord`, resolve the matching `ObjectPropertyDefinition` by id and call the shared presenter;
   - render the row through `ObjectDetailPropertyView`;
   - pass the existing reorder drag chrome through `leading`;
   - pass canonical `_relationValue(record, property)` through `relationChild` for Relations;
   - preserve current `_editValue(record, property)` through `onTap` for non-computed Properties.
4. Do **not** change the contextual header, `NotionInlineField` title editing, Property ordering persistence, Property creation, backlinks, pane sizing, full-page promotion, delete/close behavior, active View context, or canonical Relation editor in that slice.
5. Extend `test/generic_database_page_side_peek_value_edit_test.dart` (or a focused adjacent real-host test) to assert `ObjectDetailPropertyView` is present in the side pane, then keep the existing Value edit/persistence assertion on the same Object.
6. Add/retain a focused real-host Relation rendering assertion if needed, but do not change Relation mutation lifecycle; the side pane must continue supplying canonical Relation chips/editor behavior rather than serialized target ids.
7. Compare `main...branch` before PR. Because the GitHub connector replaces an existing file as a whole file, reject/reconstruct the write if unrelated `GenericDatabasePage` lines move.
8. Run Flutter CI (Drift generation, `flutter analyze`, full tests), fix only regressions caused by the slice, and merge when green.
9. After Property presentation is truly consumed by the real side pane, take the next smallest convergence slice—shared title/edit behavior or another concrete duplicate detail element—without a broad `GenericDatabasePage` rewrite.
10. Begin active-use polish on Milestone A/B flows once side/center/full detail behavior is materially unified; prioritize observed regressions over speculative abstractions.
11. Keep Image/File Body-reference actions hidden until concrete reusable asset selectors exist.
12. Implement `RichText/Document Property` only after navigation/detail convergence is stable because it affects exhaustive Property/query/group/Board/detail paths.
13. Keep manual include/exclude membership deferred until dynamic collection + Multi-View behavior is proven in real use.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must continue through canonical Relation mutation/editor APIs.
- Body Object/Database/View references remain document references, not Relation Property writes.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and Multi-View UX remain Object-owned.
- No active Relation dependency blocks side-pane shared-Property host integration.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` remains a large hotspot and the current GitHub connector replaces existing files as whole files rather than applying a partial patch. Issue #56 explicitly warns against broad whole-file hotspot replacement. The next production write is still feasible only if reconstructed from the exact latest blob and verified as a narrow diff before PR.
- PR #143 materially reduces that next hotspot diff by moving the required drag/edit host affordances into the already-shared row first.
- The right-side pane still uses legacy duplicated Property/detail UI until the next production slice lands; do not report the convergence acceptance criterion as complete yet.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Opening modes and explicit promotion must continue to reuse the same global Object/detail data rather than fork editors.

## Validation
- #143 head `1d097d418cc326bddc8680fdd62470c10839f0f2`: Flutter CI #695 — success; Drift generation — success; `flutter analyze` — success; full tests — success; squash merge `da1f0851481ab147b9179a8901169ae605f9a936`.
- #141 Flutter CI #689: success; squash merge `57109c6c2cbf5f80a78230d6c3eabee9d5ded5fd`.
- #139 Flutter CI #686: success; squash merge `6354bfb28167fc4c6b5163513b4501dfe5809d6d`.
- #138 Flutter CI #684: success; squash merge `9b67b5deca256e45de136b7bc0568a6165dcf6d2`.
- Earlier merged Object/Relation slices passed their relevant CI as recorded in prior handoffs.
- Connector runtime has no local Flutter SDK; executable validation for connector-only changes relies on GitHub Actions.

## Stop reason
This run completed multiple coherent checkpoints and integrated a production shared-widget prerequisite with green CI. The remaining next step is the large `GenericDatabasePage` hotspot write. In this runtime the available GitHub write action is whole-file replacement, while Issue #56 explicitly requires avoiding broad hotspot replacement. The exact safe follow-up is fully specified above; continuing beyond this boundary without a true partial patch would introduce a materially avoidable overwrite/conflict risk. This matches the runtime/tool limitation stopping condition rather than a product or Relation blocker.
