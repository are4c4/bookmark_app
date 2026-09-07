# AI Progress — Search & Indexing Lane

> Lane E durable handoff. Before implementation, read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, current `main`, and open PRs touching Object/Body/Relation/primitive contracts.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe, and reusable by built-in primitives and user-defined ObjectTypes.

## Current issue state — 2026-09-07
- **#414 closed.** Legacy Bookmark FTS focused refresh stale-token bug was fixed before that legacy path was retired.
- **#494 closed.** Canonical Object search/indexing is the live product path.
- **#753 closed.** Search isolates malformed persisted Object Body documents to the `body` bucket instead of aborting Object/workspace indexing; implemented by #757 (`f66c74bd7cf93365c72f22c9a880845de9673b12`).
- **#769 closed.** Search omits Relation labels for a malformed persisted Relation Property even when stale normalized edges remain; implemented by #774 (`c36315706b45bbfb73185c6a69c64993bf71e64b`).
- **Relation #773 merged** as `66d3da4d80f2a8b071410dff0d86cbf62e92ddbb`. `RelationReadService` now fails closed when persisted Relation values and normalized edges disagree on target ids, cardinality, order/position, or target-workspace/type validity.
- **#782 closed.** Search regression proves `relation_labels` inherits #773's read-side consistency boundary and focused refresh/workspace rebuild remove stale labels for well-formed serialized/index disagreement; implemented by #785 (`34604856d81852bf3058502c59689e7f2c23462c`).
- **#797 closed.** Generic typed Property search now fails closed for `system: true` metadata unless explicitly opted in with `searchable: true`; implemented by #799 (`4e685bccafdfa3fde47aadee0e6dfe424bba85c6`). Real File regression proves user-facing filename/MIME/extension remain searchable while managed path, SHA-256, and Storage ownership lifecycle metadata do not leak.
- Latest verified Search implementation checkpoint: **main `4e685bccafdfa3fde47aadee0e6dfe424bba85c6`**.
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
- **properties** — deterministic searchable typed values; Relation/File/Image/computed/internal identity values are excluded. System-maintained metadata (`config['system'] == true`) is default-deny and contributes only with explicit `searchable: true`;
- **body** — universal Body blocks through the Body-owned parsed text projection, never serialized block JSON;
- **relation labels** — trustworthy resolved target Object display titles only, never raw Relation/Object ids;
- **Weblink metadata** — URL, Domain, Page title, Site name and Description in a dedicated bucket; hidden/system media metadata is consumed but not searchable;
- **derived text** — replaceable source-keyed search metadata such as canonical File PDF `pdf-text`.

Workspace and optional ObjectType filtering use canonical ids. Query behavior remains prefix-based with FTS5 BM25 ranking.

## Completed architecture checkpoints
Major merged slices include:
- #514 — canonical Object FTS foundation and title/alias scope;
- #518/#531 — Body contributor and `body` bucket;
- #523/#543/#554 — typed Property projection and integration;
- #533/#562/#570/#581 — Relation label projection and dependent refresh planning;
- #545/#565/#572/#629 — canonical result resolution, application service, Object Global Search UI, and live product routing;
- #551/#578 — replaceable `derived_text` sink/indexing;
- #575/#587/#626 — Weblink search projection ownership and dedicated metadata bucket;
- #584/#589 — real File/Image primitive metadata through the same Object search repository;
- Primitive #609 + Search #635 — PDF extracted text -> `pdf-text` -> canonical FTS reconciliation;
- Refactor #654 — legacy Bookmark-only FTS implementation and legacy-only tests retired after replacement parity;
- #757 — malformed Body isolation after Object Core strict parsing changes;
- Relation #758 + Search #774 — strict persisted Relation inspection is reused by Search so malformed source values cannot leave stale Relation labels searchable;
- Relation #773 + Search #782/#785 — canonical Relation reads now require persisted/index agreement, and Search regression proves stale relation labels are removed without duplicating integrity logic in Search production code;
- Primitive #788 + Search #797/#799 — generic typed Property search now defaults system-maintained metadata to non-searchable, with explicit `searchable: true` opt-in and a real File privacy regression.

