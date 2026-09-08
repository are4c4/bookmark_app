# AI Progress — Search & Indexing Lane

> Lane E durable handoff. Before implementation, read `AGENTS.md`, the active focused Issue, `docs/AI_PROGRESS.md`, current `main`, this file, and live PR diffs touching Object/Body/Relation/primitive/Search contracts.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe, and reusable by built-in primitives and user-defined ObjectTypes.

Search owns:
- canonical FTS projection and query behavior;
- trustworthy source contribution rules;
- focused invalidation planning and FTS writes;
- Search-local projection freshness notification;
- mounted Global Search query replay after focused refresh;
- fail-closed result resolution and privacy-safe error behavior.

Mutation producers own their domain state and expose only narrow canonical impact. They do **not** import Search presentation or write Search FTS directly.

## Current checkpoint — 2026-09-08
The latest focused Search correctness issue, #934, is completed through PR #935.

Recent completed checkpoints:
- #414 / #494 — canonical Object search became the live product path; legacy Bookmark-only FTS was retired later by Refactor #654.
- #753/#757 — malformed Body is isolated to the `body` contribution.
- #769/#774 and #782/#785 — malformed/inconsistent Relation state fails closed for Relation-label projection.
- #797/#799 — system-maintained Property metadata is non-searchable by default unless explicitly opted in.
- #807/#822 — Search-opened detail return performs focused refresh.
- #828/#831 — re-entering cached Global Search after edits outside Search recreates Search so cross-page edits are visible.
- #847/#849 — corrupt ObjectType schema is isolated across projection, optional PDF reconciliation and result resolution.
- #877/#884 — detail-return refresh expands to trustworthy outgoing Relation targets and label dependents.
- #888/#894 — nested Inspector visits, including non-Relation Daily Note navigation, participate in focused return refresh.
- #900/#902 — delayed Weblink preview Image ingestion refreshes Search after remote completion.
- #907/#913 — live legacy Bookmark mirror changes while Search remains mounted trigger focused canonical refresh.
- Object Core #909/#923 — the mirror callback reports only canonical Object ids whose semantic state actually changed.
- #934/#935 — a mounted non-empty Global Search query automatically reruns after successful background focused Search refresh, even when producer and page use different `ObjectGlobalSearchService` instances.

Do not infer future work from this snapshot. On resume, re-audit live Issues/PRs. Lane E should remain idle when there is no concrete Search/Indexing correctness or product obligation.

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
- **body** — universal Body text projection, never serialized block JSON;
- **relation labels** — trustworthy resolved target Object titles only, never raw Relation/Object ids;
- **Weblink metadata** — URL, Domain, Page title, Site name and Description in a dedicated bucket;
- **derived text** — replaceable source-keyed metadata such as canonical File PDF `pdf-text`.

Workspace/ObjectType filtering uses canonical ids. Query behavior remains prefix-based with FTS5 BM25 ranking. Search result ids are resolved back through canonical Object/ObjectType state; stale or inconsistent hits fail closed.

## Freshness architecture
Search freshness has two layers:

1. **Projection freshness** — affected FTS rows are rebuilt or removed after a trustworthy mutation impact.
2. **Visible-query freshness** — if Global Search is already mounted with a non-empty query, successful focused projection refresh causes that active query to replay automatically.

Routine background paths must use focused refresh. Do not regress to polling, timestamps, routine workspace rebuilds, or a domain/workspace mutation event bus.

### Search-opened detail mutations — #822/#884/#894
On return from a Search-opened detail route:
- refresh every Object visited while that route was active;
- include existing label dependents;
- include trustworthy current outgoing Relation targets and their dependents;
- support non-Relation nested navigation such as Daily Note previous/next/today;
- keep missing/deleted visited ids refreshable so stale FTS rows are physically removed.

The Inspector exposes generic navigation-impact metadata only. Presentation does not import Search services.

Detail-return focused refresh now participates in the same Search-local projection-change mechanism used by background refresh; it no longer needs a separate manual query-replay authority.

### Background Weblink preview completion — #900/#902
PR #902 merged as `c34ed6377db011dbff4c200a97fde91a06b2f4f2`; Flutter CI #2738 was full green.

Contract:
- `ObjectSyncService` keeps remote preview ingestion unawaited/best-effort;
- after `WeblinkPreviewImagePipeline.ingestIfMissing(...)` durably verifies a canonical Image, `onPreviewImageIngested(int)` reports only the Image Object id;
- production composition calls `ObjectGlobalSearchService.refreshObjectLabelDependents(...)`;
- Search refreshes the Image and current backlink/label dependents such as the Weblink whose Representative Image changed;
- callback failure cannot roll back canonical Image/Relation persistence;
- diagnostics must not expose URL/path/id/user content.

