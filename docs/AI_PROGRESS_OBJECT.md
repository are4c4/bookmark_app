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

### #1064 — durable Object history / restore contract
Define restart-safe durable history for Object/Property/Body/Relation state, explicitly separate from local Undo, and make restore conflict-aware/fail-closed. Relation-integrity and managed-byte retention remain B/F-owned boundaries rather than A-side duplicate authorities.

A's logical history/checkpoint and restore-safety contracts are established, A/#1399/#1402 persist immutable A-owned checkpoint payloads restart-safely, B/#1267 owns canonical Relation checkpoint/restore integrity, F/#1268 owns managed-byte retention safety, and B/#1405 now provides restart-safe immutable Relation-history persistence. A/#1438 atomically composes A and B evidence for one Object/revision, #1441 loads that persisted whole-Object evidence after restart, and #1443 prepares read-only coordinated restore evidence through B's canonical Relation restore preview boundary. #1064 remains open for the next concrete restore-execution/product slice proven on current `main`; do not recreate Relation history/validation in A or infer managed-byte authority from logical history.

## Completed checkpoints

### #1062 — completed Object duplicate / merge / redirect capability
Completed end-to-end after the explicit Object Inspector flow integrated through #1425/#1426. Duplicate discovery remains advisory, merge remains explicit, one survivor is selected, retired IDs redirect durably, A-owned state is conflict-resolved, Relation rewiring remains B-owned, and finalization is stale-safe/atomic. Future merge defects require a new focused reproducible issue rather than reopening #1062 as an active queue.

The foundational Object-core contract/planning/materialization through #1294 remains authoritative:
- duplicate detection remains advisory unless a native stable key independently proves deterministic reuse; merge is an explicit operation;
- merge preview owns positive distinct survivor/retired identities, explicit conflict requirements and B-owned Relation blockers;
- retired Object IDs have durable A-owned redirect semantics that remain resolvable after Object-row retirement and fail closed on malformed/conflicting/cyclic mappings;
- concrete A-owned snapshots cover title, value Properties, versioned Body and ordered aliases while excluding Relation and computed Property authority;
- Property identity/type drift and cross-ObjectType merge attempts fail closed rather than being coerced;
- conflicting title/value Property/Body state requires explicit keep-survivor/take-retired decisions; alias state additionally supports only preservation-safe deterministic combine;
- the prepared merge context binds frozen survivor/retired snapshots to the exact preview used for decisions, so a plan from stale same-ID state cannot be paired with later snapshots;
- pure materialization produces proposed survivor A-owned state without persistence, Object deletion, redirect mutation, Relation mutation, Search/UI work or managed-file action;
- survivor Object identity/ObjectType and survivor-authoritative generic lifecycle policy remain authoritative.

Historical focused checkpoints include #1239/#1252 for the preview/redirect domain contract, #1257/#1258 for durable redirects, #1289/#1290 for concrete A-owned state planning, and #1294/#1297 for prepared-context-bound state materialization.

### #1306 — persistent explicit merge finalization after B/#1259
Completed. The first persistent cross-store Object merge transaction consumes B's canonical Relation rewiring contract rather than duplicating it.

Durable contract:
- current survivor/retired A-owned state and the executable Relation plan are revalidated inside one caller-owned transaction;
- B's canonical Relation rewiring runs before survivor-state persistence, redirect creation and retired-row deletion;
- only the already-resolved A-owned title/value Properties/Body/aliases are persisted by A;
- the durable redirect is recorded before the retired Object row is removed;
- stale A state or new Relation blockers fail before partial mutation, and late failure rolls Relation rewrites, survivor state, redirect and retirement back together;
- retry resolves through the durable redirect rather than creating a second survivor or competing Relation state;
- managed Image/File bytes, Database/View/Search behavior and legacy schema retirement remain outside this contract.

### #1406 — product-facing exact duplicate advisory
Completed with the Object Inspector integration. The existing exact title/alias advisory is now visible without changing merge authority.

Durable contract:
- custom ObjectTypes and canonical Person can show deterministic exact duplicate candidates in the canonical Object Inspector;
- candidate discovery remains exact title/alias overlap, read-only and self-excluding; fuzzy/partial matching does not become merge authority;
- native identity system ObjectTypes remain excluded except canonical Person;
- selecting a candidate only opens that canonical Object for inspection and never merges, reuses, redirects or deletes either Object;
- title and alias identity edits refresh the advisory, with generation guarding so stale asynchronous results cannot overwrite newer identity state;
- advisory failure is isolated from normal Object detail loading and offers retry without hiding or mutating the Object;
- explicit conflict decisions and persistent merge finalization remain separate from this advisory surface.

### #1420 / #1422 — canonical A/B merge preparation
Completed. A now has one read-only composition boundary that prepares the exact explicit merge pair without duplicating B Relation authority.

Durable contract:
- `ObjectMergePreparationService` captures frozen A-owned survivor/retired state through `ObjectMergeStateStore`;
- the same exact identities are previewed through B's canonical `RelationObjectMergeService`;
- B-owned Relation blockers are fed into `ObjectMergePreparedState.prepare`, so an integrity-blocked merge cannot accidentally become executable in later UI;
- preparation performs no Object/Relation mutation, redirect write, Object retirement, schema change or managed-file action;
- finalization still revalidates both A and B state transactionally, so preparation is review context rather than mutation authorization.

