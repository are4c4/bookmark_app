# AI Progress — Refactor & Architecture Health Lane

> Durable Lane G handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Reduce maintenance hotspots and duplicate/caller-zero legacy paths while preserving product behavior. Own architecture guardrails, CI/developer-loop health, repository-wide handoff alignment and small responsibility extraction/deletion. Do not hide product redesign inside refactor work.

## Current architecture responsibility
#1048 established the Object-first product constitution and its durable handoff alignment is complete. Lane G owns keeping repository instructions/handoffs consistent with that constitution so future agents do not follow superseded Bookmark-centric or Tag-as-native-primitive routing.

Durable product implications for G:
- `Bookmark` is legacy compatibility/migration input, not a final ObjectType;
- Person is a generic ObjectType; dedicated People runtime/UI becomes removable only after owning-lane parity;
- Tag/TagGroup are generic ObjectTypes; no native-primitive routing for Tag;
- Weblink/Image/File are Objects with native capabilities;
- legacy UI/API/code deletion follows replacement parity + caller-zero proof;
- destructive schema/data retirement is a separate preservation-proven migration, not routine refactor work.

## Active focused issues

### #1074 — classify remaining historical branches before further cleanup
#1072 completed the proven-merged historical cleanup: 840 old branch refs were deleted after dry-run and full green CI, reducing the live inventory from 1,065 to 225 branches including `main`. GitHub native automatic merged-head deletion is enabled for future PRs.

The 224 non-main survivors must not be treated as active ownership merely because their refs exist. #1074 is a read-only classification slice that separates:
- current open-PR / Dependabot / recent / default-tip refs that should be retained;
- any newly provable merged-safe refs;
- exact heads of closed-unmerged PRs that may be reversible cleanup candidates;
- branches advanced after PR history and branches with no PR history, which retain unique/ambiguous work and must not be auto-deleted.

Do not broaden #1074 into deletion until the classification report provides concrete evidence and a separately justified destructive policy.

### #1047 — Generic Database gallery state-loader extraction
Behavior-preserving extraction: move Gallery cover-source discovery into the existing `GenericDatabasePageStateLoader` snapshot without changing Gallery semantics. `generic_database_page.dart` edits must remain patch-sized and re-audited against live ownership.

### #225 — architecture health umbrella
Continue measurable hotspot reduction, `AppDatabase` narrowing, explicit failure/privacy policy and CI/AI workflow guardrails through focused Issues/PRs. Prefer deletion or responsibility movement over another abstraction layer.

### #950 — Photo compatibility caller-zero cleanup
Continue only when current-main callers prove an API/path is dead. Preserve Photo schema/data, migration/import/export/backup and Vault preservation requirements.

Future G work after owning-lane parity:
- retire caller-zero Bookmark repositories/items/pages/bridges from #1039;
- retire caller-zero People-specific repositories/pages/bridges from #1040;
- ratchet maintainability ceilings as large hosts/dependencies genuinely disappear.

## Established guardrails that remain authoritative
- maintainability report/regression ceilings;
- no-new-legacy and presentation/database boundary checks;
- hunk-aware changed-Dart formatting;
- full Flutter Test sharding + exact Drift generated-code cache;
- test-health/flake artifacts;
- docs-only CI fast path and stable `merge-gate`;
- merge-group support for a future organization-owned Merge Queue-capable repository;
- AI PR lane/Issue/dependency/hotspot contract;
- hotspot overlap/stale-base/churn diagnostics;
- duplicate focused-Issue ownership warning;
- migration single-writer lease audit;
- durable handoff audit;
- immutable GitHub Actions SHA pin audit;
- weekly Dependabot updates for Dart/pub and GitHub Actions;
- historical proven-merged branch cleanup with exact merged-PR head recognition for squash merges.

Do not relax a guardrail or create no-op commits to make unrelated work easier to merge.

## Caller-zero proof standard
Code search alone is insufficient. A deletion slice should prove:
1. current-main production caller inventory;
2. wrapper/facade chain to real hosts;
3. replacement parity/compatibility ownership;
4. Analyze success to catch missed static callers;
5. relevant/full Flutter Test green;
6. no migration/import/export/backup/preservation dependency was accidentally treated as dead.

## Shared hotspots
High-risk hosts include `generic_database_page.dart`, `bookmark_unified_stage1_page.dart`, `object_inspector_page.dart`, `people_management_page.dart`, `app_shell.dart`, `tag_management_page.dart` and `app_database.dart`.

Recheck live PR ownership before broad edits. G should usually reduce a hotspot by small extraction/deletion rather than taking a broad rewrite lease. Schema/migration writer remains single-writer.

## Cross-lane boundaries
- **A:** Object/ObjectType/Body identity and migration semantics.
- **B:** Relation integrity and Tag hierarchy correctness.
- **C:** Database/View/schema/query UX and replacement daily-use surfaces.
- **D:** Weblink/Image/File native semantics/capture.
- **E:** Search/FTS semantics.
- **F:** Vault/filesystem/preservation semantics.
- **H:** repository-wide architecture/integration oversight; routes concrete implementation back to one owning lane.

G deletes superseded implementation only after the owning product/integrity lane proves replacement parity.

## Repository settings
`main` is protected by the active `Protect main` ruleset. The default branch requires PR-only squash merging, strict/up-to-date `merge-gate`, blocks force pushes and deletion, and has no bypass actors. #980 is completed.

Repository-level housekeeping is also enabled:
- automatic deletion of merged head branches is on;
- auto-merge is allowed, but each PR must still opt into it and all ruleset requirements remain authoritative.

The repository remains personal-account owned, so Merge Queue is not available. Existing `merge_group` workflow support remains ready for a future organization-owned repository.

## Validation
Behavior-preserving refactors still require changed-Dart format, Analyze and relevant/full Flutter Test. Workflow/guard changes must exercise their focused regressions and the full authoritative CI path. Docs-only architecture synchronization should use the docs-only CI path plus handoff/coordination audits.

## Resume sequence
1. finish #1074's read-only live classification and inspect its category counts/lists;
2. if the report proves a narrow reversible cleanup class, create a separate focused deletion slice instead of silently broadening #1074; otherwise retain ambiguous/unique branches;
3. re-audit live open PR/hotspot ownership;
4. continue #1047/#225/#950 only through small focused slices;
5. when #1039/#1040 owning-lane parity lands, create caller-zero retirement slices instead of combining product migration with cleanup;
6. keep destructive schema/data removal separate and preservation-gated.
