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

### #1058 — Body structural edit Undo
Current primary Lane A Body slice after #1057.

Required behavior:
- normal block deletion remains confirmation-free and immediately exposes a short-lived Snackbar `元に戻す` action;
- successful Undo restores the exact block ID/type/text/attributes/reference payload at its original position;
- delete and inverse restoration use persisted Body as authority;
- if any later mutation makes the inverse unsafe, Undo fails closed and never overwrites newer content;
- the implementation remains local/in-memory rather than introducing a workspace command stack or durable history subsystem;
- no Body/schema migration is introduced;
- service and real widget regressions cover exact restoration, one-shot Undo and stale/conflicting Undo preservation.

Current implementation boundary:
- `ObjectBodyStore.writeIfUnchanged()` provides a narrow transactional compare-and-swap write over canonical Body JSON;
- `ObjectBodyStructuralUndoService` owns short-lived delete inverse tokens and exact restoration;
- the shared Body editor and patch-sized Object Inspector delete path use the same service and user-facing recovery/error contract;
- real shared-editor regressions cover both successful delete → Undo and delete → later mutation → rejected stale Undo.

### #1041 — Bookmark retirement A
Define collision-safe legacy Bookmark -> canonical Weblink/generic Object authority. Do not create a permanent canonical Bookmark Object. Preserve conflicting legacy user-authored content when lossless convergence is not provable.

D/#1054 is already integrated: `BookmarkWeblinkObjectBridge` consumes the canonical Weblink capture boundary. A must not reimplement or revert that wiring. The remaining A-owned work is legacy Bookmark user-state convergence, ambiguous multi-Bookmark collision/preservation policy, restart/reconciliation semantics and transition authority.

### #1044 — Person migration A
Move normal Person identity/write authority to generic Person ObjectType while preserving stable identity, Body/note, Profile Image Relation compatibility and restart/reconciliation safety. Do not retire People UI or redesign groups/roles here.

## Recently integrated

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

Authoritative final head `9c40f537af1ae187852db16f6a1a0672a4978bdb`: Flutter CI #3219 full green, including changed-Dart format, Analyze/guards, all four Flutter Test shards, test-health and merge-gate. AI Handoff Audit, AI Migration Lease Audit and Repository Settings Audit were also green.

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

Undo and richer idle/drag interaction were intentionally split from #1049 rather than broadening the phase-1 change.

## Integrated foundation that remains authoritative
- universal persisted Body model/opening surfaces;
- fail-closed Body structural/version validation with unknown/future block preservation;
- stable Object/ObjectType identity and generic Property semantics;
- Daily Note identity-managed Date protection;
- exact Search-agnostic canonical Object sync impact contract;
- template/object creation integrity and shared Object detail/opening seams.

Older handoff statements that “Lane A is idle after #909/#910” or that #1057 is still pending are obsolete. #1058 is the current Body slice, with #1041/#1044 and other focused A issues remaining after live dependency review.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration and Tag hierarchy integrity.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities. D/#1054 canonical capture is already integrated and is a prerequisite consumed by A/#1041, not work to duplicate.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after A/B/C/D parity.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. Body UX should prefer reusable Body widgets/services/tests and avoid unrelated Inspector redesign. #1058 uses only patch-sized Inspector wiring; if another live PR acquires that hotspot, resolve ownership before further edits.

## Validation
GitHub Actions is authoritative when local Flutter execution is unavailable. Body interaction slices require changed-Dart formatting, Analyze and full Flutter Test green plus real widget regressions for the changed interaction contract.

## Resume sequence
1. verify latest `main`, open PR ownership and #1058 before editing;
2. keep #1058 limited to local delete Undo and other already-demonstrated lossless inverse behavior; do not introduce durable history or a broad command-stack abstraction;
3. re-audit `object_inspector_page.dart` ownership before any further Inspector edit;
4. run changed-Dart format, Analyze/guards and full Flutter Test, then integrate #1058 only after the required merge-gate is green on an up-to-date head;
5. after #1058 integrates, close it if needed and refresh live A dependencies rather than stopping;
6. unless a newer dependency supersedes it, audit #1041 next against the already-integrated D/#1054 bridge and implement only the remaining A-owned preservation/reconciliation semantics; keep #1044 separate and avoid People UI/Relation redesign.

This sequence is not terminal. After any slice/PR/merge, apply the shared **Lane continuation and resume/stop contract** in `AGENTS.md` before ending the run. Lane A continues while concrete safe A work exists; a single completed Issue/PR is never sufficient stop evidence. If the final resume audit finds no actionable A work, record `Stop reason: idle-no-work — <live evidence>` (or another exact stop category from `AGENTS.md`) in the durable handoff before stopping.