## Fail-closed source contracts
### Body
Object Core owns Body persistence/parsing. Search does not reinterpret corrupt Body JSON.

`ObjectSearchRepository` catches only `FormatException` at the Body contribution boundary:
- malformed Body contributes `''` to `body`;
- title/aliases/Properties/Relations/Weblink/derived text still index normally;
- focused refresh replaces the prior FTS row, removing stale Body tokens;
- unrelated database/index failures still surface;
- valid future Body versions and unknown block kinds continue through the normal Body projection.

Regression: `test/repositories/object_search_malformed_body_test.dart`.

Object Core may add stricter semantic validation for known blocks (for example checklist state). As long as malformed persisted Body remains reported as `FormatException`, the same Search bucket boundary omits that source without a Search-side parser or repair path.

### Relation labels
Relation owns persisted Relation inspection/integrity/mutation/read consistency. Search does not create a second Relation parser, edge authority model, or repair path.

Current trust boundary:
- malformed persisted Relation value => that Property contributes no `relation_labels`;
- a syntactically valid persisted value that disagrees with normalized edges on target ids/count/order/positions => canonical `RelationReadService` returns no outgoing projection for that Property;
- invalid target ObjectType/workspace consistency also fails closed in the Relation read layer;
- valid Relation Properties on the same Object continue to contribute normally;
- supported compatible stored shapes remain searchable when they agree with canonical edges;
- raw persisted ids and stale normalized edges are never used independently as fallback search labels;
- focused refresh replaces the prior FTS row, removing labels that became untrustworthy;
- Search never repairs persisted Relation values or normalized edges.

Regressions:
- `test/repositories/object_search_malformed_relation_test.dart` — malformed stored value with stale edge;
- `test/repositories/object_search_relation_read_consistency_test.dart` — well-formed stored value that disagrees with normalized edges.

Search still applies the existing malformed-value guard after `RelationReadService.outgoing(...)`, but #773 is the canonical authority for broader serialized/index consistency. Do not duplicate #773 comparison rules in Search.

### Typed Property metadata
Generic typed Property search is for user-facing values, not internal lifecycle/identity/geometry bookkeeping.

Current trust/privacy boundary:
- `searchable: false` always opts a Property out;
- `system: true` is default-deny in the generic `properties` contributor;
- a system-maintained Property contributes only when it explicitly declares `searchable: true`;
- ordinary non-system supported typed Properties keep their existing default-searchable behavior;
- Search production code does not hard-code primitive Property names, lifecycle keys, hash formats, legacy ids, or geometry field names;
- dedicated native contributors may own selected searchable metadata without weakening the generic default-deny rule.

Regressions:
- `test/repositories/object_property_search_system_metadata_test.dart` — system text/number/date omission plus explicit opt-in;
- `test/repositories/file_object_search_integration_test.dart` — File Original filename / Content type / Extension remain searchable while managed path, SHA-256, and Storage ownership remain non-searchable.

## Incremental / stale-token contracts
- focused Object refresh removes the previous FTS row by FTS `rowid` and inserts the current projection;
- removed/changed title, alias, Property, Body, Relation, Weblink and derived-text tokens must disappear;
- Relation target display changes can refresh affected backlink source Objects without a workspace rebuild;
- the refresh planner may use canonical raw backlinks to enumerate affected source ids, while each source reindex still passes through `RelationReadService` trust checks;
- derived producers replace only their own source key;
- PDF re-extraction replaces `pdf-text`; blank/missing/non-PDF capability clears that contribution;
- malformed or inconsistent optional source data is a source-local omission, not permission to retain stale tokens;
- derived/search metadata is rebuildable and is never canonical Object identity.

## Live product routing
`GlobalSearchPage` is a compatibility entrypoint that resolves canonical Object search context and renders `ObjectGlobalSearchPage`.

