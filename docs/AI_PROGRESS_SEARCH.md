# AI Progress — Search & Indexing Lane

> Lane E durable handoff. Before implementation, read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, current `main`, and open PRs touching Object/Body/Relation/primitive contracts.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe, and reusable by built-in primitives and user-defined ObjectTypes.

## Current issue state — 2026-09-07
- **#414 closed.** Legacy Bookmark FTS focused-refresh stale-token bug was fixed before that path was retired.
- **#494 closed.** Canonical Object search/indexing is the live product path.
- **#753 closed.** Malformed persisted Object Body is isolated to the `body` bucket; #757 (`f66c74bd7cf93365c72f22c9a880845de9673b12`).
- **#769 closed.** Malformed persisted Relation Properties cannot leave stale Relation labels searchable; #774 (`c36315706b45bbfb73185c6a69c64993bf71e64b`).
- **Relation #773 merged** as `66d3da4d80f2a8b071410dff0d86cbf62e92ddbb`; canonical Relation reads fail closed when persisted values and normalized edges disagree.
- **#782 closed.** Search regression proves `relation_labels` inherits #773's serialized/index consistency boundary; #785 (`34604856d81852bf3058502c59689e7f2c23462c`).
- **#797 closed.** Generic typed Property search defaults `system: true` metadata to non-searchable unless explicitly opted in with `searchable: true`; #799 (`4e685bccafdfa3fde47aadee0e6dfe424bba85c6`). Real File coverage keeps user-facing filename/MIME/extension searchable while managed path, SHA-256, and Storage ownership remain private.
- **#807 closed.** Returning from a Global Search result detail now focused-refreshes the opened Object plus Relation-label dependents and reruns the active query; #822 (`b80ec83b60fa997328e5ce57347d09fdfed70e2f`). Refresh failure uses the stable error boundary and never renders raw exceptions/private paths.
- Latest verified Search implementation checkpoint: **main `b80ec83b60fa997328e5ce57347d09fdfed70e2f`**.
- Refactor #654 removed the caller-zero legacy Bookmark-only `FullTextSearchRepository`; do not recreate a parallel Bookmark/domain-specific search product.

## Canonical Object search architecture
`ObjectSearchRepository` owns one FTS5 projection shared by every ObjectType:

```text
object_search_fts
├─ object_id         (UNINDEXED canonical identity)
├─ object_type_id    (UNINDEXED filter context)
├─ workspace_id      (UNINDEXED scope)
├─ title
├─ aliases
├─ properties
├─ body
├─ relation_labels
├─ weblink_metadata
└─ derived_text
```

Contributors:
- **title / aliases** — canonical Object identity and aliases;
- **properties** — deterministic searchable typed values. Relation/File/Image/computed/internal identity values are excluded. `system: true` metadata is default-deny and contributes only with explicit `searchable: true`;
- **body** — universal Body blocks through the Body-owned parsed text projection, never serialized block JSON;
- **relation labels** — trustworthy resolved target display titles only, never raw Relation/Object ids;
- **Weblink metadata** — URL, Domain, Page title, Site name and Description in a dedicated bucket; hidden/system media metadata is consumed but not searchable;
- **derived text** — replaceable source-keyed search metadata such as canonical File PDF `pdf-text`.

Workspace and optional ObjectType filtering use canonical ids. Query behavior remains prefix-based with FTS5 BM25 ranking.

## Completed architecture checkpoints
Major merged slices:
- #514 — canonical Object FTS foundation and title/alias scope;
- #518/#531 — Body contributor and `body` bucket;
- #523/#543/#554 — typed Property projection and integration;
- #533/#562/#570/#581 — Relation label projection and dependent refresh planning;
- #545/#565/#572/#629 — canonical result resolution, application service, Object Global Search UI, and live product routing;
- #551/#578 — replaceable `derived_text` sink/indexing;
- #575/#587/#626 — Weblink projection ownership and dedicated metadata bucket;
- #584/#589 — real File/Image primitive metadata through the same Object search repository;
- Primitive #609 + Search #635 — PDF extracted text -> `pdf-text` -> canonical FTS reconciliation;
- Refactor #654 — legacy Bookmark-only FTS implementation/tests retired after replacement parity;
- #757 — malformed Body source-local isolation;
- Relation #758 + Search #774 — malformed persisted Relation values cannot leave stale labels searchable;
- Relation #773 + Search #782/#785 — canonical Relation read consistency is inherited by Search without duplicating Relation integrity logic;
- Primitive #788 + Search #797/#799 — system-maintained typed metadata is default-private from generic free-text search;
- #807/#822 — live Global Search refreshes opened Objects and current label dependents when detail returns, then reruns the active query.

