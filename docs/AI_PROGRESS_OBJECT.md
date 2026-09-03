# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane has moved decisively from foundation work into real-host completion. `main` now includes:
- #111 real `GenericDatabasePage` collection-aware loading/creation, Board create-in-group, canonical Relation editor, and collection settings;
- #112 shared Object Property presentation in the real inspector;
- #113 rich shared Body document rendering/editing in the real inspector;
- #115 move/duplicate/insert-after/delete plus empty-Body creation in the real inspector;
- #117 Daily Note previous/today/next navigation and editable Daily Note Body in the real inspector;
- #120 explicit existing-Object Body reference picker;
- #121 host-limited reference action kinds so unresolved selector types are not advertised;
- #122 real `GenericDatabasePage` verification for duplicate-current View, blank View creation, and no Object duplication.

The next highest-value work is real Object Body reference insertion and Object opening presentation. Do not create parallel abstractions for flows already represented by merged services/widgets.

## Active branch / PR
- Branch: `feature/object-inspector-object-reference-insertion`
- PR: #124 — `Insert Object references from real Object inspector`
- Latest implementation head before this handoff update: `b1915f13ca1da323a6b81510db7ae4931ec0368d`
- Flutter CI #637 is currently running on that head.

## Checkpoints completed in this sustained run
1. **Landed Daily Note real-host integration**
   - PR #117 latest head `d096a16715ce6aea952ad24c128edb9c832b27f3` passed Flutter CI #627.
   - Squash-merged #117 as `565670238d72cd91acf6de7e4c4ebeff8375d18d`.
   - Daily Note Objects are identified through the system ObjectType registry, render the shared previous/today/next bar, open/create dates through canonical Daily Note services, and keep Body editing enabled while preserving system schema/title protections.

2. **Made reference action chrome honest about host capabilities**
   - PR #121 added `allowedKinds` to `ObjectBodyReferenceInsertMenuButton` and `referenceInsertKinds` to `ObjectBodyBlockActionBar`.
   - Defaults remain backward-compatible and expose every typed reference kind.
   - A host may now expose only selectors it can actually resolve, preventing Image/File/Database actions from creating UX dead ends or unresolved placeholders.
   - Flutter CI #631 passed analyze and the full test suite; #121 was squash-merged as `e650e8666c1f19316e4e45ee76e63e71d31209a1`.

3. **Fixed and landed the explicit Object Body reference picker**
   - PR #120 provides search/filter by Object title or ObjectType and returns only an explicitly selected Object id.
   - Initial CI #630 exposed two `dialogContext` scope errors in the picker State; corrected them to use the State build context on the same branch.
   - Corrected head `09285578ba0cf5236a0ef39ad941ee6709b5936c` passed Flutter CI #632 and was squash-merged as `987b05b576879140f514bf188099f71c08c30c77`.
   - Cancel remains a pure no-op and never persists a placeholder reference.

4. **Verified adopted Multi-View creation UX in the real Database host**
   - Added a real `GenericDatabasePage` widget regression proving the primary `+` duplicates the active View configuration with a new identity.
   - Verified the secondary `空のViewを作成` path starts with empty filters/sorts/settings.
   - Verified neither path duplicates underlying Objects.
   - PR #122 passed Flutter CI #633 and was squash-merged as `0c7561ca1bc61baf80628e8e66b6575598f2a79e`.

5. **Started real Object-reference Body insertion**
   - PR #124 wires the merged Object picker into the real `ObjectInspectorPage`.
   - Candidate Objects are collected across ObjectTypes in the active workspace and sorted deterministically by ObjectType/title.
   - Explicit selection is converted to `ObjectBodyObjectReferenceInsert` and persisted through `ObjectBodyReferenceInsertController.insertAfterAllocated`, keeping latest-read/typed Body semantics.
   - The real inspector advertises only `Object` reference insertion for now; Database/View/Image/File remain hidden until their selectors exist.
   - Added real-host regression coverage that cancel leaves Body unchanged and explicit selection inserts the expected Object-reference block after the anchor.

