# AI Progress — Search & Indexing Lane

> Lane E handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation.

## Lane goal
Converge search on one canonical Object-level indexing/query architecture that works for built-in primitives and user-defined ObjectTypes.

## Current issue state — 2026-09-07
- **#414 closed.** Focused Bookmark FTS refresh removes stale rows through FTS `rowid`; removed title/tag regressions are covered.
- **#494 closed as completed.** All acceptance criteria and the close condition are satisfied on main.
- Latest verified Search completion checkpoint: **main `683bdbb74cc5dabd3ac067e9ce5a802fc16ca2b4`**, the squash merge of #635.
- Refactor lane subsequently retired the caller-zero Bookmark-only `FullTextSearchRepository` in **#654**, merged as `c2d4bd082e1e88c6781db4f51b2c12998a6ff85f`.

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

Current contributors:
- **title / aliases** — canonical Object identity and aliases;
- **properties** — deterministic text/url/select/multi-select/number/date/rating values; Relation/File/Image/computed/internal values are excluded;
- **body** — universal Body blocks through the Body-owned text contributor rather than serialized block JSON;
- **relation labels** — resolved outgoing target Object titles only, never raw Relation/Object ids;
- **Weblink metadata** — URL, Domain, Page title, Site name and Description in the dedicated bucket; Content type, Published date, Favicon URL and Preview image URL are consumed but intentionally not searchable; unrelated user-added Weblink Properties remain in the generic Property bucket;
- **derived text** — replaceable search-only contributions keyed by canonical Object id + source key. `pdf-text` is the canonical PDF producer key.

FTS query behavior remains prefix-based with BM25 ranking. Workspace and optional ObjectType filtering use canonical ids without creating per-domain indexes.

## Completed checkpoints
Major merged Search-lane slices for #414/#494:
- #514 — canonical Object FTS foundation, title/aliases, workspace/ObjectType scope.
- #518 / #531 — universal Body contributor and `body` bucket integration.
- #523 / #543 / #554 — typed Property contributor, whole-Object projection and live `properties` integration.
- #529 — #414 stale Bookmark FTS focused-refresh fix using FTS `rowid`; #414 closed.
- #533 / #562 / #570 / #581 — Relation label contributor, backlink-dependent refresh planning, `relation_labels` integration and application-facing dependent refresh APIs.
- #545 / #565 — fail-closed canonical Object/ObjectType result resolution and `ObjectGlobalSearchService`.
- #551 / #578 — replaceable derived-text sink and `derived_text` FTS integration.
- #572 — canonical `ObjectGlobalSearchPage`, mixed ObjectType results and Object Inspector opening.
- #575 / #587 / #626 — Weblink projection ownership, dedicated Property-id exclusions and live `weblink_metadata` integration. #626 merged as `70375d3d...` after all CI passed.
- #584 / #589 — real canonical File/Image primitive metadata participates in the same Object search repository while managed file identity/path values remain non-searchable.
- #629 — live `GlobalSearchPage` delegates to canonical Object Global Search; old Bookmark-only `FullTextSearchRepository` stopped being a live UI dependency. A first maintainability failure caught an added presentation DB reach-through; `ObjectSearchCompatibilityBridge` moved that conversion outside presentation, after which guardrails, Analyze and full tests passed. #629 merged as `8f74c411...`.
- #635 — Lane D PDF extraction -> Search `pdf-text` -> canonical FTS -> `ObjectGlobalSearchService.rebuildWorkspace(...)`. Workspace rebuild reconciles canonical File PDF text before one FTS rebuild; focused `refreshFilePdfText(...)` replaces/clears only that File's derived contribution. All guardrails, Analyze and full tests passed; merged as `683bdbb7...`.

Cross-lane completion:
- Primitive lane #609 — `CanonicalFilePdfTextService` exposes optional content-first PDF extracted text for canonical File Objects without owning search persistence. #635 consumes this capability.
- Refactor lane #654 — removed the caller-zero legacy Bookmark `FullTextSearchRepository` implementation and its dedicated legacy-only tests after #629 proved live Object-search routing. Canonical Object search regressions remain the active coverage.

