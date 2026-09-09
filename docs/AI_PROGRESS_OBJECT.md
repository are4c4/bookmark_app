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
Current primary Lane A slice. Move normal Person identity/write authority to generic Person ObjectType while preserving stable identity, note/Body compatibility, restart/reconciliation safety and legacy compatibility projections. Do not retire People UI or redesign groups/roles here.

Current implementation boundary on `feature/object-person-generic-write-authority-1044` / PR #1152:
- `PersonObjectWriteService` creates the canonical generic Person Object first, then projects a compatibility `people` row and `person_object_links` mapping in the same transaction;
- rename/note updates mutate the canonical Person Object first and then project legacy `people` state in the same transaction;
- legacy projection failure (including legacy unique-name conflicts) rolls the transaction back so canonical title/note cannot advance independently;
- existing legacy Persons are imported through the existing `PersonObjectBridge` and then reuse their canonical Person Object instead of creating a duplicate;
- service reconstruction/restart preserves the same `person_object_links` identity;
- normal `BookmarkRepository.createPerson` / `updatePerson` and internal `_resolvePeople()` creation now route through the generic-first boundary;
- `deletePerson` intentionally remains outside this first slice because Bookmark/PersonGroup legacy FK/cascade compatibility must be proven before authority is reversed for deletion;
- no schema/migration file or People UI is changed.

Focused regressions:
- `test/person_object_write_service_test.dart` covers canonical-first create/update, projection rollback and restart identity reuse;
- `test/bookmark_repository_person_write_authority_test.dart` covers the real repository create/update path preserving one canonical Person identity.

Next #1044 work after this create/update slice integrates: re-audit delete/profile-image/note compatibility and remaining normal Person write callers. Do not expand into B-owned role/group Relation semantics or C-owned People UI retirement.

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
- collision-safe Bookmark -> canonical Weblink convergence while compatibility data remains intact.

Older handoff statements that #1041 or #1058 are active are obsolete. #1044 is the current primary Lane A slice.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration, Person roles/groups and Tag hierarchy integrity. A/#1044 must not redesign role/group Relation semantics.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX. Dedicated People UI retirement remains C-owned.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities. D/#1054 is integrated; do not reopen it from A.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after A/B/C/D parity.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. #1044 should prefer the focused Person write boundary, repository routing and dedicated tests. Do not take over B role/group Relation convergence or C People UI work.

## Validation
GitHub Actions is authoritative when local Flutter execution is unavailable. #1044 create/update authority requires changed-Dart format, Analyze/guards, focused service/repository regressions, full Flutter Test and authoritative merge-gate on an up-to-date head.

## Resume sequence
1. verify latest `main`, #1044, open PR ownership and current CI before editing;
2. finish and integrate the generic-first Person create/update/note authority slice in PR #1152 without schema/migration or People UI changes;
3. keep legacy `people` as a compatibility projection and fail closed/roll back when projection cannot remain consistent;
4. after create/update integrates, re-audit #1044 acceptance for delete, Profile Image Relation compatibility, remaining legacy-first callers and restart/reconciliation gaps;
5. split deletion into a separate focused slice unless legacy Bookmark/PersonGroup FK/cascade behavior is proven preservation-safe;
6. continue Lane A until the shared `AGENTS.md` stop condition is actually reached.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane A continues while concrete safe A work exists; a single completed Issue/PR is never sufficient stop evidence. If the final resume audit finds no actionable A work, record `Stop reason: idle-no-work — <live evidence>` (or another exact stop category from `AGENTS.md`) in the durable handoff before stopping.
