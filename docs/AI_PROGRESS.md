# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal

Integrate the generic Object/database foundations into a coherent user-facing workflow inspired by Notion and Capacities while preserving bookmark behavior and keeping the architecture generic.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

https://github.com/are4c4/bookmark_app/issues/56

## Development lanes

1. **Object lane** — `docs/AI_PROGRESS_OBJECT.md`
   - Object/ObjectType/Property architecture
   - reusable Object types
   - Object detail content and Body/block model
   - Daily Notes and Value-to-Object promotion

2. **Relation lane** — `docs/AI_PROGRESS_RELATION.md`
   - Relation/backlink lifecycle
   - bidirectional integrity
   - relation write validation and read/mutation/index APIs
   - rename/delete propagation and Tag hierarchy expressed through Relations

`docs/AI_PROGRESS_OBJECT_RELATION.md` is legacy combined context only.

## Sustained-run policy

Implementation runs should continue across multiple safe checkpoints. Pending CI alone is not a blocker; stop only for a genuine design/risk/cross-lane/external validation boundary or runtime limit.

## Latest relevant state

- PR #61 merged: explicit Value / Object Relation / Computed Property semantics.
- PR #62 merged: bidirectional Relation pair integrity hardening.
- PR #64 merged: reversible Value-to-Object planning, versioned Body model, ObjectType defaults contract, and shared Object detail content.
- PR #65 merged at `93d8cf1` after Flutter CI #372 passed: Object Body/default persistence, reusable Weblink Object, Daily Note open-or-create, shared detail loading, Weblink reuse, and safe paragraph Body adapter are now on `main`.
- Object PR #67 is open for shared Object detail editing, Daily Note detail bridging, persisted ObjectType default resolution, and Object detail sessions.
- Relation PR #66 is open for broader Relation lifecycle plus stable read/mutation/index facades. It was based before #65 advanced `main` and must be refreshed/replayed by the Relation lane before integration.
- Existing Database/View foundations include shared Object query/filter/sort/group projection, Gallery/List/Table/Board, Board drag/drop, Formula/Rollup, and generic database integration.

## Repository-wide design contract

- Object is global and unique; Databases collect/show Objects rather than own duplicates.
- Database = which Objects; View = how to see them.
- ObjectType = schema + defaults.
- Effective defaults resolve as `View override > Database override > ObjectType default > app default`.
- Object content = structured Properties + versioned free Body blocks.
- Property semantics distinguish Value, Object Relation, and Computed.
- Tags are Objects; Select/MultiSelect remain local option sets.
- Date is a Value; Daily Note is a normal Object keyed uniquely by local date.
- Object detail should reuse one content/editing core across side peek, center peek, and full page.

## Integration policy

- Keep `main` releasable.
- Use focused lane-specific branches/PRs.
- Avoid both lanes concurrently owning broad refactors of the same core file.
- Replay/rebase narrow work on latest `main` instead of force-merging stale shared handoff conflicts.
- Preserve existing bookmark/tag data; no destructive migration without explicit approval.

## Next repository-wide actions

- Validate and integrate Object PR #67 when its latest-head CI is green.
- Relation lane refreshes #66 onto latest `main`, validates it, and lands stable Relation mutation/read/index APIs.
- After both are stable, Object lane can implement Value-to-Object Relation execution by consuming the Relation facade rather than duplicating lifecycle rules.
- Database/View integration may then consume Object detail sessions/open defaults in narrow UI slices.

## Validation

- PR #61 functional head passed Flutter CI before merge.
- PR #62 passed Flutter CI before merge.
- PR #64 passed Flutter CI #346 before merge.
- PR #65 latest head passed Flutter CI #372 before merge.
- PR #67 requires fresh latest-head CI.
- Relation #66 intermediate CI runs may be cancelled while its branch changes; only latest-head green CI should gate merge.

## Known risks

- Parallel Object/Relation work can make stale branches unmergeable even when code changes do not overlap; refresh from latest `main` before integration.
- Promotion execution depends on stable Relation mutation APIs.
- Direct Object detail UI integration may overlap Database/View presentation ownership; keep the first surface narrow.
- Block editing should preserve unknown future blocks and avoid flattening richer content.
