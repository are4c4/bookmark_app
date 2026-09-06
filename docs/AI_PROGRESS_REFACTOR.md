# AI Progress — Refactor lane

> Durable handoff for behavior-preserving maintainability work. Update this file before every Refactor-lane run ends.

## Current goal
Issue #225 — reduce maintenance hotspots and retire duplicate legacy paths while preserving product behavior.

Primary lane: **Refactor**. Object owns replacement product semantics; Relation owns canonical Relation semantics. Refactor removes duplication, narrows responsibilities, improves failure observability/privacy, and decomposes hotspots only after checking parallel PR ownership.

## Current checkpoint — 2026-09-06
The repository is past the first architecture-construction phase. Refactor work is now concentrated on measurable responsibility reduction, legacy caller retirement, and explicit/privacy-safe failure boundaries.

Latest completed/in-flight checkpoints:
- **#351 merged** — Board grouped-create rollback cleanup can no longer replace the original preset/Relation validation failure.
- **#358 merged** — managed Image import rollback cleanup can no longer replace the original canonical Image Object creation failure. Flutter CI run #1345 was green before integration.
- **#359 open** — Profile restore rollback cleanup rebuilt directly from latest `main`; deletion of a partially restored target is best-effort and must not replace the original extraction/validation failure. Focused source regression included.
- stale **#356** is closed and superseded by #359.
- **#355** (stable bootstrap failure boundary) and **#357** (ProfileManager diagnostic privacy) are still open but currently stale/non-mergeable against the fast-moving main; do not force merge them. Rebuild only their minimal intended diffs on fresh main if still needed.
- **#336** remains an older attachment failure-policy PR and should be re-audited against current main before any integration.

Parallel-lane ownership checked this run. Recent Object work #349/#350/#352/#354 has changed Property-add and Bookmark List presentation, so Refactor must continue avoiding broad edits to `bookmark_unified_stage1_page.dart`, `generic_database_page.dart`, `object_inspector_page.dart`, `app_shell.dart`, and `app_database.dart` unless current open PR ownership is clear.

## Completed architecture/refactor foundations
### P0 guardrails
Merged and active:
- `tool/maintainability_report.sh`;
- `docs/MAINTAINABILITY.md` no-new-legacy-dependency policy and hotspot baseline;
- `docs/LEGACY_BOOKMARK_INVENTORY.md`;
- `docs/ERROR_POLICY_AUDIT.md`;
- `docs/architecture.md` dependency-boundary guidance.

New Object/Database/View code must not deepen `BookmarkItem` or legacy-table coupling unless it is an explicit compatibility/migration/import/export boundary with a retirement condition.

### AppDatabase migration extraction
Historical migration bodies v2-v16 are extracted behind helpers. `AppDatabase.migration` is sequencing/wiring rather than the home of historical migration bodies. Historical fixtures cover real old schema checkpoints and the extraction must preserve ordering and compatibility semantics.

### AppDatabase responsibility reduction
Merged responsibility moves include:
- #281 `BookmarkReadStore` — screen-ready Bookmark aggregation removed from AppDatabase root;
- #282 `ProfilePathResolver` — profile-relative/absolute path conversion removed from AppDatabase root;
- #283 `SavedViewReadStore` — SavedView aggregation removed from AppDatabase root;
- #289 `PhotoReadStore` — Photo read/path responsibility removed from AppDatabase root.

Continue only when a slice removes a real responsibility. Do not add wrapper-only indirection.

### Legacy Bookmark visual duplication
The original direct visual-resolution inventory is complete:
- lifecycle rows — Object #296;
- Notion card — Refactor #294;
- reverse lookup — Refactor #299;
- Stage1 List/Table — Refactor #324.

These hosts now route through the shared canonical Bookmark visual path. Legacy thumbnail/Photo fallback remains compatibility data while old product/import/export paths still need it.

### GenericDatabasePage decomposition
Merged focused slices:
- #310 — read/projection loading and computed projection moved to `GenericDatabasePageStateLoader`;
- #323 — low-level Store/Service construction moved to `GenericDatabasePageServices.fromWorkspaceStore(...)`.

