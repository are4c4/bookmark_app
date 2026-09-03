# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow. Issue #56 is the product/design contract and contains Milestones A–D.

## Current implementation position
The generic Object/Relation foundations are substantially wired into real user-facing hosts. `GenericDatabasePage` consumes collection-aware services and the canonical Relation editor. `ObjectInspectorPage` consumes shared Property presentation, rich Body rendering/editing, block actions, and real Daily Note navigation. Multi-View duplicate/blank behavior is now verified in the real Database host.

The highest-value remaining work is **real navigation/detail completion and reference/content polish**: Object Body reference target-selection/insertion beyond the first Object flow, side/center/full-page Object opening, and active-use regression/polish.

Do not add parallel abstractions for already-integrated flows. New foundation work is justified only when it unblocks a concrete host integration or closes a correctness gap.

### Integrated Object / database foundations on `main`
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
- #121: shared reference action chrome can be limited to the kinds a concrete host can actually resolve.
- #122: real `GenericDatabasePage` verifies duplicate-current View, blank View creation, independent identities/config, and no underlying Object duplication.

PR #83 remains closed/unmerged and is not active. PR #110 was closed unmerged as redundant.

### Active Object integration
- PR #124 — `Insert Object references from real Object inspector` — wires explicit Object selection into the real Body host through the typed latest-read reference controller. It is currently under CI validation.

### Integrated Relation foundations on `main`
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
- Body Object/Database/asset references are document references and must not be conflated with Relation Property writes.

## Delivery milestones
### Milestone A — Usable Object Database
The core real-host path is integrated and regression-covered: Database-first collection loading, collection-aware normal/Board creation, collection settings, canonical Relation picker/editor, and Relation lifecycle safety. Remaining emphasis is active-use polish rather than basic architecture wiring.

### Milestone B — Multi-View Database UX
Core duplicate/blank/rename/reorder/delete/overflow foundations exist. Duplicate-current and blank View creation are now verified through the real `GenericDatabasePage`, including the invariant that Views never duplicate underlying Objects. Remaining emphasis is final rename/reorder/delete/overflow host coverage and UI polish where gaps emerge.

### Milestone C — Object Knowledge System
Reusable Weblink/Image flows, Value promotion, shared Object detail, opening-mode persistence/settings/resolution, typed Value editing, canonical Relation context, and Daily Note services/widgets are integrated. Real Daily Note navigation is now in the shared Object inspector. Remaining emphasis is side peek / center peek / full-page navigation while preserving context.

### Milestone D — Document / Knowledge Layer
Safe block persistence/editing, rich/reference contracts, shared rendering/action/reference chrome, typed reference insertion, deterministic identities, and payload-preserving duplication are integrated. The real Object inspector consumes rich Body rendering and generic block actions, and explicit Object reference selection is now available as a reusable picker.

Remaining emphasis:
- complete real-host Object reference insertion validation, then Database/View reference selection/insertion;
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
1. Finish PR #124 and land real Object-reference insertion in `ObjectInspectorPage` after CI passes.
2. Add Database/View reference target selection and consume `ObjectBodyDatabaseViewInsert` in the same real Body host; keep Image/File hidden until selectors exist.
3. Consume `ObjectOpenPresentationService` in real View navigation and implement side peek / center peek / full page while preserving originating Database/View context.
4. Extend real Multi-View verification to rename/reorder/delete/overflow only where current widget/host coverage is insufficient.
5. Exercise the generic Object Database in daily use and address concrete regressions before expanding data-model complexity.
6. Implement `RichText/Document Property` only when ready for its broad enum/query/group/Board/detail impact.
7. Keep manual include/exclude deferred until dynamic collection + multi-View behavior is proven in active use.

## Validation status
- #114 corrected head passed Drift generation, `flutter analyze`, and the full test suite in Flutter CI #620 before merge.
- #115 passed its real Object Body action regression coverage before merge.
- #117 head `d096a16715ce6aea952ad24c128edb9c832b27f3` passed Flutter CI #627; squash merge `565670238d72cd91acf6de7e4c4ebeff8375d18d`.
- #121 passed Flutter CI #631; squash merge `e650e8666c1f19316e4e45ee76e63e71d31209a1`.
- #120 initial CI #630 failed only on two picker context scope errors; corrected head `09285578ba0cf5236a0ef39ad941ee6709b5936c` passed Flutter CI #632; squash merge `987b05b576879140f514bf188099f71c08c30c77`.
- #122 passed Flutter CI #633; squash merge `0c7561ca1bc61baf80628e8e66b6575598f2a79e`.
- #124 is under current CI validation.

## Known risks / sequencing constraints
- `ObjectInspectorPage` and navigation surfaces remain integration hotspots; keep edits focused and validate full diff/CI.
- User-facing Relation writes must continue through `RelationMutationService` / `ObjectRelationEditorService`; picker load must not silently repair legacy/corrupt state.
- Ambiguous Relation repair remains explicit-only; deterministic index-only reconciliation is the only automatic repair currently allowed.
- Body document references are separate from Relation Property lifecycle and must not trigger low-level Relation writes.
- Rich Body documents must never be flattened by paragraph-only editing.
- Reference actions must remain hidden until a target selector exists for that kind.
- `RichText/Document Property` still has broad exhaustive-switch and UI/query impact.
