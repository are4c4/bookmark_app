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

## Active focused issues

### #1049 — Body UX phase 1
Primary current Lane A implementation.

Goal: make ordinary paragraph editing feel like a document rather than a form/list of block toolbars.

Required behavior:
- Enter splits/creates the next paragraph at the current selection;
- Shift+Enter inserts an in-block line break;
- Backspace at the safe leading boundary merges/focuses the previous text block;
- block actions are contextual rather than permanently occupying toolbar rows;
- focus/caret order remains predictable after split/merge/delete;
- existing persisted Body data opens unchanged.

Current implementation branch: `feature/object-body-document-chrome-1049`.
Latest durable branch checkpoint at this refresh: `0dd7f82751c7fa2cb4bc5838a3b9204c0998de89` (`test: persist safe paragraph merge behavior`).

Already implemented on that branch:
- Enter paragraph split and next-block focus;
- Shift+Enter in-block line break;
- safe paragraph Backspace merge service/persistence behavior;
- compact/contextual block action menu while insert remains close at hand;
- persisted split/merge regressions and contextual-control tests.

Exact remaining #1049 work:
1. add a real widget-level Backspace interaction regression through `ObjectBodyBlockView`;
2. add/complete editor integration coverage proving Backspace -> persisted merge -> previous paragraph focus/caret position;
3. verify unsafe boundaries remain no-op/fail-safe and preserve Body data;
4. run changed-Dart format, Analyze and full Flutter Test CI;
5. refresh this handoff from final branch state, open PR and merge after green checks;
6. split Undo/drag/slash-command work into follow-ups if it cannot be delivered cleanly inside #1049 without broadening the issue.

### #1041 — Bookmark retirement A
Define collision-safe legacy Bookmark -> canonical Weblink/generic Object authority. Do not create a permanent canonical Bookmark Object. Preserve conflicting legacy user-authored content when lossless convergence is not provable.

### #1044 — Person migration A
Move normal Person identity/write authority to generic Person ObjectType while preserving stable identity, Body/note, Profile Image Relation compatibility and restart/reconciliation safety. Do not retire People UI or redesign groups/roles here.

## Integrated foundation that remains authoritative
- universal persisted Body model/opening surfaces;
- fail-closed Body structural/version validation with unknown/future block preservation;
- stable Object/ObjectType identity and generic Property semantics;
- Daily Note identity-managed Date protection;
- exact Search-agnostic canonical Object sync impact contract;
- template/object creation integrity and shared Object detail/opening seams.

Older handoff statements that “Lane A is idle after #909/#910” are obsolete because #1041/#1044/#1049 are now focused open A issues.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration and Tag hierarchy integrity.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after A/B/C/D parity.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. #1049 should prefer reusable Body widgets/services/tests and avoid unrelated Inspector redesign.

## Validation
GitHub Actions is authoritative when local Flutter execution is unavailable. #1049 acceptance requires changed-Dart formatting, Analyze and full Flutter Test green, plus interaction-focused regressions for the primary keyboard flow.

## Resume sequence
1. verify latest `main`, #1049, active branch head and live PR ownership;
2. refresh/rebase branch if the Object-first docs/main foundation changed in an overlapping way;
3. finish the two Backspace interaction/persistence-focus regressions;
4. fix any failures, push coherent commits and open the focused PR;
5. while CI runs, continue only independent #1049 work; do not jump into #1041/#1044 unless #1049 is complete or blocked;
6. after #1049 merges, select the next A issue from live dependency order rather than assuming this handoff’s ordering is permanent.