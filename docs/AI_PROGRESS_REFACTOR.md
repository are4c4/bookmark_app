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

There is currently **no open Refactor PR** after #329. Object PR **#322** owns Notion-card canonical Weblink URL presentation and must be allowed to finish independently.

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

Intentional fail-soft product behavior must not be converted into user-visible failure merely to eliminate a broad catch. Debug diagnostics should use fixed messages plus stack traces and should not include raw names, URLs, paths, JSON, bytes, response bodies or exception text when those may echo user content.

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
- Property creation/edit dialog workflow extraction;
- layout-specific host extraction where it actually removes responsibility/LOC.

Do **not** reconstruct the 70+ KB `generic_database_page.dart` wholesale merely because the current connector lacks a safe patch-write primitive. Wait for a safe patch-sized edit path or a sequenced change where the exact file can be changed without hand-rebuilding unrelated content.

## Cross-lane coordination
### Object lane
Current Object work is #155/#56 daily-use parity and host-by-host canonical URL replacement.

Verified current URL migration state:
- **#317 merged** — Bookmark lifecycle display/open behavior prefers canonical Bookmark -> Weblink URL with legacy Bookmark URL fallback;
- **#320 merged** — reverse-lookup URL display/open behavior uses the same canonical resolver;
- **#322 open** — Notion bookmark cards are the current Object-owned URL presentation slice.

Legacy `bookmarks.url` remains compatibility/import/export data. Do not delete it merely because several presentation hosts now prefer canonical Weblink URL state.

Before touching `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart` or `app_shell.dart`, re-check open PR ownership.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Focused composition coverage includes #307 for direct Weblink enrichment -> Representative Image Relation. Refactor must preserve canonical Relation APIs and must not create alternate serialized-id/index/repair paths.

## Exact next actions
1. **Update/maintain the repository handoff docs** when #322 or later Object work changes legacy retirement sequencing.
2. **Continue GenericDatabasePage P1 decomposition** only through a safe patch-sized responsibility move. Prefer actual responsibility/LOC removal over alias-field or wrapper-only cleanup.
3. **Audit remaining user-visible raw exceptions**. `GlobalSearchPage` currently stores the caught Object and renders `message: '$_error'`; fix only with a focused testable error-state boundary rather than an untested cosmetic one-line replacement. Similar UI paths should move toward stable domain messages.
4. **Keep ProfileManager recovery policy deferred**. Corrupt profile registry metadata currently can fail soft to a default profile; changing that behavior requires an explicit data-recovery/product policy, not a routine behavior-preserving refactor.
5. **Follow Object-first URL parity host by host** (#317/#320 merged, #322 open) and narrow legacy URL reads only after the canonical replacement is proven for each live host.
6. Re-run `tool/maintainability_report.sh` when a runtime with repository/network access is available and after another meaningful hotspot slice; record actual file/LOC movement rather than adapter count.
7. Continue failure-policy work only where a truly silent/unsafe boundary remains; file-existence checks and deliberate compatibility fallbacks should not gain noisy logging just to reduce broad-catch counts.

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
- do not attach exception text when it may contain persisted/request user data.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild intended small diffs on latest main instead of force-merging stale branches;
- legacy Bookmark storage/UI cannot be deleted until Object-first read/write/presentation parity is proven;
- large shared hosts should not be reconstructed wholesale to make a small edit;
- abstraction that adds wrappers without deleting responsibility/duplication should be rejected;
- ProfileManager fallback/recovery behavior is a data-safety decision, not a silent-catch cleanup;
- local/container git currently cannot reach GitHub DNS, so maintainability report execution must use another environment rather than being guessed.

## Current validation / stop state
- v2-v16 migration extraction: complete and merged;
- AppDatabase read/path responsibility slices #281/#282/#283/#289: merged;
- original direct Bookmark visual duplication #294/#299/Object #296/#324: complete;
- GenericDatabasePage state-loader #310 and composition-root #323: full Analyze/Test green and merged;
- failure/privacy #321/#325/#326/#327/#328/#329: full Analyze/Test green and merged;
- Object #317/#320 canonical URL host slices are merged; #322 is the only currently open PR observed at this checkpoint.

Refactor work remains actionable. The next useful work is a safe, measurable hotspot responsibility extraction or a focused stable-error boundary—not another speculative abstraction layer.