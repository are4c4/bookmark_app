# AI Progress — Search & Indexing Lane

> Lane E durable handoff. Before implementation, read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, current `main`, and open PRs touching Object/Body/Relation/primitive contracts.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe, and reusable by built-in primitives and user-defined ObjectTypes.

## Current issue state — 2026-09-08
- **#414 closed.** Legacy Bookmark FTS focused refresh stale-token bug was fixed before that legacy path was retired.
- **#494 closed.** Canonical Object search/indexing is the live product path.
- **#753 closed.** Malformed persisted Body is isolated to the `body` bucket; implemented by #757 (`f66c74bd7cf93365c72f22c9a880845de9673b12`).
- **#769 closed.** Malformed persisted Relation values cannot leave stale target labels searchable; implemented by #774 (`c36315706b45bbfb73185c6a69c64993bf71e64b`).
- **Relation #773 merged** as `66d3da4d80f2a8b071410dff0d86cbf62e92ddbb`; Search inherits its persisted/index consistency contract through `RelationReadService`.
- **#782 closed.** Search regressions prove serialized/index Relation disagreement fails closed without duplicating Relation integrity logic; implemented by #785 (`34604856d81852bf3058502c59689e7f2c23462c`).
- **#797 closed.** Generic Property search treats `system: true` metadata as non-searchable unless `searchable: true` explicitly opts it in; implemented by #799 (`4e685bccafdfa3fde47aadee0e6dfe424bba85c6`).
- **#807 closed.** Search-opened detail return performs focused refresh and replays the active query; implemented by #822 (`b80ec83b60fa997328e5ce57347d09fdfed70e2f`).
- **#828 closed.** Re-entering cached Global Search from another shell destination recreates Search so cross-page edits are visible; implemented by #831 (`dfc4836a76f640456ad34c61d26db41ff7b555d6`).
- **#847 closed.** Strict ObjectType schema corruption is isolated across canonical projection, Relation labels, optional File/PDF reconciliation, and result resolution; implemented by #849 (`c945aa20c1d35842aeb19f653b80a2edcec931e4`).
- **#877 closed.** Focused detail-return refresh includes trustworthy current outgoing Relation targets and each target's Relation-label dependents; implemented by #884 (`f1651ba169240484f3376f6c67f7ce76a810172b`).
- **#888 closed.** Search-opened nested Inspector navigation tracks every visited Object and refreshes each through the same focused planner, covering non-Relation navigation such as Daily Note previous/next/today; implemented by #894 (`ac470eec38115569d58dd04e2bc384d01bd59dd6`).
- **#900 closed.** Background Weblink preview ingestion now reports the durably created/reused Image id and production composition applies focused Search label-dependent refresh, so an Image created after Search's initial rebuild and its Weblink relation-label row become fresh without shell re-entry; implemented by #902 (`c34ed6377db011dbff4c200a97fde91a06b2f4f2`).
- Latest verified Search implementation checkpoint: **main `c34ed6377db011dbff4c200a97fde91a06b2f4f2`**.
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
- **Weblink metadata** — URL, Domain, Page title, Site name and Description in a dedicated bucket; hidden/system media metadata such as Preview image URL is consumed but not searchable;
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
- Relation #758 + Search #774 — strict persisted Relation inspection reused by Search;
- Relation #773 + Search #782/#785 — persisted/index Relation consistency inherited by Search;
- #799 — system-maintained Property metadata default-deny for free-text search;
- #822 — Search-opened detail focused refresh and active-query replay;
- #831 — shell Search re-entry invalidation for edits made outside Search;
- #849 — strict ObjectType schema corruption isolation across projection, Relation labels, PDF reconciliation, and result resolution;
- #884 — detail-return refresh expands to canonical outgoing Relation targets and target dependents without a workspace rebuild;
- #894 — detail-return refresh tracks nested Inspector visits and applies the same focused refresh plan to every visited Object;
- #902 — background Weblink preview completion emits only canonical Image impact and production composition refreshes that Image plus current Relation-label dependents without awaiting remote I/O or rebuilding the workspace.

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
Relation owns persisted Relation inspection/integrity/mutation/read consistency. Search does not create a second Relation parser, edge authority model, or repair path.

