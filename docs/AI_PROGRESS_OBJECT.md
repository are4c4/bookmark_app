# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is in real-host completion. `main` now includes the major Database/Object-detail/Body/Daily Note integrations through PR #126:
- #111 real `GenericDatabasePage` collection-aware loading/creation, Board create-in-group, canonical Relation editor, and collection settings;
- #112 shared Object Property presentation in the real inspector;
- #113 rich shared Body rendering/editing in the real inspector;
- #115 move/duplicate/insert-after/delete plus empty-Body text insertion;
- #117 real Daily Note previous/today/next navigation with editable Daily Note Body;
- #120/#121 explicit Object-reference picker plus host-limited reference action kinds;
- #122 real Multi-View duplicate-current/blank creation verification;
- #124 explicit existing-Object Body reference insertion after an anchor;
- #125 explicit Database/View Body-reference target picker;
- #126 Object reference insertion as the first block of an empty Body.

The next highest-value production slice is wiring the merged Database/View picker plus candidate loading into the real `ObjectInspectorPage`, then moving to contextual Object opening/navigation. Do not create parallel abstractions for flows already represented by merged services/widgets.

## Active branches / PRs
### PR #127 — real Multi-View management regression
- Branch: `feature/object-multiview-management-real-host-regression-v2`
- Latest head: `8a618622099744a10cd4d3e123b5fdce407c2d90`
- Adds real `GenericDatabasePage` coverage for rename/delete, overflow selection, and reorder while preserving Object identity.
- Flutter CI #648 is running on latest head at this handoff checkpoint.

### PR #128 — Database/View reference candidate catalog
- Branch: `feature/object-body-database-view-reference-catalog`
- Latest functional head before this handoff update: `801f16825e04f6b5d63c4b2c5f81f49141c97a08`
- Adds a presentation-side catalog that loads custom Database entries and persisted Views from the active workspace for the #125 picker.
- Flutter CI #649 is running on that functional head at this handoff checkpoint.
- This handoff update is committed on the same branch after that functional head; rerun CI on the resulting latest branch head before merge.

A stale pre-#126 branch `feature/object-multiview-management-real-host-regression` contains an earlier rename/delete-only test commit and is superseded by PR #127.

## Checkpoints completed in this sustained run
1. **Validated and landed empty-Body Object reference insertion**
   - PR #126 head `d73f2841294fde48b85a2dd9e04e3b7b42966be1` passed Flutter CI #644.
   - Squash-merged #126 as `49ede2013bd78b0e53718b9f87a0fb71e0913234`.
   - Real Object inspector can now choose an existing Object and persist it directly as the first Body block; cancel remains a no-op and no Relation Property write is involved.

2. **Added real-host Multi-View rename/delete regression coverage**
   - PR #127 verifies rename persists through the real View menu/dialog.
   - Deleting the duplicated View restores a single persisted View without deleting or duplicating underlying Objects.

3. **Added real-host Multi-View overflow regression coverage**
   - PR #127 creates enough Views to trigger the `その他` menu.
   - It selects a hidden View from overflow and verifies the chosen View becomes directly visible as a top tab while Objects remain unchanged.

4. **Added real-host Multi-View reorder regression coverage**
   - PR #127 drives horizontal tab drag/reorder through the real `GenericDatabasePage`.
   - It verifies persisted order changes while View identities and underlying Objects are preserved.

5. **Added concrete Database/View Body-reference candidate loading**
   - PR #128 loads user-facing custom Databases from `GenericDatabaseStore.listDatabases` and each persisted View from `DatabaseViewStore.listViews`.
   - It emits Database-only and specific-View candidates with stable ids/names/icons for the merged #125 picker.
   - Candidate loading is read-only and does not create, mutate, or repair Views.
   - Focused in-memory regression coverage verifies Database-then-View identity/display metadata.

