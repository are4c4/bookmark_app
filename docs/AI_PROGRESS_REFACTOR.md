# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Always read live GitHub state before editing; PR numbers below are checkpoints, not a substitute for current ownership/CI.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics. Refactor owns measurable responsibility reduction, legacy retirement after parity, failure-policy/privacy cleanup, and maintainability guardrails.

## Current checkpoint — 2026-09-06
Latest `main` observed at this checkpoint: `217437e440b40532c9a84c3566f365a9dcdb0cf0` after Refactor #406.

Recent Refactor convergence:
- **#373 merged** — `BookmarkVisualImage` and Bookmark lifecycle URL presentation delegate low-level resolver construction to `BookmarkPresentationResolverFactory`.
- **#374 merged** — backup workflow moved out of `SettingsPage` into `DatabaseBackupSettingsSection`, removing about 108 lines of workflow responsibility from the shell.
- **#377 merged** — maintainability report now shows presentation `workspaceStore.database` reach-through counts/files without failing on existing debt.
- **#383 merged** — duplicate legacy Bookmark -> mirrored Object lookup SQL/catch logic is centralized in `BookmarkObjectLinkReadStore` and reused by Bookmark URL/visual resolvers.
- **#393 merged** — optional `WeblinkCreateEnrichmentService` diagnostics no longer attach raw exception objects.
- **#395 merged** — reverse-lookup URL resolver composition delegates to `BookmarkPresentationResolverFactory`.
- **#400 merged** — `DatabaseBackupSettingsSection` no longer reaches through `BookmarkRepository` to `workspaceStore.database`; `DatabaseBackupService.fromRepository(...)` owns that composition.
- **#401 merged** — tests-only architecture guard prevents new direct `BookmarkUrlResolver` / `BookmarkVisualResolver` construction in presentation; only Stage1 and `NotionBookmarkCard` are currently allowlisted legacy hosts.
- **#404 merged** — optional remote-image dimension-probe diagnostics keep fixed message + stack but omit the raw exception object; undecodable image bytes still import successfully.
- **#406 merged** — optional post-create Weblink enrichment in `GenericDatabaseObjectCreateService` keeps canonical creation fail-soft, omits raw exception objects from diagnostics, and has a real behavior regression proving enrichment failure does not roll back the canonical Weblink.

Current parallel ownership observed at the checkpoint:
- Object #402 is active on canonical Image managed-file deletion/cleanup safety;
- Relation #403 has merged the Bookmark Cover Image Relation lifecycle regression;
- no open Refactor production PR remains after #406.

## Major completed checkpoints

### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh` and `docs/MAINTAINABILITY.md`;
- no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- #401 direct Bookmark resolver construction guard.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### AppDatabase migration extraction / responsibility reduction
Historical migration bodies v2-v16 are extracted behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Merged responsibility moves include:
- #281 `BookmarkReadStore`;
- #282 `ProfilePathResolver`;
- #283 `SavedViewReadStore`;
- #289 `PhotoReadStore`.

A concrete next AppDatabase candidate exists: favorite/status/rating/open-count plus the three batch state updates are still near-passthrough calls from `BookmarkRepository` into the database root. A focused `BookmarkStateMutationStore` would remove real application mutation responsibility. **Do not implement this while the available write path requires reconstructing the large `app_database.dart` file wholesale.** Wait for a safe patch-sized edit path or another sequenced change that already owns that file.

### Legacy Bookmark visual / URL presentation retirement
All four direct visual duplicates from the original inventory are canonicalized through `BookmarkVisualImage` (Notion card, reverse lookup, lifecycle rows, Stage1 List/Table). Canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion card, Stage1 and Bookmark List metadata.

Resolver composition has also converged through #373/#395. #401 prevents new presentation-side direct resolver construction. The remaining allowlisted direct construction hosts are:
- `lib/views/bookmark_unified_stage1_page.dart`;
- `lib/widgets/notion_bookmark_card.dart`.

Migrating either host away should shrink the allowlist; do not relax the guard for new callers.

Legacy `bookmarks.url`, thumbnail, Photo and Bookmark tables remain compatibility/import/export/live-host data until production caller-zero and migration policy are proven. Presentation convergence alone is not permission to delete storage.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 `GenericDatabasePageStateLoader` owns read/projection loading and computed projection;
- #323 `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Store/Service composition graph.

Remaining high-value responsibilities include schema/database actions, Property-create/edit workflows and layout-specific host code. Continue only through patch-sized moves that measurably remove Widget responsibility/LOC. Do not reconstruct the large host wholesale.