Current trust boundary:
- malformed persisted Relation value => that Property contributes no `relation_labels`;
- persisted/index disagreement on target ids/count/order/positions => canonical `RelationReadService` returns no trustworthy outgoing projection for that Property;
- invalid target ObjectType/workspace consistency fails closed;
- valid Relation Properties on the same Object continue to contribute;
- raw persisted ids and stale normalized edges are never independently used as fallback search labels;
- focused refresh removes prior labels that became untrustworthy;
- Search never repairs Relation values or normalized edges;
- if target ObjectType schema hydration itself throws `FormatException`, only the optional Relation-derived contribution/planning expansion is omitted for an otherwise healthy source Object.

Regressions:
- `test/repositories/object_search_malformed_relation_test.dart`;
- `test/repositories/object_search_relation_read_consistency_test.dart`;
- `test/repositories/object_search_corrupt_object_type_test.dart`;
- `test/repositories/object_search_refresh_planner_test.dart`.

### System-maintained Property metadata
Generic free-text Property search is default-deny for internal system metadata:
- `system: true` => omitted from the generic `properties` bucket by default;
- `system: true, searchable: true` => explicit opt-in;
- user-facing File metadata such as Original filename / Content type / Extension remains searchable because it is not system-maintained;
- managed path, SHA-256, Storage ownership and similar internal identity/lifecycle values must not become accidental free-text tokens.

Regression coverage is in the Property contributor and real File search integration tests added by #799.

### Corrupt ObjectType schemas
Object Core owns strict ObjectType/Property schema decoding. Unknown persisted Property storage types fail closed with `FormatException`; Search does not reinterpret them.

#849 establishes four Search boundaries:
1. **projection** — a corrupt ObjectType is omitted from the current projection pass while healthy ObjectTypes continue; focused refresh can still delete its stale row;
2. **Relation labels** — a healthy source may keep non-Relation buckets while Relation-label resolution fails closed on a corrupt related ObjectType;
3. **File/PDF reconciliation** — corrupt canonical File schema skips only optional PDF reconciliation, then canonical workspace FTS rebuild still runs;
4. **result resolution** — stale hits for a corrupt ObjectType are dropped while healthy hits retain ranking/order.

Schema repair restores normal Object/Relation/PDF indexing on the next normal rebuild/refresh. Unrelated DB/FTS failures still surface.

Regressions:
- `test/repositories/object_search_corrupt_object_type_test.dart`;
- `test/repositories/canonical_file_pdf_search_indexer_test.dart`;
- `test/repositories/object_search_result_resolver_test.dart`.

