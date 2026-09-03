# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is in real-host completion. `main` includes the major Database/Object-detail/Body/Daily Note integrations plus real Multi-View management verification and Database/View Body-reference candidate loading through PR #128.

Key real-host milestones now integrated:
- #111 real `GenericDatabasePage` collection-aware loading/creation, Board create-in-group, canonical Relation editor, and collection settings;
- #112 shared Object Property presentation in the real inspector;
- #113 rich shared Body rendering/editing in the real inspector;
- #115 move/duplicate/insert-after/delete plus empty-Body text insertion;
- #117 real Daily Note previous/today/next navigation with editable Daily Note Body;
- #120/#121 explicit Object-reference picker plus host-limited reference action kinds;
- #122 real duplicate-current/blank View creation verification;
- #124 Object reference insertion after an anchor;
- #125 explicit Database/View Body-reference target picker;
- #126 Object reference insertion as the first block of an empty Body;
- #127 real View rename/delete/reorder/overflow verification while preserving Object identity;
- #128 read-only Database/View Body-reference candidate catalog over the active workspace.

The next production priority after the active PR is contextual Object opening: consume persisted `ObjectOpenPresentationService` results in real Database/View navigation for side peek / center peek / full page without forking Object detail content.

## Active branch / PR
- Branch: `feature/object-inspector-database-view-reference-insertion-v2`
- PR: #130 — `Insert Database View references from Object inspector`
- Latest implementation head before this handoff update: `7f6d0b3497cd70b2a7f64d1f95c7b0544fa4e3b5`
- PR #129 was closed unmerged because its stacked pre-squash ancestry made already-merged #128 files appear in the diff. #130 is the clean replay on current `main`.

## Checkpoints completed in this sustained run
1. **Validated and landed empty-Body Object reference insertion**
   - PR #126 head `d73f2841294fde48b85a2dd9e04e3b7b42966be1` passed Flutter CI #644.
   - Squash-merged as `49ede2013bd78b0e53718b9f87a0fb71e0913234`.

2. **Completed real-host Multi-View management verification**
   - PR #127 added real `GenericDatabasePage` coverage for rename/delete, overflow selection, and reorder.
   - Tests verify View identity/order changes never delete or duplicate underlying Objects.
   - Latest functional head `8a618622099744a10cd4d3e123b5fdce407c2d90` passed Flutter CI #648.
   - Squash-merged as `47bb9a40cf6b72724bf41e7319dfbef598cd8f17`.

3. **Added and landed Database/View Body-reference candidate loading**
   - PR #128 added `ObjectBodyDatabaseViewReferenceCatalog` over `GenericDatabaseStore.listDatabases` + `DatabaseViewStore.listViews`.
   - Candidate loading is read-only and emits Database-only plus specific-View choices with stable ids/names/icons.
   - Latest head `1d1d265d1c95ffcb462b46c4b5eb2a542d7e3a64` passed Flutter CI #651.
   - Squash-merged as `ca30556be09ec37d736279ba7e6a09352fc8ff71`.

4. **Wired Database/View reference insertion into the real Object inspector**
   - Active PR #130 loads candidates through the #128 catalog and opens the #125 explicit picker.
   - Database-only or specific-View selection becomes `ObjectBodyDatabaseViewInsert` and persists through the existing latest-read reference controller.
   - Supports both insert-after-anchor and first-block insertion into an empty Body.
   - Host now advertises Object + Database/View reference kinds only; Image/File remain hidden until concrete selectors exist.
   - Cancel remains a no-op and Body references remain separate from Relation Property writes.

5. **Added real-host Database/View insertion regressions and repaired the existing Object-reference expectation**
   - New tests cover cancel-without-persistence, explicit View insertion after an anchor, Database-only first-block insertion, and Image/File action hiding.
   - Initial PR #130 CI #654 passed Drift generation and `flutter analyze`, and the new Database/View tests passed, but one older Object-reference test failed because it still expected Database/View to be hidden.
   - Updated that older host test to expect Object + Database/View while continuing to require Image/File hidden. A fresh latest-head CI run is required before merge.

