# Maintainability guardrails

This document is the repository-level refactoring baseline for Issue #225. It is intentionally conservative: behavior-preserving consolidation is preferred over architecture rewrites.

## No-new-legacy-dependency rule

New Object / ObjectType / Database / View / Relation product work must not introduce new dependencies on Bookmark-era models or tables merely for convenience.

In particular, do not add a new production dependency on `BookmarkItem`, `BookmarkRepository`, `bookmarks.*` compatibility columns, or Bookmark-specific presentation when the operation can be expressed through the canonical Object/Database/View/Relation APIs.

An exception is allowed only for a still-live compatibility bridge, migration/import/export code, or a staged replacement with an explicit retirement condition. Relation behavior remains behind the canonical Relation subsystem.

## Refactor boundaries

- Preserve behavior unless an Issue explicitly owns a behavior change.
- Prefer deleting duplicate paths over adding adapters around both old and new paths.
- Do not move large folders simply to improve aesthetics.
- Do not rewrite historical migration semantics for style.
- Do not split a hotspot while another active PR owns the same large file; sequence the work instead.
- Treat `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, and other AGENTS-listed hosts as coordination hotspots.

## Hotspot baseline — 2026-09-05

Issue #225 recorded these approximate source sizes before the lane started:

| File | Approx. size | Refactor note |
| --- | ---: | --- |
| `lib/views/generic_database_page.dart` | 72 KB | Highest conflict risk; coordinate with Database/View work. |
| `lib/views/bookmark_unified_stage1_page.dart` | 56 KB | Legacy Bookmark presentation hotspot. |
| `lib/views/people_management_page.dart` | 40 KB | Mixed management/presentation responsibilities. |
| `lib/data/app_database.dart` | 37 KB | Schema/migrations plus compatibility CRUD; several responsibilities have since moved out. |
| `lib/views/app_shell.dart` | 34 KB | Composition/navigation hotspot. |
| `lib/views/object_inspector_page.dart` | 33 KB | Object presentation hotspot. |
| `lib/views/photo_management_page.dart` | 29 KB | Legacy/feature-specific presentation hotspot. |

A refactor should reduce responsibility, duplicate production references, or source size rather than merely relocate the same complexity.

## Maintainability report

Run:

```bash
bash tool/maintainability_report.sh
```

The report measures total Dart LOC, largest Dart files, presentation `workspaceStore.database` reach-through, direct canonical feature-presentation `AppDatabase` imports, guarded historical Database-presentation shim imports, and re-export shim files.

The report is non-blocking by default. CI supplies accepted regression ceilings explicitly:

```bash
bash tool/maintainability_report.sh \
  --max-boundary-refs 9 \
  --max-feature-presentation-db-imports 8 \
  --max-legacy-shim-imports 5 \
  --max-legacy-shims 3
```

Current accepted ceilings are therefore:
- presentation direct `workspaceStore.database`: **9**;
- canonical feature-presentation direct `AppDatabase` imports: **8**;
- legacy Database-presentation shim imports: **5**;
- Database-presentation re-export shim files: **3**.

Ratchet a ceiling downward only when real debt is removed. Never relax one merely to land unrelated work.

### Temporary Database-presentation shims

Canonical implementations live under `lib/features/database/presentation/widgets/`.

The remaining re-export shim files are:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

Retired shim names remain guarded by the import scanner so they cannot be silently reintroduced.

Shim retirement history:
- initial baseline: **22 imports / 5 shim files**;
- #474 moved three test-only imports to canonical feature imports: **22 → 19** imports;
- #499 moved `BookmarkAttachmentSection` to canonical `DetailPropertyRow`: **19 → 18**;
- #541 moved `BookmarkReorderableProperties`: **18 → 17**;
- #672 deleted caller-zero `detail_property_row.dart`: shim files **5 → 4**;
- #687 moved Collection management off four shims: imports **17 → 13**;
- #695 moved Photo management off four shims: **13 → 9**;
- #707 moved People management off four shims: **9 → 5**;
- after #707, `database_page_toolbar.dart` had no remaining production caller and was deleted in the following Refactor slice: shim files **4 → 3**.

The five remaining legacy shim imports are concentrated in shared hotspots: `GenericDatabasePage` uses `database_create_tiles`, `database_view_tabs`, and `resizable_detail_pane`; Stage1 uses `database_create_tiles` and `database_view_tabs`. Do not reconstruct those large hosts solely to lower a metric.

`tool/maintainability_report_test.sh` exercises passing ceilings and each regression-failure path, including canonical feature presentation reach-through, direct `AppDatabase` import detection, relative/package/same-directory shim imports, and detection of newly added shim files.

## Progress measures

For Issue #225, prefer these measures over abstraction count:

1. production `BookmarkItem` / `BookmarkRepository` references removed;
2. duplicate presentation/read paths deleted;
3. `AppDatabase` responsibilities moved behind existing Repository/Store ownership without semantic changes;
4. large-file LOC and responsibility count reduced;
5. broad silent catches replaced with explicit best-effort/error policy plus tests where practical;
6. direct presentation -> database reach-through reduced where a meaningful boundary already exists;
7. canonical feature-presentation direct `AppDatabase` imports reduced through real responsibility moves;
8. temporary re-export imports reduced until their shims reach caller-zero;
9. caller-zero shim files deleted rather than retained as speculative compatibility layers.
