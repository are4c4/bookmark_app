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
Canonical Object Search is established and covers focused freshness, Body/Property/Relation projection, corruption isolation, background completion refresh, mounted-query replay and Japanese/CJK intra-token matching, including ordinary surrounding query punctuation and full-width/half-width Katakana compatibility, without a second persistent index.

Idle is a valid Lane E state when live Issues and a final current-main audit reveal no concrete Search obligation. Never infer that state from this handoff alone.

## Integrated contracts that remain authoritative
- one shared Object FTS projection across ObjectTypes;
- title/aliases/Properties/Body and supported Relation label projection;
- derived producer contributions such as Weblink preview/PDF extracted text with source-scoped replacement;
- existing FTS prefix matching and ranking remain the primary path for normal queries;
- Japanese/Han/Hiragana/Katakana terms that begin inside a `unicode61` token may use a query-time substring fallback over the **same canonical Object FTS projection**; non-CJK terms remain prefix-matched, mixed queries retain AND semantics, and no language/domain-specific persistent index is introduced;
- CJK substring fallback may trim recognized punctuation only from the **leading/trailing boundary** of a CJK-containing query term so copy/pasted terms such as `大学。` or `「大学」` behave like tokenizer-delimited input; punctuation inside the meaningful term is preserved, a trim that leaves no CJK needle does not broaden the fallback, and the primary FTS query/ranking path is unchanged;
- the same CJK fallback may compare deterministic Japanese width-compatibility variants for the half-width punctuation/Katakana block, including composed dakuten/handakuten forms such as `ｶﾞ` ↔ `ガ`; original/full-width/half-width variants are query-time alternatives over the same projection, internal punctuation such as `東・京` ↔ `東･京` is preserved rather than erased, and this is intentionally narrower than general NFKC/transliteration/fuzzy search so ordinary Latin infix semantics remain unchanged;
- existing FTS-ranked hits retain their ordering and fallback-only hits are deterministic and de-duplicated;
- focused canonical Object invalidation/refresh rather than routine workspace-wide rebuild;
- stale/deleted impacted ids remain refreshable so rows can be removed;
- fail-closed corruption isolation for malformed Body/schema/Relation state;
- Search result resolution does not manufacture missing canonical identity;
- mounted Global Search can replay the active query after successful focused refresh.

## Resume triggers
Open a focused Lane E issue when real behavior demonstrates one of these:
- canonical Object Search misses new Object-first Properties/Body/native metadata that should be searchable;
- language/tokenization behavior causes an ordinary query to miss searchable canonical text;
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
Search changes require focused projection/freshness/query/restart regressions as applicable, plus Analyze and full Flutter Test. Preserve privacy-safe errors and do not turn corruption into silent repair.

## Resume sequence
1. re-read live open Issues/PRs and current architecture;
2. take only a concrete Search/Indexing obligation;
3. reuse canonical Object projection/refresh infrastructure;
4. avoid domain-specific permanent indexes;
5. update this handoff only with durable contracts/state, leaving volatile PR/branch/CI facts to live GitHub;
6. if no concrete E issue exists, stop under the no-actionable-work condition.

Lane E inherits the shared **Lane continuation and resume/stop contract** in `AGENTS.md`. Its legitimate idle behavior is intentional: do not invent Search features merely to keep the lane active. Before `idle-no-work`, however, perform the full final resume audit against live Issues, recent Object/Relation/native changes and the triggers above. Record `Stop reason: idle-no-work — <live evidence>` only when no concrete Search obligation exists; if a prerequisite is merely blocked, use the more precise dependency/conflict/external category instead.
