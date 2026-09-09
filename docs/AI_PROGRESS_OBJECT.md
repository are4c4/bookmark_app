# AI Progress — Object Core & Body Lane

> Durable Lane A handoff. Before implementation read the focused Issue, `docs/product_architecture.md`, `AGENTS.md`, `docs/AI_PROGRESS.md`, latest `main`, live PR ownership and current CI. Historical completion detail remains in git/Issue/PR history; this file prioritizes current contracts and exact resume actions.

## Lane goal
Own generic Object/ObjectType identity and lifecycle semantics, reusable Property value/type semantics, universal Body/block/reference behavior, Daily Note identity, and shared Object opening/detail contracts. Lane A does not own native Weblink/Image/File behavior, Relation integrity, Database/View presentation, Search FTS, Vault lifecycle or broad behavior-preserving refactors.

## Current architecture contract
- Every durable user-facing entity is an Object.
- One Object has one primary ObjectType.
- `Bookmark` is not a final ObjectType. Legacy Bookmark data is migration/compatibility input toward canonical Weblink + generic Object capabilities.
- Person is an ordinary generic ObjectType, not a permanent dedicated People write subsystem.
- Tag/TagGroup are generic ObjectTypes; A owns only concrete Object-core/type prerequisites, not hierarchy integrity/query UX.
- Body is the free-form document side of every Object and must preserve versioned persisted compatibility while interaction UX improves.
- Local Body Undo is short-lived interaction recovery. It must not be expanded into durable Object/Vault history without a separate explicit contract.

## Active focused issues

### #1044 — Person migration A
Current primary Lane A issue. Generic Person identity/write authority is moving onto the ordinary Object/ObjectType lifecycle while legacy `people` remains only an explicit compatibility projection until B/C/G parity and caller-zero work is complete.

PR #1152 is integrated as `c3719420756611bf56f5f5c6be2ad94112bb4ae7` and established the create/update/reconciliation authority direction:
- `PersonObjectWriteService` creates the canonical generic Person Object first, then projects a compatibility `people` row and `person_object_links` mapping in one transaction;
- rename/note updates mutate canonical title/Note first and project legacy state transactionally;
- mapped Person reconciliation treats canonical Object title/Note as authority, while unmapped historical legacy Persons may seed one canonical Object once;
- damaged/ambiguous identity or legacy projection conflict fails closed instead of duplicating or partially advancing identity;
- normal `BookmarkRepository.createPerson` / `updatePerson` plus internal Person creation use this generic-first boundary;
- Profile Image is already canonical `Relation<Image>` authority; legacy `profilePhotoId` is compatibility projection only;
- restart/service reconstruction preserves one canonical Person identity.

Current focused lifecycle slice: `feature/person-generic-delete-lifecycle-1044` / PR #1180.
- `PersonObjectDeletionService` resolves and validates the canonical Person before a surviving People caller may delete it;
- canonical incoming Relation detach/Object deletion stays delegated to B's established `RelationMutationService.deleteObject()`; A does not add a Person-specific Relation store or detach algorithm;
- explicit Person deletion removes the temporary legacy `people` projection in the same outer transaction so reconciliation cannot resurrect the deleted canonical Person;
- existing compatibility FK behavior remains intact while legacy callers survive: Bookmark role rows and PersonGroup memberships cascade, Saved View Person filters become null;
- Generic Database/Object deletion recognizes only the registered system Person ObjectType and applies the same compatibility cleanup; canonical-only Person Objects with no legacy projection remain directly deletable;
- deleting Person removes its outgoing Profile Image Relation with the Person Object but does not delete the target Image Object or infer managed-byte deletion authority;
- missing transition mapping may be recovered only from one valid/unambiguous canonical `Legacy Person ID` claim; malformed, missing or conflicting identity fails closed;
- late canonical deletion failure rolls back Relation detach and legacy compatibility cleanup together;
- no schemaVersion/migration/legacy-table retirement or People UI change is part of this slice.

Focused regressions cover:
- canonical-first create/update, rollback and restart identity reuse;
- real repository create/update/delete lifecycle and restart non-recreation;
- legacy role/group/Saved View compatibility cleanup during explicit Person deletion;
- missing-link recovery and late-delete transactional rollback;
- real Generic Database deletion of legacy-backed Person with incoming Relations and Profile Image target preservation;
- deletion of canonical-only Person without creating legacy People state.

After #1180 integrates, re-audit #1044 acceptance and current-main Person write/delete callers. Do not absorb B/#1045 role/group Relation convergence, C/#1046 People UI replacement or G caller-zero retirement into Lane A merely to keep #1044 active.

## Recently integrated

### #1041 — Bookmark retirement A
Completed and closed through PR #1140, merged as `8f4dbd372e993e8463ba836eddf8df2e6be322d2`.

Delivered:
- canonical Weblink identity remains D/#1054-owned and is consumed rather than reimplemented;
- every legacy Bookmark resolves canonical identity before mirrored Relation/legacy-URL mutation;
- multiple Bookmarks converging on one Weblink must have equivalent `Favorite`, `Reading Status`, `Storage State`, `Genre` and `Rating` saved-item state;
- conflicting saved-item state fails closed before Relation writes or mirrored URL retirement, preserving legacy compatibility evidence;
- title/description/thumbnail remain compatibility-preserved/best-effort rather than silently collapsed;
- restart/reconciliation reuses the existing canonical Weblink target;
- no schema/migration or destructive Bookmark-row deletion.

