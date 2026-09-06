# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics; this lane deletes duplication, narrows responsibilities, improves failure observability/privacy, and decomposes hotspots only after checking parallel PR ownership.

## Current checkpoint
The previous Stage1 blocker is resolved. The latest sustained Refactor sequence has now merged:

- **#323 `Centralize GenericDatabasePage dependency composition`** — `GenericDatabasePageServices.fromWorkspaceStore(...)` owns the low-level Object/Database/View Store/Service graph used by the page. The Widget no longer reaches through `BookmarkRepository` to `AppDatabase` to construct that graph, and no new Bookmark-layer dependency was added to the composition service.
- **#324 `Route Stage1 list and table visuals through canonical resolver`** — the final original direct Bookmark cover/thumbnail rendering duplicate now uses `BookmarkVisualImage`. List `60x44` and Table `58x38` geometry are preserved.
- **#325–#329 failure-policy/privacy slices** — malformed persisted UI/Object JSON and optional enrichment/evaluation failures retain their established fail-soft contracts while becoming debug-visible without logging raw user content or exception text.

The old heavyweight Stage1 full-page Widget regression was the cause of the ~12-minute Test step/hang. #324 replaced it with a deterministic architecture guard that checks canonical visual routing and geometry directly; fresh full CI returned to the normal ~3-minute Test range. This was a test-lifecycle problem, not a production behavior defect.

The handoff text above predates the latest open Refactor sequence. Current open Refactor PRs observed on 2026-09-06 are #336, #340, #342, #343 and #347. Object PR #346 owns the new shared Property-add popover and intentionally avoids the major shared hosts for now. Relation PR #345 is handoff-only.

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
Behavior-preserving merged slices include:
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
- #328 Database View malformed-JSON diagnostics no longer attach `FormatException`, avoiding persisted user JSON echo;
- #329 malformed generic Property config / Record value JSON remains `{}` / `null` respectively, with privacy-safe debug visibility and focused coverage.

Current open rollback/error-boundary slices:
- #336 attachment failure handling;
- #340 ProfileManager diagnostic privacy;
- #342 profile restore cleanup preserves the original restore failure;
- #343 managed Image import cleanup preserves the original canonical creation failure; CI run #1310 is green;
- #347 Board grouped-create rollback cleanup preserves the original preset failure even when deleting the newly-created Object also fails.

Intentional fail-soft product behavior must not be converted into user-visible failure merely to eliminate a broad catch. Debug diagnostics should use fixed messages plus stack traces and should not include raw names, URLs, paths, JSON, bytes, response bodies or exception text when those may echo user content.

Rollback policy is now explicit: secondary cleanup failure must not replace the primary operation failure unless a product/recovery contract explicitly requires otherwise.

### AppDatabase migration extraction — complete
All historical migration bodies **v2 through v16** live behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Historical fixtures cover real schemaVersion checkpoints down to v1 and exposed installed-user defects that were fixed before extraction:
- #257 guarded duplicate `photos.tags` addition;
- #259 guarded duplicate `people.profile_photo_id` addition;
- #269 replaced current-row-mapper use against historical SavedView schema with historical/raw SQL;
- #270 replaced current Bookmark mapper/table assumptions in v2->v3 normalization with historical DDL/raw reads.

Canonical Relation bootstrap regressions replay old migration boundaries; Refactor must not redesign Relation storage while maintaining them.

### AppDatabase responsibility reduction — complete slices
Merged responsibility-moving slices:
- **#281 `BookmarkReadStore`** — removed `AppDatabase.watchBookmarkItems()` and moved screen-ready Bookmark aggregation behind a dedicated read store;
- **#282 `ProfilePathResolver`** — removed AppDatabase profile-path conversion methods and centralized relative/absolute path semantics;
- **#283 `SavedViewReadStore`** — removed `AppDatabase.watchSavedViewConfigs()` and saved-view tag aggregation from the database root;
- **#289 `PhotoReadStore`** — removed `AppDatabase.watchAllPhotos()` and centralized Photo path resolution.

Continue shrinking AppDatabase only when a slice removes a real responsibility; do not add wrapper-only indirection.

### Legacy Bookmark visual duplication — original inventory complete
Canonical `BookmarkVisualImage` migration is merged for all four direct visual duplicates identified by the original inventory:
- lifecycle Bookmark rows — Object #296;
- Notion card — Refactor #294;
- reverse lookup dialog — Refactor #299;
- Stage1 List/Table helper — Refactor #324.

