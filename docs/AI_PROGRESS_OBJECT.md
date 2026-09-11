# AI Progress — Object Core & Body Lane

> Durable Lane A handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history; this file prioritizes durable contracts and exact resume actions.

## Lane goal
Own generic Object/ObjectType identity and lifecycle semantics, reusable Property value/type semantics, universal Body/block/reference behavior, Daily Note identity, and shared Object opening/detail contracts. Lane A does not own native Weblink/Image/File behavior, Relation integrity, Database/View presentation, Search FTS, Vault lifecycle or broad behavior-preserving refactors.

## Current architecture contract
- Every durable user-facing entity is an Object.
- One Object has one primary ObjectType.
- `Bookmark` is not a final ObjectType. Legacy Bookmark data is migration/compatibility input toward canonical Weblink + generic Object capabilities.
- Person is an ordinary generic ObjectType, not a permanent dedicated People write subsystem.
- Tag/TagGroup are generic ObjectTypes; A owns only concrete Object-core/type prerequisites, not hierarchy integrity/query UX.
- Body is the free-form document side of every Object and must preserve versioned persisted compatibility while interaction UX improves.
- Local Body Undo/concurrency is short-lived interaction/correctness behavior. It is distinct from durable Object/Vault history.

## Active focused issues

Always verify live GitHub before taking ownership. Completed issues below are checkpoints, not active work sources.

### #1062 — Object duplicate / merge / redirect semantics
Define advisory duplicate detection separately from explicit merge, preserve one canonical Object identity, define redirect/tombstone behavior for retired IDs, preserve Body/Properties/lifecycle state, and split Relation rewiring to B when implementation reaches that boundary. Fuzzy matching must never silently merge Objects.

### #1064 — durable Object history / restore contract
Define restart-safe durable history for Object/Property/Body/Relation state, explicitly separate from local Undo, and make restore conflict-aware/fail-closed. Split Relation-integrity and managed-byte retention work to B/F when the contract reaches those boundaries.

### #1177 — legacy-only Bookmark preservation boundary
The completed #1041 Bookmark migration checkpoint does not by itself prove a canonical destination for every legacy scalar/lifecycle fact. In particular `lastOpenedAt`, `openCount`, and `deletedAt` remain legacy compatibility/preservation concerns until a separately proven lossless destination or explicit retirement policy exists. Do not invent speculative generic Properties merely to eliminate these fields, and do not let later G caller-zero/schema retirement treat #1041 completion as permission to discard them.

## Completed checkpoints

### #1044 — generic-first Person authority
Completed. Generic Person identity/write authority is now Object-first rather than legacy-`people`-first.

Durable contract:
- `PersonObjectWriteService` creates the canonical generic Person Object first and maintains the temporary `people` compatibility projection transactionally;
- normal rename/note updates mutate canonical Object title/Note first and project compatibility state in the same authority boundary;
- reconciliation reuses one canonical Person identity and fails closed on damaged, ambiguous, mismatched or conflicting identity evidence instead of duplicating or partially advancing state;
- normal surviving Person creation paths, including retained Bookmark creation with Person names, route through the generic-first authority;
- `PersonObjectDeletionService` resolves the canonical Person before deletion, removes the temporary legacy projection atomically with canonical deletion, and prevents reconciliation from resurrecting an explicitly deleted Person;
- Generic Database/Object deletion of system Person Objects uses the same lifecycle semantics while canonical-only Person Objects remain directly deletable without synthesizing legacy state;
- incoming Relation detach/Object deletion remains delegated to B's canonical `RelationMutationService`; A does not own a Person-specific Relation store or detach algorithm;
- Profile Image remains canonical `Relation<Image>` authority; deleting a Person removes the Person's relation, not the Image Object or managed bytes;
- legacy People schema/data remains compatibility state until C daily-use parity, E Search parity where applicable, G caller-zero proof and preservation/destructive-migration gates are complete.

Historical implementation checkpoints include PR #1180 for canonical deletion and PR #1221 for the remaining normal Bookmark-create Person path. They are integrated history, not resume instructions.

### #1058 / #1121 — local Body Undo and concurrency
Completed. Local Undo and overlapping Body mutation correctness are established without turning Body into durable history/event sourcing.

