# AI Progress — Refactor lane

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving behavior.

Primary lane: **Refactor**. This lane coordinates with the Object lane and must avoid broad edits to files owned by active Object PRs. Relation semantics are out of scope except for preserving canonical API usage.

## Active branch / PR
- `refactor/issue-225-p0-guardrails-v2` — PR #228, rebuilt directly on current `main` after #226 conflicted with newer repository handoff edits.

## Checkpoints completed
- read `AGENTS.md`, #225, #56, `docs/AI_PROGRESS.md`, `docs/architecture.md`, recent commits, open PRs and Actions state;
- confirmed Object PR #223 directly owns `generic_database_page.dart`, so broad GenericDatabasePage extraction remains deferred;
- added `tool/maintainability_report.sh` for non-blocking Dart LOC / largest-file reporting;
- added `docs/MAINTAINABILITY.md` with no-new-legacy-dependency policy, hotspot baseline and progress metrics;
- clarified presentation/application/legacy dependency boundaries in `docs/architecture.md`;
- added `docs/LEGACY_BOOKMARK_INVENTORY.md` and classified production `BookmarkItem` / `BookmarkRepository` consumers;
- identified direct legacy visual-resolution duplication in `NotionBookmarkCard`, reverse-lookup thumbnails and remaining Stage1 image helpers; whole live hosts are not marked superseded;
- added `docs/ERROR_POLICY_AUDIT.md`, separating fallback-contract, best-effort enrichment, rollback/fail-closed and user-visible catch policies;
- replaced the empty PDF-author-enrichment `catch (_) {}` in `GlobalFileDropLayer` with behavior-preserving debug/assert visibility and stack trace;
- PR #227 passed full Flutter Analyze/Test CI and was squash-merged to `main` as `20ba50674823190337561c7a97ac16e928b4b009`;
- PR #226 was closed unmerged after main advanced and created a documentation conflict; its guardrail content was rebuilt on latest main as PR #228 without overwriting newer Relation/repository handoffs;
- inspected `AppDatabase` migration wiring: v2–v14 remain inline in `app_database.dart`, while v15/v16 are already extracted into `app_database_migrations.dart`.

## Coordination state
Open Object work includes #221 and #223; #223 directly owns `generic_database_page.dart`. Do not perform a broad rewrite of that file until the Object Gallery stack is merged/rebased and the file is free of active ownership. Re-check `app_shell.dart` and `object_inspector_page.dart` immediately before any non-trivial edit.

Legacy visual cleanup also needs sequencing: `NotionBookmarkCard` currently receives no `BookmarkRepository`, so canonical `BookmarkVisualImage` adoption would require a caller change in the large Stage1 host. `showBookmarkReverseLookupDialog` likewise receives only a Bookmark stream, so canonical visual resolution would touch tag/photo/people management callers. Prefer focused patch-level edits when ownership is clear.

## Validation
- PR #227 CI run `33941591849`: `analyze-test` completed successfully, including Flutter Analyze and full Test.
- PR #228 changes documentation plus a read-only shell report only; no application, schema, migration, or Relation semantics change.
- `tool/maintainability_report.sh` was syntax/smoke checked before the original PR and remains byte-identical in #228.

## AppDatabase inspection
`AppDatabase.migration` still contains historical v2–v14 bodies inline. Versions v3/v4/v10/v11 transform existing rows and are higher risk. Extraction must preserve statement order and helper semantics exactly. No migration body has been moved yet; establish focused historical migration regression coverage first, then move one versioned block at a time into `app_database_migrations.dart` without stylistic rewrites.

## Exact next actions
1. Integrate PR #228 when merge state permits; it is rebuilt on current main and intentionally leaves `docs/AI_PROGRESS.md` untouched to avoid cross-lane overwrite.
2. Add focused historical migration regression coverage for the smallest supported checkpoint, then extract one low-risk v2–v14 migration slice.
3. Continue broad-catch audit with `profile_manager.dart` and other higher-risk fallback boundaries, preserving intentional best-effort behavior.
4. Re-check open Object PR ownership and migrate the smallest direct legacy visual renderer to `BookmarkVisualImage` when it can be done without reconstructing Stage1 or management hotspots.
5. Re-run production `BookmarkItem` / `BookmarkRepository` searches after Object-lane merges and track references removed, not adapters added.

## Risks / blockers
- `generic_database_page.dart` remains an active cross-lane conflict because #223 owns it.
- Legacy Bookmark storage must not be deleted before old production hosts have read/write parity.
- Historical migration semantics must not change during extraction.
- Large Stage1/management hosts should not be whole-file reconstructed solely to replace a small visual slice.

## Stop reason
Not stopped: safe independent refactor work remains. Continue with migration regression coverage and failure-policy cleanup while Object-owned presentation hotspots are busy.
