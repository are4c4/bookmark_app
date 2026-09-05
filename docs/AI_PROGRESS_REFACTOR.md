# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics and Relation owns canonical Relation semantics; this lane deletes duplication, narrows responsibilities, improves failure observability, and decomposes hotspots only after checking parallel PR ownership.

## Current checkpoint
Latest merged Refactor architecture slice:
- **#310 `Extract GenericDatabasePage read projection state loader`** — merged as `4c4a3c09059f6e763ef7353ec2bf2eee7b4e6eda`.

#310 adds `GenericDatabasePageStateLoader` and moves the following out of `GenericDatabasePage._reload()` without changing mutation/UI semantics:
- Database/collection snapshot loading;
- all-ObjectType record aggregation;
- create-mode resolution;
- formula/rollup evaluation and existing fail-soft `null` projection.

The Widget now consumes one immutable state snapshot. Focused regression `test/generic_database_page_state_loader_test.dart` covers page/record aggregation, related records, computed values, create-mode resolution and malformed-formula fallback. Full Analyze/Test was green before merge.

### Active Refactor PR
- **#304 `Route Stage1 list and table visuals through canonical resolver`** — `BookmarkUnifiedStage1Page` List/Table direct cover/thumbnail helper is replaced with `BookmarkVisualImage`, preserving List `60x44` and Table `58x38` geometry.
- Production diff is small; the current blocker is the newly added full-page widget regression leaving a `flutter_tester` worker alive under the full suite. Analyze passes and hundreds of unrelated tests pass, but the CI Test step reaches its 12-minute action timeout. `pumpAndSettle()` was already removed; latest branch work explicitly unmounts the Stage1 widget before closing the in-memory database. Do not change production behavior to solve this test-only lifecycle problem.

## Completed checkpoints
### P0 guardrails / architecture
Merged through #228:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance;
- dedicated Refactor handoff.

New Object/Database/View code must not deepen `BookmarkItem` / legacy-table coupling unless it is an explicit compatibility or migration boundary.

### Failure-policy / observability
Behavior-preserving merged slices include:
- #227 optional PDF author enrichment diagnostics;
- #229 profile state / backup metadata fallback diagnostics;
- #234 corrupt Database View JSON fail-soft diagnostics;
- #237 remote image geometry decode diagnostics;
- #274 PDF metadata filename fallback diagnostics without path/content logging;
- #279 Bookmark metadata fallback diagnostics without URL/response/exception-text logging.

Intentional fail-soft product behavior must not be converted into user-visible failure merely to remove a broad catch.

### AppDatabase migration extraction — complete
All historical migration bodies **v2 through v16** now live behind migration helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical bodies.

Historical fixtures cover real schemaVersion checkpoints down to v1 and exposed installed-user defects that were fixed before extraction:
- #257 guarded duplicate `photos.tags` addition;
- #259 guarded duplicate `people.profile_photo_id` addition;
- #269 replaced current-row-mapper use against historical SavedView schema with historical/raw SQL;
- #270 replaced current Bookmark mapper/table assumptions in v2->v3 normalization with historical DDL/raw reads.

Canonical Relation bootstrap regressions also replay old migration boundaries; Refactor must not redesign Relation storage while maintaining them.

### AppDatabase responsibility reduction — complete slices
Merged responsibility-moving slices:
- **#281 `BookmarkReadStore`** — removed `AppDatabase.watchBookmarkItems()` and moved screen-ready Bookmark aggregation behind a dedicated read store; BookmarkRepository/ObjectSync use it.
- **#282 `ProfilePathResolver`** — removed AppDatabase profile-path conversion methods and centralized relative/absolute path semantics.
- **#283 `SavedViewReadStore`** — removed `AppDatabase.watchSavedViewConfigs()` and saved-view tag aggregation from the database root.
- **#289 `PhotoReadStore`** — removed `AppDatabase.watchAllPhotos()` and centralized Photo path resolution, including the duplicate BookmarkReadStore resolver path.

