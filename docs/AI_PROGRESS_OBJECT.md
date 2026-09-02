# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state

`main` contains the major Object/Relation foundations and the current Database/View integration through PR #96.

Recent merged Object slices:
- #82 Database = target ObjectType + collectionFilter foundation.
- #85 collection settings dialog.
- #86 collection-aware page loader.
- #87 collection-aware create/Board create and canonical Object-owned Relation editor adapter.
- #88/#89 multi-View creation and management.
- #90/#92 typed per-View Object opening mode persistence + settings UI.
- #91 reversible URL -> reusable Weblink promotion in real Object detail.
- #93 shared basic Object inspector title/text/URL/number editing.
- #94 merged as `d316b84fe0849c6ce6567c6cc5466be7076bce1f`: View tab overflow policy and `その他` handling. Latest head `63847321ea498b69869606665c8406546262c547` passed Flutter CI #514 before merge.
- #95 typed checkbox/select/multi-select/date/rating mutation entry points in `ObjectDetailEditService`.
- #96 `GenericDatabasePageServices` composition root for collection loader/config, collection-aware creation/Board creation, and canonical Relation editing.

Active Object PRs:
- #97 `feature/object-detail-editor-model`, head `30d65bff24332938d1757043b676def63891d812`: shared `ObjectDetailValueEditor` descriptor/dispatch contract for full/side/center detail surfaces. Relation/Computed remain explicitly outside Value editing. Flutter CI #516 is in progress.
- #98 `feature/object-open-mode-resolver`, head `77e7f73070118717a967024d0da1e41777acca74`: `ObjectOpenPresentationService` loads ObjectType defaults and resolves actual View presentation mode through the adopted `View > Database > ObjectType > app` precedence. CI pending/starting.

PR #83 remains closed/unmerged and is not an active path.

## Checkpoints completed in this run

1. **Landed View overflow handling**
   - Re-read #94 and confirmed it was mergeable.
   - Latest head had successful Flutter CI #514.
   - Squash-merged #94 as `d316b84fe0849c6ce6567c6cc5466be7076bce1f`.
   - Milestone B now has top-tab overflow behavior in addition to create/rename/reorder/duplicate/delete.

2. **Added a shared typed Value editor contract**
   - Opened PR #97.
   - `ObjectDetailValueEditor` describes text/number/checkbox/select/multi-select/date/rating editors from Property semantics and configured options.
   - Dispatch routes typed values through the already-merged `ObjectDetailEditService` typed mutation methods.
   - Relation and Computed Properties fail closed as unsupported Value editors.
   - Tests cover editor descriptors, configured options, canonical persistence and invalid option rejection.
   - CI #516 is running.

3. **Added persisted Object opening presentation resolution**
   - Opened PR #98.
   - `ObjectOpenPresentationService` centralizes loading ObjectType defaults before delegating to `DatabaseViewOpenModeService`.
   - This removes the need for eventual page/navigation widgets to coordinate View and ObjectType persistence themselves.
   - Tests cover ObjectType fallback and View override precedence.
   - CI is pending/starting on latest head.

## Exact next actions

1. Inspect PR #97 CI #516; fix branch-caused failures and merge when green.
2. Inspect PR #98 latest CI; fix branch-caused failures and merge when green.
3. In a patch-capable environment, wire `GenericDatabasePageServices` into the real `GenericDatabasePage` hotspot:
   - collection-aware reload,
   - collection-aware normal creation,
   - Board `onCreateInGroup`,
   - canonical Relation picker/editor,
   - collection settings.
4. Add page/widget regression coverage proving Database membership is resolved before View projection and creation targets the configured ObjectType.
5. Wire `ObjectOpenPresentationService.resolve()` into real View Object navigation, then route side peek / center peek / full page while preserving Database/View context.
6. Wire the shared typed Value editor contract into shared Object detail presentation so checkbox/select/multi-select/date/rating editing is available consistently across full/side/center surfaces.
7. Continue Daily Note and Body/Block work only after Milestone A page integration is coherent.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation stay Relation-owned.
- Object UI consumes `RelationMutationService`, `RelationReadService.neighborhood()`, and `RelationTargetService.selectionFor()`; do not duplicate their validation/index lifecycle.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion and multi-View UX are Object-owned surfaces.
- Avoid competing broad Relation-lane edits to `GenericDatabasePage`.

## Validation

- PR #94 head `63847321ea498b69869606665c8406546262c547`: Flutter CI #514 success before merge.
- PR #97 head `30d65bff24332938d1757043b676def63891d812`: Flutter CI #516 in progress.
- PR #98 head `77e7f73070118717a967024d0da1e41777acca74`: CI pending/starting.
- Earlier merged #82/#86/#87/#88/#89/#90/#91/#92/#93/#95/#96 were validated through their PR CI as recorded in repository-wide handoff/history.
- This connector runtime does not expose a local Flutter SDK, so executable validation is delegated to GitHub Actions.

## Risks / blockers

- No product/design blocker is active.
- `GenericDatabasePage` remains the main Milestone A integration hotspot. The current GitHub write surface replaces existing files whole; broad replacement of this large file remains an avoidable corruption/merge risk. Prefer a patch-capable implementation environment for that file.
- User-facing Relation writes must stay on canonical Relation services.
- View opening-mode settings now have persistence, UI and a resolver, but real navigation still needs wiring.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

This run completed three coherent checkpoints: green #94 was merged, and independent Object-owned PRs #97 and #98 were opened with focused tests while avoiding the unsafe broad `GenericDatabasePage` replacement. The remaining highest-priority Milestone A work converges on that large page hotspot and requires a patch-capable implementation environment for safe direct wiring. CI for #97/#98 is still progressing; pending CI alone is not the reason for stopping—the remaining immediately actionable high-priority work in this connector is the hotspot that is unsafe to whole-file replace.
