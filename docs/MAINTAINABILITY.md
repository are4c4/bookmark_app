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
| `lib/views/generic_database_page.dart` | 72 KB | Highest conflict risk; coordinate with Database/View work. |
| `lib/views/bookmark_unified_stage1_page.dart` | 56 KB | Legacy Bookmark presentation hotspot. |
| `lib/views/people_management_page.dart` | 40 KB | Mixed management/presentation responsibilities. |
| `lib/data/app_database.dart` | 37 KB | Schema/migrations plus compatibility CRUD; several responsibilities have since moved out. |
| `lib/views/app_shell.dart` | 34 KB | Composition/navigation hotspot. |
| `lib/views/object_inspector_page.dart` | 33 KB | Object presentation hotspot. |
| `lib/views/photo_management_page.dart` | 29 KB | Legacy/feature-specific presentation hotspot. |

These are a baseline, not hard limits. A refactor should reduce responsibility, duplicate production references, or source size rather than merely relocate the same complexity.

## Maintainability report

Run from the repository root:

```bash
bash tool/maintainability_report.sh
```

Use `--top N` to change the number of files shown. The report includes:
- total Dart LOC under `lib/` and `test/`;
- the largest Dart files by LOC;
- direct `workspaceStore.database` reach-through occurrences under legacy `lib/views/` / `lib/widgets/` and canonical `lib/features/**/presentation/` trees, grouped by file;
- direct imports of `data/app_database.dart` from canonical `lib/features/**/presentation/`, grouped by file;
- imports of the guarded historical Database-presentation shim names under `lib/widgets/`, grouped by caller file;
- the number and paths of Database-presentation re-export shim files themselves.

The presentation/database metrics are intentionally regression-oriented. They do not claim every existing occurrence is currently removable; they make composition debt visible so responsibility-moving PRs can show an actual reduction instead of only adding another wrapper. Refactor #522 extended the `workspaceStore.database` ceiling to canonical feature-presentation trees so moving code from a legacy host into `lib/features/**/presentation` cannot hide direct database reach-through.

Canonical feature presentation currently has **7 files** that import `app_database.dart` directly. Those existing dependencies are not being removed by fiat: several widgets still receive `AppDatabase` as part of their current contract. The import metric therefore prevents an eighth direct database import from being added while those dependencies are classified and migrated behind meaningful application-facing boundaries. Do not introduce a wrapper solely to lower this count. The previous eight-file baseline fell to seven when the production-caller-zero `ObjectWeblinkDetailPreview` module and its dedicated dead test were retired rather than kept as an unused presentation path.

### Temporary Database-presentation shims

The current re-export shim files are:
- `lib/widgets/database_view_tabs.dart`;
- `lib/widgets/database_create_tiles.dart`;
- `lib/widgets/resizable_detail_pane.dart`.

`lib/widgets/detail_property_row.dart` reached caller-zero after production/test consumers moved to the canonical feature import and was retired by #672. `lib/widgets/database_page_toolbar.dart` later reached true caller-zero after management hosts moved to the canonical toolbar and was retired by #735. Their historical names intentionally remain in the import scanner so reintroducing either old shim/import path is still detected as legacy dependency growth.

Canonical implementations live under `lib/features/database/presentation/widgets/`. Existing callers of the three remaining shims remain temporarily valid because they are concentrated in large legacy/shared hosts that should not be reconstructed merely to change imports. The metrics prevent both new shim dependencies and new shim files while allowing current migration debt to ratchet down naturally.

The report remains non-blocking by default so existing debt does not make unrelated local runs fail. For regression-only validation, callers may provide accepted ceilings explicitly:

```bash
bash tool/maintainability_report.sh \
  --max-boundary-refs 9 \
  --max-feature-presentation-db-imports 7 \
  --max-legacy-shim-imports 5 \
  --max-legacy-shims 3
```

`--max-boundary-refs N` exits with status 1 only when measured presentation `workspaceStore.database` references exceed `N`.

`--max-feature-presentation-db-imports N` exits with status 1 only when direct `app_database.dart` imports from canonical `lib/features/**/presentation` exceed `N`. Application/data/service code outside presentation is intentionally not counted.

