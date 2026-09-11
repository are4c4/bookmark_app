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

The A-owned contract/planning/materialization boundary is established. Actual persistent Object retirement/finalization becomes actionable only after B's focused canonical Relation rewiring boundary from #1259 is integrated. A must not delete the retired Object first because record deletion can cascade Relation evidence that B still needs to validate and rewrite.

### #1064 — durable Object history / restore contract
Define restart-safe durable history for Object/Property/Body/Relation state, explicitly separate from local Undo, and make restore conflict-aware/fail-closed. Split Relation-integrity and managed-byte retention work to B/F when the contract reaches those boundaries.

A's logical history/checkpoint and restore-safety contracts are established, and F's managed-byte retention safety boundary from #1268 is integrated. Relation-aware durable restore/persistence remains dependent on B's focused #1267 contract; A must not serialize or replay Relation edges directly while that boundary remains unresolved.

## Completed checkpoints

### #1062 A-side explicit merge contract through #1294
Completed as the Object-core contract/planning/materialization foundation for explicit merge. This is not yet the persistent cross-store merge transaction.

Durable contract:
- duplicate detection remains advisory unless a native stable key independently proves deterministic reuse; merge is an explicit operation;
- merge preview owns positive distinct survivor/retired identities, explicit conflict requirements and B-owned Relation blockers;
- retired Object IDs have durable A-owned redirect semantics that remain resolvable after Object-row retirement and fail closed on malformed/conflicting/cyclic mappings;
- concrete A-owned snapshots cover title, value Properties, versioned Body and ordered aliases while excluding Relation and computed Property authority;
- Property identity/type drift and cross-ObjectType merge attempts fail closed rather than being coerced;
- conflicting title/value Property/Body state requires explicit keep-survivor/take-retired decisions; alias state additionally supports only preservation-safe deterministic combine;
- the prepared merge context binds frozen survivor/retired snapshots to the exact preview used for decisions, so a plan from stale same-ID state cannot be paired with later snapshots;
- pure materialization produces proposed survivor A-owned state without persistence, Object deletion, redirect mutation, Relation mutation, Search/UI work or managed-file action;
- survivor Object identity/ObjectType and survivor-authoritative generic lifecycle policy remain authoritative;
- the next persistent A finalization must revalidate current state inside the coordinating transaction and compose B's canonical Relation rewiring before retired Object deletion.

Historical focused checkpoints include #1239/#1252 for the preview/redirect domain contract, #1257/#1258 for durable redirects, #1289/#1290 for concrete A-owned state planning, and #1294/#1297 for prepared-context-bound state materialization.

### #1064 A/F durable-history boundary through #1268
Completed contract checkpoints establish the A-owned logical history shape and F-owned managed-byte safety boundary, while Relation history remains explicitly B-owned.

Durable contract:
- durable history is restart-safe checkpoint/history data distinct from short-lived local Undo;
- history entries use explicit Object/revision identity, source metadata, whole/selective restore scope and stale-current-revision checks;
- A-owned checkpoint payload preserves title/value Property/Body semantics without turning Relation or computed values into A authority;
- restore must fail closed rather than overwrite a changed current revision;
- Relation checkpoint/restore integrity is delegated to B/#1267 and must pass current canonical Relation rules before execution;
- logical Image/File references in history do not by themselves promise byte retention or deletion authority;
- F/#1268 establishes managed-byte identity/retention/GC safety: retained history claims and current/backup/export preservation can block deletion, external references remain metadata-only, and physical deletion still requires F-side complete ownership/reference proof;
- current canonical Object state remains authoritative; these contracts do not turn normal reads into event-log reconstruction.

Historical A checkpoints include #1254/#1255 for history identity/restore safety and #1260 for A-owned checkpoint payload semantics. F/#1268 is the integrated managed-byte boundary. Do not advance whole-Object Relation-aware durable persistence/restore by inventing an A-side Relation snapshot while B/#1267 is open.

