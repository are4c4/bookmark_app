# AI Progress — Search & Indexing Lane

> Lane E durable handoff. Before implementation, read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, current `main`, and open PRs touching Object/Body/Relation/primitive contracts.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe, and reusable by built-in primitives and user-defined ObjectTypes.

## Current issue state — 2026-09-07
- **#414 closed.** Legacy Bookmark FTS focused refresh stale-token bug was fixed before that legacy path was retired.
- **#494 closed.** Canonical Object search/indexing is the live product path.
- **#753 closed.** Search isolates malformed persisted Object Body documents to the `body` bucket instead of aborting Object/workspace indexing; implemented by #757 (`f66c74bd7cf93365c72f22c9a880845de9673b12`).
- **#769 closed.** Search omits Relation labels for a malformed persisted Relation Property even when stale normalized edges remain; implemented by #774 (`c36315706b45bbfb73185c6a69c64993bf71e64b`).
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
- **properties** — deterministic searchable typed values; Relation/File/Image/computed/internal identity values are excluded;
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
- Relation #758 + Search #774 — strict persisted Relation inspection is reused by Search so malformed source values cannot leave stale Relation labels searchable.

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

### Relation labels
Relation owns persisted Relation inspection/integrity/mutation. Search reuses Relation's `inspectRelationStoredValue(...)` and does not create a second parser or repair Relation data.

For each outgoing Relation Property:
- malformed persisted value => that Property contributes no `relation_labels`;
- valid Relation Properties on the same Object still contribute normally;
- supported legacy stored shapes remain searchable;
- stale normalized edges alone are not sufficient authority for Search;
- focused refresh removes previously indexed labels when the stored value becomes malformed;
- normalized edges and raw malformed values remain untouched by Search.

Regression: `test/repositories/object_search_malformed_relation_test.dart`.

## Incremental / stale-token contracts
- focused Object refresh removes the previous FTS row by FTS `rowid` and inserts the current projection;
- removed/changed title, alias, Property, Body, Relation, Weblink and derived-text tokens must disappear;
- Relation target display changes can refresh affected backlink source Objects without a workspace rebuild;
- derived producers replace only their own source key;
- PDF re-extraction replaces `pdf-text`; blank/missing/non-PDF capability clears that contribution;
- malformed optional source data is a source-local omission, not permission to retain stale tokens;
- derived/search metadata is rebuildable and is never canonical Object identity.

## Live product routing
`GlobalSearchPage` is a compatibility entrypoint that resolves canonical Object search context and renders `ObjectGlobalSearchPage`.

There is no live Bookmark-only FTS repository after #654. New domains participate by contributing to the canonical Object projection rather than adding separate long-term search repositories.

Global Search workspace rebuild also reconciles optional canonical File/PDF extracted text before rebuilding FTS.

## Validation
Recent correctness slices #757 and #774 passed repository Flutter CI before merge, including:
- maintainability guardrail tests;
- maintainability regression ceilings;
- feature legacy-dependency guard;
- feature presentation error-privacy guard;
- `flutter analyze`;
- full Flutter test suite.

#769 regression specifically proves that after corrupting only one persisted Relation value while leaving normalized edges intact:
- focused refresh removes that Property's stale target label;
- another valid Relation label remains searchable;
- Object title and ordinary Property search remain available;
- workspace rebuild remains available;
- Relation ids and malformed payload content are not fallback search text;
- Search does not mutate source Relation data or normalized edges.

## Cross-lane dependencies / ownership
- Object Core owns Body persistence/parsing/editor semantics; Search consumes only its parsed search-text projection and isolates parse failure at its bucket boundary.
- Relation owns Relation persistence, strict stored-value inspection, integrity and mutation; Search owns denormalized trustworthy label indexing and dependent refresh planning.
- Primitive owns File/PDF extraction and native behavior; Search owns derived-text persistence/index/reconciliation.
- Refactor owns behavior-preserving legacy retirement; Bookmark-only FTS retirement is complete.
- Lane E currently holds no shared-hotspot lease.

## Next actions
There is no remaining actionable work in #414, #494, #753, or #769.

For the next Lane E run:
1. Re-read current `main`, open Issues/PRs, and recent cross-lane changes.
2. Resume only for a concrete Search/Indexing issue or a real cross-lane correctness obligation.
3. Prefer source-local fail-closed contribution boundaries over allowing one corrupt optional source to take down the canonical index.
4. Do not swallow unrelated persistence/index errors and do not log raw user content, extracted text, private paths, malformed Body payloads, or malformed Relation payloads.
5. Do not recreate domain-specific long-term search repositories.

Potential future work such as large-PDF rebuild caching, richer ranking/filter UX, or semantic/vector search requires a separately scoped Issue; it is not implied by completed #494/#753/#769.

## Stop reason
**#753 and #769 are implemented with all repository CI green; PRs #757 and #774 are merged and both Issues are closed. No additional concrete Search/Indexing issue is currently assigned. Lane E is idle under the `AGENTS.md` stopping criteria until a new Search issue or cross-lane search obligation appears.**