There is no live Bookmark-only FTS repository after #654. New domains participate by contributing to the canonical Object projection rather than adding separate long-term search repositories.

Global Search workspace rebuild also reconciles optional canonical File/PDF extracted text before rebuilding FTS.

## Validation
Recent correctness slices #757, #774, #785 and #799 passed repository Flutter CI before merge, including:
- maintainability guardrail tests;
- maintainability regression ceilings;
- feature legacy-dependency guard;
- feature presentation error-privacy guard;
- Drift generation;
- `flutter analyze`;
- full Flutter test suite.

#769 regression proves malformed persisted Relation data with a still-present normalized edge cannot leave its target title searchable while another valid Relation, Object title and ordinary Property remain available.

#782 regression specifically proves that a **well-formed** persisted Relation value can disagree with the normalized edge without leaking either side into Search:
- the previously indexed edge target label disappears after focused refresh;
- the new persisted-only target is not inferred/indexed as fallback text;
- another consistent Relation on the same Object remains searchable;
- Object title and ordinary Property search remain available;
- workspace rebuild preserves the same fail-closed result;
- persisted Relation values and normalized edges remain untouched by Search.

#797/#799 regression proves that the generic Property contributor cannot leak newly added system-maintained metadata merely because its storage type is text/number/date:
- default system metadata is omitted;
- explicit `system: true, searchable: true` opt-in works;
- ordinary user-facing typed Properties remain unchanged;
- real File filename/MIME/extension remain searchable;
- managed path, SHA-256, and the Storage ownership lifecycle key remain non-searchable.

## Cross-lane dependencies / ownership
- Object Core owns Body persistence/parsing/editor semantics; Search consumes only its parsed search-text projection and isolates parse failure at its bucket boundary.
- Relation owns Relation persistence, strict stored-value inspection, integrity, mutation, and canonical read consistency. **#773 is merged and is the authority for serialized/index agreement.** Search owns denormalized trustworthy label indexing and dependent refresh planning, with #785 locking the cross-lane contract in a Search regression.
- Primitive owns File/Image/Weblink metadata, File/PDF extraction and native behavior. Search owns which generic metadata is safe to expose as free text plus derived-text persistence/index/reconciliation. New primitive system metadata does not become searchable by default after #799.
- Refactor owns behavior-preserving legacy retirement; Bookmark-only FTS retirement is complete.
- Lane E currently holds no shared-hotspot lease.

## Next actions
There is no remaining Search-owned actionable work in #414, #494, #753, #769, #782, or #797.

For the next Lane E run:
1. Re-read current `main`, open Issues/PRs, and recent cross-lane changes before creating work.
2. Resume implementation only for a concrete Search/Indexing issue or a demonstrated cross-lane search correctness/privacy obligation.
3. Reuse canonical Object/Body/Relation/Primitive trust boundaries rather than duplicating their parsing/integrity semantics in Search.
4. Prefer source-local fail-closed contribution boundaries over allowing one corrupt optional source to take down the canonical index.
5. Treat newly introduced `system: true` typed metadata as non-searchable by default unless the owning contract deliberately marks it `searchable: true`; do not add primitive-name special cases in Search.
6. Do not swallow unrelated persistence/index errors and do not log raw user content, extracted text, private paths, malformed Body payloads, or malformed Relation payloads.
7. Do not recreate domain-specific long-term search repositories.

Potential future work such as large-PDF rebuild caching, richer ranking/filter UX, or semantic/vector search requires a separately scoped Issue; it is not implied by completed #494/#753/#769/#782/#797.

## Stop reason
**#753, #769, #782 and #797 are complete with repository CI green; #757, #774, #785 and #799 are merged; canonical Relation read consistency and system-metadata privacy boundaries are live on main; and no additional Search-owned issue is currently actionable. Lane E is idle under the `AGENTS.md` stopping criteria unless a new Search issue or concrete Search-specific regression/privacy obligation appears.**