## Integrated Object foundations available to consume
- Database collection and real host: #82/#85/#86/#87/#96/#111
- Board grouped creation and real host: #79/#87/#111
- multi-View management/overflow and real-host coverage: #88/#89/#94/#122/#127
- Object opening settings/resolution: #90/#92/#98 (`ObjectOpenPresentationService` exists but real Database/View navigation still does not consume it)
- URL -> Weblink promotion UI: #91
- shared Object detail/value editing/presentation and real inspector: #93/#95/#97/#99/#100/#112
- Body persistence/contracts/presentation/actions/reference insertion and real inspector: #101/#103/#105/#106/#107/#108/#113/#115/#120/#121/#124/#125/#126/#128 plus #130 active
- Daily Note services/widgets and real inspector navigation: #102/#104/#106/#117
- canonical Relation APIs consumed by Object UI: `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`, `ObjectRelationEditorService`

## Integration-first rule
1. Prefer connecting existing services/widgets to real user-facing hosts over creating more Object-layer abstractions.
2. New foundation work is appropriate only when it directly unblocks host integration or fixes correctness.
3. Keep reference target selection explicit; never persist unresolved placeholder blocks.
4. Body Object/Database/View references remain document references, separate from Relation Property lifecycle.
5. Reuse shared Object detail content for all opening modes rather than creating separate side/center/full-page editors.
6. Finish Milestone A/B/C host polish and begin active app use before manual collection membership complexity.

## Exact next actions
1. Inspect the latest CI for PR #130 after the repaired Object-reference host expectation; fix branch-caused failures and merge when green/mergeable.
2. On current `main`, consume `ObjectOpenPresentationService` from real `GenericDatabasePage` record/card selection:
   - resolve `View > Database > ObjectType > app` open mode;
   - side peek keeps contextual Database work;
   - center peek reuses shared Object detail content in a modal presentation;
   - full page opens the shared Object inspector/detail route;
   - preserve originating Database/View context where practical.
3. Add real-host tests for side/center/full-page selection and View override precedence.
4. After opening-mode integration, exercise Milestone A/B flows in active use and prioritize concrete regressions/polish.
5. Add Image/File Body reference selectors only when a concrete reusable asset picker is available.
6. Implement `RichText/Document Property` only after real navigation work is stable because it affects exhaustive Property/query/group/Board/detail paths.
7. Keep manuallyIncluded/manuallyExcluded membership deferred until dynamic collection + multi-View behavior is proven in active use.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must use canonical Relation mutation/editor APIs; Object UI must not duplicate Relation validation/index lifecycle.
- Body Object/Database/View references are document references, not Relation Property mutations.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and multi-View UX remain Object-owned.
- No active Relation implementation dependency blocks current Object navigation work.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` is a large hotspot; contextual opening requires focused patch-capable edits rather than broad whole-file replacement through the connector.
- `ObjectInspectorPage` remains a hotspot but PR #130 diff is intentionally limited and was replayed cleanly after #128 squash merge.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Reference-bearing blocks require explicit target selection; unresolved placeholder blocks must never be persisted.
- Image/File reference actions must remain hidden until concrete selectors exist.

## Validation
- #126 Flutter CI #644: success; squash merge `49ede2013bd78b0e53718b9f87a0fb71e0913234`.
- #127 Flutter CI #648: success; squash merge `47bb9a40cf6b72724bf41e7319dfbef598cd8f17`.
- #128 Flutter CI #651: success; squash merge `ca30556be09ec37d736279ba7e6a09352fc8ff71`.
- #130 CI #654: Drift generation + analyze succeeded; 417 tests passed, 1 failed only because the pre-existing Object-reference host test expected Database/View to remain hidden. The new Database/View insertion tests both passed. That expectation has been corrected on latest head; rerun required.
- Connector runtime has no local Flutter SDK; executable validation for connector-only changes relies on GitHub Actions.

## Stop reason
This handoff records multiple coherent implementation/verification checkpoints. The active PR still requires latest-head CI after the branch-caused regression expectation repair. Independent next work is contextual Object opening in `GenericDatabasePage`; that is the next priority once #130 is green, but it is a large real-host hotspot and should be changed with focused patch-capable editing rather than speculative parallel abstractions.
