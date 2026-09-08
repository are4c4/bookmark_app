# AI Progress — Search & Indexing Lane

> Lane E durable handoff. Before implementation, read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, current `main`, and open PRs touching Object/Body/Relation/primitive contracts.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe, and reusable by built-in primitives and user-defined ObjectTypes. Search owns FTS projection, invalidation planning, reconciliation and result behavior; mutation producers expose only narrow canonical impact and never write FTS directly.

## Current issue state — 2026-09-08
Completed/closed Search correctness issues include:
- #414 / #494 — canonical Object search is the live product path; legacy Bookmark-only FTS is retired.
- #753/#757 — malformed persisted Body is isolated to the `body` bucket.
- #769/#774 and #782/#785 — malformed/inconsistent Relation values fail closed for relation-label projection without duplicating Relation authority.
- #797/#799 — system-maintained Property metadata is non-searchable by default unless explicitly opted in.
- #807/#822 — Search-opened detail return performs focused refresh and replays the active query.
- #828/#831 — re-entering cached Global Search after edits outside Search recreates Search so cross-page edits are visible.
- #847/#849 — corrupt ObjectType schema is isolated across projection, Relation labels, optional PDF reconciliation and result resolution.
- #877/#884 — detail-return refresh expands to trustworthy outgoing Relation targets and their label dependents.
- #888/#894 — nested Inspector visits, including non-Relation Daily Note navigation, participate in focused return refresh.
- #900/#902 — background Weblink preview Image ingestion refreshes the canonical Image plus label dependents after delayed remote completion.
- #907/#913 — live legacy Bookmark mirror changes produced while Search stays mounted trigger focused canonical Object refresh.

Object Core follow-up #909 is also completed through PR #923 and now makes the #913 mirror callback **exact** rather than broad: unchanged mirror passes do not emit false-positive Object ids.

There is currently **no open Search-owned Issue** in the live audit. Lane E is idle by design until a concrete Search/Indexing correctness or product requirement appears.

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

Workspace/ObjectType filtering uses canonical ids. Query behavior remains prefix-based with FTS5 BM25 ranking.

## Focused freshness architecture
Search freshness now covers several distinct production mutation timings without routine workspace rebuilds.

### Search-opened detail mutations — #822/#884/#894
On return from a Search-opened detail route:
- refresh the root Object;
- include existing label dependents;
- include trustworthy current outgoing Relation targets from canonical Relation reads and their dependents;
- track every Object visited through nested Inspector navigation, including non-Relation Daily Note previous/next/today navigation;
- keep missing/deleted visited ids in the refresh set so stale FTS rows are physically removed.

The Inspector callback is generic navigation-impact metadata only. Presentation does not import Search services.

### Background Weblink preview completion — #900/#902
PR #902 merged as `c34ed6377db011dbff4c200a97fde91a06b2f4f2`; Flutter CI #2738 was full green.

Production contract:
- `ObjectSyncService` keeps remote preview ingestion unawaited/best-effort;
- after `WeblinkPreviewImagePipeline.ingestIfMissing(...)` returns a durably verified canonical Image id, the optional `onPreviewImageIngested(int)` callback fires;
- app composition wires that id to `ObjectGlobalSearchService.refreshObjectLabelDependents`;
- this refreshes the Image itself plus current backlink sources, including the Weblink whose Representative Image relation changed;
- callback failure cannot undo successful Image/Relation persistence and diagnostics exclude URL/path/id/user content;
- repeated preview sync in one live service does not create duplicate completion impact for the same unchanged URL.

Regression `test/object_sync_preview_image_search_refresh_test.dart` reproduces delayed network I/O: Search rebuild finishes first, preview ingestion finishes later, then both Image title and Weblink relation-label search become current without Search re-entry or workspace rebuild.

### Live legacy mirror changes while Search remains mounted — #907/#913
PR #913 merged as `53fde6f305fb745d31a1faf2597bd105922935fc`; #907 is completed/closed.

This covers the real global-file-drop ordering:
1. live `ObjectSyncService` watcher is active;
2. Global Search rebuild completes;
3. `GlobalFileDropLayer` creates legacy Bookmark/workspace data while Search remains visible;
4. the existing debounced mirror later creates/updates canonical Bookmark/Weblink Objects;
5. the generic `onCanonicalObjectsMirrored(Iterable<int>)` callback forwards canonical impact to `ObjectGlobalSearchService.refreshObjectLabelDependentsFor(...)`;
6. focused refresh updates only affected canonical rows and label dependents.

`GlobalFileDropLayer`, compatibility bridges and Object stores do not import Search or write FTS. The 250 ms live mirror debounce remains intact. No polling, timestamp heuristic or workspace mutation event bus was introduced.

Regressions include:
- `test/object_sync_global_file_drop_search_refresh_test.dart` — Search rebuild first, watcher mutation second, focused canonical Bookmark/Weblink refresh third;
- deletion path physically removes stale FTS rows;
- downstream Search callback failure cannot roll back canonical Bookmark -> Weblink persistence;
- production wiring guard proves bootstrap/profile and workspace-switch Object sync hosts use the same composition boundary.

### Exact canonical impact refinement — Object Core #909/#923
PR #923 merged as `03acb81633031cb833975196b29f66947d9de747`; Flutter CI #2795 was full green.

Lane A now owns exactness of the generic sync-impact seam:
- immutable `ObjectSyncImpact` contains canonical Object ids only;
- semantic comparison uses canonical title + persisted Value state and excludes timestamps;
- bridge-local candidates are filtered again by whole-pass before/after state, cancelling transient compatibility writes retired later in the same pass;
- unchanged repeat sync produces no notification;
- new target retarget reports changed Bookmark + new Weblink;
- retarget to an already-existing unchanged Weblink reports only the changed Bookmark source;
- deletion reports the deleted canonical id so Search can remove its row;
- callback failure remains post-persistence and isolated.

