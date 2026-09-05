# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics; this lane deletes duplication, narrows responsibilities, improves failure observability/privacy, and decomposes hotspots only after checking parallel PR ownership.

## Current checkpoint — 2026-09-06
The Refactor lane has moved beyond the earlier #325–#329 persistence/fallback audit and is now systematically removing raw implementation exceptions from live UI boundaries without changing domain behavior.

Latest merged sequence:
- **#330** — Global Search index/query failures share a stable retryable error state; raw caught Objects are no longer rendered.
- **#331** — Settings backup export/restore failures use stable messages; restore confirmation and backup semantics are unchanged.
- **#332** — Auto-organize rule creation/bulk-apply failures use stable messages.
- **#335** — malformed Database View open-mode state fails closed without exposing raw parsing details.
- **#338** — global file-drop import failure uses a stable message and privacy-safe debug diagnostics.
- **#337** — Bookmark URL/file creation failures use stable retry messages; production duplicate detection and metadata semantics remain unchanged. Merged as `186d8cd` after full Analyze/Test green.

Current Refactor PRs at this checkpoint:
- **#336 `Stabilize attachment failure handling`** — attachment import failure + best-effort PDF author enrichment. Analyze is green; the latest Test run is validating a test-lifecycle-only fix that explicitly unmounts Drift-backed StreamBuilders and avoids `pumpAndSettle` while an intentional indeterminate progress indicator is active.
- **#340 `Sanitize ProfileManager fallback diagnostics`** — privacy-only diagnostic change. It removes raw exception text from profile-registry/imported-metadata debug output while preserving the exact fail-soft recovery behavior, persistence and data-location policy. Full CI is running.

Object #322/#333/#334 are merged. In particular, #334 no longer owns `generic_database_page.dart`, so the shared hotspot is not currently cross-lane locked; however the current GitHub connector still lacks a safe patch-write primitive, so the 70+ KB host must not be reconstructed wholesale.

## Completed checkpoints
### P0 guardrails / architecture
Merged guardrails include:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- dedicated Refactor handoff.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### Failure-policy / observability / diagnostic privacy
Merged behavior-preserving slices include:
- #227 optional PDF author enrichment diagnostics;
- #229 profile state / backup metadata fallback diagnostics;
- #234 corrupt Database View JSON fail-soft diagnostics;
- #237 remote image geometry decode diagnostics;
- #274 PDF metadata filename fallback diagnostics without path/content logging;
- #279 Bookmark metadata fallback diagnostics without URL/response/exception-text logging;
- #321 PDF author enrichment diagnostics aligned across create/drop paths without author names, URLs, paths or exception text;
- #325 malformed tag-tree expansion JSON remains fail-soft to collapsed state but is debug-visible;
- #326 malformed formula/rollup projection remains `null` but is debug-visible;
- #327 optional ObjectSync remote-preview failures remain non-blocking/no-repeat but are debug-visible;
- #328 Database View malformed-JSON diagnostics no longer attach `FormatException`;
- #329 malformed generic Property config / Record value JSON remains `{}` / `null` with privacy-safe debug visibility;
- #330 Global Search stable retryable error state;
- #331 Settings backup stable error boundaries;
- #332 Auto-organize stable error boundaries;
- #335 View open-mode stable/fail-closed error boundary;
- #338 global file-drop stable error boundary;
- #337 Bookmark creation stable error boundaries.

Intentional fail-soft product behavior must not be converted into user-visible failure merely to eliminate a broad catch. Debug diagnostics should use fixed messages plus stack traces and should not include raw names, URLs, paths, JSON, bytes, response bodies or exception text when those may echo user content.

### AppDatabase migration extraction — complete
All historical migration bodies **v2 through v16** live behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Historical fixtures cover real schemaVersion checkpoints down to v1 and exposed installed-user defects fixed before extraction:
- #257 guarded duplicate `photos.tags` addition;
- #259 guarded duplicate `people.profile_photo_id` addition;
- #269 replaced current-row-mapper use against historical SavedView schema with historical/raw SQL;
- #270 replaced current Bookmark mapper/table assumptions in v2->v3 normalization with historical DDL/raw reads.

Canonical Relation bootstrap regressions replay old migration boundaries; Refactor must not redesign Relation storage while maintaining them.

### AppDatabase responsibility reduction — complete slices
Merged responsibility-moving slices:
- **#281 `BookmarkReadStore`** — removed `AppDatabase.watchBookmarkItems()`;
- **#282 `ProfilePathResolver`** — removed AppDatabase profile-path conversion methods;
- **#283 `SavedViewReadStore`** — removed `AppDatabase.watchSavedViewConfigs()` / saved-view tag aggregation;
- **#289 `PhotoReadStore`** — removed `AppDatabase.watchAllPhotos()` and duplicate path reconstruction.

Continue shrinking AppDatabase only when a slice removes a real responsibility; do not add wrapper-only indirection.

### Legacy Bookmark visual / URL duplication
All four direct Bookmark visual duplicates from the original inventory route through canonical `BookmarkVisualImage`:
- lifecycle rows — Object #296;
- Notion card — Refactor #294;
- reverse lookup — Refactor #299;
- Stage1 List/Table — Refactor #324.

