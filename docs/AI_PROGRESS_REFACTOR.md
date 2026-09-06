# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-06
Latest `main` observed: `5095d4d7a65214ad8af4fc46621dec0e28abbc43` after Object #350/#352 merged.

Current focused Refactor work:
- **#351** — Board create rollback cleanup; full Flutter CI run #1329 green.
- **#353** — Image import rollback cleanup; full Flutter CI run #1332 green.
- **#355** — stable bootstrap/Profile-switch failure boundary; current branch for this handoff, CI running at this checkpoint.
- **#356** — refreshed profile restore cleanup boundary on current main; supersedes stale #342 and adds a source-level rollback guard.
- **#357** — refreshed ProfileManager diagnostic-privacy boundary on current main; supersedes stale #340 and keeps recovery behavior unchanged.
- **#336** remains the only older stale Refactor branch still requiring reassessment/rebuild if its attachment error-boundary changes are still needed.

Parallel ownership observed during this run:
- Object #350 and #352 were active at run start and then merged to main.
- Relation #345 is handoff-only.

This run intentionally avoided `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and `app_database.dart` while shared-host ownership was moving.

## Checkpoints completed in this run
### 1. Stable bootstrap/Profile-switch error boundary — #355
Branch: `refactor/issue-225-bootstrap-stable-error`

- preserve existing fail-closed startup/Profile-switch behavior;
- stop interpolating caught implementation exceptions into the fatal UI;
- show one stable retry-oriented user message;
- make bootstrap, Profile-switch, and Profile-switch rollback failures debug/assert-visible through fixed operation diagnostics + stack traces only;
- keep exception text, profile names, database names, directory paths, and other user content out of diagnostics;
- keep the original error object internally so fallback/state semantics remain unchanged;
- add `test/bootstrap_error_boundary_test.dart` as a deterministic privacy/stable-message guard;
- update `docs/ERROR_POLICY_AUDIT.md`.

### 2. Refresh stale profile restore cleanup work — #356
Rebuilt old #342 directly on current main as `refactor/issue-225-profile-restore-cleanup-v2`.

- preserve extraction/validation failure as the primary failure;
- make partial-target deletion best-effort so cleanup cannot mask the original restore failure;
- add fixed debug/assert diagnostic + stack trace without path/exception text;
- add `test/profile_backup_cleanup_boundary_test.dart`;
- close stale #342 as superseded.

### 3. Refresh stale ProfileManager diagnostic privacy work — #357
Rebuilt old #340 directly on current main as `refactor/issue-225-profile-diagnostic-privacy-v2`.

- keep corrupt-registry fallback selection unchanged;
- keep imported profile metadata optional/best-effort;
- remove raw exception interpolation from fallback diagnostics;
- retain fixed operation labels + stack traces;
- add `test/profile_manager_diagnostic_privacy_test.dart`;
- close stale #340 as superseded.

No checkpoint in this run changes schema, Object identity, Relation semantics, Profile recovery policy, or shared host product behavior.

## Major completed checkpoints
### P0 guardrails / architecture
Merged:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance.

### AppDatabase narrowing
Historical migration extraction v2-v16 is complete with regression coverage and compatibility fixes. Responsibility moves already merged include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

Only move another AppDatabase responsibility when a real responsibility/caller is removed; reject wrapper-only indirection.

### Legacy Bookmark presentation consolidation
Original direct visual duplicates are migrated to canonical `BookmarkVisualImage`:
- lifecycle rows #296;
- Notion card #294;
- reverse lookup #299;
- Stage1 List/Table #324.

Keep legacy URL/thumbnail/Photo compatibility storage until Object-first replacement parity and production caller-zero are proven.

### GenericDatabasePage decomposition
Merged:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns low-level page dependency composition.

Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Avoid monolithic controller rewrites.

### Failure-policy / privacy
Merged work already covers PDF metadata/enrichment, Weblink metadata, remote image decode, ObjectSync preview ingestion, malformed View/tag/generic Object JSON, computed projection, GlobalSearch, Settings backup/AutoOrganize, View opening-mode failures, global file drop, and related user-visible boundaries.

Policy:
- intentional fail-soft behavior stays fail-soft;
- user-visible failures use stable domain/retry messages instead of raw implementation exceptions;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies, and exception text;
- rollback cleanup must never replace the original primary failure.

## Cross-lane coordination
### Object lane
Object owns #56/#155/#249/#252 product/presentation work. Re-check open PR ownership before touching shared Bookmark/generic hosts even after #350/#352 merged, because Object lane advances quickly.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Refactor must not redesign Relation storage or create parallel serialized-id/index/repair paths. #351 uses an existing Relation validation failure only to test rollback behavior.

## Exact next actions
1. Monitor #351/#353/#355/#356/#357 CI; integrate when green and mergeable. Rebuild only when main advances into a real conflict.
2. Reassess stale #336 on latest main. If the attachment error-boundary work remains needed, recreate only the minimal diff and focused tests, then close #336 as superseded.
3. After open failure-policy slices settle, prefer a measurable P1 responsibility extraction over continuing to generate micro logging PRs.
4. Continue GenericDatabasePage P1 only when no Object PR owns the hotspot and the patch removes real Widget responsibility/LOC.
5. Follow Object-first legacy retirement sequencing; do not delete Bookmark URL/Photo compatibility storage before caller-zero/parity is demonstrated.
6. Re-run maintainability metrics after another meaningful hotspot extraction and record actual file/LOC movement.
7. Keep ProfileManager corrupt-registry recovery behavior deferred; changing fallback selection/data-location recovery requires an explicit product/data-safety decision.

## Validation expectations
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- migrations: historical fixture coverage and exact schema/order preservation;
- failure-policy: preserve fail-soft/fail-closed semantics except replacing raw implementation detail with a stable message; keep diagnostics privacy-safe;
- legacy deletion: prove production caller-zero first.

## Risks / blockers
- parallel lanes move `main` quickly; prefer clean rebuilds on latest main over force-merging stale branches;
- large shared hosts should not be reconstructed wholesale;
- legacy Bookmark/Photo storage remains live compatibility data while replacement parity is incomplete;
- ProfileManager recovery policy is a product/data-safety decision, not routine cleanup;
- CI pending alone is not a blocker, but no further overlapping shared-host work should be started while ownership is unclear.

## Stop state for this run
Three coherent non-hotspot checkpoints were completed: #355, #356, and #357, with stale #342/#340 retired. #351/#353 are already full-CI green. Remaining immediately actionable cleanup is stale #336, but that overlaps the attachment area and should be reassessed against latest main in a fresh minimal branch rather than expanded inside the current bootstrap PR. This run stops after multiple reviewable checkpoints with shared hotspots deliberately untouched.