### #1177 — legacy-only Bookmark preservation boundary
Completed as a durable preservation-contract checkpoint. The completed #1041 Bookmark migration checkpoint does not by itself prove a canonical destination for every legacy scalar/lifecycle fact. In particular `lastOpenedAt`, `openCount`, and `deletedAt` remain legacy compatibility/preservation concerns until a separately proven lossless destination or explicit retirement policy exists.

Durable contract:
- do not invent speculative generic Properties merely to eliminate these fields;
- do not let later G caller-zero/schema retirement treat #1041 completion as permission to discard them;
- any future canonical destination or intentional retirement policy for these facts requires a separate focused product/preservation decision;
- Issue closure means this preservation boundary is now recorded, not that the underlying legacy facts are disposable.

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

Converged/preservation-checked saved-item state includes `Favorite`, `Reading Status`, `Storage State`, `Genre` and `Rating`; title/description/thumbnail remain compatibility-preserved/best-effort transition data. This checkpoint does **not** erase completed #1177's retained legacy-only `lastOpenedAt`, `openCount`, and `deletedAt` preservation boundary.

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
- generic-first Person create/update/delete/reconciliation authority with temporary legacy projection;
- explicit preservation of legacy-only Bookmark `lastOpenedAt`, `openCount`, and `deletedAt` until a separate destination/retirement decision exists;
- explicit Object merge preview/redirect, concrete A-owned state planning and pure resolved-state materialization, with persistent retirement still sequenced behind canonical Relation rewiring;
- durable Object history identity/checkpoint/restore-safety contracts plus the integrated F-owned managed-byte retention boundary, with Relation history still B-owned.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration, Person roles/groups and Tag hierarchy integrity. #1062 persistent merge finalization waits for the canonical rewiring boundary from #1259; #1064 Relation-history/restore composition waits for #1267. A must consume those contracts rather than write Relation values/edges directly.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX. Dedicated People UI retirement remains C-owned.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities. A consumes those contracts rather than recreating them.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle. The #1268 managed-byte history retention safety boundary is integrated; physical byte retention/GC remains F-owned and is never inferred from A metadata history.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after owning-lane parity and preservation evidence.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. Do not take over B Relation work, C People UI work, E Search work or G legacy caller-zero cleanup merely to keep Lane A active. Schema/migration work remains subject to the repository single-writer gate.

## Validation
A runtime Object/Body change requires changed-Dart Format, Analyze/guards, focused regressions, full Flutter Test shards, test-health and authoritative `merge-gate` on a latest-main-synchronized head. Docs-only handoff updates use the repository docs/coordination path plus required merge-gate.

## Resume sequence
1. refresh latest `main`, live open PR ownership, current CI, shared hotspots and migration ownership;
2. verify the state/acceptance of #1062 and #1064 plus any newer focused A issues; treat completed focused merge/history checkpoints as integrated contracts rather than active work sources;
3. for #1062, check B/#1259 first. Once its canonical Relation rewiring boundary is integrated, create or reuse one focused A finalization Issue that revalidates current A state inside a caller-owned outer transaction, invokes B's canonical rewiring boundary, persists the resolved A-owned survivor state and redirect, and only then retires the losing Object. Do not implement a competing Relation planner/service;
4. for #1064, check B/#1267 first. Once the Relation checkpoint/restore boundary is integrated, re-audit whether the next focused A slice is durable checkpoint persistence/restore coordination. Consume F's integrated managed-byte retention contract rather than adding filesystem authority to A;
5. preserve the legacy-only Bookmark facts recorded by completed #1177 until a lossless destination or explicit retirement policy exists; do not convert documentation pressure into speculative schema design;
6. after each coherent slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` and continue while safe A work exists.

## Current stop contract

Stop reason: `dependency` — the final live resume audit found no independent safe A implementation slice. #1062 persistent Object merge/final retirement is sequenced behind B/#1259 canonical Relation rewiring integration, and #1064 Relation-aware durable history/restore coordination is sequenced behind B/#1267. F/#1268 is already integrated and is no longer a history blocker. On the next A run, refresh live GitHub first: if either B dependency has integrated, take the newly unblocked focused A slice; otherwise do not invent duplicate Relation/history abstractions merely to keep Lane A active.
