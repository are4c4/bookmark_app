# AI Progress — Database, View & Schema UX Lane

> Lane C handoff. Read `AGENTS.md`, the active Issues, and `docs/AI_PROGRESS.md` before implementation. Verify current open PR ownership before touching shared hosts.

## Lane goal
Make generic ObjectType/Database/View configuration expressive enough that new domains are created and used through reusable schema/View UX rather than domain-specific management pages.

## Primary active issues
- #490 — templates instantiate user-owned ObjectTypes/Databases/Views.
- #491 — first-class Relation Property authoring and target quick-create UX.
- #492 — generic Gallery cover/media source from Object Relations.
- #493 — schema-evolution UX; integrity-sensitive mutation remains Lane B.
- #249 — only generic Database/View presentation contracts relevant to Bookmark parity.
- #56 / #484 — umbrella generic Object/Database/View architecture.

## Current checkpoint — 2026-09-07
Latest observed `main`: `1431e0734af7760f1e5caf87e3d865252a3fdceb` (`Reject mismatched Gallery cover Relation targets in templates (#601)`).

Recently merged foundations relevant to Lane C:
- #520 — Relation schema-change impact/explicit multi→single confirmation UX.
- #524 — fail-closed Gallery Relation cover-target resolver.
- #592 — Paper user-owned template using generic primitive Relations/Views.
- #595 — presentation-only safe Relation target quick-create action policy surface.
- #601 — template Gallery cover target-kind mismatch guard from Lane B.

Open Lane C slices observed in this run:
- #604 — refresh-safe generic Relation value picker seam; returns refreshed canonical selection context after target quick-create.
- #608 — searchable Relation Property target authoring fields with built-in/custom distinction and explicit single/multi; also reused by the existing safe Relation schema editor.
- #613 — regression proving newer template versions create new instances without implicitly rewriting a customized user-owned older instance.

## Work completed in this run
### #491 — Relation Property authoring UX
- Added reusable searchable target ObjectType fields.
- Results visibly distinguish built-in and custom ObjectTypes.
- Cardinality is an explicit `single` / `multi` choice.
- The component returns canonical ObjectType ids only and performs no Relation/schema mutation itself.
- Reused the same fields in `RelationPropertySchemaEditorDialog`; target/cardinality edits still flow through `RelationSchemaEvolutionService.inspectChange(...) -> explicit impact confirmation -> updateRelationSchema(...)`.
- Updated focused widget coverage for target selection, filtering, clearing, cardinality, target-change impact, and multi→single explicit survivor selection.

### #490 — user-owned template/version semantics
- Added regression coverage for two versions of one template key.
- A version-1 instance is renamed and given a user Property.
- Instantiating version 2 creates a separate user-owned ObjectType and leaves the customized version-1 instance untouched.
- Provenance remains version 1 on the old instance and version 2 only on the new instance.

## #492 status
The generic cover stack is already split into reusable pieces on `main`:
- `DatabaseViewGalleryCoverSourceService` discovers eligible direct Image / Image Relation / Weblink Relation sources.
- `DatabaseViewGalleryCoverTargetResolver` resolves configured sources fail-closed without Relation repair.
- `DatabaseGalleryCoverMedia` dispatches canonical Image/Weblink targets to existing media presenters.
- `ObjectViewToolbar` accepts Gallery cover-source options and persists the View setting through the existing adapter contract.

The remaining meaningful #492 slice is real `GenericDatabasePage` host wiring. Do not add another cover abstraction merely to avoid the host integration.

## Validation / CI
No local Flutter runtime is available through the connector execution path, so executable validation is GitHub CI.
At handoff refresh time:
- #604 Flutter CI: in progress; analyze passed and tests were running.
- #608 Flutter CI: in progress on the latest head.
- #613 Flutter CI: in progress on the test-only head before this docs refresh; this docs commit will trigger a new run.

Do not merge a slice until its latest-head Flutter CI succeeds.

## Exact next actions
1. Re-check latest `main`, open PRs, and shared-hotspot ownership.
2. If #604 is green, merge/rebase it first; then replace the duplicate Relation picker dialog in `generic_database_page.dart` with the refresh-safe shared picker in one patch-sized host slice.
3. After that host is stable, wire #491 creation authoring through the existing `DatabasePropertyAuthoringService` rather than calling schema stores directly from UI.
4. Wire #492 into the generic Gallery host: discover cover options for the active ObjectType, pass them to `ObjectViewToolbar`, decode the active View cover source, and render `DatabaseGalleryCoverMedia` instead of the current hard-coded Weblink media path.
5. Keep Gallery reads fail-closed; never repair Relation/index disagreement from presentation.
6. Continue #490 only for concrete template-instantiation gaps; user schema ownership/versioning, Paper, Plant, primitive Relation targets, and Gallery cover metadata now have focused regressions.
7. #493 data-integrity/migration correctness stays in Lane B; Lane C owns preview, impact explanation, explicit user choices, and safe authoring surfaces.

## Shared hotspot rule
`generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `app_shell.dart`, and `object_inspector_page.dart` require an open-PR ownership check before edits. At this run's check, no open PR was found claiming `generic_database_page.dart` by name, but refresh immediately before touching it because other lanes are active and `main` is moving quickly.

## Current branch / PR
Branch: `feature/database-view-template-version-ownership-490`
PR: #613
Latest functional commit before this handoff: `223bc06e8f6c798ca571289875e21a8c151d8418`.

## Stop / resume boundary
Independent non-hotspot slices for #490/#491 are now represented by focused PRs. The next highest-value work is real-host composition in `generic_database_page.dart`, sequenced behind the shared Relation picker seam and a fresh ownership check; CI pending by itself is not a stopping condition.
