# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow. Issue #56 is the product/design contract and contains Milestones A–D.

## Current implementation position
The generic Object/Relation foundations are substantially wired into real user-facing hosts. `GenericDatabasePage` consumes collection-aware services and the canonical Relation editor. `ObjectInspectorPage` consumes shared Property presentation, rich Body rendering/editing, block actions, real Daily Note navigation, explicit Object-reference insertion after an anchor, and Object-reference insertion into an empty Body.

The highest-value remaining work is **real navigation/detail completion and reference/content polish**: Database/View Body reference insertion in the real inspector, side/center/full-page Object opening, and active-use regression/polish.

Do not add parallel abstractions for already-integrated flows. New foundation work is justified only when it directly unblocks a concrete host integration or closes a correctness gap.

## Integrated Object / database foundations on `main`
- #61/#64/#65/#68/#71/#76/#77/#78: Property semantics, Body/defaults, Daily Notes, reusable Weblink/Image, shared detail, canonical Relation neighborhood consumption, safe Value promotion.
- #79: grouped Board Object creation with Relation-safe presets.
- #82: Database = target ObjectType + collectionFilter foundation and Database-first/View-second projection contract.
- #85/#86/#87: collection settings UI, collection-aware page loader, collection-aware normal/Board creation, canonical Object-owned Relation editor adapter.
- #88/#89/#94: multi-View creation/management/overflow.
- #90/#92/#98: persisted View Object opening modes, settings UI, and effective presentation resolution.
- #91: reversible URL -> reusable Weblink promotion in Object inspector.
- #93/#95/#97/#99/#100: shared Object inspector/detail editing, typed mutation/input contracts, and shared Property presentation.
- #96: `GenericDatabasePageServices` composition root.
- #101/#103/#105/#106/#107/#108: safe Body mutation/persistence, rich/reference block contracts, shared rendering/editing/actions, typed Object/Database/View/Image/File reference insertion, deterministic ids, and payload-preserving duplication.
- #102/#104/#106: Daily Note previous/today/next navigation services plus shared navigation widget.
- #111: real `GenericDatabasePage` consumes collection-aware load/create/Board create, collection settings, and canonical Relation picker/editor paths.
- #112: real `ObjectInspectorPage` uses shared Object detail Property presentation.
- #113: real Object inspector uses the rich shared Body document view with latest-read text/checklist editing and unknown-payload preservation.
- #115: real Object inspector wires move/duplicate/insert-after/delete actions plus empty-Body insertion.
- #117: real Object inspector identifies Daily Notes via the system registry, renders previous/today/next navigation, opens/creates dates through canonical Daily Note services, and allows Daily Note Body editing while preserving system schema/title protections.
- #120: explicit existing-Object Body reference picker with search/filter and cancel-without-persistence semantics.
- #121: shared reference action chrome can be limited to the kinds a concrete host can resolve.
- #122: real `GenericDatabasePage` verifies duplicate-current View, blank View creation, independent identities/config, and no underlying Object duplication.
- #124: real Object inspector inserts an explicitly selected existing Object reference after a Body anchor through the typed latest-read controller.
- #125: explicit Database/View Body reference target picker supporting Database-only and specific-View choices.
- #126: real Object inspector can insert an explicitly selected Object reference as the first block of an empty Body.

PR #83 remains closed/unmerged and is not active. PR #110 was closed unmerged as redundant.

## Active Object integration
- PR #127 — real `GenericDatabasePage` regression coverage for View rename/delete, overflow selection, and reorder. Latest functional head `8a618622099744a10cd4d3e123b5fdce407c2d90`; Flutter CI #648 running at the latest recorded checkpoint.
- PR #128 — Database/View Body-reference candidate catalog over the active workspace. Latest functional head before handoff updates `801f16825e04f6b5d63c4b2c5f81f49141c97a08`; Flutter CI #649 running at the latest recorded checkpoint. Handoff commits follow that functional head and require latest-head CI before merge.

## Integrated Relation foundations on `main`
- #62/#66/#69/#73/#74/#75/#80/#81 provide canonical Relation validation/mutation/read/index lifecycle, integrity audit, deterministic index reconciliation, neighborhood reads, picker candidates/selection diagnostics, safe deletion, and core Image/Tag lifecycle migration.
- #109 adds regression coverage around the canonical editor boundary: bidirectional inverse synchronization, stale picker fail-closed behavior, missing-target/cardinality non-mutation on load, explicit repair boundaries, page-composition behavior, and stale bidirectional rename/delete callers.
- #114 adds real `GenericDatabasePage` widget coverage proving inverse synchronization, visible missing-target/cardinality diagnostics without mutation on cancel, and stale-target fail-closed behavior after picker load.
- `lib/views` has no user-facing direct `ObjectStore.setRelation()` path; real Database-page Relation writes go through the canonical editor/mutation facade.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicate records.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = how to narrow/present a Database collection.
- Database collection filtering and View filtering are separate pipeline stages and persistence concerns.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = structured Properties + Body designed for blocks.
- Value, Object Relation and Computed semantics remain distinct.
- Tags are Objects; Select/MultiSelect remain lightweight local option sets.
- Date is a Value; Daily Note is an Object keyed by date.
- Object detail content, Property rendering/editing, Body rendering/editing, and Daily Note navigation should be shared across side peek, center peek and full page rather than forked per presentation.
- User-facing Relation writes must use canonical Relation mutation/editor APIs. Opening Relation UI must remain read-only until explicit save.
- Body Object/Database/View/asset references are document references and must not be conflated with Relation Property writes.

