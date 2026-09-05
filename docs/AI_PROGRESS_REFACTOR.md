# AI Progress — Refactor lane

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving behavior.

Primary lane: **Refactor**. This lane coordinates with the Object lane and must avoid broad edits to files owned by active Object PRs. Relation semantics are out of scope except for preserving canonical API usage.

## Active branch / PR
- `refactor/issue-225-migration-v13-regression` — PR #230, migration-safety regression coverage before v14 extraction.

## Checkpoints completed
- read `AGENTS.md`, #225, #56, `docs/AI_PROGRESS.md`, `docs/architecture.md`, recent commits, open PRs and Actions state;
- confirmed Object PR #223 directly owns `generic_database_page.dart`, so broad GenericDatabasePage extraction remains deferred;
- P0 guardrails/inventory/audit were rebuilt on latest main and merged through PR #228 (`310ec2c5e11edbf97a7f56e13c32120c6cbb51c0`):
  - `tool/maintainability_report.sh` for non-blocking Dart LOC / largest-file reporting;
  - `docs/MAINTAINABILITY.md` with no-new-legacy-dependency policy, hotspot baseline and progress metrics;
  - presentation/application/legacy dependency boundaries in `docs/architecture.md`;
  - `docs/LEGACY_BOOKMARK_INVENTORY.md` classifying production Bookmark-era consumers;
  - `docs/ERROR_POLICY_AUDIT.md` classifying broad catch/fallback behavior;
- PR #227 replaced the empty PDF-author-enrichment catch in `GlobalFileDropLayer` with behavior-preserving debug visibility; Analyze/Test passed and it merged as `20ba50674823190337561c7a97ac16e928b4b009`;
- PR #229 made persisted profile-state and imported-profile-metadata fallbacks observable in debug/assert builds while preserving fail-soft behavior; Analyze/Test passed and it merged as `3bf2d895175bcd53381a0feb285b7743d12edd58`;
- inspected `AppDatabase` migration wiring: v2–v14 remain inline in `app_database.dart`, while v15/v16 are already extracted into `app_database_migrations.dart`;
- confirmed from Git history that `schemaVersion => 14` was the live pre-v15 state before the generic-table promotion;
- opened PR #230 with a focused in-memory v13 -> current migration regression. It preserves a seeded `saved_views` row, verifies the v14 columns/defaults, and checks the already-extracted v15/v16 tables are installed before any v14 body is moved.

## Coordination state
Open Object work includes #221 and #223; #223 directly owns `generic_database_page.dart`. Do not perform a broad rewrite of that file until the Object Gallery stack is merged/rebased and the file is free of active ownership. Re-check `app_shell.dart` and `object_inspector_page.dart` immediately before any non-trivial edit.

Legacy visual cleanup also needs sequencing: `NotionBookmarkCard` currently receives no `BookmarkRepository`, so canonical `BookmarkVisualImage` adoption would require a caller change in the large Stage1 host. `showBookmarkReverseLookupDialog` likewise receives only a Bookmark stream, so canonical visual resolution would touch tag/photo/people management callers. Prefer focused patch-level edits when ownership is clear.

## Validation
- PR #227: full Flutter Analyze/Test success.
- PR #229: CI run `33942454104`, full Flutter Analyze/Test success.
- PR #230: CI run `33942611697` is currently in progress. Its production diff is zero; only `test/app_database_migration_v13_test.dart` plus this handoff are changed.
- Drift 2.34 native API documentation confirms `NativeDatabase.memory(setup: ...)` is a supported way to seed an in-memory database before Drift opens it; dedicated Drift migration guidance recommends regression coverage before changing migration code.

## AppDatabase inspection
`AppDatabase.migration` still contains historical v2–v14 bodies inline. Versions v3/v4/v10/v11 transform existing rows and are higher risk. The first extraction target is v14 because PR #230 directly protects that boundary and the v14 body only adds three `saved_views` columns. Preserve statement order and exact semantics; do not rewrite the migration for style.

## Exact next actions
1. Let PR #230 finish CI. If green, merge it and branch the v14 extraction from latest main.
2. Extract only the `from < 14` body into `migrateToV14(Migrator)` in `app_database_migrations.dart`; keep `AppDatabase.migration` as `if (from < 14) await migrateToV14(m);` and make no other migration edits.
3. Run the focused v13 migration regression plus full Analyze/Test; merge only when green.
4. Repeat the test-before-extraction pattern for the next low-risk historical boundary. Leave v3/v4/v10/v11 until their data-transform semantics have dedicated fixtures.
5. Re-check Object PR ownership before any legacy visual migration or edits to the named hotspot files.
6. Re-run production `BookmarkItem` / `BookmarkRepository` searches after Object-lane merges and track references removed, not adapters added.

## Risks / blockers
- `generic_database_page.dart` remains an active cross-lane conflict because #223 owns it.
- Legacy Bookmark storage must not be deleted before old production hosts have read/write parity.
- Historical migration semantics must not change during extraction.
- Large Stage1/management hosts should not be whole-file reconstructed solely to replace a small visual slice.

## Stop reason
Current next implementation step (v14 migration extraction) is intentionally gated on PR #230's historical migration regression passing. The remaining presentation cleanup is concurrently blocked by Object-lane ownership of the relevant large hosts. No destructive or speculative migration change should be made before that regression result.
