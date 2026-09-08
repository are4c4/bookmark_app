# AI Progress — Refactor & Architecture Health Lane

> Durable Lane G handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Reduce maintenance hotspots and duplicate/caller-zero legacy paths while preserving product behavior. Own architecture guardrails, CI/developer-loop health, repository-wide handoff alignment and small responsibility extraction/deletion. Do not hide product redesign inside refactor work.

## Current architecture responsibility
#1048 established the Object-first product constitution. Lane G owns making repository instructions/handoffs consistent with it so future agents do not follow superseded Bookmark-centric or Tag-as-native-primitive routing.

Durable product implications for G:
- `Bookmark` is legacy compatibility/migration input, not a final ObjectType;
- Person is a generic ObjectType; dedicated People runtime/UI becomes removable only after owning-lane parity;
- Tag/TagGroup are generic ObjectTypes; no native-primitive routing for Tag;
- Weblink/Image/File are Objects with native capabilities;
- legacy UI/API/code deletion follows replacement parity + caller-zero proof;
- destructive schema/data retirement is a separate preservation-proven migration, not routine refactor work.

## Active focused issues

### #1048 — architecture/handoff synchronization
`docs/product_architecture.md` is already integrated through #1051. Remaining work is to align `AGENTS.md`, repository/lane handoffs and stale umbrella routing with the constitution, then close #1048 when acceptance is fully satisfied.

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
- merge-group support;
- AI PR lane/Issue/dependency/hotspot contract;
- hotspot overlap/stale-base/churn diagnostics;
- duplicate focused-Issue ownership warning;
- migration single-writer lease audit;
- durable handoff audit.

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

G deletes superseded implementation only after the owning product/integrity lane proves replacement parity.

## Repository settings risk
`main` is currently unprotected; #980 tracks enabling required branch protection/`merge-gate`. The connected GitHub App may not have administration access to apply those settings. This is a repository-settings risk, not a reason to weaken CI in code.

## Validation
Behavior-preserving refactors still require changed-Dart format, Analyze and relevant/full Flutter Test. Docs-only architecture synchronization should use the docs-only CI path plus handoff/coordination audits.

## Resume sequence
1. complete #1048 durable docs/Issue alignment and close it only after acceptance is verified;
2. re-audit live open PR/hotspot ownership;
3. continue #1047/#225/#950 only through small focused slices;
4. when #1039/#1040 owning-lane parity lands, create caller-zero retirement slices instead of combining product migration with cleanup;
5. keep destructive schema/data removal separate and preservation-gated.