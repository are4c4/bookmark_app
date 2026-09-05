# AI Progress — Refactor lane

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving behavior.

Primary lane: **Refactor**. This lane coordinates with the Object lane and must avoid broad edits to files owned by active Object PRs. Relation semantics are out of scope except for preserving canonical API usage.

## Active branch
`refactor/issue-225-p0-guardrails`

## Checkpoints completed in this run
- confirmed latest `main` at `fca093ce50871a6bb57662e8534bcb807844ebca` before branching;
- read `AGENTS.md`, #225, #56, `docs/AI_PROGRESS.md`, `docs/architecture.md`, recent commits, open PRs and Actions state;
- confirmed open Object PR #223 changes `generic_database_page.dart`, so large GenericDatabasePage extraction is deferred;
- added `tool/maintainability_report.sh` to report `lib/` / `test/` Dart LOC and the largest Dart files without failing existing debt;
- added `docs/MAINTAINABILITY.md` with no-new-legacy-dependency policy, hotspot baseline and refactor metrics;
- clarified presentation/application/legacy dependency boundaries in `docs/architecture.md`.

## Coordination state
Open PRs observed at branch start:
- #221 — managed Weblink media geometry widget;
- #223 — real masonry Gallery integration; directly touches `generic_database_page.dart`;
- #224 — CI test time budget.

Do not perform a broad rewrite of `generic_database_page.dart` until the Object-lane Gallery stack is merged/rebased and the file is free of active ownership. Check `app_shell.dart` and `object_inspector_page.dart` again immediately before any non-trivial edit.

## Validation
This slice changes documentation and adds a read-only shell report. No application behavior or schema semantics changed. The report is intentionally non-blocking and uses POSIX/macOS-available shell tools plus Bash.

Remote CI should still be checked on the PR. If CI is pending, continue with independent inventory work rather than waiting idly.

## Exact next actions
1. Complete a production inventory of `BookmarkItem` / `BookmarkRepository` consumers and classify each as canonical product behavior, compatibility bridge, migration-only, or superseded duplicate.
2. Prioritize direct legacy visual renderers (`NotionBookmarkCard`, reverse-lookup rendering, remaining Stage1 image helpers) for deletion/migration only after checking Object-lane overlap.
3. Inspect `AppDatabase` v2–v14 migration bodies and existing v15/v16 extraction/tests; choose the smallest semantics-preserving extraction slice.
4. Audit broad `catch (_) {}` / broad catches and classify intentional best-effort vs silent regression hiding.
5. Update this file and `docs/AI_PROGRESS.md` before the run ends.

## Risks / blockers
- `generic_database_page.dart` is currently an unavoidable cross-lane conflict because #223 owns it. Defer its large split.
- Legacy Bookmark storage must not be deleted before old production hosts have read/write parity.
- Historical migration semantics must not change during extraction.

## Stop reason
Not stopped; safe independent refactor work remains after the P0 guardrail slice.