## Delivery milestones
### Milestone A — Usable Object Database
The core real-host path is integrated and regression-covered: Database-first collection loading, collection-aware normal/Board creation, collection settings, canonical Relation picker/editor, and Relation lifecycle safety. Remaining emphasis is active-use polish rather than basic architecture wiring.

### Milestone B — Multi-View Database UX
Core duplicate/blank/rename/reorder/delete/overflow foundations exist. Duplicate-current and blank creation are verified through the real `GenericDatabasePage`; PR #127 is adding real-host rename/delete/reorder/overflow verification. Remaining emphasis is active-use UI polish after that coverage lands.

### Milestone C — Object Knowledge System
Reusable Weblink/Image flows, Value promotion, shared Object detail, opening-mode persistence/settings/resolution, typed Value editing, canonical Relation context, and Daily Note services/widgets are integrated. Real Daily Note navigation is in the shared Object inspector. Remaining emphasis is side peek / center peek / full-page navigation while preserving context.

### Milestone D — Document / Knowledge Layer
Safe block persistence/editing, rich/reference contracts, shared rendering/action/reference chrome, typed reference insertion, deterministic identities, and payload-preserving duplication are integrated. The real Object inspector consumes rich Body rendering/actions and explicit Object-reference insertion, including empty-Body insertion. Database/View selection UI is merged and candidate loading is active in PR #128.

Remaining emphasis:
- land Database/View candidate loading and wire `ObjectBodyDatabaseViewInsert` into the real inspector;
- add Image/File target selection only when concrete reusable selectors are available;
- embedded Database/View rendering/interaction beyond stored references;
- `RichText/Document Property`;
- higher-level Daily/Weekly/Monthly compositions driven by real usage.

## Integration-first sequencing rule
1. Prefer finishing real user-facing hosts over creating another parallel abstraction.
2. Reuse `GenericDatabasePageServices`, shared Object detail widgets/services, and canonical Relation APIs rather than duplicating lifecycle logic.
3. Preserve rich/unknown Body payloads during all editing.
4. Reference target selection must be explicit; never persist unresolved placeholders or advertise host actions without selectors.
5. Finish Milestone A/B/C host polish and begin active app use before adding manual membership complexity.
6. Let real usage drive later Milestone C/D expansions.

## Next repository-wide actions
1. Finish CI/merge for PR #127 and PR #128, repairing branch-caused failures if any.
2. Wire Database/View reference target selection into the real `ObjectInspectorPage`: load #128 candidates, use the #125 picker, persist `ObjectBodyDatabaseViewInsert` through the typed latest-read controller, and expose Object + Database/View kinds while keeping Image/File hidden.
3. Add real-host Database/View reference insertion regressions for cancel, Database-only/View choice, insert-after-anchor, and empty-Body insertion.
4. Consume `ObjectOpenPresentationService` in real View navigation and implement side peek / center peek / full page while preserving originating Database/View context.
5. Exercise the generic Object Database in daily use and address concrete regressions before expanding data-model complexity.
6. Implement `RichText/Document Property` only when ready for its broad enum/query/group/Board/detail impact.
7. Keep manual include/exclude deferred until dynamic collection + multi-View behavior is proven in active use.

## Validation status
- #126 head `d73f2841294fde48b85a2dd9e04e3b7b42966be1` passed Flutter CI #644; squash merge `49ede2013bd78b0e53718b9f87a0fb71e0913234`.
- #127 functional head `8a618622099744a10cd4d3e123b5fdce407c2d90`: Flutter CI #648 running at the latest handoff checkpoint.
- #128 functional head `801f16825e04f6b5d63c4b2c5f81f49141c97a08`: Flutter CI #649 running at the latest handoff checkpoint; latest handoff commits require rerun before merge.
- Earlier merged Object and Relation slices passed their relevant PR CI as recorded in lane handoffs.

## Known risks / sequencing constraints
- `ObjectInspectorPage` and navigation surfaces remain integration hotspots; keep edits focused and validate full diff/CI.
- User-facing Relation writes must continue through `RelationMutationService` / `ObjectRelationEditorService`; picker load must not silently repair legacy/corrupt state.
- Ambiguous Relation repair remains explicit-only; deterministic index-only reconciliation is the only automatic repair currently allowed.
- Body document references are separate from Relation Property lifecycle and must not trigger low-level Relation writes.
- Rich Body documents must never be flattened by paragraph-only editing.
- Reference actions must remain hidden until a target selector exists for that kind.
- `RichText/Document Property` still has broad exhaustive-switch and UI/query impact.