### #1425 / #1426 — explicit Object Inspector merge execution
Completed. The canonical Object Inspector can execute the already-proven merge contract only through explicit user control.
Durable contract:
- duplicate-row navigation remains read-only; `統合…` is a distinct action;
- the user explicitly chooses current vs candidate identity as survivor before execution;
- every unresolved A-owned requirement must receive one contract-allowed decision, and Relation blockers remain B-owned/read-only and disable execution;
- the destructive action requires a second confirmation naming survivor and retired Object;
- execution delegates only to `ObjectMergeFinalizer`; UI does not reproduce Relation rewiring, redirect creation, stale checks or Object retirement logic;
- current-survivor completion reloads the Inspector, while candidate-survivor completion replaces the retired route with the surviving canonical Object;
- cancellation performs no mutation, and stale/late failure fails closed, re-prepares current state and preserves both Objects without partial mutation;
- internal Relation blocker keys remain diagnostic/widget identity only and are not exposed as ordinary user-facing text;
- survivor selection uses the current Flutter `RadioGroup` contract, and destructive buttons are not autofocus defaults.

### #1064 A/B/F durable-history boundaries through #1267/#1268
Completed contract checkpoints establish the A-owned logical history shape, B-owned Relation checkpoint/restore integrity boundary and F-owned managed-byte safety boundary.

Durable contract:
- durable history is restart-safe checkpoint/history data distinct from short-lived local Undo;
- history entries use explicit Object/revision identity, source metadata, whole/selective restore scope and stale-current-revision checks;
- A-owned checkpoint payload preserves title/value Property/Body semantics without turning Relation or computed values into A authority;
- restore must fail closed rather than overwrite a changed current revision;
- B/#1267 owns canonical Relation checkpoint/restore validation and execution under current Relation integrity rules; A consumes that boundary rather than replaying Relation edges directly;
- logical Image/File references in history do not by themselves promise byte retention or deletion authority;
- F/#1268 establishes managed-byte identity/retention/GC safety: retained history claims and current/backup/export preservation can block deletion, external references remain metadata-only, and physical deletion still requires F-side complete ownership/reference proof;
- current canonical Object state remains authoritative; these contracts do not turn normal reads into event-log reconstruction.

Historical A checkpoints include #1254/#1255 for history identity/restore safety and #1260 for A-owned checkpoint payload semantics. B/#1267 and F/#1268 are integrated boundaries. Any future whole-Object durable persistence/restore coordinator must compose them rather than inventing A-owned Relation snapshots or filesystem retention authority.

### #1399 / #1402 — restart-safe immutable A-owned checkpoints
Completed. A-owned logical checkpoint payloads now have restart-safe persistence without claiming Relation or filesystem authority.

Durable contract:
- immutable checkpoints are keyed by explicit Object/revision identity and preserve the accepted A-owned title/value Property/Body payload plus source metadata;
- exact retry is idempotent while conflicting reuse of an existing historical Object/revision identity fails closed;
- malformed stored payload or stored-key/payload mismatch fails closed instead of being normalized silently;
- checkpoints survive database close/reopen and remain historical evidence rather than the authority for normal current-state reads;
- Relation state is intentionally absent from this A store and must be persisted through B's history boundary;
- logical Image/File references do not grant A byte-retention or deletion authority;
- #1438/#1439 now transactionally compose this A store with B/#1405 persisted Relation snapshots for the same Object/revision, while Relation history remains B-owned rather than a parallel A store.

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
- completed explicit Object duplicate/merge/redirect capability: preview/redirect, concrete A-owned state planning, A/B preparation, resolved-state materialization, canonical Relation rewiring, atomic finalization and user-controlled Object Inspector execution;
- durable Object history identity/checkpoint/restore-safety contracts plus restart-safe A-owned checkpoint persistence, B Relation checkpoint/restore and restart-safe history, F managed-byte retention, atomic A+B whole-checkpoint capture, restart-safe whole-checkpoint loading, and read-only coordinated restore preparation through #1443.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration, Person roles/groups and Tag hierarchy integrity. #1259 merge rewiring, #1267 Relation checkpoint/restore integrity and #1405 restart-safe Relation-history persistence are completed boundaries that A consumes. A/#1438 capture, #1441 loading and #1443 restore preparation compose those B-owned boundaries; A must not write Relation values/edges or invent a parallel Relation-history store directly.
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
2. treat completed #1062 and its focused merge checkpoints as integrated contracts, then verify the live state/acceptance of #1064 plus any newer focused A issue;
3. do not reopen #1062 as a work queue. A future merge defect or product gap must be demonstrated on current main and opened as a new focused Issue; do not recreate the explicit merge UI or make exact-advisory candidates auto-merge;
4. for #1064, treat A/#1402, B/#1267/#1405, F/#1268 and A/#1438/#1441/#1443 as integrated boundaries. Any next restore-execution/product slice must be demonstrated on current `main`, consume the established persisted whole-checkpoint loader/restore-preparation and canonical B Relation restore authority, and must not serialize or validate Relation history independently in A;
5. preserve the legacy-only Bookmark facts recorded by completed #1177 until a lossless destination or explicit retirement policy exists; do not convert documentation pressure into speculative schema design;
6. after each coherent slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` and continue while safe A work exists.

## Current continuation / stop contract

#1062 is completed and must not be reopened merely to keep Lane A active. #1405 and A/#1438/#1441/#1443 are integrated, so there is no longer a B/#1405 dependency gate for #1064. Recheck live GitHub for a newer focused A issue or a concrete reproducible current-main gap that advances the remaining restore-execution/product acceptance while preserving B/F ownership. If neither exists, `idle-no-work` is the exact stop category. Do not reopen completed history checkpoints, duplicate B Relation restore/history authority, or invent speculative A work merely to avoid that stop.