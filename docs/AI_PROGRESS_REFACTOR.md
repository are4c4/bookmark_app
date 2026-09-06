# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Read live GitHub state before acting; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-06
Latest `main` observed after this run: `a5968bc5d259731097f31ba60b5bf540aaaf664b` (PR #368).

This run converged the remaining stale failure-policy branches instead of force-merging them:

- **#351 merged** — Board create rollback cleanup cannot replace the original grouped-preset/create failure.
- **#358 merged** — Image import rollback cleanup cannot replace the original canonical Image creation/import failure.
- **#362 merged** — Profile restore/import cleanup preserves the primary restore failure when partial-target cleanup also fails.
- **#363 merged** — `ProfileManager` fail-soft diagnostics no longer interpolate raw exception text; fallback/recovery behavior is unchanged.
- **#364 merged** — attachment import failure uses a stable retry message and privacy-safe debug diagnostics; optional PDF author enrichment remains best-effort. This superseded #336 and removed the old public test-only seams that caused repeated Widget/Drift lifecycle hangs.
- **#368 merged** — bootstrap/Profile-switch remains fail-closed, but fatal UI no longer renders raw implementation exceptions; fixed debug operation labels + stack traces preserve observability without Profile/path/exception text. Full Flutter CI #1367 succeeded.

Stale predecessors #336/#355/#357/#365 were closed rather than force-merged. #364 and #368 were rebuilt directly on current main and validated there.

There is **no open Refactor production PR** at this checkpoint. Object PR **#366** (`BookmarkReorderableProperties` person-role Property add convergence) has full CI #1364 green but became non-mergeable after main advanced; Object lane owns its refresh/integration. Refactor must not touch that host while #366 is active/stale.

## Major completed checkpoints

### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase migration extraction
Historical migration bodies **v2 through v16** are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Historical compatibility fixes/regressions include:
- #257 duplicate `photos.tags` guard;
- #259 duplicate `people.profile_photo_id` guard;
- #269 historical SavedView raw-schema handling;
- #270 historical Bookmark v2->v3 normalization without current-row mapper assumptions.

Canonical Relation bootstrap regressions replay old boundaries; Refactor must not redesign Relation storage while maintaining them.

### AppDatabase responsibility reduction
Merged responsibility-moving slices:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

Only add another abstraction when it removes a real database-root/Widget responsibility or duplicate caller logic. Reject wrapper-only indirection.

### Legacy Bookmark visual / URL presentation retirement
Original direct visual duplicates are canonicalized through `BookmarkVisualImage`:
- Notion card #294;
- reverse lookup #299;
- lifecycle rows Object #296;
- Stage1 List/Table #324.

Object-first URL presentation has advanced well beyond the old #322 checkpoint:
- lifecycle #317;
- reverse lookup #320;
- Notion card #322;
- Stage1 #341;
- Bookmark List metadata no longer reads legacy URL directly #360.

Legacy `bookmarks.url` remains compatibility/import/export data. Presentation progress does **not** prove storage caller-zero; deletion still requires a fresh production audit and migration policy.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Do not reconstruct the large host wholesale.

### Failure policy / diagnostic privacy
Merged work now covers PDF enrichment/metadata, remote image geometry, Weblink metadata, malformed View/tag/generic Object JSON, computed projection, ObjectSync preview ingestion, GlobalSearch, Settings operations, Board/Image/Profile rollback cleanup, ProfileManager fallback diagnostics, attachment import/enrichment, and bootstrap/Profile-switch failure UI.

Policy:
- intentional fail-soft behavior stays fail-soft;
- rollback cleanup never replaces the primary failure;
- user-visible failures use stable retry/domain messages instead of raw implementation strings;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies, and exception text;
- changing `ProfileManager` corrupt-registry fallback selection remains a product/data-safety decision, not routine cleanup.

## Cross-lane coordination

### Object lane
Object owns #56/#155/#149/#245/#249/#252 product/presentation convergence. Before touching Bookmark/generic hosts, re-check open PRs.

At this checkpoint #366 owns `bookmark_reorderable_properties.dart`. Do not overlap it from Refactor.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile remains mature. Relation handoff was refreshed in #367. Refactor must not create alternate serialized-id Relation writes, indexes, repair paths, or presentation-side mutation.

## Exact next actions
1. **Do not immediately create another micro logging PR.** The recent failure-policy sequence is sufficiently broad; prefer measurable responsibility/LOC reduction next.
2. Re-check Object #366 and all open PR ownership before touching shared hosts.
3. Continue GenericDatabasePage P1 only when a safe patch-sized extraction removes a concrete responsibility such as schema/database actions, Property workflow orchestration, or layout host logic.
4. Re-audit remaining raw user-visible exception interpolation outside current Object-owned hotspots; choose only small files that can be edited/tested deterministically.
5. Follow Object-first legacy retirement: re-run production searches before deleting any direct Bookmark URL/thumbnail/Photo dependency; compatibility/import/export data stays until caller-zero and migration policy are proven.
6. Re-run `tool/maintainability_report.sh` after another meaningful responsibility extraction and record actual file/LOC movement rather than adapter count.
7. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.

## Validation expectations
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- failure-policy work: preserve fail-soft/fail-closed semantics except replacing unsafe raw diagnostics/messages; keep diagnostics privacy-safe;
- legacy deletion: prove production caller-zero and import/export/backup handling first.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild small intended diffs on latest main instead of force-merging stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- test lifecycle hangs must not be solved by changing production semantics or simply raising global timeouts;
- abstractions that add wrappers without removing responsibility should be rejected.

## Stop / continuation state
The stale failure-boundary backlog has been converged and merged through #368 with full CI on the final branches. Refactor is actionable, but the next useful slice should be a **measurable hotspot responsibility extraction or a genuinely unsafe remaining boundary**, not another speculative abstraction or logging-only cleanup.