## Integrated Object foundations available to consume
- Database collection and real host: #82/#85/#86/#87/#96/#111
- Board grouped creation and real host: #79/#87/#111
- multi-View management/overflow and real-host coverage: #88/#89/#94/#122 plus #127 pending
- Object opening settings/resolution: #90/#92/#98
- URL -> Weblink promotion UI: #91
- shared Object detail/value editing/presentation and real inspector: #93/#95/#97/#99/#100/#112
- Body persistence/contracts/presentation/actions/reference insertion and real inspector: #101/#103/#105/#106/#107/#108/#113/#115/#120/#121/#124/#125/#126
- Daily Note services/widgets and real inspector navigation: #102/#104/#106/#117
- canonical Relation APIs consumed by Object UI: `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`, `ObjectRelationEditorService`

## Integration-first rule
1. Prefer connecting existing services/widgets to real user-facing hosts over creating more Object-layer abstractions.
2. New foundation work is appropriate only when it directly unblocks host integration or fixes correctness.
3. Keep reference target selection explicit; never persist unresolved placeholder blocks.
4. Body document references remain separate from Relation Property lifecycle.
5. Finish Milestone A/B/C host polish and begin active app use before manual collection membership complexity.

## Exact next actions
1. Inspect latest CI for #127 and #128; fix branch-caused failures and merge each when green and mergeable.
2. On current `main`, wire Database/View reference insertion into real `ObjectInspectorPage`:
   - load candidates through the #128 catalog;
   - open the #125 picker explicitly;
   - convert selection to `ObjectBodyDatabaseViewInsert`;
   - persist through `ObjectBodyReferenceInsertController.insertAllocated` / `insertAfterAllocated`;
   - expose only Object + Database/View reference kinds; continue hiding Image/File until concrete selectors exist.
3. Add real-host regressions for Database-only/View selection, cancel-without-persistence, insert-after-anchor, and empty-Body first reference.
4. Consume `ObjectOpenPresentationService` in real Database/View navigation and implement side peek / center peek / full page while preserving originating Database/View context and shared detail content.
5. Begin active use of Milestone A/B flows and prioritize concrete regressions/polish.
6. Implement `RichText/Document Property` only after real-host/navigation work is stable because it affects exhaustive Property/query/group/Board/detail paths.
7. Keep manuallyIncluded/manuallyExcluded membership deferred until dynamic collection + multi-View behavior is proven in active use.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must use canonical Relation mutation/editor APIs; Object UI must not duplicate Relation validation/index lifecycle.
- Body Object/Database/View references are document references, not Relation Property mutations.
- `GenericDatabasePage`, Object detail/navigation, Body editing/reference insertion, Daily Notes, and multi-View UX remain Object-owned.
- No active Relation implementation dependency blocks the current Database/View Body reference path.

## Risks / blockers
- No product/design blocker is active.
- `ObjectInspectorPage` remains a large integration hotspot; keep edits focused and verify the full diff and CI.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Reference-bearing blocks require explicit target selection; unresolved placeholder blocks must never be persisted.
- Image/File reference actions must remain hidden until their concrete selectors exist.
- Object opening side/center/full-page work must reuse shared detail content rather than fork behavior by presentation mode.

## Validation
- #126 Flutter CI #644: success; squash merge `49ede2013bd78b0e53718b9f87a0fb71e0913234`.
- #127 latest functional head `8a618622099744a10cd4d3e123b5fdce407c2d90`: Flutter CI #648 running at handoff.
- #128 latest functional head `801f16825e04f6b5d63c4b2c5f81f49141c97a08`: Flutter CI #649 running at handoff.
- Connector runtime has no local Flutter SDK; executable validation for connector-only changes relies on GitHub Actions.

## Stop reason
No product blocker is active. This checkpoint records multiple independent implementation/verification slices while #127/#128 CI runs. Continue by repairing/merging those PRs when CI resolves, then perform the Database/View reference real-host integration. Pending CI alone is not a stopping condition; this run also completed independent work that did not depend on those results.
