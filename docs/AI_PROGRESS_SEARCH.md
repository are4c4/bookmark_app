# AI Progress — Search & Indexing Lane

> Lane E handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, and latest GitHub state before implementation.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe, and reusable by built-in primitives and user-defined ObjectTypes.

## Current issue state — 2026-09-07
- **#414 closed.** Focused Bookmark FTS stale-token correctness was fixed before the legacy Bookmark-only FTS path was retired.
- **#494 closed.** Canonical Object search/indexing is the live product path.
- **#753 closed as completed.** Follow-up after Object Core #749: malformed persisted Body documents are isolated to the `body` search contribution instead of aborting Object/workspace indexing.
- Latest Search implementation merge: **#757 / `f66c74bd7cf93365c72f22c9a880845de9673b12`**.
- Refactor #654 previously removed the caller-zero legacy `FullTextSearchRepository`; do not recreate a parallel Bookmark/domain-specific search product.

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
- **properties** — deterministic searchable typed values, excluding Relation/File/Image/computed/internal identity values;
- **body** — universal Body blocks through the Body-owned text projection, never raw serialized JSON;
- **relation labels** — resolved target Object display titles only, never raw Object/Relation ids;
- **Weblink metadata** — URL, Domain, Page title, Site name and Description in the dedicated bucket; hidden/system media metadata is not searchable;
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
- #609 Primitive + #635 Search — PDF extracted text -> `pdf-text` -> canonical FTS reconciliation;
- #654 Refactor — legacy Bookmark-only `FullTextSearchRepository` and legacy-only tests retired after replacement parity;
- #757 — malformed Body isolation after Object Core #749.

## #753 malformed Body contract
Object Core owns strict Body parsing. Search must not reinterpret malformed persisted Body documents or add a parallel parser.

`ObjectSearchRepository` now catches only `FormatException` at the Body contribution boundary:
- malformed Body contributes `''` to the `body` bucket;
- title/aliases/Properties/Relations/Weblink/derived text still index normally;
- workspace rebuild remains available when one Object Body is malformed;
- focused refresh removes any previously indexed Body tokens because the old FTS row is replaced by the current projection with an empty Body bucket;
- raw malformed Body JSON is never indexed as fallback text;
- database, FTS, Relation and unrelated failures still surface normally;
- valid future Body versions and unknown block kinds continue through the existing Body projection.

Regression file: `test/repositories/object_search_malformed_body_test.dart`.

## Incremental / stale-token contracts
- focused Object refresh removes the previous FTS row by FTS `rowid` and inserts the current projection;
- removed/changed title, alias, Property, Body, Relation, Weblink and derived-text tokens must disappear;
- Relation target display changes can refresh affected backlink source Objects without requiring a full workspace rebuild;
- derived producers replace only their own source key;
- PDF re-extraction replaces `pdf-text`; blank/missing/non-PDF capability clears that contribution;
- malformed Body is a source-local omission, not permission to keep stale Body tokens;
- derived/search metadata is rebuildable and is never canonical Object identity.

## Live product routing
`GlobalSearchPage` is a compatibility entrypoint that resolves canonical Object search context and renders `ObjectGlobalSearchPage`.

There is no live Bookmark-only FTS repository after #654. New domains participate by contributing to the canonical Object projection rather than adding separate long-term search repositories.

Global Search workspace rebuild also reconciles optional canonical File/PDF extracted text before rebuilding FTS.

## Validation
#757 passed repository Flutter CI before merge, including:
- maintainability guardrail tests;
- maintainability regression ceilings;
- feature legacy-dependency guard;
- feature presentation error-privacy guard;
- `flutter analyze`;
- full Flutter test suite.

Focused #753 regressions prove:
- workspace rebuild succeeds with one malformed Body;
- the malformed Object's valid title and healthy Objects' Body text remain searchable;
- malformed raw Body content is not searchable;
- focused refresh removes stale Body tokens after corruption;
- future Body versions and unknown block kinds remain searchable.

## Cross-lane dependencies / ownership
- Object Core owns Body persistence/parsing/editor semantics; Search consumes only the parsed search-text projection and isolates parse failure at its bucket boundary.
- Primitive lane owns File/PDF extraction and native behavior; Search owns derived-text persistence/index/reconciliation.
- Relation lane owns Relation persistence/integrity; Search owns denormalized display-label indexing and dependent refresh planning.
- Refactor owns behavior-preserving legacy retirement; legacy Bookmark FTS retirement is already complete.
- Lane E currently holds no shared-hotspot lease.

## Next actions
There is no remaining actionable work in #414, #494, or #753.

For the next Lane E run:
1. Re-read current `main`, open Issues/PRs and recent cross-lane changes.
2. Resume only for a concrete Search/Indexing issue or a real cross-lane correctness obligation.
3. Prefer source-local fail-closed contribution boundaries over making one corrupt optional source take down the entire canonical index.
4. Do not swallow unrelated persistence/index errors and do not log raw user content, extracted text, private paths or malformed Body payloads.
5. Do not recreate domain-specific long-term search repositories.

Potential future work such as large-PDF rebuild caching, richer ranking/filter UX, or semantic/vector search requires a separately scoped Issue; it is not implied by completed #494/#753.

## Stop reason
**#753 is implemented, all CI passed, PR #757 merged, and the Issue is closed. No additional concrete Search/Indexing issue is currently assigned. Lane E is idle under the AGENTS.md stopping criteria until a new Search issue or cross-lane search obligation appears.**
