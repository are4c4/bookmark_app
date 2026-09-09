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

### #1041 — Bookmark retirement A
Current primary Lane A slice. Define collision-safe legacy Bookmark -> canonical Weblink/generic Object authority without creating a permanent canonical Bookmark Object.

D/#1054 is already integrated: `BookmarkWeblinkObjectBridge` consumes `CanonicalWeblinkCaptureService`. A must not reimplement URL normalization, canonical Weblink create/reuse or D-owned collision identity logic.

Current A-owned implementation boundary on `feature/object-bookmark-state-convergence-1041`:
- `BookmarkWeblinkObjectBridge` resolves canonical Weblink identities for the workspace before mutating mirrored Bookmark Relations or retiring mirrored direct URL Values;
- when multiple legacy Bookmarks resolve to the same canonical Weblink, their saved-item scalar state (`Favorite`, `Reading Status`, `Storage State`, `Genre`, `Rating`) must be equivalent before convergence proceeds;
- non-equivalent saved-item state fails closed before Bookmark -> Weblink Relation writes or mirrored URL retirement, leaving legacy Bookmark rows and mirrored state intact;
- canonical Weblink identity remains D-owned and may already exist/be created by the shared capture boundary; the A preflight does not duplicate identity logic;
- restart/reconciliation after the conflict is resolved must reuse the existing canonical Weblink rather than create another target;
- title/description/thumbnail remain compatibility-preserved in the legacy Bookmark row/mirror and are only best-effort resource enrichment; this slice does not claim they have been losslessly collapsed into one saved-item identity;
- direct Tag convergence remains B-owned (#1118/#1120); Images/Cover Image and other Relation-era convergence remain B/#1042 work.

Focused regression: `test/bookmark_weblink_user_state_convergence_test.dart` covers each scalar-state conflict before Relation/URL retirement plus conflict resolution followed by restart-style reconciliation with one reused Weblink target.

No schema/migration file is changed and no legacy Bookmark row/data is deleted.

### #1044 — Person migration A
Move normal Person identity/write authority to generic Person ObjectType while preserving stable identity, Body/note, Profile Image Relation compatibility and restart/reconciliation safety. Do not retire People UI or redesign groups/roles here.

## Recently integrated

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
- local Body structural Undo as interaction recovery, not durable history.

Older handoff statements that #1058 is still active are obsolete. #1041 is the current primary Lane A slice, with #1044 and later A-focused contracts remaining after live dependency review.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration and Tag hierarchy integrity. #1120 owns direct Bookmark Tag -> Weblink Tag convergence; do not duplicate it in #1041.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities. D/#1054 canonical capture is integrated and consumed by A/#1041, not work to duplicate.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after A/B/C/D parity.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. #1041 should remain in the focused Bookmark reconciliation boundary and tests unless a concrete acceptance gap proves another A-owned file is required. Do not take over B Relation convergence or D Weblink identity.

## Validation
GitHub Actions is authoritative when local Flutter execution is unavailable. #1041 requires changed-Dart format, Analyze/guards, focused preservation/restart regressions, full Flutter Test and authoritative merge-gate on an up-to-date head.

## Resume sequence
1. verify latest `main`, #1041, open PR ownership and current CI before editing;
2. validate the current saved-item scalar collision preflight and focused restart/reconciliation regressions;
3. fix only demonstrated #1041 preservation/reconciliation gaps; do not broaden into Tag/Image/role Relation convergence, UI retirement, schema deletion or D-owned Weblink identity;
4. integrate #1041 only after authoritative CI/merge-gate is green on a latest-main-synchronized head;
5. after integration, re-audit #1041 acceptance before closing it: conflicting legacy values must remain compatibility-preserved and restart must not duplicate canonical targets;
6. then refresh live A dependencies and continue the next safe A issue, normally #1044 unless another focused A obligation has become higher priority/unblocked.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane A continues while concrete safe A work exists; a single completed Issue/PR is never sufficient stop evidence. If the final resume audit finds no actionable A work, record `Stop reason: idle-no-work — <live evidence>` (or another exact stop category from `AGENTS.md`) in the durable handoff before stopping.