## Fail-closed source contracts
### Body
Object Core owns Body persistence/parsing. Search does not reinterpret corrupt Body JSON.

`ObjectSearchRepository` catches only `FormatException` at the Body contribution boundary:
- malformed Body contributes `''` to `body`;
- title/aliases/Properties/Relations/Weblink/derived text still index normally;
- focused refresh replaces the previous FTS row, removing stale Body tokens;
- unrelated database/index failures still surface;
- valid future Body versions and unknown block kinds continue through the normal Body projection.

Regression: `test/repositories/object_search_malformed_body_test.dart`.

Object Core may strengthen semantic validation for known blocks. As long as malformed persisted Body is surfaced as `FormatException`, Search should keep using the same source-local omission boundary rather than adding a second Body parser/repair path.

### Relation labels
Relation owns persisted Relation inspection, integrity, mutation, and canonical read consistency. Search must not create a second Relation authority model.

Trust boundary:
- malformed persisted Relation value => that Property contributes no `relation_labels`;
- syntactically valid persisted value that disagrees with normalized edges on target ids/count/order/positions => `RelationReadService` contributes no outgoing projection for that Property;
- invalid target workspace/ObjectType consistency also fails closed in Relation read logic;
- valid Relation Properties on the same Object continue to contribute normally;
- raw persisted ids and stale normalized edges are never independent fallback search labels;
- focused refresh removes stale labels that became untrustworthy;
- Search never repairs persisted Relation values or normalized edges.

Regressions:
- `test/repositories/object_search_malformed_relation_test.dart`;
- `test/repositories/object_search_relation_read_consistency_test.dart`.

### Typed Property metadata
Generic typed Property search is for user-facing values, not lifecycle/identity/geometry bookkeeping.

Privacy boundary:
- `searchable: false` always opts out;
- `system: true` is default-deny in the generic `properties` contributor;
- system-maintained metadata contributes only with explicit `searchable: true`;
- ordinary non-system supported typed Properties keep existing default-searchable behavior;
- Search production code does not hard-code primitive Property names, lifecycle keys, hash formats, legacy ids, or geometry field names;
- dedicated native contributors may own explicitly selected searchable metadata without weakening the generic default-deny rule.

Regressions:
- `test/repositories/object_property_search_system_metadata_test.dart`;
- `test/repositories/file_object_search_integration_test.dart`.

## Incremental / stale-token contracts
- focused Object refresh removes the previous FTS row by FTS `rowid` and inserts the current projection;
- removed/changed title, alias, Property, Body, Relation, Weblink and derived-text tokens must disappear;
- Relation target display changes refresh affected backlink source Objects without a workspace rebuild;
- the refresh planner may use canonical raw backlinks to enumerate affected source ids, while every source reindex still passes through `RelationReadService` trust checks;
- derived producers replace only their own source key;
- PDF re-extraction replaces `pdf-text`; blank/missing/non-PDF capability clears that contribution;
- malformed/inconsistent optional source data is a source-local omission, never permission to retain stale tokens;
- derived/search metadata is rebuildable and is never canonical Object identity.

### Live detail-return refresh
`ObjectGlobalSearchPage` owns freshness for Objects it opens from its own result list.

After `ObjectInspectorPage` returns:
1. call `ObjectGlobalSearchService.refreshObjectLabelDependents(openedObjectId)`;
2. this refreshes the opened Object plus current Relation source Objects denormalizing its label;
3. if the query is still non-empty, rerun that active query;
4. do **not** run a workspace-wide rebuild for an ordinary detail return;
5. refresh failures go through `_recordSearchFailure(...)`, preserving stable retryable UI without raw exception/path leakage.