## Incremental / stale-token contracts
- focused Object refresh deletes the previous FTS row by `rowid` and inserts the current projection;
- title/alias/Property/Body/Relation/Weblink/derived-text tests cover stale-token removal;
- Relation target label changes can refresh the target plus current backlink source Objects without a workspace rebuild;
- derived producers replace only their own `sourceKey`, so one producer cannot erase another;
- PDF re-extraction replaces `pdf-text`; missing/blank/non-PDF capability clears the previous contribution before refresh;
- PDF-derived text is rebuildable search metadata, never File/Object identity;
- raw extracted text, private local file paths and raw search exceptions are not rendered/logged by normal diagnostics.

## Live product routing
`BookmarkAppShell` still calls `GlobalSearchPage(repository: ...)`, but that class is only a compatibility entrypoint. It resolves the Object search context through `ObjectSearchCompatibilityBridge` and renders `ObjectGlobalSearchPage`.

Therefore the live full-text search product is Object-based without rewriting the shared `app_shell.dart` hotspot. The former Bookmark-only `FullTextSearchRepository` is no longer present after Refactor #654; new work must not recreate a parallel Bookmark search product.

Global Search workspace rebuild also reconciles optional canonical File PDF extracted text. This makes user-defined ObjectTypes, Weblinks, Images/File metadata, Body notes, Relation labels and PDF-derived text participate in one application-facing Object search path.

## Validation
Search completion slices were gated by repository Flutter CI, including:
- maintainability guardrail tests;
- maintainability regression ceilings;
- feature legacy-dependency guard;
- `flutter analyze`;
- full Flutter test suite.

Focused regressions cover:
- title/alias and custom ObjectType search;
- workspace/ObjectType scoping;
- Body update/clear stale cleanup;
- typed Property inclusion/exclusion and internal-id non-leakage;
- Relation label rename/clear and dependent-source refresh;
- Weblink bucket ownership and hidden metadata non-leakage;
- real File/Image primitive metadata and managed-path non-leakage;
- derived-text replacement/source isolation;
- PDF content-first extraction, replacement and non-PDF clear through Global Search APIs;
- canonical Object result resolution/opening;
- Global Search stable error boundaries without exposing raw exception/path/query content.

Refactor #654 separately passed the repository validation gates before removing the caller-zero legacy Bookmark FTS implementation and its legacy-only tests.

## Cross-lane dependencies / ownership
- Primitive lane owns File/PDF extraction and native managed-resource behavior; Search consumes #609 through #635.
- Object Core owns Body persistence/editing; Search reads only its search-text projection.
- Relation lane owns Relation persistence/integrity; Search reads resolved labels and owns denormalized search refresh planning.
- Refactor lane completed the caller-zero Bookmark FTS retirement in #654 after Search #629 established replacement parity.
- No hotspot lease is held by Lane E. #629 deliberately avoided an `app_shell.dart` edit.

## Next actions
There is no remaining actionable work in #414 or #494.

For the next Lane E run:
1. Re-read GitHub for any newly opened Search/Indexing issue before creating work.
2. If no new Search issue exists, remain idle rather than inventing speculative search abstractions.
3. Potential follow-ups belong in separately scoped issues, for example PDF extraction/rebuild caching for very large File sets, richer ranking/filter UX, or semantic/vector search; none are required by #494.
4. Do not recreate a Bookmark/domain-specific long-term search repository; the legacy Bookmark FTS path was retired in #654.

## Safety
- Removing/changing source data must remove stale searchable tokens.
- Derived text is rebuildable/search-only metadata, not Object identity.
- Do not log raw user content, extracted file text, private file paths or raw search exceptions.
- New domains contribute to the canonical Object projection instead of introducing domain-specific long-term search repositories.

## Stop reason
**Active Lane E issues #414 and #494 are complete and closed; the legacy Bookmark FTS duplicate has also been retired by Refactor #654; no remaining actionable Search task is currently assigned.** This matches the AGENTS.md stopping condition for an idle lane. Resume only when a new Search/Indexing issue or a concrete cross-lane search obligation appears.