Canonical Bookmark -> Weblink URL presentation is also live in:
- lifecycle — #317;
- reverse lookup — #320;
- Notion bookmark card — #322.

Legacy `bookmarks.url` and thumbnail fields remain compatibility/import/export data until all production dependencies and migration requirements have proven replacements.

### GenericDatabasePage P1 / composition decomposition
Merged focused slices:
- **#310** — read/projection loading, all-ObjectType aggregation, create-mode resolution and computed evaluation -> `GenericDatabasePageStateLoader`;
- **#323** — low-level Store/Service graph construction -> `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Current source is about 74 KB. The next high-value responsibilities remain:
- schema/database actions behind an application service/facade;
- Property creation/edit dialog workflow extraction;
- layout-specific host extraction where it removes real responsibility/LOC.

The Property creation workflow is a concrete high-value next candidate, but **do not reconstruct the whole file** to perform it. Wait for a safe patch-sized editing path or a sequenced local change.

## Cross-lane coordination
### Object lane
Object owns #155/#56 daily-use parity. Recent relevant Object work is merged:
- #317/#320/#322 canonical URL adoption;
- #333/#334 generic Gallery managed-media follow-ons.

Before touching `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart` or `app_shell.dart`, re-check actual open PR ownership; do not trust stale handoff PR numbers.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Refactor must preserve canonical Relation APIs and must not create alternate serialized-id/index/repair paths.

## Exact next actions
1. **Finish #336**: if the bounded-pump/unmount test lifecycle fix returns full green, merge. If Test still stalls/fails, inspect only the focused Widget regression before changing production semantics.
2. **Finish #340**: merge only after full Analyze/Test green. This PR authorizes diagnostic sanitization only, not ProfileManager recovery behavior changes.
3. **Finalize repository handoff docs** (`AI_PROGRESS_REFACTOR.md`, `AI_PROGRESS.md`, `LEGACY_BOOKMARK_INVENTORY.md`, `ERROR_POLICY_AUDIT.md`) on `docs/refactor-handoff-20260906` after #336/#340 settle.
4. **Continue raw user-visible error cleanup** in a small independently testable host. Current candidates include Image editor, Photo management, Bookmark detail, Object inspector, AppShell, Tag management, Stage1 compatibility URL-add and GenericDatabasePage. Prefer the smallest deterministic boundary first.
5. **Continue GenericDatabasePage P1 decomposition** only through a safe patch-sized responsibility move. Property create/edit workflow is high value; avoid a monolithic controller rewrite or whole-file reconstruction.
6. **Keep ProfileManager recovery policy deferred**. Corrupt registry fallback can affect data-location selection; changing fallback selection/persistence requires explicit product/data-recovery policy.
7. Re-run `tool/maintainability_report.sh` when a runtime with repository/network access is available after another meaningful hotspot slice; record actual file/LOC movement.

## Validation expectations
For responsibility-moving refactors:
- preserve ordering/path/public behavior;
- add focused regression coverage when practical;
- run `flutter analyze` and full tests before merge;
- verify old production callers are gone before deleting the old responsibility.

For migration work:
- historical regression must pass;
- schema version/order/defaults remain unchanged unless a regression proves the old implementation was broken.

For failure-policy work:
- fail-soft/user-visible behavior remains unchanged unless a separate product issue says otherwise;
- avoid logging raw user content, paths, URLs, JSON, bytes, credentials or secrets;
- do not attach exception text when it may contain persisted/request user data;
- test an actual failure/retry boundary where possible; use source guards only for native/platform boundaries that are not reliably injectable.

## Risks / blockers
- parallel lanes move `main` quickly; refresh intended small diffs instead of force-merging stale branches;
- legacy Bookmark storage/UI cannot be deleted until Object-first read/write/presentation parity is proven;
- large shared hosts should not be reconstructed wholesale to make a small edit;
- abstraction that adds wrappers without deleting responsibility/duplication should be rejected;
- ProfileManager fallback/recovery behavior is a data-safety decision even though its debug output can be sanitized independently;
- test-only lifecycle/hang failures must not be fixed by changing production behavior or merely increasing global timeouts;
- GitHub code search can lag fresh merges; verify branch/main files directly before acting on search hits.

## Current validation / stop state
- v2-v16 migration extraction: complete and merged;
- AppDatabase read/path responsibility slices #281/#282/#283/#289: merged;
- direct Bookmark visual duplication #294/#299/Object #296/#324: complete;
- GenericDatabasePage state-loader #310 and composition-root #323: merged after green Analyze/Test;
- failure/privacy #321/#325–#332/#335/#337/#338: merged after relevant green validation;
- #336: Analyze green; latest Test run in progress after test-lifecycle-only correction;
- #340: open, focused diff confirmed, full CI in progress;
- Object #322/#333/#334: merged.

Refactor work remains actionable. Continue through safe stable-error slices and measured responsibility extraction; do not stop merely because one PR finishes or CI is pending.