Next useful decomposition candidates remain schema/database actions, Property/dialog workflows, or layout-specific host responsibilities, but only through patch-sized edits with focused regression coverage. Do not reconstruct the whole 70KB+ page.

### Failure-policy / privacy work
Merged work already covers PDF enrichment, persisted View/Object JSON, tag-tree fallback, computed projection, optional preview ingestion, GlobalSearch, Settings backup/restore, AutoOrganize, View open-mode settings, global file-drop, Board rollback, and Image import rollback.

Policy:
- preserve existing fail-soft/fail-closed product behavior unless a product issue explicitly changes it;
- stable user-facing messages instead of raw implementation exceptions;
- debug/assert diagnostics use fixed operation labels plus stack traces;
- do not include paths, URLs, names, JSON, response bodies, exception text, or other user content when diagnostics can avoid it;
- rollback cleanup must be best-effort and must not replace the primary failure.

## Cross-lane coordination
### Object lane
Object-first presentation is moving quickly. Recent main includes anchored Property-add parity and Bookmark List readability work. Legacy Bookmark URL/thumbnail storage remains compatibility data until Object-first read/write/presentation parity and migration policy are proven.

Before touching shared hotspots, re-check open PRs. Prefer a non-overlapping service/test/docs slice when another lane owns a host.

### Relation lane
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Refactor must not create alternate serialized-id/index/backlink/repair paths. Presentation/refactor changes should preserve Relation semantics exactly.

## Exact next actions
1. Let **#359** run Flutter CI. If green and mergeable, integrate it.
2. Re-check **#355/#357/#336** against latest main. Rebuild only minimal diffs from fresh main; never force merge stale/conflicting branches.
3. Prefer the next Issue #225 slice that removes a real responsibility or unsafe failure boundary. Good candidates are another patch-sized GenericDatabasePage extraction or remaining raw user-visible exception boundary outside Object-owned hotspots.
4. Re-run/refresh maintainability metrics after another meaningful hotspot extraction; track actual LOC/responsibility reduction, not adapter count.
5. Keep ProfileManager recovery semantics themselves deferred. Sanitizing diagnostics is behavior-preserving; changing corrupt-registry fallback/recovery is a product/data-safety decision.
6. Continue legacy Photo/Bookmark caller retirement only after Object/Image/Weblink replacement behavior is proven by production callers and tests.

## Validation expectations
For responsibility-moving refactors:
- preserve ordering/public behavior;
- add focused regression coverage;
- run `flutter analyze` and full tests before merge;
- prove old production callers are gone before deletion.

For failure-policy work:
- preserve the existing user-visible success/failure contract;
- ensure cleanup cannot mask the primary error;
- keep diagnostics privacy-safe;
- use focused tests that exercise the real boundary where practical.

## Risks / blockers
- main advances rapidly across Object/Relation/Refactor lanes; rebuild small diffs instead of force-merging stale branches;
- legacy Bookmark/Photo storage cannot be destructively removed before proven parity;
- large shared hosts should not be rebuilt wholesale for small edits;
- ProfileManager fallback/recovery behavior is a data-safety/product decision, not routine cleanup;
- speculative abstractions that do not remove responsibility/duplication should be rejected.

## This run
- read latest `AGENTS.md`, #225, repository handoff, Refactor handoff, architecture guidance, recent main commits, open PR ownership and CI state;
- confirmed **#358** mergeable with Flutter CI run #1345 successful and merged it to `main` as `dc496643a200d8eb4c61d3ab9d0a2241b2b394c8`;
- detected **#356** was stale/non-mergeable and did not force merge it;
- rebuilt its exact two-file behavior-preserving change from latest `main` as **#359**, then closed #356 as superseded;
- updated this handoff on #359;
- did not modify Relation semantics or Object-owned presentation hotspots.

### Stop state
#359 is the current focused Refactor PR. CI/mergeability for its new head is the next integration gate; independent Refactor work remains available after that, especially stale-PR cleanup and patch-sized responsibility/failure-boundary work.