Regressions:
- `test/object_global_search_page_test.dart` — renamed Relation target + source `relation_labels` stale-token replacement on return;
- `test/global_search_page_error_test.dart` — detail-return refresh failure privacy/stable-error boundary.

Note: `refreshObjectLabelDependents` is intended for rename/update flows while Relation edges exist. Destructive delete workflows must collect dependents before deletion because Relation edges cascade. The shared Object inspector currently does not introduce a Search-owned delete path; if a future result-detail route adds deletion, explicitly revisit this contract rather than assuming post-delete dependent discovery is sufficient.

## Live product routing
`GlobalSearchPage` is a compatibility entrypoint that resolves canonical Object search context and renders `ObjectGlobalSearchPage`.

There is no live Bookmark-only FTS repository after #654. New domains participate by contributing to the canonical Object projection rather than adding separate long-term search repositories.

Global Search workspace rebuild reconciles optional canonical File/PDF extracted text before rebuilding FTS. Ordinary result-detail return uses focused refresh only and leaves that initial/rebuild PDF reconciliation contract unchanged.

## Validation
Recent correctness slices #757, #774, #785, #799 and #822 passed repository Flutter CI before merge, including:
- maintainability guardrail tests;
- maintainability regression ceilings;
- feature legacy-dependency guard;
- feature presentation error-privacy guard;
- Drift generation;
- `flutter analyze`;
- full Flutter test suite.

#797/#799 specifically proves newly added system-maintained metadata cannot become searchable merely because its storage type is text/number/date, while intended File filename/MIME/extension search remains available.

#807/#822 specifically proves:
- an Object rename performed while its detail route is open removes the old direct title hit after return;
- a source Object matched only through the target's `relation_labels` also loses the old token;
- both target and source become searchable under the new label;
- the current non-empty query is rerun after refresh;
- refresh failure renders only the stable Global Search error state, not raw exception text or private filesystem paths.

## Cross-lane dependencies / ownership
- Object Core owns Body persistence/parsing/editor/detail semantics; Search consumes parsed Body text and owns search freshness after its own result-opening route returns.
- Relation owns persisted Relation inspection/integrity/mutation/read consistency. Search owns trustworthy denormalized label indexing and dependent refresh planning, reusing canonical Relation reads.
- Primitive owns File/Image/Weblink metadata plus File/PDF extraction/native behavior. Search owns which generic metadata is safe for free-text exposure plus derived-text persistence/index/reconciliation.
- Refactor owns behavior-preserving legacy retirement; Bookmark-only FTS retirement is complete.
- Lane E currently holds no shared-hotspot lease. #822 changed only `object_global_search_page.dart` plus Search-owned regressions; `ObjectInspectorPage` was not modified.

## Next actions
There is no remaining Search-owned actionable work in #414, #494, #753, #769, #782, #797, or #807.

For the next Lane E run:
1. Re-read current `main`, open Issues/PRs, and recent cross-lane changes before creating work.
2. Resume only for a concrete Search/Indexing issue or demonstrated cross-lane search correctness/privacy obligation.
3. Reuse canonical Object/Body/Relation/Primitive trust boundaries instead of duplicating their parsing/integrity semantics.
4. Prefer source-local fail-closed contribution boundaries over allowing one corrupt optional source to take down the canonical index.
5. Treat newly introduced `system: true` typed metadata as non-searchable by default unless deliberately marked `searchable: true`; do not add primitive-name special cases.
6. Preserve focused refresh for live edit-return flows; do not turn ordinary navigation into full workspace rebuilds.
7. Do not swallow unrelated persistence/index errors and do not log raw user content, extracted text, private paths, malformed Body payloads, or malformed Relation payloads.
8. Do not recreate domain-specific long-term search repositories.

Potential future work such as large-PDF rebuild caching, richer ranking/filter UX, semantic/vector search, or delete-aware result-detail refresh requires a separately scoped Issue backed by a concrete product/correctness need.

## Stop reason
**#753, #769, #782, #797 and #807 are complete with repository CI green; #757, #774, #785, #799 and #822 are merged; canonical Relation read consistency, system-metadata privacy, and live detail-return freshness are all protected by regressions. No additional Search-owned issue is currently actionable, so Lane E is idle under `AGENTS.md` unless a new concrete Search regression/privacy obligation appears.**
