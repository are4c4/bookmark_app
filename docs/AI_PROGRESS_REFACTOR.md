# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Read live GitHub state before acting; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-06
Latest `main` observed: `25c9618c8a957aff771fd3c864be15a57e6ba339` after Object #381.

Recent Refactor work:
- **#369 merged** — repository/refactor handoff refresh after failure-policy convergence.
- **#377 merged** — `tool/maintainability_report.sh` now reports presentation `workspaceStore.database` reach-through so dependency-boundary debt is measurable instead of anecdotal.
- **#383 open** — centralizes duplicate fail-soft `bookmark_object_links` compatibility reads from Bookmark URL/visual resolvers behind `BookmarkObjectLinkReadStore`; stale predecessor #376 was closed. CI #1406 was cancelled while `main` advanced, so re-check/re-run only after current mergeability is verified.
- **#385 open** — reverse-lookup URL presentation now reuses the existing `BookmarkPresentationResolverFactory` rather than constructing `BookmarkUrlResolver` from `repository.workspaceStore.database`. The regression extends the existing composition guard to this host. This removes one presentation database reach-through reference/file without adding a new abstraction. The immediately stale predecessor #384 was closed and the same two-file diff was rebuilt on Object #381 main.

Object lane is moving quickly through Image identity/import convergence (#378–#382), so Refactor must keep rebuilding only narrow intended diffs on latest main rather than force-merging stale ancestry.

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

Historical compatibility fixes/regressions include #257, #259, #269 and #270. Canonical Relation bootstrap regressions replay old boundaries; Refactor must not redesign Relation storage while maintaining them.

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

Object-first URL presentation has advanced through lifecycle #317, reverse lookup #320, Notion card #322, Stage1 #341 and Bookmark List metadata #360.

Legacy `bookmarks.url`, Photo and thumbnail storage remain compatibility/import/export/live-host data. Presentation progress does **not** prove caller-zero; deletion still requires a fresh production audit and migration policy.

### GenericDatabasePage decomposition / dependency composition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph;
- #377 makes remaining presentation-to-database reach-through countable.

Continue only through patch-sized moves that measurably remove Widget responsibility/LOC or direct persistence composition. Do not reconstruct the large host wholesale.

### Failure policy / diagnostic privacy
Merged work covers PDF enrichment/metadata, remote image geometry, Weblink metadata, malformed View/tag/generic Object JSON, computed projection, ObjectSync preview ingestion, GlobalSearch, Settings operations, Board/Image/Profile rollback cleanup, ProfileManager fallback diagnostics, attachment import/enrichment, and bootstrap/Profile-switch failure UI.

Policy:
- intentional fail-soft behavior stays fail-soft;
- rollback cleanup never replaces the primary failure;
- user-visible failures use stable retry/domain messages instead of raw implementation strings;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies, and exception text;
- changing `ProfileManager` corrupt-registry fallback selection remains a product/data-safety decision, not routine cleanup.

## Cross-lane coordination

### Object lane
Object owns #56/#155/#245/#249/#252 product/presentation convergence. Current open Object PRs include #382 (canonical Image reimport/file reuse); #381 merged while this run was active. Re-check all open PRs before touching shared Bookmark/generic/Image hosts.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile remains mature. Refactor must not create alternate serialized-id Relation writes, indexes, repair paths, or presentation-side mutation.

## Validation / CI state
- #383 is mergeable on its recorded base, but Flutter CI #1406 was cancelled while `main` advanced; treat it as needing a fresh live-state check before merge/re-run.
- #385 has a focused source-level architecture regression in `test/bookmark_presentation_resolver_composition_test.dart`; full Flutter CI should be required before merge.
- No local toolchain validation was available in this connector-only run, so GitHub CI is authoritative for these open branches.

## Exact next actions
1. Re-check current `main`, open Object PR ownership and #383/#385 mergeability before any write.
2. If #383 remains the intended four-file diff, refresh/re-run it on current main rather than force-merging stale ancestry; merge only after green CI.
3. Do the same for #385; expected behavioral contract is unchanged `resolveUrl` injection and URL/opening behavior with one less direct presentation database reach-through.
4. Continue the #377 metric-driven dependency-composition cleanup using **existing** boundaries first. Small candidates include remaining Bookmark presentation hosts that still construct canonical resolvers directly. Avoid wrapper-only abstractions.
5. Continue GenericDatabasePage P1 only when no Object PR owns it and a patch-sized extraction removes a concrete responsibility such as schema/database actions, Property workflow orchestration, or layout host logic.
6. Follow Object-first legacy retirement: re-run production searches before deleting any Bookmark URL/thumbnail/Photo dependency; compatibility/import/export/backup data stays until caller-zero and migration policy are proven.
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
Refactor remains actionable. This run completed stale-PR cleanup and opened a measurable dependency-boundary reduction (#385) while #383 remains an independent duplicate-read-path consolidation. Further work should continue after live PR/main refresh; do not treat pending CI alone as a stopping reason when another non-conflicting patch-sized boundary reduction exists.