Regression: `test/object_sync_preview_image_search_refresh_test.dart` reproduces Search rebuild first, delayed network completion second, focused Image/Weblink refresh third.

### Live legacy mirror changes — #907/#913 + Object Core #909/#923
PR #913 merged as `53fde6f305fb745d31a1faf2597bd105922935fc`; Flutter CI #2763 was full green.

Real ordering covered:
1. live `ObjectSyncService` watcher is active;
2. Global Search rebuild completes;
3. a legacy producer such as `GlobalFileDropLayer` changes Bookmark/workspace data while Search remains mounted;
4. the existing debounced mirror creates/updates canonical Bookmark/Weblink Objects;
5. `onCanonicalObjectsMirrored(Iterable<int>)` reports canonical impact;
6. `ObjectGlobalSearchService.refreshObjectLabelDependentsFor(...)` performs focused Search refresh.

Object Core #909 refined that impact in PR #923 (`03acb81633031cb833975196b29f66947d9de747`, CI #2795 full green):
- impact contains canonical Object ids only;
- semantic comparison uses canonical title + persisted Value state and excludes timestamps;
- unchanged repeat sync emits nothing;
- transient compatibility writes cancelled within the same whole sync pass do not become false-positive impact;
- retarget to a new Weblink reports changed Bookmark + new Weblink;
- retarget to an already-existing unchanged Weblink reports only the changed Bookmark;
- deletion reports the deleted canonical id so Search can physically remove stale FTS state;
- callback failure remains post-persistence and isolated.

Search consumes those ids as invalidation input. It does not own or reinterpret Object Core's semantic mirror snapshot.

Regression: `test/object_sync_global_file_drop_search_refresh_test.dart` covers creation, deletion/stale-row cleanup and downstream Search callback failure isolation.

### Mounted active-query replay — #934/#935
PR #935 merged as `0b9e83e52728f8ea4afcc32a6d16f89b7284b9ca`; Flutter CI #2823 was full green.

The remaining gap after #902/#913 was presentation freshness: focused refresh could make `object_search_fts` correct while `ObjectGlobalSearchPage` still displayed cached `_results` until query edit, re-entry, detail return or manual rebuild.

The current contract:
- `ObjectGlobalSearchService` exposes a **Search-owned, database-scoped projection-change stream**;
- distinct `ObjectGlobalSearchService` instances backed by the same `AppDatabase` observe the same Search projection signal;
- focused Search refresh emits only **after** its FTS work succeeds;
- workspace rebuild remains explicit and does not become a generic mutation event source;
- `ObjectGlobalSearchPage` subscribes to projection changes and replays only a non-empty active query;
- replay is microtask-coalesced, with no artificial polling/timer latency;
- clearing the query or starting a rebuild invalidates in-flight query results;
- each search request receives a monotonically increasing generation; only the latest generation may update results or surface query failure;
- therefore an older request for the **same query text** cannot finish late and overwrite fresher results produced after a projection refresh;
- blank queries do not trigger background searches.

This is deliberately a Search projection notification, not a domain mutation bus. Object/Relation/Primitive producers continue to expose only canonical mutation impact.

Regressions in `test/object_global_search_page_test.dart` prove:
- two separate Search service instances over one database: page query is initially empty-result, another service performs focused `refreshObject(...)`, and the mounted page shows the new Object without query edit/re-entry/manual rebuild;
- an intentionally delayed pre-refresh request for the same query cannot overwrite the newer replay result when it completes later;
- existing Search-opened detail-return Relation-label behavior still works through the unified projection replay path.

## Fail-closed source contracts
### Body
Object Core owns Body persistence/parsing. Search catches source-local `FormatException` for malformed Body contribution, contributes an empty `body` bucket, and replaces the previous FTS row so stale Body tokens disappear. Unrelated persistence/index failures still surface.

### Relation labels
Relation owns Relation persistence, integrity, target/cardinality validation, mutation and read authority. Search never falls back to raw ids or stale normalized edges. Untrusted Relation state contributes no label for that Property while healthy source buckets remain indexable.

### System-maintained metadata
Generic free-text Property search is default-deny for internal `system: true` metadata unless `searchable: true` explicitly opts it in. Managed paths, hashes, storage ownership and lifecycle metadata must not become accidental search tokens.

### Corrupt ObjectType schemas
Unknown persisted Property storage types fail closed at Object Core. Search isolates corrupt ObjectTypes/source contributions where possible, removes stale rows on focused refresh, and does not reinterpret invalid schema metadata.

