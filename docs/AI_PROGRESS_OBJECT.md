# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state

`main` contains the major Object/Relation foundations and current Database/View integration through PR #96.

Recent merged Object slices:
- #82 Database = target ObjectType + collectionFilter foundation.
- #85 collection settings dialog.
- #86 collection-aware page loader.
- #87 collection-aware create/Board create and canonical Object-owned Relation editor adapter.
- #88/#89 multi-View creation and management.
- #90/#92 typed per-View Object opening mode persistence + settings UI.
- #91 reversible URL -> reusable Weblink promotion in Object detail.
- #93 shared basic Object inspector title/text/URL/number editing.
- #94 merged as `d316b84fe0849c6ce6567c6cc5466be7076bce1f`: View tab overflow policy and `その他` handling. Head `63847321ea498b69869606665c8406546262c547` passed Flutter CI #514.
- #95 typed checkbox/select/multi-select/date/rating mutation entry points in `ObjectDetailEditService`.
- #96 `GenericDatabasePageServices` composition root for collection loader/config, collection-aware creation/Board creation, and canonical Relation editing.

Active Object PRs:
- #97 `feature/object-detail-editor-model`, latest head `fac6571bc659b6c73e310ca44ad8ddfb4967a946`: shared `ObjectDetailValueEditor` descriptor/dispatch contract. Initial CI #516 failed in analyze because the first switch omitted existing non-editable Value kinds (`title`, `image`, `file`, `createdTime`, `updatedTime`). The switch now handles those explicitly as unsupported rather than treating them as editable. Corrected Flutter CI #520 is in progress.
- #98 `feature/object-open-mode-resolver`, head `77e7f73070118717a967024d0da1e41777acca74`: `ObjectOpenPresentationService` loads ObjectType defaults and resolves actual View presentation mode using `View > Database > ObjectType > app`. Flutter CI #517 is in progress.

PR #83 remains closed/unmerged and is not active.

## Checkpoints completed in this run

1. **Landed View overflow handling**
   - Confirmed PR #94 was mergeable and green on Flutter CI #514.
   - Squash-merged #94 as `d316b84fe0849c6ce6567c6cc5466be7076bce1f`.
   - Milestone B now includes top-tab overflow behavior in addition to create/rename/reorder/duplicate/delete.

2. **Added a shared typed Value editor contract**
   - Opened PR #97.
   - `ObjectDetailValueEditor` describes text/number/checkbox/select/multi-select/date/rating editors and configured options.
   - Dispatch routes through existing typed `ObjectDetailEditService` mutations.
   - Relation, Computed, title, image/file and created/updated-time fields remain outside this Value editor.
   - Tests cover descriptors, configured options, persistence and invalid option rejection.
   - CI #516 exposed the missing enum cases before tests; fixed at `fac6571bc659b6c73e310ca44ad8ddfb4967a946`. Corrected CI #520 is running.

3. **Added persisted Object opening presentation resolution**
   - Opened PR #98.
   - `ObjectOpenPresentationService` centralizes loading ObjectType defaults before delegating to `DatabaseViewOpenModeService`.
   - Tests cover ObjectType fallback and View override precedence.
   - Flutter CI #517 is running.

## Exact next actions

1. Inspect corrected PR #97 CI #520; fix any remaining branch-caused failure and merge when green.
2. Inspect PR #98 CI #517; fix branch-caused failures and merge when green.
3. In a patch-capable environment, wire `GenericDatabasePageServices` into real `GenericDatabasePage`: collection-aware reload/create, Board `onCreateInGroup`, canonical Relation picker/editor, and collection settings.
4. Add page/widget regression coverage proving Database membership resolves before View projection and creation targets the configured ObjectType.
5. Wire `ObjectOpenPresentationService.resolve()` into real View navigation and route side peek / center peek / full page while preserving Database/View context.
6. Wire `ObjectDetailValueEditor` into shared Object detail UI so checkbox/select/multi-select/date/rating editors behave consistently across presentation modes.
7. Continue Daily Note and Body/Block work only after Milestone A page integration is coherent.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Object UI consumes canonical Relation APIs and does not duplicate their validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion and multi-View UX are Object-owned.
- Avoid competing broad Relation-lane edits to `GenericDatabasePage`.

## Validation

- PR #94 head `63847321ea498b69869606665c8406546262c547`: Flutter CI #514 success before merge.
- PR #97 initial head `30d65bff24332938d1757043b676def63891d812`: Flutter CI #516 failed in analyze due to missing enum switch cases introduced by the branch; corrected in `fac6571bc659b6c73e310ca44ad8ddfb4967a946`.
- PR #97 corrected Flutter CI #520: in progress.
- PR #98 head `77e7f73070118717a967024d0da1e41777acca74`: Flutter CI #517 in progress.
- Earlier merged #82/#86/#87/#88/#89/#90/#91/#92/#93/#95/#96 passed their relevant PR CI as recorded in history.
- This connector runtime does not expose a local Flutter SDK; executable validation is delegated to GitHub Actions.

## Risks / blockers

- No product/design blocker is active.
- `GenericDatabasePage` remains the main Milestone A integration hotspot. The current GitHub write surface replaces existing files whole; broad replacement of this large file is an avoidable corruption/merge risk. Prefer a patch-capable implementation environment.
- User-facing Relation writes must stay on canonical Relation services.
- Opening-mode persistence/settings/resolution exist, but real navigation still needs wiring.
- Rich Body documents must never be flattened by the paragraph-safe editor.

## Stop reason

This run completed three coherent checkpoints: green #94 was merged, PR #97 and #98 were opened with focused tests, and the branch-caused #97 analyzer failure was diagnosed and corrected immediately. Corrected CI is still running. Pending CI alone is not the stop reason: the remaining highest-priority Milestone A work converges on the large `GenericDatabasePage` hotspot, which is unsafe to whole-file replace through this connector and should be handled in a patch-capable implementation environment.
