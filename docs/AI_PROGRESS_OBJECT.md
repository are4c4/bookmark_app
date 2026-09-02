# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state

`main` contains the major Object/Relation foundations, Database/View integration services, and the shared Object-detail contracts through PR #100/#99.

Recent merged Object slices:
- #82 Database = target ObjectType + collectionFilter foundation.
- #85 collection settings dialog.
- #86 collection-aware page loader.
- #87 collection-aware create/Board create and canonical Object-owned Relation editor adapter.
- #88/#89 multi-View creation and management.
- #90/#92 typed per-View Object opening mode persistence + settings UI.
- #91 reversible URL -> reusable Weblink promotion in Object detail.
- #93/#95 shared basic Object inspector editing and typed checkbox/select/multi-select/date/rating mutation contracts.
- #94 View tab overflow policy and `その他` handling.
- #96 `GenericDatabasePageServices` composition root for collection loader/config, collection-aware creation/Board creation, and canonical Relation editing.
- #97 merged as `8aeba4da7fc8a093eb20b16afe87aea426eee22d`: shared `ObjectDetailValueEditor` descriptor/dispatch contract for full-page/side/center detail surfaces.
- #98 merged as `123c8aabc6ab8913e30b657023953cd03ec8a9cb`: `ObjectOpenPresentationService` resolves actual Object opening mode using persisted View/ObjectType defaults and `View > Database > ObjectType > app` precedence.
- #100 merged as `09802d5aaef8d1f4ae6d3e9f8e4d7e46a6b6c498`: shared read-only Object-detail Property presentation model, including canonical Relation-renderer separation.
- #99 merged as `96b15bae63299a6dc566558066e2d5902e5a6f3f`: shared text-input codec for number/select/multi-select/date/rating detail editing.

PR #83 remains closed/unmerged and is not active.

## Checkpoints completed in this run

1. **Validated and landed the shared typed Value editor**
   - PR #97 corrected head `fac6571bc659b6c73e310ca44ad8ddfb4967a946` passed Flutter CI #520.
   - Squash-merged as `8aeba4da7fc8a093eb20b16afe87aea426eee22d`.
   - `ObjectDetailValueEditor` now describes canonical Value editor kinds/options and dispatches through `ObjectDetailEditService`, while Relation/Computed/system-derived fields remain outside the Value editor.

2. **Validated and landed persisted Object opening presentation resolution**
   - PR #98 head `77e7f73070118717a967024d0da1e41777acca74` passed Flutter CI #517.
   - Squash-merged as `123c8aabc6ab8913e30b657023953cd03ec8a9cb`.
   - Detail/navigation hosts no longer need to coordinate ObjectType-default persistence themselves before resolving side/center/full-page behavior.

3. **Added and landed shared Object-detail Property presentation**
   - PR #100 added `ObjectDetailPropertyPresenter` and `ObjectDetailPropertyPresentation` for container-agnostic display state.
   - Ordinary/computed values share formatting; hidden state is surfaced explicitly.
   - Relation display text is intentionally omitted so all surfaces use canonical resolved Relation data rather than serialized target ids.
   - Flutter CI #525 passed Drift generation, `flutter analyze`, and tests.
   - Squash-merged as `09802d5aaef8d1f4ae6d3e9f8e4d7e46a6b6c498`.

4. **Added, fixed, validated, and landed shared Value input normalization**
   - PR #99 added `ObjectDetailValueInputCodec` for text-oriented detail controls.
   - It normalizes number/select/multi-select/date/rating inputs, supports clear values, validates configured options, and keeps checkbox input on boolean controls.
   - Initial Flutter CI #524 failed only in analyze because nullable `int.tryParse()` output was passed directly to `RangeError.range`.
   - Fixed at `b358f6936e3f5fba72b83ad4bd2f45dd613586ad` by separating parse failure from range validation.
   - Corrected Flutter CI #526 reported `No issues found!` and **305 tests passed**, including all new codec tests.
   - Squash-merged as `96b15bae63299a6dc566558066e2d5902e5a6f3f`.

## Exact next actions

1. In a patch-capable implementation environment, wire `GenericDatabasePageServices` into the real `GenericDatabasePage`: collection-aware reload/create, Board `onCreateInGroup`, canonical Relation picker/editor, and collection settings.
2. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
3. Wire `ObjectOpenPresentationService.resolve()` into real View navigation and route side peek / center peek / full page while preserving Database/View context.
4. Replace ad-hoc Object-detail Property display/editor branching with the merged `ObjectDetailPropertyPresenter`, `ObjectDetailValueEditor`, and `ObjectDetailValueInputCodec`; add checkbox/select/multi-select/date/rating UI coverage.
5. Keep Relation display/editing on canonical Relation neighborhood/selection/mutation services; do not format raw Relation ids or reimplement lifecycle validation.
6. Continue Daily Note and Body/Block work only after Milestone A page integration is coherent, unless an independent small slice is clearly non-conflicting.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Object UI consumes canonical Relation APIs and does not duplicate their validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion and multi-View UX are Object-owned.
- Avoid competing broad Relation-lane edits to `GenericDatabasePage`.

## Validation

- PR #97 head `fac6571bc659b6c73e310ca44ad8ddfb4967a946`: Flutter CI #520 success before merge.
- PR #98 head `77e7f73070118717a967024d0da1e41777acca74`: Flutter CI #517 success before merge.
- PR #100 head `c4bb2096ab8bb5ce2acc680c133d3721678cf63f`: Flutter CI #525 success before merge.
- PR #99 initial head `2572fdfe5f1b1ceb023b5c5f84e2f8800055ef08`: Flutter CI #524 failed only in analyze on nullable rating range validation.
- PR #99 corrected head `b358f6936e3f5fba72b83ad4bd2f45dd613586ad`: Flutter CI #526 success; Drift generation and analyze passed, and 305 tests passed.
- Earlier merged #82/#86/#87/#88/#89/#90/#91/#92/#93/#94/#95/#96 passed their relevant PR CI as recorded in history.
- This connector runtime does not expose a local Flutter SDK; executable validation is delegated to GitHub Actions, with exact job logs inspected for branch-caused failures.

## Risks / blockers

- No product/design blocker is active.
- `GenericDatabasePage` remains the main Milestone A integration hotspot. The current GitHub write surface replaces existing files whole; broad replacement of this large file is an avoidable corruption/merge risk. The next highest-priority integration should therefore be performed in a patch-capable implementation environment.
- The existing full-page `ObjectInspectorPage` still contains ad-hoc simple editor/display branching. Shared contracts are now merged and ready to consume, but editing that large existing UI file through whole-file replacement carries similar avoidable risk.
- User-facing Relation writes must stay on canonical Relation services.
- Opening-mode persistence/settings/resolution exist, but real contextual navigation still needs wiring.
- Rich Body documents must never be flattened by the paragraph-safe editor.

## Stop reason

This run completed four coherent checkpoints: PR #97 and #98 were validated and merged; PR #100 added shared Property presentation and was validated/merged; PR #99 added shared input normalization, its branch-caused analyzer failure was diagnosed from exact CI logs, fixed, revalidated with 305 passing tests, and merged. The remaining highest-priority Milestone A work requires patching the large `GenericDatabasePage` integration hotspot (and then large shared detail/navigation surfaces). With the current whole-file GitHub write surface, that next step carries an avoidable corruption/conflict risk and is the active tool/runtime limitation matching the AGENTS.md stop criteria.
