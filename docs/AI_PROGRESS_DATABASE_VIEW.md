# AI Progress — Database, View & Schema UX Lane

> Lane C handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. Verify current open PR ownership before touching shared hosts.

## Lane goal
Make generic ObjectType/Database/View configuration expressive enough that new domains are created by configuration/templates rather than new management pages.

## Primary active issues
- #490 — templates instantiate user-owned ObjectTypes/Databases/Views.
- #491 — first-class Relation Property authoring and inline target creation UX.
- #492 — generic Gallery cover/media source from Object Relations.
- #493 — schema-evolution UX side; coordinate integrity-sensitive changes with Relation/Data Integrity lane.
- #249 — remaining Bookmark presentation parity only where it is a generic Database/View contract.
- #56 / #484 — umbrella product architecture.

## Current checkpoint — 2026-09-07
Latest verified `main` at run start: `5ad92a00bd242032aa647134356ed1f83e89f3ae`.

### Completed in the latest run
- re-read current `AGENTS.md`, latest `main`, current open PRs, and the canonical Lane C ownership boundaries before editing;
- confirmed the active open Refactor PRs do not edit `.github/workflows/flutter_ci.yml`, so the CI diagnostics change does not overlap an active shared-infrastructure edit;
- created `feature/database-view-ci-test-diagnostics` from current `main` to unblock autonomous diagnosis of #726 and future lane failures;
- changed the Flutter Test CI step to preserve the test exit code while teeing the full expanded reporter output to `ci-artifacts/flutter-test.log`;
- added failure-only GitHub Step Summary output containing the final 200 test-log lines, making the assertion/error tail visible without depending on the raw Actions log stream;
- added a failure-only `actions/upload-artifact@v4` upload of the complete Flutter test log with a seven-day retention window;
- kept Analyze, maintainability guards, generated-code behavior, test timeout, and product/runtime code unchanged.

## Current open Lane C work
- #726 — current priority for #491 Relation Property authoring UX. It remains open and must be fixed/validated before merge; preserve `RelationSchemaEvolutionService.inspectChange -> confirmation -> updateRelationSchema` unchanged.
- #696 — stale/superseded Relation Property authoring PR. Close it once #726 or its successor is green and confirmed to cover the same slice.
- `feature/database-view-ci-test-diagnostics` — temporary Lane C unblocker branch for making Flutter Test failures self-diagnosing through Step Summary + artifact.

## Validation
- Local Flutter execution is not available in this automation environment; GitHub CI is the validation gate for the workflow change.
- The workflow change is infrastructure-only and does not touch application code, schema, Relation mutation, primitive semantics, Search, Vault, or shared presentation hotspots.
- `set -o pipefail` keeps a failing `flutter test` pipeline red even though output is piped through `tee`.

## Exact next actions
1. Open the CI diagnostics PR and confirm its own workflow syntax/CI run is valid; fix any Actions/YAML issue if necessary.
2. Merge the diagnostics PR once green.
3. Trigger a fresh #726 CI run from a head/base refresh so the new diagnostics path is used; read the Step Summary/artifact, identify the concrete failing test, and fix it on #726.
4. Re-run #726 CI, merge when green, then close stale #696 after confirming duplication.
5. Re-fetch latest `main` and continue #491 inline target creation or #490 template work according to current hotspot/dependency ownership.
6. Keep #493 destructive Relation migration correctness in Lane B; Lane C owns explicit impact/confirmation UX and canonical service composition only.

## Shared hotspot lease / ownership
No shared presentation hotspot is edited by the CI diagnostics branch. `generic_database_page.dart`, `app_shell.dart`, `object_inspector_page.dart`, `bookmark_unified_stage1_page.dart`, `bookmark_reorderable_properties.dart`, `people_management_page.dart`, and `app_database.dart` still require a fresh open-PR changed-file audit immediately before any non-trivial edit.

## Cross-lane dependencies
- Lane B owns destructive Relation target/cardinality migration correctness and fail-closed integrity behavior consumed by Lane C schema UX.
- Lane D owns canonical Weblink/Image/File/Tag creation/import semantics used by Relation quick-create and Gallery media resolution.
- Lane A owns core Object/Body contracts; Lane C may compose them into Database/View hosts only after hotspot ownership is clear.
- Lane G owns broad maintainability/refactor work; this CI change is a narrow Lane C execution unblocker and does not alter maintainability policy.

## Stop reason
Do not stop on this checkpoint alone. The immediate continuation is to validate and integrate the CI diagnostics change, then use it to diagnose and repair #726.