Durable contract:
- normal structural deletion can expose short-lived Snackbar Undo with exact block ID/type/text/attributes/reference payload/position restoration;
- stale inverse restoration fails closed rather than overwriting newer Body content;
- `ObjectBodyStore.writeIfUnchanged()` compares persisted Body through the accepted semantic compatibility contract while conditioning the final write on the exact persisted snapshot, so historical/noncanonical valid JSON does not false-conflict merely because canonical encoding differs;
- `ObjectBodyBlockEditService` uses the persistence CAS boundary so separate callers cannot silently last-writer-win a stale full document;
- `ObjectBodyEditorSection` routes text, split/merge, checklist, insert, move/reorder, duplicate, delete/Undo and reference insertion through one Object-bound local mutation sequence;
- queued work captures Object/service identity and does not retarget itself or publish stale UI state after the editor switches Objects;
- valid unknown/future Body payload remains preserved;
- local Undo/concurrency remains separate from #1064 durable restart-safe history/restore.

Historical implementation checkpoints include PR #1226 for compatibility-safe persisted CAS and PR #1227 for the unified Object-bound editor mutation queue. They are integrated history, not active work.

### #1041 — Bookmark retirement A authority
Completed. Canonical Weblink identity remains D-owned and is consumed rather than reimplemented. Legacy Bookmark collision/reconciliation preserves or fails closed on saved-item state conflicts instead of silently collapsing user-authored data.

Converged/preservation-checked saved-item state includes `Favorite`, `Reading Status`, `Storage State`, `Genre` and `Rating`; title/description/thumbnail remain compatibility-preserved/best-effort transition data. This checkpoint does **not** erase #1177's retained legacy-only `lastOpenedAt`, `openCount`, and `deletedAt` preservation boundary.

### #1057 — Body UX phase 2
Completed. Idle Body chrome is content-first; hover/focus/touch preserve contextual actions, drag reorder persists through the canonical edit service, and popup/menu interaction remains stable.

### #1049 — Body UX phase 1
Completed. Enter split, Shift+Enter newline, safe leading-Backspace merge, compact contextual actions and serialized text mutations establish the primary keyboard editing flow.

## Integrated foundation that remains authoritative
- universal persisted Body model/opening surfaces;
- fail-closed Body structural/version validation with unknown/future block preservation;
- stable Object/ObjectType identity and generic Property semantics;
- Daily Note identity-managed Date protection;
- exact Search-agnostic canonical Object sync impact contract;
- template/object creation integrity and shared Object detail/opening seams;
- local Body structural Undo + persistence/editor concurrency correctness, distinct from durable history;
- collision-safe Bookmark -> canonical Weblink convergence while compatibility data remains intact;
- generic-first Person create/update/delete/reconciliation authority with temporary legacy projection.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration, Person roles/groups and Tag hierarchy integrity. Future #1062/#1064 Relation rewiring/restore slices must be split to B rather than implemented directly in A.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX. Dedicated People UI retirement remains C-owned.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities. A consumes those contracts rather than recreating them.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle; durable history managed-byte retention belongs to F when explicitly split.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after owning-lane parity and preservation evidence.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. Do not take over B Relation work, C People UI work, E Search work or G legacy caller-zero cleanup merely to keep Lane A active. Schema/migration work remains subject to the repository single-writer gate.

## Validation
A runtime Object/Body change requires changed-Dart Format, Analyze/guards, focused regressions, full Flutter Test shards, test-health and authoritative `merge-gate` on a latest-main-synchronized head. Docs-only handoff updates use the repository docs/coordination path plus required merge-gate.

## Resume sequence
1. refresh latest `main`, live open PR ownership, current CI, shared hotspots and migration ownership;
2. verify the state/acceptance of #1062, #1064 and #1177 plus any newer focused A issues; do **not** reopen #1044/#1058/#1121 merely because their historical implementation details remain relevant;
3. select the next concrete non-conflicting A-owned acceptance slice from live GitHub;
4. keep #1062 Relation rewiring and #1064 Relation/history-byte implications split to B/F when those boundaries are reached;
5. preserve #1177 legacy-only Bookmark facts until a lossless destination or explicit retirement policy exists; do not convert documentation pressure into speculative schema design;
6. after each coherent slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` and continue while safe A work exists.

If the final resume audit finds no actionable A work, record the exact stop category from `AGENTS.md` with live evidence. A completed historical PR or completed #1044/#1058/#1121 is never, by itself, a stop reason.
