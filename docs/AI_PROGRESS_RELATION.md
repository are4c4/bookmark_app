# AI Progress — Relations & Data Integrity Lane

> Lane B durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. This lane supersedes the former narrow Relation-only routing while preserving the canonical Relation subsystem.

## Lane goal
Own cross-Object correctness and fail-closed data integrity: canonical Relation lifecycle plus integrity-sensitive schema evolution and deletion/reference invariants.

## Primary active issues
- #493 — integrity side of safe/reversible schema evolution, especially Relation target/cardinality changes.
- #491 — lifecycle/integrity regressions for new generic Relation Property authoring and inline target creation.
- #492 — integrity/read regressions if generic Gallery cover-source work introduces new Relation traversal assumptions.
- #245/#484 — new primitive/person/file Relation-producing workflows only when real production writes appear.
- #56 — umbrella canonical Relation contract.

## Canonical Relation contract
- Feature writes go through `RelationMutationService`.
- Reads/backlinks use `RelationReadService` / canonical ObjectStore projections.
- `RelationIntegrityService` is read-only.
- `RelationIndexReconcileService` repairs deterministic index drift only.
- Relation-safe Object deletion detaches surviving sources through canonical APIs.
- Ambiguous damage, missing targets, cardinality conflicts, stale metadata, or target-type mismatches are not guessed or silently repaired from editor paths.
- No feature may introduce a parallel serialized-id Relation writer or alternate edge/index store.
- Low-level `ObjectStore.setRelation` remains storage-internal/test-facing rather than a normal product mutation path.

## Why this lane is broader now
The Relation subsystem itself is mature, so production Relation redesign is rarely justified. The lane now also owns independent **data-integrity obligations** created by user-composable schema work:
- validating every existing target before changing a Relation target ObjectType;
- safe `single <-> multi` cardinality changes;
- deterministic/fail-closed migration behavior;
- rollback/atomicity when a schema mutation fails;
- deletion/reference integrity across newly composable domains;
- corruption/inconsistent-index regressions.

This gives the lane useful independent work without inventing new Relation architecture.

## Stable integrated coverage
Existing production workflows already have strong lifecycle coverage for:
- Bookmark -> Weblink;
- Weblink -> Image Representative/Related image Relations;
- Bookmark -> Image `Images` multi-Relation;
- Bookmark -> Image `Cover Image` single Relation;
- delete/detach/retarget/backlink/index/audit/reconcile behavior;
- alias-aware Relation candidate/picker behavior;
- historical migration/bootstrap separation from legacy relation-like tables.

Recent Image edit/crop/geometry work is Relation-neutral and does not justify new Relation production code.

## Current implementation checkpoint — 2026-09-07

Active integrity contract: Issue #493 Relation target/cardinality schema evolution, plus #491/#492/new-workflow integrity audits.

Integrated checkpoint:
- implementation branch: `feature/relation-schema-evolution-integrity`
- merged PR: #506 `Add fail-closed Relation schema evolution integrity`
- squash merge on main: `6cc91cccb4b1ac4d23b6dc8ae3d1f1e7c40aa8e4`
- final reviewed PR head: `c60e0800a4ea78439c0fc1de34990a1f9779d9ba`
- branch base when work started: main `844f6b77e7b6947bceaaf6986e6ff8182212e71b`
- duplicate concurrent PR #508 targeted the same service/test paths; it was compared, documented as superseded by the broader #506 contract, and closed unmerged with its branch retained for history/recovery.

Completed checkpoints in this run:
1. Added UI-agnostic `RelationSchemaEvolutionService` with a read-only `inspectChange(...)` impact/preflight contract and transactional `updateRelationSchema(...)` apply path.
2. Relation target ObjectType changes resolve the persisted Property, validate current/next ObjectTypes in the same workspace, audit existing Relation/index/bidirectional health, then validate **every existing target** against the proposed target ObjectType before any write.
3. `multi -> single` reports per-source conflicts and refuses to proceed until the caller supplies an explicit target already present in each conflicting source value; no target is silently selected or dropped.
4. `single -> multi` changes schema configuration without rewriting the existing stored Relation value or unrelated normalized edges.
5. Ambiguous/corrupt state fails closed: stale/missing index edges, missing target Objects, invalid pair metadata, or other relevant `RelationIntegrityService` findings block schema mutation rather than triggering editor-side repair.
6. Bidirectional Relation target retargeting is deliberately blocked until an explicit paired migration contract exists. Cardinality reduction continues through `RelationMutationService`, preserving inverse values/index lifecycle.
7. Added forced database-failure coverage: if the schema Property update fails after a multi-to-single reduction begins, the enclosing transaction rolls back the earlier Relation value/index changes and preserves the old schema/data.
8. Added regressions for target mismatch rollback/preservation, empty-value target retarget, explicit multi-to-single selection, single-to-multi preservation, bidirectional integrity, stale index fail-closed behavior, missing-target fail-closed behavior, and transaction rollback.
9. Audited Database/View PR #507 for #492. Its current Gallery cover-source discovery is read-only, checks Relation target existence/workspace, and adds no alternate Relation writer/index. Commented one B-lane constraint for the resolver follow-up: #492 intentionally permits multi Relations such as `Images`, so resolution must not assume single cardinality and must not repair corrupted Relation data from a View path.
10. Recorded the #493 integrity contract on the Issue so Database/View can consume the preflight result for impact/prompt UX without owning Relation mutation semantics.
11. Detected and reconciled concurrent duplicate #508 before integration so only one Relation schema-evolution implementation landed.
12. Audited Database/View PR #515 for #491 compact Relation Property authoring. The presentation widget only returns a structured target ObjectType/cardinality request, requires explicit target selection, and does not persist Relation config. B-lane integration constraint was recorded: the host must route creation through `ObjectStore.createRelationProperty(...)` (or a canonical facade delegating to it), not generic hand-built Relation config.
13. Audited Database/View PR #516, a real new Relation-producing domain-template workflow. It resolves every required primitive target by stable system key **before** user ObjectType creation, fails before user schema when a target is missing, wraps ObjectType/Property/View/provenance creation in one transaction, and creates Relations via canonical `ObjectStore.createRelationProperty(...)` with explicit cardinality. Its focused tests cover target/cardinality persistence and missing-target no-partial-schema behavior. No B-lane blocker or duplicate Relation writer was found.

