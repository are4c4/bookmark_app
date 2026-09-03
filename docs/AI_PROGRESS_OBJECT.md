# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The main real-host Database/View opening path is integrated. `main` contains collection-aware `GenericDatabasePage`, canonical Relation editing, shared Object Property/Body inspector content, Body actions and Object/Database/View references, Daily Note navigation, Multi-View management, persisted Object opening modes, contextual side/center/full Object opening, explicit side-peek → full-page promotion, and regression coverage that promotion/editing continues to operate on the same global Object.

PR #143 passed Flutter CI #695 and squash-merged as `da1f0851481ab147b9179a8901169ae605f9a936`. `ObjectDetailPropertyView` now accepts optional host-owned `leading` chrome and `onTap` behavior so the contextual Database side peek can preserve drag/edit behavior while consuming the shared Property row. PR #144 then refreshed this handoff; current `main` is `3f0e3c455a696f2779cd69bce9276ffc2e0bab60`.

The remaining concrete convergence gap is production `GenericDatabasePage._detail(...)`: its Property rows are still manually rendered, while center/full Object detail use `ObjectDetailPropertyPresenter` + `ObjectDetailPropertyView`.

## Active branch / PR
- No Object production PR is open.
- This handoff-only checkpoint uses `docs/object-side-peek-host-tool-blocker`.
- Latest production integration checkpoint: #143 squash `da1f0851481ab147b9179a8901169ae605f9a936`.
- Latest main checkpoint before this handoff: `3f0e3c455a696f2779cd69bce9276ffc2e0bab60` (#144).

## Checkpoints completed in the latest run
1. Re-read `AGENTS.md`, Issue #56, `docs/AI_PROGRESS.md`, this Object handoff, the Relation handoff, latest PRs, branch state, current main, and relevant CI.
2. Reconfirmed Relation lane has no active dependency or competing broad Object-host edit; canonical Relation lifecycle remains stable and Object-owned host work may proceed without changing Relation mutation semantics.
3. Verified PR #143 head `1d097d418cc326bddc8680fdd62470c10839f0f2` remains Flutter CI #695 green (Drift generation, `flutter analyze`, full tests).
4. Re-audited exact latest `GenericDatabasePage._detail(...)` from blob `c1a77e31b2fff0b2b633e332b6e06f3496b10ad3`. The first safe production slice remains limited to replacing the manual Property row presentation while preserving title edit, reorder, Value editing, canonical Relation chips/editor, backlinks, pane sizing, full-page promotion, delete/close, and active View context.
5. Re-read `ObjectDetailContent`, `ObjectDetailPropertyPresenter`, and `ObjectDetailPropertyView`; all contracts required for the side-peek Property convergence are already present on main.
6. Rechecked connector capabilities. The available GitHub write API can only replace an existing UTF-8 file with its complete contents; no partial-file patch/update action is exposed. `GenericDatabasePage` is ~67 KB and full-file retrieval is truncated by the connector response surface, so this runtime cannot safely reconstruct and replace the exact latest file without an avoidable overwrite/truncation risk.
7. Searched for an alternative safe Object production slice. Image/File Body references are intentionally deferred until concrete reusable asset selectors exist, RichText/Document Property is intentionally deferred until detail/navigation convergence stabilizes, Daily Note and opening integration are already landed, and adding another parallel abstraction would violate Issue #56's integration-first rule. No independent production slice should be invented merely to keep the lane busy.

## Exact next actions
1. Resume from fresh latest `main` in an environment that can apply a true partial patch to `lib/views/generic_database_page.dart` (or once this connector exposes partial-file editing).
2. Make the smallest side-peek Property convergence diff only:
   - import `ObjectDetailContent`, `ObjectDetailPropertyPresenter`, and `ObjectDetailPropertyView`;
   - add/reuse a const `ObjectDetailPropertyPresenter`;
   - resolve the selected `AppObject` and current `AppObjectType` already loaded by the page;
   - build `ObjectDetailContent` with `_computedValues[record.id]`;
   - match each visible/reordered `GenericPropertyRecord` to its `ObjectPropertyDefinition` by id;
   - render through `ObjectDetailPropertyView`;
   - preserve the reorder handle via host-owned `leading`;
   - preserve `_relationValue(record, property)` as the canonical `relationChild`;
   - preserve `_editValue(record, property)` via `onTap` for non-computed Properties.
3. Do not alter the side-peek header, `NotionInlineField` title editing, Property-order persistence, Property creation, backlinks, pane sizing, full-page promotion, delete/close behavior, active View context, collection behavior, Body, schema/migrations, or Relation lifecycle in that slice.
4. Extend `test/generic_database_page_side_peek_value_edit_test.dart` to assert `ObjectDetailPropertyView` is present in the real side pane while retaining the existing same-Object Value edit/persistence assertion.
5. Add a focused real-host Relation rendering assertion only if needed; do not alter Relation mutation lifecycle.
6. Compare `main...branch` and require the `GenericDatabasePage` diff to contain only the intended imports/presenter/content mapping/Property builder changes before opening or merging a PR.
7. Run Flutter CI, fix regressions caused by the slice, and merge when green.
8. After the shared Property row is truly consumed by side peek, take the next smallest duplicated detail element rather than a broad rewrite.
9. Keep Image/File Body-reference actions hidden until concrete reusable asset selectors exist. Keep RichText/Document Property and manual collection membership deferred as already recorded in `docs/AI_PROGRESS.md`.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must continue through canonical Relation mutation/editor APIs.
- Body Object/Database/View references are document references, not Relation Property writes.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and Multi-View UX remain Object-owned.
- No Relation dependency blocks the planned side-peek shared-Property host integration.

## Validation
- #143 head `1d097d418cc326bddc8680fdd62470c10839f0f2`: Flutter CI #695 — success; Drift generation — success; `flutter analyze` — success; full tests — success.
- Current main before this handoff: `3f0e3c455a696f2779cd69bce9276ffc2e0bab60`.
- `GenericDatabasePage` current blob audited: `c1a77e31b2fff0b2b633e332b6e06f3496b10ad3`.
- No production code changed in this run, so no new Flutter CI validation was warranted for code.

## Risks / blockers
- No product/design blocker and no Relation blocker is active.
- The blocker is strictly the current automation runtime's file-edit capability: existing files are whole-file replacements, while the exact current 67 KB hotspot cannot be retrieved intact in one writable payload. Issue #56 explicitly warns against broad/unsafe hotspot replacement.
- Do not work around this by adding a parallel detail abstraction or speculative feature; the next desired production diff is already concrete and small.

## Stop reason
This run reached the AGENTS.md runtime/tool-limit stop condition. The next actionable Issue #56 work requires a narrow edit to `GenericDatabasePage`, but this runtime exposes no partial-file write and cannot safely round-trip the complete latest hotspot. Continuing would create an avoidable overwrite/truncation risk. Resume immediately when a patch-capable edit path is available; the exact production diff and regression test are specified above.