The latest `main` Stage1 source directly delegates `_image(...)` to `BookmarkVisualImage`; List/Table retain their old dimensions. Whole Bookmark hosts are **not** automatically deletable: only the duplicated visual-resolution logic is retired. `BookmarkVisualImage` and `BookmarkVisualResolver` intentionally retain legacy thumbnail fallback while compatibility hosts remain.

### GenericDatabasePage P1 / composition decomposition
Merged focused slices:
- **#310** moves read/projection loading, all-ObjectType record aggregation, create-mode resolution and computed evaluation out of `_reload()` into `GenericDatabasePageStateLoader`;
- **#323** moves low-level Store/Service graph construction out of the Widget into `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Keep following the same pattern: focused regression first/with the move, patch-sized host diff, no monolithic controller rewrite, and no Object/Relation semantic changes.

The next high-value candidates from Issue #225 remain:
- schema/database actions behind an application service/facade;
- Property creation/edit dialog workflow extraction, sequenced behind Object #346 where relevant;
- layout-specific host extraction where it actually removes responsibility/LOC.

Do **not** reconstruct the 70+ KB `generic_database_page.dart` wholesale merely because the current connector lacks a safe patch-write primitive. Wait for a safe patch-sized edit path or a sequenced change where the exact file can be changed without hand-rebuilding unrelated content.

## Cross-lane coordination
### Object lane
Current Object work is #56/#155/#252 daily-use parity and host-by-host canonical replacement.

Latest observed state:
- canonical Bookmark opening-mode work has landed on main;
- **#346 open** — shared anchored `PropertyAddPopover` foundation for #252, intentionally not yet integrating `GenericDatabasePage`, `ObjectInspectorPage`, or Bookmark detail;
- avoid overlapping broad edits to those shared hosts until Object integration ownership is clear.

Legacy `bookmarks.url` remains compatibility/import/export data. Do not delete it merely because several presentation hosts now prefer canonical Weblink URL state.

Before touching `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart` or `app_shell.dart`, re-check open PR ownership.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. #345 is a handoff-only audit confirming no new independent Relation implementation is currently required. Refactor must preserve canonical Relation APIs and must not create alternate serialized-id/index/repair paths.

## Exact next actions
1. **Let #347 validate in CI**; if green, it is a focused rollback-policy improvement and does not overlap shared UI hotspots.
2. **Do not overlap #346** in Property-add/shared detail hosts. GenericDatabasePage P1 work should choose a non-overlapping responsibility or wait for Object integration sequencing.
3. **Continue rollback/error-boundary audit** only where a real masking/privacy bug exists; do not add logging to normal file-existence/compatibility fallbacks just to reduce catch counts.
4. **Keep ProfileManager recovery policy deferred**. #340 may sanitize diagnostics, but corrupt-registry fallback behavior itself still requires an explicit data-recovery/product policy.
5. **Follow Object-first legacy retirement** and narrow legacy URL/Photo reads only after canonical replacement is proven for each live host.
6. Re-run `tool/maintainability_report.sh` after another meaningful hotspot slice in an environment with repository execution access; record actual LOC/responsibility movement rather than adapter count.
7. Once current failure-policy PRs settle, prefer the next measurable responsibility extraction over another wrapper-only abstraction.

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
- cleanup/rollback failure must not mask the primary operation failure.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild intended small diffs on latest main instead of force-merging stale branches;
- legacy Bookmark storage/UI cannot be deleted until Object-first read/write/presentation parity is proven;
- large shared hosts should not be reconstructed wholesale to make a small edit;
- abstraction that adds wrappers without deleting responsibility/duplication should be rejected;
- ProfileManager fallback/recovery behavior is a data-safety decision, not a silent-catch cleanup;
- Object #346 owns the current shared Property-add foundation, so overlapping host integrations must be sequenced;
- local/container git may not have reliable GitHub access, so CI remains the authoritative full Analyze/Test validation for connector-authored branches.

## Current validation / stop state
- v2-v16 migration extraction: complete and merged;
- AppDatabase read/path responsibility slices #281/#282/#283/#289: merged;
- original direct Bookmark visual duplication #294/#299/Object #296/#324: complete;
- GenericDatabasePage state-loader #310 and composition-root #323: full Analyze/Test green and merged;
- failure/privacy #321/#325/#326/#327/#328/#329: full Analyze/Test green and merged;
- #343 CI run #1310: success;
- #347 created from latest observed main with production rollback hardening + focused integration regression; CI pending at this handoff.

Refactor work remains actionable. The current run stopped after opening #347 and updating the audit/handoff because the next larger hotspot work would risk overlapping Object #346 or require a broader shared-host edit; pending CI alone is not a blocker for future independent safe work.