## Incremental / stale-token contracts
- focused Object refresh removes the previous FTS row by FTS `rowid` and inserts the current projection;
- removed/changed title, alias, Property, Body, Relation, Weblink and derived-text tokens must disappear;
- Relation target display changes can refresh affected backlink source Objects without a workspace rebuild;
- the label-change planner may use canonical raw backlinks to enumerate affected source ids, while each source reindex still passes through Relation trust checks;
- Search-opened detail return uses focused refresh rather than a workspace rebuild;
- #884 detail-return planning refreshes the opened Object, its existing label dependents, trustworthy current outgoing Relation targets from `RelationReadService.outgoing(...)`, and each target's label dependents;
- outgoing-target planning is only invalidation input: it never converts raw ids/edges into searchable text;
- optional Relation target expansion fails closed on `FormatException`, while unrelated persistence/index failures still surface through the existing Search error boundary;
- #894 records Object ids visited while one Search-opened Inspector route is active, including nested Inspector pushes that are not Relation-backed;
- on return, visited ids are deterministically de-duplicated, their current ObjectType ids are re-resolved through `ObjectGraphQueryStore.getNode()`, and each existing Object reuses the #884 `forDetailReturn()` planner;
- missing/deleted visited Objects keep their ids in the refresh set so stale FTS rows are physically removed rather than merely hidden by result resolution;
- the Inspector callback is generic presentation/navigation impact metadata only: `ObjectInspectorPage` does not import Search services and is not a second Object/Relation authority;
- #902 keeps remote preview ingestion non-blocking: `ObjectSyncService` continues launching it with `unawaited(...)`, and only after `WeblinkPreviewImagePipeline.ingestIfMissing(...)` returns a durably verified Image/Representative Relation does it invoke the optional Image-id completion callback;
- production composition wires that Image id to `ObjectGlobalSearchService.refreshObjectLabelDependents(...)`, so the Image and current backlink sources such as its Weblink refresh through canonical projection without the preview pipeline importing Search or writing FTS directly;
- a post-ingestion Search refresh failure is best-effort and must not undo successful canonical preview mutation, force network retry, or expose URL/path/exception content through UI;
- repeated preview attempts for the same URL in one live sync service remain de-duplicated by the existing attempt guard;
- derived producers replace only their own source key;
- PDF re-extraction replaces `pdf-text`; blank/missing/non-PDF capability clears that contribution;
- malformed/inconsistent/corrupt optional source data is a source-local omission, not permission to retain stale tokens;
- shell re-entry from another destination recreates Global Search so cross-page changes are reflected (#831);
- derived/search metadata is rebuildable and is never canonical Object identity.

Focused regressions:
- `test/object_global_search_weblink_promotion_refresh_test.dart` — #884 Search -> detail -> Weblink create/reuse -> return freshness;
- `test/object_global_search_daily_note_refresh_test.dart` — #894 Search -> Daily Note A -> Daily Note B -> Body edit -> return, proving new Body token appears and stale token disappears;
- `test/repositories/object_global_search_visited_refresh_test.dart` — duplicate visited ids and deleted visited Object stale-row removal;
- `test/object_sync_preview_image_search_refresh_test.dart` — #902 delayed remote preview completes after Search rebuild and focused completion refresh makes both Image and Weblink relation-label projection searchable; callback failure does not undo canonical preview success;
- `test/object_sync_search_refresh_wiring_test.dart` — production bootstrap/workspace-switch composition cannot silently bypass the preview completion refresh callback;
- `test/global_search_page_error_test.dart` — detail-return refresh failures stay behind the stable privacy-safe Search error boundary.

## Live product routing
`GlobalSearchPage` is a compatibility entrypoint that resolves canonical Object search context and renders `ObjectGlobalSearchPage`.

There is no live Bookmark-only FTS repository after #654. New domains participate by contributing to the canonical Object projection rather than adding separate long-term search repositories.

Global Search workspace rebuild reconciles optional canonical File/PDF extracted text before rebuilding FTS. A corrupt File schema must not prevent the FTS rebuild.

Background Weblink preview ingestion is not Search-owned enrichment. Primitive/Object services keep Image identity/storage/Relation mutation ownership; the app composition root merely forwards the resulting canonical Image impact to Search's existing focused refresh boundary.

## Validation
Recent Search correctness slices passed repository Flutter CI before merge:
- #799 / system metadata privacy boundary;
- #822 / original detail-return freshness;
- #831 / shell Search re-entry freshness;
- #849 / strict schema corruption isolation;
- #884 / related-Object detail-return focused refresh;
- #894 / nested visited-Object detail-return refresh;
- #902 / background Weblink preview Image completion refresh.

#884 passed Flutter CI #2700. #894 passed Flutter CI #2725. #902 passed Flutter CI #2738. The #902 run included:
- maintainability guardrail tests;
- maintainability regression ceilings;
- feature legacy-dependency guard;
- feature presentation error-privacy guard;
- Drift code generation;
- `flutter analyze`;
- full Flutter test suite.

The superseded #883 head carried the #877/#884 code/test delta and also passed CI #2696 before #884 was recreated directly from current main. Handoff PR #887 was intentionally closed unmerged after #888 was discovered so Lane E would not be recorded as idle prematurely. Handoff PR #898 then recorded #877/#888 completion before the later #900 re-audit found the background preview race.

## Cross-lane dependencies / ownership
- Object Core owns Body persistence/parsing and strict ObjectType/Property schema decoding; Search owns source-local omission and stale-row behavior at its consumption boundaries.
- Object presentation owns reusable Inspector navigation. #894 adds only an optional generic visited-Object callback and propagates it through nested Inspector pushes; Search owns collecting that metadata and deciding FTS invalidation.
- Relation owns Relation persistence, strict stored-value inspection, integrity, mutation, and canonical read consistency; Search owns denormalized trustworthy label indexing and refresh invalidation planning. #884 deliberately reuses `RelationReadService.outgoing(...)` for trustworthy target enumeration instead of introducing a second Relation authority model.
- Primitive/Object owns Weblink remote preview enrichment plus canonical Image identity/storage and Representative Image Relation mutation. #902 adds only a generic post-ingestion Image-id callback to `ObjectSyncService`; the production composition root wires it to Search focused refresh. The preview pipeline does not import Search or become an FTS authority.
- Primitive owns File/PDF identity, extraction and native behavior; Search owns derived-text persistence/index/reconciliation and ensures optional PDF capability failure does not take down canonical FTS.
- Refactor owns behavior-preserving legacy retirement; Bookmark-only FTS retirement is complete.
- Lane E currently holds no shared-hotspot lease after #902 merge.

## Next actions
There is no remaining Search-owned actionable work in #414, #494, #753, #769, #782, #797, #807, #828, #847, #877, #888, or #900.

For the next Lane E run:
1. Re-read current `main`, open Issues/PRs, and recent cross-lane changes before creating work.
2. Resume implementation only for a concrete Search/Indexing issue or demonstrated cross-lane Search correctness obligation.
3. Reuse canonical Object/Body/Relation/Primitive trust boundaries rather than duplicating parsing/integrity semantics in Search.
4. Prefer source-local fail-closed contribution/planning boundaries over allowing one corrupt optional source to take down the canonical index.
5. Do not swallow unrelated persistence/index errors and do not log raw user content, extracted text, private paths, malformed payloads, or internal metadata.
6. Keep system-maintained metadata non-searchable unless a deliberate product requirement explicitly opts it in.
7. Preserve focused invalidation; do not replace #822/#884/#894/#902 with routine full-workspace rebuilds or a workspace mutation event bus without a separately scoped requirement.
8. For asynchronous cross-lane mutations, prefer narrow canonical impact callbacks at composition boundaries rather than making producers depend on Search repositories.
9. Do not recreate domain-specific long-term search repositories.

Potential future work such as large-PDF rebuild caching, richer ranking/filter UX, semantic/vector search, or a workspace-wide mutation event bus requires a separately scoped Issue; it is not implied by completed correctness work.

## Stop reason
**#877, #888 and #900 are complete. #884 is merged as `f1651ba169240484f3376f6c67f7ce76a810172b` with Flutter CI #2700 green, #894 is merged as `ac470eec38115569d58dd04e2bc384d01bd59dd6` with Flutter CI #2725 green, and #902 is merged as `c34ed6377db011dbff4c200a97fde91a06b2f4f2` with Flutter CI #2738 green. Canonical Search freshness now covers Search-opened related/nested detail mutations and production background Weblink preview Image ingestion while preserving focused invalidation, canonical Object/Relation ownership, Search-owned projection, non-blocking enrichment and privacy-safe failure isolation. Live GitHub re-audit after #902 has not yet found another open Search-owned Issue, so Lane E is idle under the `AGENTS.md` stopping criteria unless a new concrete Search obligation is demonstrated.**
