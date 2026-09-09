# AI Progress — Search & Indexing Lane

> Durable Lane E handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history.

## Lane goal
Keep one canonical Object-level search/index architecture correct, stale-safe, privacy-safe and reusable by native and user-defined ObjectTypes.

## Architecture contract
- Search indexes Objects, not permanent domain-specific Bookmark/People/Tag repositories.
- `Bookmark` retirement must converge search onto canonical Weblink/generic Object state; do not add a new Bookmark-specific FTS path.
- Person and Tag/TagGroup participate through the same canonical Object projection.
- Tag hierarchy query semantics for Database/View filters belong to C; Lane E owns global Search/FTS only when hierarchy-aware global search behavior is explicitly required by a focused Issue.
- Native producers such as Weblink metadata or File/PDF extracted text expose canonical facts/impact; they do not write Search storage directly.

## Current state
Canonical Object Search is established and already covers focused freshness, Body/Property/Relation projection, corruption isolation, background completion refresh and mounted-query replay.

There is **no currently required focused Lane E implementation issue** in the Object-first transition. That is a valid idle state, but it must be determined from live Issues on every resume rather than inherited from an old snapshot.

## Integrated contracts that remain authoritative
- one shared Object FTS projection across ObjectTypes;
- title/aliases/Properties/Body and supported Relation label projection;
- derived producer contributions such as Weblink preview/PDF extracted text with source-scoped replacement;
- focused canonical Object invalidation/refresh rather than routine workspace-wide rebuild;
- stale/deleted impacted ids remain refreshable so rows can be removed;
- fail-closed corruption isolation for malformed Body/schema/Relation state;
- Search result resolution does not manufacture missing canonical identity;
- mounted Global Search can replay the active query after successful focused refresh.

## Resume triggers
Open a focused Lane E issue when real behavior demonstrates one of these:
- canonical Object Search misses new Object-first Properties/Body/native metadata that should be searchable;
- stale tokens remain after canonical Object/Relation/native producer mutation;
- ranking/filter/result-opening correctness regresses;
- Bookmark/People legacy retirement strands an FTS source or stale row;
- Tag hierarchy needs explicitly defined global Search semantics beyond normal Database/View query filters;
- rebuild/reconciliation/privacy behavior is incorrect.

## Cross-lane boundaries
- **A:** canonical Object identity/Body mutation impact.
- **B:** integrity-filtered Relation reads and relationship changes.
- **C:** Database/View typed query/filter semantics and Tag descendant filtering.
- **D:** Weblink/Image/File native facts and extracted-content production.
- **F:** file availability/Vault lifecycle; Search must fail safely when derived sources are unavailable.
- **G:** legacy Search caller-zero deletion only after canonical Search parity.

## Validation
Search changes require focused projection/freshness/restart regressions plus Analyze and full Flutter Test. Preserve privacy-safe errors and do not turn corruption into silent repair.

## Resume sequence
1. re-read live open Issues/PRs and current architecture;
2. take only a concrete Search/Indexing obligation;
3. reuse canonical Object projection/refresh infrastructure;
4. avoid domain-specific permanent indexes;
5. update this handoff with durable branch/commit/PR facts;
6. if no concrete E issue exists, stop under the no-actionable-work condition.

Lane E inherits the shared **Lane continuation and resume/stop contract** in `AGENTS.md`. Its legitimate idle behavior is intentional: do not invent Search features merely to keep the lane active. Before `idle-no-work`, however, perform the full final resume audit against live Issues, recent Object/Relation/native changes and the triggers above. Record `Stop reason: idle-no-work — <live evidence>` only when no concrete Search obligation exists; if a prerequisite is merely blocked, use the more precise dependency/conflict/external category instead.