## Incremental / stale-token contracts
- focused Object refresh removes the previous FTS row by rowid and inserts the current projection;
- changed/removed title, alias, Property, Body, Relation, Weblink and derived-text tokens must disappear;
- label-change refresh may enumerate canonical backlink source ids, but each source reindex still passes Relation trust checks;
- mutation/completion callbacks contain only invalidation metadata, never searchable text;
- missing/deleted impacted ids remain refreshable so stale rows are physically removed;
- derived producers replace only their own source key;
- PDF re-extraction replaces `pdf-text`; blank/missing/non-PDF capability clears that contribution;
- derived/search metadata is rebuildable and is never canonical Object identity;
- successful focused refresh emits the Search-local projection signal used for mounted-query replay;
- stale async query results cannot overwrite later query generations;
- routine background producers must prefer focused refresh over full workspace rebuild.

## Live product routing
`GlobalSearchPage` resolves canonical Object search context and renders `ObjectGlobalSearchPage`.

There is no live Bookmark-only FTS repository after Refactor #654. New domains participate by contributing to the canonical Object projection rather than creating domain-specific long-term search repositories.

Global Search workspace rebuild still reconciles optional canonical File/PDF extracted text before rebuilding FTS. Corrupt optional File/PDF capability/schema must not prevent canonical workspace FTS rebuild.

The mounted page's visible-result freshness is now driven by the Search-local projection-change stream, so producer-side focused refresh and page-side Search service instances do not need to be the same object instance.

## Cross-lane dependencies / ownership
- **Object Core:** Body/schema authority plus Search-agnostic canonical sync-impact truthfulness/exactness. Search consumes ids only.
- **Relation:** Relation persistence/integrity/read consistency. Search owns trustworthy label indexing and dependent refresh planning.
- **Primitive:** File/PDF/Weblink/Image identity, enrichment and native behavior. Search owns searchable projection/derived text and post-mutation refresh planning.
- **Presentation:** consumes Search result/query state and generic navigation-impact callbacks; domain presentation does not own FTS invalidation.
- **Refactor:** legacy Search retirement is complete; do not recreate Bookmark/domain-specific search products.

Do not infer a shared-hotspot lease from this file. Always inspect live open PR diffs immediately before editing Search or shared Object/Relation/primitive hosts.

## Validation checkpoints
Recent relevant CI:
- #884 / CI #2700 — related-Object detail-return focused refresh;
- #894 / CI #2725 — nested visited-Object refresh;
- #902 / CI #2738 — delayed background preview Image freshness;
- #913 / CI #2763 — live legacy mirror -> focused Search refresh;
- Object #923 / CI #2795 — exact canonical impact;
- #935 / CI #2823 — mounted active-query projection replay + latest-request-wins race protection.

CI #2823 passed maintainability/feature guards, Drift generation, `flutter analyze`, and the full Flutter test suite.

## Exact next actions
1. Re-read current `main`, live open Issues/PRs, `AGENTS.md`, `docs/AI_PROGRESS.md`, and this handoff before creating Search work.
2. Resume only for a concrete Search/Indexing issue or demonstrated cross-lane Search correctness obligation.
3. Reuse canonical Object/Body/Relation/Primitive trust boundaries rather than duplicating parsing/integrity semantics in Search.
4. Preserve both layers of freshness: focused FTS projection update **and** mounted active-query replay.
5. Do not regress to routine workspace rebuilds, polling, timestamp heuristics, or a domain/workspace mutation event bus.
6. Do not swallow unrelated persistence/index errors and do not log raw user content, extracted text, private paths, malformed payloads or internal metadata.
7. Keep system-maintained metadata non-searchable unless a deliberate product requirement explicitly opts it in.
8. Do not recreate domain-specific long-term search repositories.

Potential future work such as large-PDF rebuild caching, richer ranking/filter UX, semantic/vector search, or a general mutation bus requires a separately scoped Issue.

## Latest run checkpoint / stop reason — 2026-09-08
- #900 completed through PR #902 / `c34ed6377db011dbff4c200a97fde91a06b2f4f2`; CI #2738 full green.
- #907 completed through PR #913 / `53fde6f305fb745d31a1faf2597bd105922935fc`; CI #2763 full green.
- Object Core #909 completed through PR #923 / `03acb81633031cb833975196b29f66947d9de747`; CI #2795 full green.
- #934 completed through PR #935 / `0b9e83e52728f8ea4afcc32a6d16f89b7284b9ca`; CI #2823 full green.
- The durable handoff refresh starts from main `4f01eee6f32525cb061771cdc75c350811b0101e`, which already contains #935 plus later non-Search #938.
- Re-audit live Issue/PR state on every resume rather than treating the current open/closed set as durable routing.
- **Lane E is idle under the `AGENTS.md` stopping criteria unless a new concrete Search obligation is found by that live audit.**