Continue shrinking AppDatabase only when a slice removes a real responsibility; do not add wrapper-only indirection.

### Legacy Bookmark visual duplication
Canonical `BookmarkVisualImage` migration is now merged for:
- lifecycle Bookmark rows — Object #296;
- Notion card — Refactor #294;
- reverse lookup dialog — Refactor #299, including Tag/Photo/People host wiring.

The last duplicate identified in the original inventory is the Stage1 List/Table helper in active #304. Whole legacy hosts are not automatically deletable; only the duplicated presentation slices are superseded until Object-first product parity is complete.

### GenericDatabasePage P1 decomposition
The broad #223 ownership blocker is gone. P1 decomposition has started as small behavior-preserving slices:
- #310 moves read/projection state loading out of the Widget.

Keep following the same pattern: focused regression first/with the move, patch-sized host diff, no monolithic rewrite, and no Object/Relation semantic changes.

## Cross-lane coordination
### Object lane
Current Object work is #155/#56 daily-use parity. Recent main includes canonical Weblink URL creation, managed Image import/media, richer Weblink/Image defaults, site metadata, clickable shared URL properties, and Object-first visual replacements. Open Object PR #312 moves Bookmark lifecycle URL presentation/opening toward canonical Weblink URL resolution; it explicitly avoids Stage1 while #304 owns that host.

Before touching `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart` or `app_shell.dart`, re-check open PR ownership. GenericDatabasePage is now a sequenced shared hotspot: Refactor may decompose it, but Object product changes there should remain patch-sized and coordinated.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Latest focused Relation composition coverage includes #307 for direct Weblink enrichment -> Representative Image Relation. Refactor must preserve canonical Relation APIs and must not create alternate serialized-id/index paths.

## Exact next actions
1. Finish #304 by proving the focused Stage1 visual regression exits cleanly; latest attempt explicitly unmounts the Widget before database close. If the test still hangs, replace the heavyweight regression with a smaller deterministic host seam rather than raising CI timeouts or changing production semantics.
2. Once #304 is green, normalize its two intended files onto latest `main`, rerun fresh CI, and merge.
3. Re-run production searches for direct Bookmark `coverPhoto` / `thumbnail` rendering. Delete only genuinely superseded presentation logic; do not remove compatibility storage prematurely.
4. Continue `GenericDatabasePage` P1 decomposition. The next candidate should remove a coherent responsibility from the Widget (for example composition/mutation-flow construction using existing services) and must be coordinated against active Object PRs.
5. Re-run `tool/maintainability_report.sh` after another meaningful hotspot slice and record actual file/LOC reduction.
6. Continue failure-policy work only where a truly silent broad catch remains and behavior-preserving diagnostics/tests add value.
7. Keep `docs/LEGACY_BOOKMARK_INVENTORY.md` and repository-wide `docs/AI_PROGRESS.md` synchronized when sequencing/ownership materially changes.

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
- avoid logging raw user content, paths, URLs, bytes, credentials or secrets.

## Risks / blockers
- parallel lanes move `main` quickly; rebuild intended small diffs on latest main instead of force-merging stale branches.
- legacy Bookmark storage/UI cannot be deleted until Object-first read/write/presentation parity is proven.
- #304 currently has a **test lifecycle/hang blocker**, not a known production failure.
- large shared hosts should not be reconstructed wholesale to make a small edit.
- abstraction that adds wrappers without deleting responsibility/duplication should be rejected.

## Current validation / stop state
- v2-v16 migration extraction: complete and merged.
- AppDatabase read/path responsibility slices #281/#282/#283/#289: merged with focused regressions.
- visual consolidation #294/#299 and Object #296: merged.
- GenericDatabasePage state-loader #310: full Analyze/Test green and merged.
- #304: Analyze green; full-suite Test currently blocked by a hanging focused widget-test worker. Latest branch change explicitly disposes the Stage1 host before closing DB and requires fresh CI.

Refactor work remains actionable; do not stop on #304 CI alone because GenericDatabasePage decomposition and documentation/inventory maintenance remain safe independent work.
