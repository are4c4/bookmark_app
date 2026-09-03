# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow. Issue #56 remains the product/design contract.

## Current implementation position
The generic Object/Relation foundations are substantially wired into real user-facing hosts. `GenericDatabasePage` consumes collection-aware services and the canonical Relation editor. `ObjectInspectorPage` consumes shared Property presentation, rich Body rendering/editing/actions, real Daily Note navigation, and explicit Object-reference insertion. Multi-View management is now verified through the real Database host, and Database/View Body reference selection/candidate loading is integrated through #128.

The highest-value remaining work is **real navigation/detail completion and reference/content polish**: finish active Database/View Body reference insertion in the real inspector, then consume persisted Object opening modes for side peek / center peek / full page while preserving Database/View context.

Do not add parallel abstractions for already-integrated flows. New foundation work is justified only when it directly unblocks concrete host integration or closes a correctness gap.

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
- #115: real Object inspector wires move/duplicate/insert-after/delete actions plus empty-Body text insertion.
- #117: real Object inspector identifies Daily Notes via the system registry, renders previous/today/next navigation, opens/creates dates through canonical Daily Note services, and allows Daily Note Body editing while preserving system schema/title protections.
- #120/#121: explicit existing-Object Body reference selection with host-limited reference kinds.
- #122: real `GenericDatabasePage` verifies duplicate-current View, blank View creation, independent identities/config, and no underlying Object duplication.
- #124: real Object inspector inserts an explicitly selected existing Object reference after a Body anchor through the typed latest-read controller.
- #125: explicit Database/View Body reference target picker supporting Database-only and specific-View choices.
- #126: real Object inspector can insert an explicitly selected Object reference as the first block of an empty Body.
- #127: real `GenericDatabasePage` verifies View rename/delete/reorder/overflow while preserving View/Object identities.
- #128: active-workspace Database/View Body-reference candidate catalog using existing Database/View stores without mutation.

PR #83 remains closed/unmerged and is not active. PR #110 was closed unmerged as redundant. PR #129 was closed unmerged as a stacked ancestry artifact and superseded by clean PR #130.

## Active Object integration
- PR #130 — `Insert Database View references from Object inspector` — clean replay on current `main`.
- It wires the #125 picker + #128 catalog into real `ObjectInspectorPage`, persists `ObjectBodyDatabaseViewInsert` through the typed latest-read controller, supports insert-after and empty-Body first insertion, and exposes only Object + Database/View reference kinds.
- Initial Flutter CI #654 passed Drift generation and `flutter analyze`. Both new Database/View insertion tests passed. One pre-existing Object-reference host test failed only because it still expected Database/View to be hidden; that branch-caused expectation has been updated and a fresh latest-head CI is required.

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
Duplicate-current, blank creation, rename, delete, reorder and overflow are now verified through the real `GenericDatabasePage`, including invariants that View operations never duplicate/delete underlying Objects. Remaining emphasis is active-use UI polish.

### Milestone C — Object Knowledge System
Reusable Weblink/Image flows, Value promotion, shared Object detail, opening-mode persistence/settings/resolution, typed Value editing, canonical Relation context, and Daily Note services/widgets are integrated. Real Daily Note navigation is in the shared Object inspector. Remaining emphasis is consuming `ObjectOpenPresentationService` in real Database/View navigation for side/center/full-page presentation while preserving context.

### Milestone D — Document / Knowledge Layer
Safe block persistence/editing, rich/reference contracts, shared rendering/action/reference chrome, typed reference insertion, deterministic identities, and payload-preserving duplication are integrated. The real Object inspector consumes rich Body rendering/actions and explicit Object-reference insertion. Database/View picker and candidate loading are merged; active PR #130 completes their real-host persistence path.

Remaining emphasis:
- finish PR #130;
- add Image/File target selection only when concrete reusable selectors are available;
- embedded Database/View rendering/interaction beyond stored references;
- `RichText/Document Property`;
- higher-level Daily/Weekly/Monthly compositions driven by real usage.

## Integration-first sequencing rule
1. Prefer finishing real user-facing hosts over creating another parallel abstraction.
2. Reuse `GenericDatabasePageServices`, shared Object detail widgets/services, and canonical Relation APIs rather than duplicating lifecycle logic.
3. Preserve rich/unknown Body payloads during all editing.
4. Reference target selection must be explicit; never persist unresolved placeholders or advertise host actions without selectors.
5. Reuse shared Object detail content across opening modes rather than forking side/center/full-page editors.
6. Finish Milestone A/B/C host polish and begin active app use before adding manual membership complexity.

## Next repository-wide actions
1. Finish latest-head CI/merge for PR #130, repairing any branch-caused failures.
2. Consume `ObjectOpenPresentationService` from real `GenericDatabasePage` record/card selection and implement side peek / center peek / full page with View override precedence and shared Object detail content.
3. Add real-host tests for opening-mode selection and Database/View context preservation.
4. Exercise the generic Object Database in daily use and address concrete regressions before expanding data-model complexity.
5. Add Image/File Body reference selectors only when concrete reusable asset-selection UI is available.
6. Implement `RichText/Document Property` only when ready for its broad enum/query/group/Board/detail impact.
7. Keep manual include/exclude deferred until dynamic collection + multi-View behavior is proven in active use.

## Validation status
- #126 head `d73f2841294fde48b85a2dd9e04e3b7b42966be1` passed Flutter CI #644; squash merge `49ede2013bd78b0e53718b9f87a0fb71e0913234`.
- #127 head `8a618622099744a10cd4d3e123b5fdce407c2d90` passed Flutter CI #648; squash merge `47bb9a40cf6b72724bf41e7319dfbef598cd8f17`.
- #128 head `1d1d265d1c95ffcb462b46c4b5eb2a542d7e3a64` passed Flutter CI #651; squash merge `ca30556be09ec37d736279ba7e6a09352fc8ff71`.
- #130 CI #654: Drift generation and analyze succeeded; 417 tests passed, 1 failed only on a stale pre-existing host expectation. Both newly-added Database/View insertion tests passed. The expectation is corrected on the active branch and latest-head CI is required.
- Earlier merged Object and Relation slices passed their relevant PR CI as recorded in lane handoffs.

## Known risks / sequencing constraints
- `GenericDatabasePage` and Object navigation surfaces remain large integration hotspots; use focused patch-capable editing for opening-mode work.
- User-facing Relation writes must continue through `RelationMutationService` / `ObjectRelationEditorService`; picker load must not silently repair legacy/corrupt state.
- Ambiguous Relation repair remains explicit-only; deterministic index-only reconciliation is the only automatic repair currently allowed.
- Body document references are separate from Relation Property lifecycle and must not trigger low-level Relation writes.
- Rich Body documents must never be flattened by paragraph-only editing.
- Reference actions must remain hidden until a target selector exists for that kind.
- `RichText/Document Property` still has broad exhaustive-switch and UI/query impact.
