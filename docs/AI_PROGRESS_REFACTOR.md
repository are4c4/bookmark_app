# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-06
Latest `main` observed: `7493bda4c011fe167244542f19c4d49f4c4d1913` (#349).

Active Refactor PRs observed before this run:
- #351 — preserve Board create failure during rollback cleanup; full Flutter CI run #1329 is green.
- #353 — preserve Image import failure during rollback cleanup; full Flutter CI run #1332 is green.
- #342/#340/#336 are older Refactor branches based on stale main and should be refreshed/replaced rather than force-integrated if their changes are still needed.

Parallel ownership:
- Object #350 owns Bookmark person-role Property-add popover integration.
- Object #352 owns Bookmark Stage1 List readability.
- Relation #345 is handoff-only.

Therefore this run intentionally avoided `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and `app_database.dart`.

### New slice in this run
Branch: `refactor/issue-225-bootstrap-stable-error`

Implemented a focused `lib/main.dart` startup/Profile-switch error boundary:
- preserve existing fail-closed startup and Profile-switch behavior;
- stop interpolating the caught implementation exception into the fatal UI;
- show one stable retry-oriented user message instead;
- make bootstrap, Profile-switch, and Profile-switch rollback failures debug/assert-visible through fixed operation diagnostics + stack traces only;
- do not attach exception text, profile names, directory paths, database names, or other user content to diagnostics;
- keep the original error object internally so existing state/fallback semantics are unchanged;
- add `test/bootstrap_error_boundary_test.dart`, a deterministic source-level guard for the stable message and privacy-safe diagnostics;
- update `docs/ERROR_POLICY_AUDIT.md`.

No schema, Object identity, Relation behavior, Profile recovery policy, or shared presentation hotspot semantics changed.

## Major completed checkpoints
### P0 guardrails / architecture
Merged:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance.

### AppDatabase narrowing
Completed historical migration extraction v2-v16 with regression coverage and compatibility fixes. Responsibility moves already merged include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

Do not add wrapper-only indirection; only move another AppDatabase responsibility when a real caller/responsibility is removed.

### Legacy Bookmark presentation consolidation
Original direct visual duplicates are migrated to canonical `BookmarkVisualImage`:
- lifecycle rows #296;
- Notion card #294;
- reverse lookup #299;
- Stage1 List/Table #324.

Canonical URL preference is also moving host-by-host through Object-owned `BookmarkUrlResolver` work. Keep legacy URL/thumbnail storage until all required compatibility/import/export callers are proven replaceable.

### GenericDatabasePage decomposition
Merged:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns low-level page dependency composition.

Continue only through patch-sized moves that measurably remove responsibility/LOC. Avoid monolithic controller rewrites.

### Failure-policy / privacy
Merged work covers PDF metadata/enrichment, Weblink metadata, remote image decode, ObjectSync preview ingestion, malformed View/tag/generic Object JSON, computed projections, GlobalSearch, Settings backup/AutoOrganize, View opening-mode errors, global file drop and related user-visible boundaries.

Current policy:
- intentional fail-soft behavior stays fail-soft;
- user-visible failures use stable domain/retry messages rather than raw implementation exceptions;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies and exception text;
- rollback cleanup must not replace the original primary failure.

## Cross-lane coordination
### Object lane
Object currently owns #56/#155/#249/#252 product/presentation work. Before touching shared Bookmark or generic hosts, re-check open PR ownership.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Refactor must not redesign Relation storage or create parallel serialized-id/index/repair paths. #351 exercises an existing Relation validation failure only as a rollback regression; it does not change Relation semantics.

## Exact next actions
1. Let #351 and #353 integrate after their already-green CI; rebuild them again only if main advances into a real conflict.
2. Validate the bootstrap stable-error PR with Analyze/Test CI and integrate if green.
3. Reassess stale #336/#340/#342 against latest main. Close as superseded where newer merged/main behavior already covers them; otherwise recreate only the still-needed minimal diff on latest main.
4. Continue failure-policy work only where a real unsafe/silent boundary remains. Do not add logging to normal no-media/file-existence fallbacks.
5. Continue GenericDatabasePage P1 only when no Object PR owns the hotspot and a patch-sized responsibility move removes real Widget responsibility.
6. Follow Object-first legacy retirement sequencing; do not delete Bookmark URL/Photo compatibility storage before caller-zero/parity is demonstrated.
7. Re-run maintainability metrics after another meaningful hotspot extraction and record actual file/LOC movement.

## Validation expectations
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- migrations: historical fixture coverage and exact schema/order preservation;
- failure-policy: preserve user-visible/fail-soft semantics except replacing raw implementation detail with a stable message; keep diagnostics privacy-safe;
- legacy deletion: prove production caller-zero first.

## Risks / blockers
- parallel lanes move `main` quickly; prefer clean rebuilds on latest main over force-merging stale branches;
- large shared hosts should not be reconstructed wholesale;
- ProfileManager corrupt-registry recovery behavior is a product/data-safety decision and remains deferred;
- legacy Bookmark/Photo storage remains live compatibility data while replacement parity is incomplete;
- CI pending alone is not a blocker; continue only with independent non-conflicting slices.

## Stop state for this run
A coherent non-hotspot failure-policy slice is implemented with a focused regression and handoff/audit updates. The next high-value work depends on either integrating/refeshing already-open Refactor PRs or finding another independent boundary; shared hotspot work is currently owned by active Object PRs, so this run stops before creating overlapping edits.
