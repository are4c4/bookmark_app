# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent user-facing database workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow. Issue #56 is the product/design contract and contains Milestones A–D.

## Current implementation position
The generic Object/Relation foundations are now substantially wired into real user-facing hosts. `GenericDatabasePage` consumes the collection-aware composition root and canonical Relation editor, while `ObjectInspectorPage` has begun consuming the shared Property and rich Body presentation/editing stack.

The highest-value remaining work is no longer basic service wiring. It is **real navigation/detail completion and end-to-end product polish**: Object opening modes, Daily Note navigation, remaining rich Body/reference target-selection flows, and final Multi-View/database-host verification.

Do not add parallel abstractions for flows already integrated. New foundation work is justified only when it unblocks a concrete host integration or closes a correctness gap.

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
- #101/#103/#105/#106/#107/#108: safe Body block mutation/persistence, rich/reference block contracts, presentation metadata, reusable Flutter rendering/editing, insert/remove/move/insert-after actions, typed Object/Database/View/Image/File reference insertion, deterministic block-id allocation, payload-preserving duplication, and shared reference action chrome.
- #102/#104/#106: Daily Note previous/today/next navigation services plus shared navigation widget.
- #111: real `GenericDatabasePage` now consumes collection-aware load/create/Board create, collection settings, and canonical Relation picker/editor paths.
- #112: real `ObjectInspectorPage` uses the shared Object detail Property view while preserving canonical Relation chips/edit affordances.
- #113: real Object inspector uses the rich shared Body document view with latest-read paragraph/checklist editing and unknown-payload preservation.
- #115: real Object inspector wires shared Body move/duplicate/insert-after/delete actions plus empty-Body insertion.

PR #83 remains closed/unmerged and is not active.
PR #110 was closed unmerged because it duplicated already-integrated #86/#87/#96 functionality.

### Integrated Relation foundations on `main`
- #62/#66/#69/#73/#74/#75/#80/#81 provide canonical Relation validation/mutation/read/index lifecycle, integrity audit, deterministic index reconciliation, neighborhood reads, picker candidates/selection diagnostics, safe deletion, and core Image/Tag lifecycle migration.
- #109 adds regression coverage around the canonical editor boundary: bidirectional inverse synchronization, stale picker fail-closed behavior, missing-target/cardinality non-mutation on load, explicit repair boundaries, page-composition behavior, and stale bidirectional rename/delete callers. Squash merge: `d51b5023ede27bcf0c66670620e86643a1b07038`.
- #114 adds real `GenericDatabasePage` widget coverage proving bidirectional inverse synchronization, visible missing-target/cardinality diagnostics without mutation on cancel, and stale-target fail-closed behavior after picker load. Squash merge: `a152c4984331789af8450bfe10ed62a4bea0cce1`.
- `lib/views` no longer has a user-facing direct `ObjectStore.setRelation()` path; real Database-page Relation writes go through the canonical editor/mutation facade.

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

## Delivery milestones
### Milestone A — Usable Object Database
The core real-host path is now integrated:
- Database-first collection loading before View projection;
- collection-aware normal and Board grouped creation;
- collection settings in the real page;
- canonical Relation picker/editor in the real page;
- end-to-end Relation lifecycle regression coverage.

Remaining emphasis is end-to-end product polish and active-use verification rather than basic architecture wiring.

### Milestone B — Multi-View Database UX
Core View duplicate/blank/rename/reorder/delete/overflow foundations exist. Remaining emphasis is verifying the complete real-host flow and preserving Database sidebar vs View top-tab separation during continued UI integration.

### Milestone C — Object Knowledge System
Reusable Weblink/Image flows, Value promotion, shared Object detail, opening-mode persistence/settings/resolution, typed Value editing, canonical Relation context, and Daily Note services/widgets are integrated. The real Object inspector now consumes shared Property presentation. Remaining emphasis is side peek / center peek / full-page navigation and real Daily Note navigation in the shared host.

### Milestone D — Document / Knowledge Layer
Safe block persistence/editing, rich/reference contracts, shared rendering/action/reference chrome, typed reference insertion, deterministic identities, and payload-preserving duplication are integrated. The real Object inspector now consumes rich Body rendering and generic block actions.

Remaining emphasis:
- reference target-selection/creation in the real Body host;
- embedded Database/View rendering/interaction beyond stored references;
- `RichText/Document Property`;
- higher-level Daily/Weekly/Monthly compositions driven by real usage.

## Integration-first sequencing rule
1. Prefer finishing real user-facing hosts over creating another parallel abstraction.
2. Reuse `GenericDatabasePageServices`, shared Object detail widgets/services, and canonical Relation APIs rather than duplicating lifecycle logic.
3. Preserve rich/unknown Body payloads during all editing.
4. Finish Milestone A/B polish and begin active app use before adding manual membership complexity.
5. Let real usage drive later Milestone C/D expansions.

## Next repository-wide actions
1. Finish real Object opening presentation using `ObjectOpenPresentationService`: side peek / center peek / full page while preserving originating Database/View context.
2. Wire `DailyNoteNavigationBar` + `DailyNoteDetailNavigationService` into the real shared Object host.
3. Continue real Object Body host integration with reference target-selection/insertion while preserving the latest-read/payload-safe mutation path already integrated.
4. Verify Multi-View navigation end-to-end in the real Database host, including duplicate/blank/overflow behavior and Database sidebar vs top View tabs separation.
5. Exercise the generic Object Database in real daily use and address concrete regressions before expanding data-model complexity.
6. Implement `RichText/Document Property` only when ready for its broad enum/query/group/Board/detail impact.
7. Keep manual include/exclude deferred until dynamic collection + multi-View behavior is proven in active use.

## Validation status
- #107 Flutter CI #574 succeeded before squash merge as `39fdc54b276a5241eb2fd07214b868d1abb0e466`.
- #108 functional head Flutter CI #590 succeeded before squash merge as `273578d94f272e9e37169f02afafcf1d60c60082`.
- #109 head `576346d836c2ad07c3f2a590640751dd8b107741` passed Drift generation, `flutter analyze`, and the full test suite in Flutter CI #597 before squash merge.
- #114 corrected head `e3b357c5427e43d4ba248d2391ffe73e48253812` passed Drift generation, `flutter analyze`, and the full test suite in Flutter CI #620 before squash merge as `a152c4984331789af8450bfe10ed62a4bea0cce1`.
- #114's preceding attempt failed only on one unused import in the newly-added stale-picker test; it was corrected immediately before the green run.
- Earlier merged Object and Relation slices passed their relevant PR CI as recorded in lane history.

## Known risks / sequencing constraints
- Broad direct replacement of `GenericDatabasePage`, `ObjectInspectorPage`, or other large navigation/detail surfaces remains an avoidable corruption/merge risk; use focused patches.
- User-facing Relation writes must continue through `RelationMutationService` / `ObjectRelationEditorService`; picker load must not silently repair legacy/corrupt state.
- Ambiguous Relation repair remains explicit-only; deterministic index-only reconciliation is the only automatic repair currently allowed.
- Future editable Relation UI outside the Database page should reuse the existing canonical editor boundaries rather than creating a second lifecycle path.
- Rich Body documents must never be flattened by paragraph-only editing.
- `RichText/Document Property` still has broad exhaustive-switch and UI/query impact.
