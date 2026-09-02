# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope

Own Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current integration state

- `main` now includes Object detail/Body UI from PR #68, shared Relation detail context from PR #76, safe Value -> Object/Weblink promotion from PR #77, and canonical Relation-neighborhood rendering in `ObjectInspectorPage` from PR #78.
- PR #79 (`feature/object-board-create-in-group-v2`) is open and replays grouped Board Object creation on current foundations. Its first CI failure was an exact stale test-constructor mismatch and has been fixed; Relation presets now route through `RelationMutationService` rather than direct Relation writes, with focused integration coverage added.
- Stale PR #60 is closed as superseded by #79. Superseded stale Object PRs #70 and #72 also remain closed.

## Checkpoints completed in the latest sustained run

1. **Merged shared Object detail Relation context**
   - Verified PR #76 head `86369405b703a3f34bca51a9fe48cbe295ad7dbe` had green Flutter CI #434.
   - Squash-merged #76 as `dac4a64f22d6ab63279ed3075664847f213cf992`.
   - Object detail now has a reusable context loader composed with the Relation lane's canonical `neighborhood()` API.

2. **Fixed, validated, and merged Value -> Object execution**
   - CI on PR #77 exposed an analyzer-redundant non-null assertion that remained after replaying the older slice.
   - Removed the exact remaining assertion at `e6857b9bf097905fd9dd0b355fac142c46ffe09d`.
   - Flutter CI #439 then passed Drift generation, `flutter analyze`, and the full test step.
   - Squash-merged PR #77 as `d952ec409fdf69b45219ae00d3c38d3c74b59619`.
   - Generic promotion preserves the source Value by default, rejects stale plans before target creation, delegates link writes to `RelationMutationService`, supports rollback, and provides URL -> reusable Weblink promotion.

3. **Moved Object inspector Relation rendering onto the canonical read API**
   - PR #78 replaced ad-hoc ObjectGraph backlink/target resolution in `ObjectInspectorPage` with one `RelationReadService.neighborhood()` payload.
   - Outgoing Relation chips and Backlinks now read the same resolved Relation model.
   - Flutter CI #440 passed, including analyze and tests.
   - Squash-merged #78 as `521063771df658058dd625a5601a22f6ca77332e`.

4. **Replayed and hardened grouped Board Object creation**
   - Replayed stale PR #60 as PR #79 instead of force-merging its old base.
   - `ObjectBoardCreatePlanner` derives initial grouped values for scalar, Multi-select, Relation, and unassigned buckets while sharing eligibility rules with Board drag/drop.
   - CI #441 failed before tests because the test helper did not provide the newer required `ObjectGroupBucket.isEmptyGroup` argument. Exact job logs identified the issue; commit `ba445f171644c55d444809e3fdf2c1998693b546` fixes it.
   - Commit `8f3922c9cc85885121025c4a5ddea1f95feb711e` routes Relation-group initialization through the stable `RelationMutationService` rather than bypassing Relation lifecycle rules.
   - Commit `af9db0a4c2ab6ccce9a46eadee3fe5bead4eb8b7` adds an integration test proving Relation-group creation persists the Relation value and normalized outgoing edge through the canonical path.
   - Flutter CI #449 is running on latest PR #79 head `af9db0a4c2ab6ccce9a46eadee3fe5bead4eb8b7`.

## Validation

- PR #76 Flutter CI #434: success before merge.
- PR #77 Flutter CI #439: success after analyzer correction; Drift generation, analyze, and tests all passed before merge.
- PR #78 Flutter CI #440: success before merge.
- PR #79 CI #441: failed only in analyze due to missing required `isEmptyGroup` in the new test helper; exact workflow logs inspected and correction pushed.
- PR #79 Flutter CI #449: in progress on latest Relation-safe head with integration coverage.
- This connector runtime does not provide a local Flutter SDK, so executable validation is delegated to PR CI and exact workflow job logs.

## Exact next actions

1. Inspect Flutter CI #449 for PR #79 head `af9db0a4c2ab6ccce9a46eadee3fe5bead4eb8b7`; fix any branch-caused failure, then merge when green.
2. After #79 lands, connect `ObjectBoardCreateService` to the existing `ObjectBoardView.onCreateInGroup` callback in `GenericDatabasePage`, prompting for a title, creating in the selected bucket, reloading, and selecting the new Object.
3. Add focused page/widget regression coverage for Board-column creation so the grouped Property is initialized through the real UI path.
4. Expose URL -> Weblink promotion through a narrow Object-owned UI affordance after the inspector's canonical Relation-neighborhood integration; preserve the scalar URL by default.
5. Use `RelationTargetService` for any new Relation picker/editing UI and continue to avoid duplicating target validation.
6. Continue Daily Note through general Object detail/Relation mechanisms; avoid a special note data silo.

## Cross-lane boundaries

- Relation lifecycle, bidirectional integrity, target/source validation, backlink/index repair, and Tag hierarchy mutation stay in `docs/AI_PROGRESS_RELATION.md`.
- Stable Relation APIs available to Object lane: `RelationMutationService`, `RelationReadService.neighborhood()`, `RelationTargetService`, and integrity/index services for diagnostics/reconciliation.
- Object-owned callers may consume those APIs, but should not reimplement Relation validation/index lifecycle.
- Object detail UI, Daily Note UI, Value promotion UI, and Object-centric Database/View interactions remain Object-owned surfaces.

## Blockers / risks

- PR #79 needs latest-head CI before merge; its known constructor mismatch has already been fixed.
- Board grouped creation for Relation properties must continue using the Relation mutation facade; do not regress to low-level direct Relation writes.
- Rich Body documents must never be flattened by the thin paragraph editor.

## Stop reason

No product/design blocker was reached in this run. Multiple safe checkpoints were completed and validated/merged. The remaining active #79 slice now has an exact CI-derived constructor fix, a Relation-safe write path, and focused integration coverage; its latest executable validation is running. The next UI slice depends directly on that service contract, so continue from CI #449 and then wire the existing Board column create callback after #79 is green.
