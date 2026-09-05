# AI Progress — Refactor lane

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving behavior.

Primary lane: **Refactor**. This lane coordinates with the Object lane and must avoid broad edits to files owned by active Object PRs. Relation semantics are out of scope except for preserving canonical API usage.

## Active branches / PRs
- `refactor/issue-225-p0-guardrails` — PR #226.
- `refactor/issue-225-file-drop-error-visibility` — PR #227.

## Checkpoints completed in this run
- confirmed latest `main` at `fca093ce50871a6bb57662e8534bcb807844ebca` before the first branch; main later advanced through repository-handoff refresh and merged #224 to `e10a04ff2fb8ed86b3f6eb278ec9abbe61e19df5`;
- read `AGENTS.md`, #225, #56, `docs/AI_PROGRESS.md`, `docs/architecture.md`, recent commits, open PRs and Actions state;
- confirmed Object PR #223 changes `generic_database_page.dart`, so broad GenericDatabasePage extraction is deferred;
- added `tool/maintainability_report.sh` to report `lib/` / `test/` Dart LOC and the largest Dart files without failing existing debt;
- added `docs/MAINTAINABILITY.md` with no-new-legacy-dependency policy, hotspot baseline and refactor metrics;
- clarified presentation/application/legacy dependency boundaries in `docs/architecture.md`;
- added `docs/LEGACY_BOOKMARK_INVENTORY.md`, classifying production `BookmarkItem` / `BookmarkRepository` consumers as canonical product behavior, compatibility bridge, migration-only, or superseded duplicate slices;
- identified direct legacy visual-resolution duplication in `NotionBookmarkCard`, reverse-lookup thumbnails and remaining Stage1 image helpers; whole live hosts are not marked superseded;
- added `docs/ERROR_POLICY_AUDIT.md`, separating fallback-contract, best-effort enrichment, rollback/fail-closed and user-visible catch policies;
- opened PR #226 for P0 guardrails/inventory/audit documentation;
- replaced the empty PDF-author-enrichment `catch (_) {}` in `GlobalFileDropLayer` with behavior-preserving debug/assert visibility and stack trace; opened PR #227;
- inspected `AppDatabase` migration wiring: v2–v14 remain inline in `app_database.dart`, while v15/v16 are already extracted into `app_database_migrations.dart`.

## Coordination state
Open Object work observed during this run includes #221 and #223; #223 directly owns `generic_database_page.dart`. #224 was merged into `main` during the run.

Do not perform a broad rewrite of `generic_database_page.dart` until the Object-lane Gallery stack is merged/rebased and the file is free of active ownership. Check `app_shell.dart` and `object_inspector_page.dart` again immediately before any non-trivial edit.

Legacy visual cleanup also needs sequencing: `NotionBookmarkCard` currently receives no `BookmarkRepository`, so canonical `BookmarkVisualImage` adoption would require a change in the large Stage1 caller. `showBookmarkReverseLookupDialog` likewise receives only a Bookmark stream, and adding the canonical resolver dependency would touch current tag/photo/people management callers. Prefer a focused patch when ownership is clear rather than reconstructing those large files.

## Validation
- P0 documentation/tooling changes do not change application or schema behavior.
- `tool/maintainability_report.sh` passed `bash -n` and a local smoke run against sample Dart files; output sorted LOC correctly.
- PR #227 changes one production file only (`+22/-1`) and preserves successful import behavior when optional PDF-author enrichment fails.
- PR #227 Flutter CI run `33941591849` was still in progress at the latest check; pending CI is not a stop condition.
- PR #226 is currently behind/diverged from newer `main` because main advanced while the branch was active; refresh/reconcile before integration rather than force-rewriting shared handoff content.

## AppDatabase inspection
`AppDatabase.migration` still contains historical v2–v14 bodies inline. The highest-risk slices are versions that transform existing rows (v3/v4/v10/v11), so extraction must preserve statement order and helper semantics exactly. No migration body was moved in this run because the current remote editing surface would require replacing the full ~37 KB file and no dedicated historical migration regression was found in the initial test search. A safe next implementation should establish/locate migration regression coverage first, then move one versioned block at a time to the existing migration part file without stylistic rewrites.

## Exact next actions
1. Refresh PR #226 from latest `main` without discarding newer repository handoff changes; merge after relevant checks/review state permit.
2. Check PR #227 CI; merge only after relevant checks pass, then record the integrated empty-catch cleanup.
3. Add focused historical migration regression coverage for the smallest supported checkpoint, then extract one v2–v14 migration slice into `app_database_migrations.dart` with byte-for-byte/statement-order semantics preserved.
4. Re-check open Object PR ownership and choose the smallest legacy visual renderer that can adopt `BookmarkVisualImage` without a broad Stage1/management-page rewrite.
5. Continue broad-catch audit with higher-risk `profile_manager.dart` fallback and repeated widget-level constraint parsing, preserving intentional best-effort behavior.
6. Re-run production `BookmarkItem` / `BookmarkRepository` searches after Object-lane merges and update the inventory by references removed, not adapters added.

## Risks / blockers
- `generic_database_page.dart` is currently an unavoidable cross-lane conflict because #223 owns it. Defer its large split.
- Legacy Bookmark storage must not be deleted before old production hosts have read/write parity.
- Historical migration semantics must not change during extraction.
- Large Stage1/management hosts should not be whole-file reconstructed solely to replace a small visual slice.

## Stop reason
The run reached the current execution/tool boundary after multiple independent checkpoints and two focused PRs. Remaining code slices are actionable, but the next migration/legacy-visual edits require safe patch-level changes to large/high-risk files or newly established migration regression coverage; forcing full-file replacements would violate the lane's small, behavior-preserving conflict-avoidance rules. CI pending is not the reason for stopping.