Search **does not** own or reinterpret that semantic snapshot. It consumes the canonical ids as invalidation input and owns `refreshObjectLabelDependentsFor(...)` planning/FTS writes.

## Fail-closed source contracts
### Body
Object Core owns Body persistence/parsing. Search catches source-local `FormatException` for malformed Body contribution, contributes an empty `body` bucket, and replaces the old FTS row so stale tokens disappear. Unrelated database/index failures still surface.

### Relation labels
Relation owns persisted Relation inspection, index consistency, target/cardinality validation, mutation and read authority. Search never falls back to raw ids or stale normalized edges. Untrusted Relation state contributes no relation label for that Property; healthy source buckets remain indexable.

### System-maintained metadata
Generic free-text Property search is default-deny for internal `system: true` metadata unless `searchable: true` explicitly opts it in. Managed paths, SHA-256, storage ownership and similar lifecycle metadata must not become accidental search tokens.

### Corrupt ObjectType schemas
Unknown persisted Property storage types fail closed at Object Core. Search isolates corrupt ObjectTypes/source contributions where possible, removes stale rows on focused refresh, and does not reinterpret invalid schema metadata.

## Incremental / stale-token contracts
- focused Object refresh removes the previous FTS row by rowid and inserts the current projection;
- changed/removed title, alias, Property, Body, Relation, Weblink and derived-text tokens must disappear;
- label-change refresh may enumerate canonical backlink source ids, but each source reindex still passes through Relation trust checks;
- mutation/completion callbacks contain only invalidation metadata, never searchable text;
- missing/deleted impacted ids remain refreshable so stale rows are physically removed;
- derived producers replace only their own source key;
- PDF re-extraction replaces `pdf-text`; blank/missing/non-PDF capability clears that contribution;
- derived/search metadata is rebuildable and is never canonical Object identity;
- routine background producers must prefer focused refresh over a full workspace rebuild.

## Live product routing
`GlobalSearchPage` resolves canonical Object search context and renders `ObjectGlobalSearchPage`.

There is no live Bookmark-only FTS repository after Refactor #654. New domains participate by contributing to the canonical Object projection rather than adding separate long-term search repositories.

Global Search workspace rebuild still reconciles optional canonical File/PDF extracted text before rebuilding FTS. Corrupt optional File/PDF capability/schema must not prevent the canonical workspace FTS rebuild.

## Cross-lane dependencies / ownership
- **Object Core:** Body/schema authority plus Search-agnostic canonical sync-impact truthfulness/exactness (#909). Search consumes ids only.
- **Relation:** Relation persistence/integrity/read consistency. Search owns trustworthy label indexing and dependent refresh planning.
- **Primitive:** File/PDF/Weblink/Image identity, enrichment and native behavior. Search owns searchable projection/derived text and post-mutation refresh planning.
- **Presentation:** exposes generic navigation-impact callbacks only; it does not own FTS invalidation.
- **Refactor:** legacy Search retirement is complete; do not recreate a Bookmark/domain-specific search product.

Lane E currently holds no shared-hotspot lease.

## Validation
Recent relevant CI checkpoints:
- #884 / CI #2700 — related-Object detail-return focused refresh;
- #894 / CI #2725 — nested visited-Object refresh;
- #902 / CI #2738 — delayed background preview Image freshness;
- #913 / CI #2763 — live legacy mirror -> focused Search refresh;
- Object #923 / CI #2795 — exact canonical impact consumed by the same Search boundary.

The final #923 CI passed maintainability/feature guards, Drift generation, `flutter analyze`, and the full Flutter test suite.

## Exact next actions
1. Re-read current `main`, open Issues/PRs and recent cross-lane changes before creating Search work.
2. Resume only for a concrete Search/Indexing issue or demonstrated cross-lane Search correctness obligation.
3. Reuse canonical Object/Body/Relation/Primitive trust boundaries rather than duplicating parsing/integrity semantics in Search.
4. Keep focused mutation/return invalidation; do not regress to routine workspace rebuilds, polling, timestamp same-second detection, or a workspace mutation event bus.
5. Do not swallow unrelated persistence/index errors and do not log raw user content, extracted text, private paths, malformed payloads or internal metadata.
6. Keep system-maintained metadata non-searchable unless a deliberate product requirement explicitly opts it in.
7. Do not recreate domain-specific long-term search repositories.

Potential future work such as large-PDF rebuild caching, richer ranking/filter UX, semantic/vector search, or a general mutation bus requires a separately scoped Issue.

## Latest run checkpoint / stop reason — 2026-09-08
- #900 completed through PR #902 / `c34ed6377db011dbff4c200a97fde91a06b2f4f2`; CI #2738 full green.
- #907 completed through PR #913 / `53fde6f305fb745d31a1faf2597bd105922935fc`; CI #2763 green.
- Object Core #909 completed through PR #923 / `03acb81633031cb833975196b29f66947d9de747`; CI #2795 full green and removes unchanged-pass false-positive mirror impact without changing Search ownership.
- This handoff branch starts from main `5659edaf9bfc21a04592ca3d3cc7fbf13fcca80b`. Lane A handoff is owned separately by PR #928 and repository-wide/Lane C routing by PR #929, so this PR intentionally changes only `docs/AI_PROGRESS_SEARCH.md`.
- **Lane E is idle under the `AGENTS.md` stopping criteria until a new concrete Search obligation appears.**