Validation state:
- PR #506 final head `c60e0800...` completed Flutter CI successfully.
- Maintainability guardrail tests: success.
- Maintainability regression ceilings: success.
- Flutter setup/dependency install: success.
- Drift code generation: success.
- `flutter analyze`: success.
- full test step: success.
- PR #506 was squash-merged only after those checks were green.
- Local Flutter validation was not available in this execution environment because the container could not resolve `github.com` for a repository clone; GitHub Actions was the executable validation source for this run.

Cross-lane dependencies / ownership:
- Database/View lane owns the schema-authoring UI, impact summary, explicit multi-to-single target choice UI, and user confirmation flows. It should call the integrated B-lane integrity service rather than directly updating Relation config.
- PR #515 is presentation-only and B-audited; the next #491 host wiring remains the point where canonical `ObjectStore.createRelationProperty(...)` routing must be verified.
- PR #516 is a B-audited new Relation-producing workflow and currently follows the canonical target/cardinality/transaction contract. Keep its outer transaction as the atomic boundary as template Views/provenance evolve.
- PR #507 current slice is Relation-read-only and has no B blocker; its future media resolver must define stable behavior for multi-valued Relation cover sources without mutating Relation state.
- No shared hotspot lease was taken in this run. Production changes were isolated to the new data-integrity service plus focused tests and this handoff; `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, and `app_database.dart` were not edited by Lane B.

Exact next actions, in priority order:
1. When Database/View wires #515 into the real #491 host, audit that Relation creation calls `ObjectStore.createRelationProperty(...)` with the structured target/cardinality request and does not construct `targetObjectTypeId`/`multiple` config directly.
2. When Database/View implements the #493 editing surface, audit that Relation target/cardinality edits call `inspectChange` / `updateRelationSchema` and preserve explicit-choice semantics.
3. When #507 gains actual Relation-backed media resolution, audit multi-valued selection/fallback and ensure View reads never repair or mutate Relation state.
4. If product requirements later need bidirectional Relation target retargeting, design it as an explicit paired migration that validates both sides before writes; keep the current fail-closed rejection until then.
5. Continue Relation-producing workflow coverage only when a real new production writer/reader lands from #491/#492/#245/#484 or another composable-domain path.

Current risks / stop condition:
- Non-empty Relation target retargeting can only proceed when every existing target is already valid for the proposed ObjectType. Mapping/converting targets across ObjectTypes is a separate explicit migration decision and must not be guessed here.
- Bidirectional target retargeting remains intentionally unsupported rather than partially rewriting pair metadata.
- #515 has not yet been wired into the real Property-creation host, and #507 has not yet added the actual Relation media resolver. #516's current Relation writer has been audited and is canonical. With no remaining unreviewed Relation writer/resolver or independent #493 integrity slice at this checkpoint, Lane B should remain idle until one of those concrete cross-lane paths lands rather than invent speculative abstractions. This is the explicit stop reason.

## Initial next actions
The original bootstrap list below is retained as historical context; merged PR #506 implements actions 1–4 and subsequent audits cover the currently open #491/#492/new-template seams.

1. For #493, define transactional validation rules for `Relation(A) -> Relation(B)` target changes: validate all existing targets first and leave old schema/data intact on any failure.
2. Define `multi -> single` behavior: require explicit deterministic user choice when multiple values exist; never silently drop targets.
3. Define `single -> multi` behavior: preserve the existing target without rewriting unrelated edges.
4. Add focused service/domain regressions around schema mutation rollback, edge/index/backlink preservation and fail-closed target mismatch.
5. As #491 lands, verify generic Relation Property creation still uses canonical target/cardinality validation and no alternate writer/index.
6. Resume product-workflow lifecycle coverage only when Primitive/Database-View lanes add a genuinely new Relation-producing production path.

## Cross-lane boundaries
- **Database/View lane** owns schema-authoring dialogs and user-facing migration prompts.
- **Object Core lane** owns Object/ObjectType core model and Body semantics.
- **Primitive lane** owns Image/File/Weblink/Tag product semantics and decides when new Relations are required.
- **Refactor lane** may delete dead compatibility code only after product parity; it must not redesign Relation semantics.

## Safety / sequencing
- Legacy Bookmark/Photo compatibility state remains live until caller-zero; integrity tests do not authorize destructive cleanup.
- Do not infer a new Person -> Image Relation contract until Primitive/Object work establishes a real production workflow.
- Do not add Relation tests merely because an Image/Weblink participates in Relations; add them only when identity/targets/writes/deletion semantics change.
- Prefer tests/integrity services and avoid presentation-only edits.

## Handoff checklist
Before ending a run, record:
- active Issue and exact integrity contract;
- branch/commit/PR;
- regressions/services added;
- validation results;
- cross-lane dependency and hotspot ownership;
- next independent integrity actions;
- explicit stop reason.

## Stop rule
If there is no new Relation-producing workflow, schema-integrity slice, deletion/reference invariant, or concrete correctness regression, remain idle rather than adding speculative abstractions. The broadened #493/#491 scope is the current source of independent work.