### Failure policy / diagnostic privacy
Broad high-value boundaries are now covered across search/settings/bootstrap/profile/attachments/rollback/malformed persisted data and optional Weblink/Image enrichment.

Recent additions:
- #393 — Weblink create enrichment diagnostics;
- #404 — remote image dimension probe diagnostics;
- #406 — generic Database Weblink post-create enrichment diagnostics plus behavior regression.

Policy remains:
- intentional fail-soft behavior stays fail-soft;
- rollback cleanup never replaces the primary failure;
- user-visible failures use stable retry/domain messages instead of raw implementation strings;
- debug diagnostics use fixed operation labels + stack traces and avoid raw names, URLs, paths, JSON, bytes, response bodies, and exception text;
- changing `ProfileManager` corrupt-registry fallback selection remains a product/data-safety decision, not routine cleanup.

Remaining raw user-visible exception interpolation is concentrated in large/shared legacy hosts such as Photo management, Tag management and Stage1. Do not create more micro logging PRs merely to chase strings in those files; address them only as part of a safe, owned, testable host slice.

## Dependency-composition state
#377 makes presentation database reach-through visible. Recent reductions include resolver composition (#373/#395) and backup service composition (#400).

Known remaining presentation reach-through includes large/shared hosts such as:
- `app_shell.dart`;
- `people_management_page.dart`;
- `photo_management_page.dart`;
- `collection_management_page.dart`;
- `bookmark_unified_stage1_page.dart`;
- `generic_database_page.dart`.

Some low-level database access inside dedicated composition/service factories is intentional and should not be counted as presentation debt. Prefer a real responsibility move with two or more callers, or an existing focused boundary, over a wrapper created solely to hide one property access.

## Cross-lane coordination

### Object lane
Object owns #56/#155/#245/#249 product/presentation convergence and currently #402 Image managed-file deletion safety. Re-check live PRs before touching Bookmark/generic/media hosts because Object advances quickly.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile remains mature. #403 covers the new Bookmark Cover Image production Relation lifecycle. Refactor must not create alternate serialized-id Relation writes, indexes, repair paths, or presentation-side mutation.

## Exact next actions
1. Re-read live open PR ownership before every shared-host change.
2. Prefer the next **measurable responsibility reduction** over another diagnostic micro-PR.
3. When a safe patch-sized edit path is available, migrate `NotionBookmarkCard` to `BookmarkPresentationResolverFactory.urlFor(repository)` and shrink the #401 allowlist. Stage1 remains a large shared hotspot and should be sequenced separately.
4. Continue reducing `workspaceStore.database` presentation reach-through only in small/owned hosts with an existing meaningful Store/Service boundary. Do not mass-wrap every occurrence.
5. Continue GenericDatabasePage P1 only when a safe extraction removes concrete schema/database action, Property workflow, or layout-host responsibility.
6. Revisit `BookmarkStateMutationStore` only when `app_database.dart` can be patched safely without whole-file reconstruction.
7. Follow Object-first legacy retirement: prove production caller-zero plus import/export/backup handling before deleting Bookmark URL/thumbnail/Photo storage.
8. Keep ProfileManager recovery-selection behavior deferred unless there is an explicit product/data-recovery decision.
9. Issue #225 checklist is historically stale. Update it only in a dedicated admin pass that preserves concurrent issue edits; do not replace the large body opportunistically from a feature branch.

## Validation expectations
- responsibility moves: focused regression + `flutter analyze` + full tests before merge;
- migration work: historical fixture coverage and exact schema/order/default preservation;
- failure-policy work: preserve fail-soft/fail-closed semantics and privacy-safe diagnostics;
- legacy deletion: prove production caller-zero and import/export/backup handling first.

## Risks / blockers
- parallel lanes move `main` quickly; small diffs may be rebuilt on latest main, but do not force-merge stale branches;
- large shared hosts are conflict-prone and must remain patch-sized;
- current connector file writes replace complete files, so do not hand-reconstruct a large shared host for a small hunk;
- local/container git still cannot reliably resolve GitHub in this environment, so do not invent maintainability-report numbers that were not actually measured;
- legacy Bookmark URL/thumbnail/Photo storage remains live compatibility data while replacement parity is incomplete;
- test lifecycle hangs must not be solved by changing production semantics or merely raising global timeouts;
- abstractions that add wrappers without removing responsibility should be rejected.

## Stop / continuation state
Refactor remains actionable, but the next work should return to responsibility/LOC reduction and Object-first legacy retirement. Small failure/privacy gaps have largely been exhausted; large shared-host error strings are intentionally deferred until a safe host slice owns them.