Authoritative final latest-main-synchronized head `238148cf2209fc2a176236e42c0a6b667078b6d9`: changed-Dart Format, Analyze/guards, all four Flutter Test shards, test-health and merge-gate green; repository audits were green before auto-merge.

### #1058 — Body structural edit Undo
Completed and closed through PR #1104, merged as `6306a2d9c723a2f6218ced47d62fba8e15eb26e0`.

Delivered:
- confirmation-free block deletion with short-lived Snackbar `元に戻す` recovery;
- exact block ID/type/text/attributes/reference payload/position restoration;
- persisted Body remains authoritative through compare-and-swap delete/restore;
- stale inverse restoration fails closed and preserves newer Body content;
- `ObjectBodyStore.writeIfUnchanged()` is the narrow CAS boundary;
- `ObjectBodyStructuralUndoService` owns in-memory delete inverse tokens;
- reusable `ObjectBodyEditorSection` provides the shared interaction path without modifying `object_inspector_page.dart`;
- focused service and real widget regressions cover successful Undo, one-shot behavior and later-mutation conflict preservation.

Authoritative final synchronized head `acc23a40e8b1950081d613431ed83b49373133cb`: Flutter CI #3322, Analyze/guards, all four Flutter Test shards, test-health/merge-gate and repository audits were green before merge.

### #1057 — Body UX phase 2
Merged through PR #1110 as squash commit `c871d68e54b35ac7f183f59a64ba00fb134dc661`.

Delivered:
- repeated per-block chrome stays hidden while idle so Body reads content-first;
- desktop hover/focus reveals contextual actions and drag affordance;
- touch keeps an explicit overflow-compatible action path;
- drag reorder persists only through the canonical `ObjectBodyBlockEditService.move` path and preserves block identity/payload/order;
- menu move up/down, duplicate, delete, insert and reference actions remain accessible fallbacks;
- contextual action subtrees stay mounted while hidden so opening a popup does not invalidate its command when hover/focus changes;
- shared-editor and Inspector/reference regressions cover contextual visibility, focus preservation, popup survivability and persisted reorder.

### #1049 — Body UX phase 1
Merged through PR #1056 as squash commit `2f6eb24a7ff7fda6997703edc37d91e2087fd305`.

Delivered:
- Enter splits a paragraph at the caret and focuses the next paragraph;
- Shift+Enter remains an in-block newline;
- leading Backspace safely merges compatible plain paragraphs and restores the previous paragraph focus/caret;
- styled/heading or otherwise unsafe merge boundaries fail closed without data loss;
- lower-frequency move/duplicate/delete actions live in compact contextual overflow chrome while insertion remains nearby;
- text mutations are serialized so split/merge cannot race a stale paragraph save;
- domain, persistence, widget and real editor integration regressions cover the primary keyboard flow.

## Integrated foundation that remains authoritative
- universal persisted Body model/opening surfaces;
- fail-closed Body structural/version validation with unknown/future block preservation;
- stable Object/ObjectType identity and generic Property semantics;
- Daily Note identity-managed Date protection;
- exact Search-agnostic canonical Object sync impact contract;
- template/object creation integrity and shared Object detail/opening seams;
- local Body structural Undo as interaction recovery, not durable history;
- collision-safe Bookmark -> canonical Weblink convergence while compatibility data remains intact;
- generic-first Person create/update/reconciliation authority with temporary legacy projection.

Older handoff statements that #1041, #1058 or PR #1152 are still active are obsolete. #1044 remains the current primary Lane A issue while the focused delete/lifecycle slice is validated.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration, Person roles/groups and Tag hierarchy integrity. A/#1044 consumes canonical Relation deletion but must not redesign role/group Relation semantics.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX. Dedicated People UI retirement remains C-owned.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities. D/#1054 is integrated; do not reopen it from A.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after A/B/C/D parity.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. #1180 deliberately composes deletion in `generic_database_page_services.dart` rather than taking C's live `generic_database_page.dart` ownership. Do not take over B role/group Relation convergence or C People UI work.

## Validation
GitHub Actions is authoritative when local Flutter execution is unavailable. #1044 lifecycle authority requires changed-Dart Format, Analyze/guards, focused service/repository/real-host regressions, full Flutter Test shards, test-health and authoritative merge-gate on a latest-main-synchronized head.

## Resume sequence
1. verify latest `main`, #1044, open PR ownership and current CI before editing;
2. validate/fix PR #1180's canonical Person delete + legacy compatibility cleanup without schema/migration or shared People UI changes;
3. preserve Relation semantics by delegating detach/delete to `RelationMutationService`; fix only A-owned identity/lifecycle composition failures exposed by tests;
4. synchronize #1180 onto latest main only after its implementation is format/analyze/test stable, then require authoritative full CI/merge-gate before integration;
5. after #1180 integrates, re-audit #1044 acceptance, remaining normal Person write/delete callers and restart/reconciliation behavior;
6. close #1044 only if the A-owned authority acceptance is genuinely complete; otherwise continue the next focused non-conflicting A slice;
7. if A's #1044 authority is complete but remaining People retirement work is exclusively B/#1045, C/#1046 or G caller-zero, record the appropriate shared stop reason instead of inventing A work.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane A continues while concrete safe A work exists; a single completed Issue/PR is never sufficient stop evidence. If the final resume audit finds no actionable A work, record `Stop reason: idle-no-work — <live evidence>` (or another exact stop category from `AGENTS.md`) in the durable handoff before stopping.
