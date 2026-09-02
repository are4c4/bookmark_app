# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Integrate generic Object/database foundations into a coherent Notion/Capacities-inspired workflow while preserving bookmark behavior and keeping Objects globally reusable.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Development lanes

1. **Object lane** — `docs/AI_PROGRESS_OBJECT.md`
   - Object/ObjectType/Property architecture
   - reusable Object types
   - shared Object detail/content and Body
   - Daily Notes and Value-to-Object promotion

2. **Relation lane** — `docs/AI_PROGRESS_RELATION.md`
   - Relation/backlink lifecycle and integrity
   - stable Relation read/mutation/index APIs
   - rename/delete propagation and Tag hierarchy Relations

`docs/AI_PROGRESS_OBJECT_RELATION.md` is legacy combined context only.

## Latest relevant state

- PR #61 merged: Value / Object Relation / Computed semantics.
- PR #62 merged: bidirectional Relation pair integrity.
- PR #64 merged: promotion planning, versioned Body model, ObjectType defaults contract, shared Object detail content.
- PR #65 merged: Body/default persistence, Weblink Object, Daily Note open-or-create, detail loader, Weblink reuse, safe paragraph Body adapter.
- Relation PR #66 merged at `6770a5f1` after Flutter CI #390: stable `RelationMutationService`, `RelationReadService`, Relation index/lifecycle hardening, Relation-safe delete/rename, and Tag hierarchy cleanup are on `main`.
- Object PR #71 merged at `f89ea089` after Flutter CI #408: shared detail editing, Daily Note detail bridge, persisted ObjectType default resolution, Object detail sessions, and reusable Image Object facade are on `main`.
- Object PR #68 owns current ObjectInspector/Body/Daily Note entry presentation work; avoid parallel competing inspector rewrites.
- Object PR #70 owns Value -> Object promotion execution using merged Relation APIs; latest-head CI is being revalidated after an analyzer nullability fix.
- Object PR #72 adds resolved Relation/Backlink context to the shared Object detail session using `RelationReadService`.
- Relation PR #69 separately owns read-only Relation integrity diagnostics.

## Repository-wide design contract

- Object is global and unique; Databases collect/show Objects rather than own duplicates.
- Database = which Objects; View = how to see them.
- ObjectType = schema + defaults.
- Effective defaults resolve as `View > Database > ObjectType > app`.
- Object content = structured Properties + versioned Body blocks.
- Property semantics distinguish Value, Object Relation, and Computed.
- Tags are Objects; Select/MultiSelect remain local option sets.
- Date is a Value; Daily Note is a normal Object uniquely keyed by local date.
- Object detail should reuse one content/editing core across side peek, center peek, and full page.

## Integration policy

- Keep `main` releasable and merge only latest-head green PRs.
- Use focused lane-specific branches/PRs.
- Consume stable cross-lane APIs rather than duplicating ownership.
- If concurrent work advances `main`, replay narrow code/test diffs instead of force-merging stale handoff files.
- Preserve existing bookmark/tag data; no destructive migration without explicit approval.

## Next repository-wide actions

- Validate/integrate Object PR #72 and promotion PR #70 in independent reviewable slices.
- Let PR #68 remain the single owner of current ObjectInspector presentation integration.
- Relation lane continues from `docs/AI_PROGRESS_RELATION.md`, including PR #69 diagnostics, without editing Object-owned UI.
- After promotion execution lands, Object UI can expose promotion actions by consuming the executor/Relation facade while preserving source Values by default.

## Validation

- #64 final CI green before merge.
- #65 Flutter CI #372 green before merge.
- #66 Flutter CI #390 green before merge.
- superseded #67 Flutter CI #395 green; replay #71 Flutter CI #408 green before merge.
- #70 and #72 require latest-head CI before merge.

## Known risks

- Parallel agents can create overlap in presentation files or handoff docs; respect active PR ownership and prefer sequencing.
- Promotion source clearing is destructive and must stay explicit/confirmed.
- Simplified Body editing must preserve unknown/richer block kinds.
- Relation context consumers should use stable Relation read services rather than rebuilding graph logic in Object UI.