## Integrated Object foundations available to consume
- Database collection and real host: #82/#85/#86/#87/#96/#111
- Board grouped creation and real host: #79/#87/#111
- multi-View management/overflow and real-host creation verification: #88/#89/#94/#122
- Object opening settings/resolution: #90/#92/#98
- URL -> Weblink promotion UI: #91
- shared Object detail/value editing/presentation and real inspector: #93/#95/#97/#99/#100/#112
- Body block persistence/contracts/presentation/actions/reference contracts and real inspector: #101/#103/#105/#106/#107/#108/#113/#115/#120/#121
- Daily Note services/widgets and real inspector navigation: #102/#104/#106/#117
- canonical Relation APIs consumed by Object UI: `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`, `ObjectRelationEditorService`

## Integration-first rule
1. Prefer connecting existing services/widgets to real user-facing hosts over creating more Object-layer abstractions.
2. New foundation work is appropriate only when it unblocks concrete host integration or fixes correctness.
3. Keep reference target selection explicit; never persist unresolved placeholder blocks.
4. `GenericDatabasePage`, Object detail/navigation, Daily Note host, and Multi-View real-host behavior outrank speculative model expansion.
5. Finish Milestone A/B/C host polish and begin active app use before adding manual collection membership complexity.

## Exact next actions
1. Finish PR #124 CI; repair any branch-caused analyze/test failure, then merge when green.
2. Add Database/View reference target selection and wire it into the same real Object Body host using `ObjectBodyDatabaseViewInsert`; continue to hide Image/File until concrete selectors exist.
3. Add an explicit empty-Body reference insertion entry point once reference-after-anchor behavior is stable, reusing the same picker/controller path.
4. Consume `ObjectOpenPresentationService` in real Database/View navigation and implement side peek / center peek / full page while preserving originating Database/View context and shared detail content.
5. Extend real Multi-View verification to remaining rename/reorder/delete/overflow behavior only where current host tests do not already cover it.
6. Begin active use of Milestone A/B flows and prioritize concrete regressions/polish.
7. Implement `RichText/Document Property` only after real-host/navigation work is stable because it affects exhaustive Property/query/group/Board/detail paths.
8. Keep manuallyIncluded/manuallyExcluded collection membership deferred until dynamic collection + multi-View behavior is proven in real use.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must use canonical Relation mutation/editor APIs; Object UI must not duplicate Relation validation/index lifecycle.
- Body Object references are document references, not Relation Property mutations; PR #124 does not touch Relation lifecycle/index code.
- `GenericDatabasePage`, Object detail UI, Database collection integration, Board create UI, Value promotion, Body/block editing, Daily Notes, and multi-View UX remain Object-owned.
- No active Relation implementation dependency blocks the current Object reference-host path.

## Risks / blockers
- No product/design blocker is active.
- `ObjectInspectorPage` remains a large integration hotspot; keep edits focused and verify diffs/CI carefully.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Reference-bearing blocks require explicit target selection; unresolved placeholder blocks must never be persisted.
- Database/View/Image/File reference actions must remain hidden from a concrete host until that host has a valid selector.
- Object opening side/center/full-page work must reuse shared detail content rather than fork behavior by presentation mode.

## Validation
- #117 Flutter CI #627: success; squash merge `565670238d72cd91acf6de7e4c4ebeff8375d18d`.
- #121 Flutter CI #631: success; squash merge `e650e8666c1f19316e4e45ee76e63e71d31209a1`.
- #120 initial CI #630: analyze failure caused by two picker context identifiers; fixed on branch.
- #120 corrected Flutter CI #632: success; squash merge `987b05b576879140f514bf188099f71c08c30c77`.
- #122 Flutter CI #633: success; squash merge `0c7561ca1bc61baf80628e8e66b6575598f2a79e`.
- #124 Flutter CI #637: running at this handoff checkpoint.

## Stop reason
No stopping condition is active at this checkpoint. The Object lane still has actionable real-host work. Continue from PR #124 validation into the next reference/navigation slice unless a genuine `AGENTS.md` blocker appears.