`--max-legacy-shim-imports N` exits with status 1 only when imports of guarded historical Database-presentation shim names exceed `N`. It counts package imports through `package:bookmark_app/widgets/...`, relative imports through `../widgets/...`, and same-directory imports within `lib/widgets/`; canonical `features/database/presentation/widgets/...` imports are not counted. Retired shim names remain guarded to prevent regression.

`--max-legacy-shims N` exits with status 1 only when the number of `lib/widgets/**/*.dart` files that re-export `../features/database/presentation/widgets/*.dart` exceeds `N`. This closes the loophole where a new compatibility shim could be introduced under a new filename and therefore bypass a known-import-name ceiling.

The initial repository baseline was **22** legacy shim imports across **5** shim files. Refactor #474 migrated the three test-only imports in `test/database_interaction_widgets_test.dart` to canonical feature imports, lowering the accepted import ceiling to **19** without touching a production host. Refactor #499 moved `BookmarkAttachmentSection` directly to the canonical `DetailPropertyRow`, lowering the import ceiling to **18**. Refactor #541 moved `BookmarkReorderableProperties` to the same canonical `DetailPropertyRow`, lowering it again to **17**. The final `detail_property_row.dart` re-export then reached true caller-zero and was removed by #672, lowering the shim-file ceiling **5 → 4** without changing the import ceiling. Collection management moved its four shared Database presentation widgets directly to the canonical feature package in #687, lowering the accepted shim-import ceiling **17 → 13** without changing UI behavior. Photo management did the same in #695, lowering the accepted ceiling **13 → 9**. People management then moved its four imports in #707, lowering the accepted ceiling **9 → 5**. Finally, the now-unreferenced `database_page_toolbar.dart` re-export was removed by #735, lowering the shim-file ceiling **4 → 3**.

The presentation/database reach-through ceiling was initially enforced at **12**. Later cleanup in adjacent responsibility-moving slices reduced the measured production presentation baseline to **9 references across 6 files** without adding a replacement wrapper, so the accepted ceiling is now **9** and must not regress to the older 12-reference state.

Flutter CI enforces the accepted current ceilings of **9** direct presentation/database reach-through references, **7** canonical feature-presentation `AppDatabase` imports, **5** legacy shim imports, and **3** Database-presentation re-export shim files. When Refactor removes one or more of any category, lower the corresponding CI ceiling in the same or an immediately following focused PR so the improvement cannot silently regress.

`tool/maintainability_report_test.sh` exercises passing ceilings and each regression-failure path against an isolated fixture, including canonical feature presentation reach-through, direct `AppDatabase` import detection, relative/package/same-directory shim imports, and detection of newly-added shim files. Canonical feature imports do not count as legacy shim imports. The fixture may use a retired shim name to prove the denylist remains effective; it is not a production caller.

## Feature-presentation error privacy

Canonical `lib/features/**/presentation/` code is additionally protected by `tool/feature_presentation_error_privacy_guard.sh` (#745). A catch may forward its typed/raw error object to a higher-level callback such as `onError(error)`, but presentation code must not interpolate the caught variable directly into a string such as `$error` or `${error.runtimeType}`. Use a stable user-safe message and privacy-safe diagnostics or typed mapping instead. Legacy `lib/views/` / `lib/widgets/` remain separately audited debt so existing raw-error surfaces do not block unrelated canonical feature work.

## Progress measures

For Issue #225, prefer these measures over abstraction count:

1. production `BookmarkItem` / `BookmarkRepository` references removed;
2. duplicate presentation/read paths deleted;
3. `AppDatabase` responsibilities moved behind existing Repository/Store ownership without semantic changes;
4. large-file LOC and responsibility count reduced;
5. broad silent catches replaced with explicit best-effort/error policy plus tests where practical;
6. direct presentation -> database reach-through references reduced where a focused Store/Service/composition boundary already exists;
7. canonical feature-presentation direct `AppDatabase` imports reduced when meaningful application-facing boundaries replace them;
8. temporary Database-presentation re-export imports reduced until each shim can be deleted;
9. temporary Database-presentation re-export shim files reduced from the current three without introducing replacements under new filenames.
