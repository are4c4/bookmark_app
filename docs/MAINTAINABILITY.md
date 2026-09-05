# Maintainability guardrails

This document is the repository-level refactoring baseline for Issue #225. It is intentionally conservative: behavior-preserving consolidation is preferred over architecture rewrites.

## No-new-legacy-dependency rule

New Object / ObjectType / Database / View / Relation product work must not introduce new dependencies on Bookmark-era models or tables merely for convenience.

In particular, do not add a new production dependency on `BookmarkItem`, `BookmarkRepository`, `bookmarks.*` compatibility columns, or Bookmark-specific presentation when the operation can be expressed through the canonical Object/Database/View/Relation APIs.

An exception is allowed only when the dependency is explicitly one of these:

- a compatibility bridge required by a still-live Bookmark host;
- migration/import/export code that must understand historical storage;
- a staged replacement where the PR names the existing consumer being retired and does not create a second permanent path.

When an exception is necessary, keep it narrow and leave enough context in the PR or code comment to explain the retirement condition. Do not create new Relation serialization/index logic outside the canonical Relation subsystem.

## Refactor boundaries

- Preserve behavior unless an Issue explicitly owns a behavior change.
- Prefer deleting duplicate paths over adding adapters around both old and new paths.
- Do not move large folders simply to improve aesthetics.
- Do not rewrite historical migration semantics for style.
- Do not split a hotspot while another active PR owns the same large file; sequence the work instead.
- Treat `generic_database_page.dart`, `app_shell.dart`, and `object_inspector_page.dart` as coordination hotspots. Check open PRs before editing them.

## Hotspot baseline — 2026-09-05

Issue #225 recorded the following approximate source sizes before this refactor lane started:

| File | Approx. size | Refactor note |
| --- | ---: | --- |
| `lib/views/generic_database_page.dart` | 72 KB | Highest conflict risk; Object lane currently owns active Gallery work here. |
| `lib/views/bookmark_unified_stage1_page.dart` | 56 KB | Legacy Bookmark presentation hotspot. |
| `lib/views/people_management_page.dart` | 40 KB | Mixed management/presentation responsibilities. |
| `lib/data/app_database.dart` | 37 KB | Schema/migrations plus application aggregation. |
| `lib/views/app_shell.dart` | 34 KB | Composition/navigation hotspot. |
| `lib/views/object_inspector_page.dart` | 33 KB | Object presentation hotspot. |
| `lib/views/photo_management_page.dart` | 29 KB | Legacy/feature-specific presentation hotspot. |

These are a baseline, not hard limits. A refactor should reduce responsibility, duplicate production references, or source size rather than merely relocate the same complexity.

## LOC report

Run from the repository root:

```bash
bash tool/maintainability_report.sh
```

Use `--top N` to change the number of files shown. The report includes total Dart LOC under `lib/` and `test/` plus the largest Dart files by LOC.

The report is deliberately non-blocking at first. Existing debt should not make unrelated PRs fail. Once the baseline has stabilized, CI may add regression-only thresholds that tolerate current hotspots but reject major new growth.

## Progress measures

For Issue #225, prefer these measures over abstraction count:

1. production `BookmarkItem` / `BookmarkRepository` references removed;
2. duplicate presentation/read paths deleted;
3. `AppDatabase` responsibilities moved behind existing Repository/Store ownership without semantic changes;
4. large-file LOC and responsibility count reduced;
5. broad silent catches replaced with explicit best-effort/error policy plus tests where practical.
