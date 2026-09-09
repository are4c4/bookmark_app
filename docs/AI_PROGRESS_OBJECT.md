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

### #1057 — Body UX phase 2: contextual block handles and drag reorder
Primary next Lane A Body interaction slice after #1049.

Goal: make an idle Body read as content-first while preserving discoverable and accessible structural actions.

Required behavior:
- repeated block chrome is hidden while idle;
- desktop reveals a small block handle/add affordance on hover or focus;
- touch retains an explicit discoverable overflow/long-press-compatible path;
- drag reorder uses the canonical Body reorder mutation path and preserves block identity/payload/order;
- menu-based move up/down remains as keyboard/screen-reader fallback;
- insert/reference actions remain reachable without restoring a permanent full toolbar row;
- widget regressions cover idle/contextual visibility, focus, reorder and fallback commands.

### #1058 — Body structural edit Undo
Add local reversible Body structural edits/delete Undo without redesigning persistence. Keep this separate from #1057 unless live dependency review proves a tiny shared prerequisite is unavoidable.

### #1041 — Bookmark retirement A
Define collision-safe legacy Bookmark -> canonical Weblink/generic Object authority. Do not create a permanent canonical Bookmark Object. Preserve conflicting legacy user-authored content when lossless convergence is not provable.

### #1044 — Person migration A
Move normal Person identity/write authority to generic Person ObjectType while preserving stable identity, Body/note, Profile Image Relation compatibility and restart/reconciliation safety. Do not retire People UI or redesign groups/roles here.

## Recently integrated

### #1049 — Body UX phase 1
Merged through PR #1056 as squash commit `2f6eb24a7ff7fda6997703edc37d91e2087fd305`.

Delivered:
- Enter splits a paragraph at the caret and focuses the next paragraph;
- Shift+Enter remains an in-block newline;
- leading Backspace safely merges compatible plain paragraphs and restores the previous paragraph focus/caret;
- styled/heading or otherwise unsafe merge boundaries fail closed without data loss;
- lower-frequency move/duplicate/delete actions live in compact contextual overflow chrome while insertion remains nearby;
- text mutations are serialized so split/merge cannot race a stale paragraph save;
- domain, persistence, widget and real editor integration regressions cover the primary keyboard flow;
- the Object Inspector shared-action regression now opens the contextual menu rather than assuming permanent toolbar actions.

Authoritative validation for final PR head `85734340f2bbc49c48d5a4ee6a81590d1bf41149`: Flutter CI #3068 full green, including changed-Dart format, Analyze/guards and all four Flutter Test shards. AI Handoff Audit #91 and AI Migration Lease Audit #73 were also green.

Undo and richer idle/drag interaction were intentionally split to #1058 and #1057 respectively rather than broadening #1056.

## Integrated foundation that remains authoritative
- universal persisted Body model/opening surfaces;
- fail-closed Body structural/version validation with unknown/future block preservation;
- stable Object/ObjectType identity and generic Property semantics;
- Daily Note identity-managed Date protection;
- exact Search-agnostic canonical Object sync impact contract;
- template/object creation integrity and shared Object detail/opening seams.

Older handoff statements that “Lane A is idle after #909/#910” are obsolete because #1041/#1044/#1057/#1058 are focused open A issues.

## Cross-lane boundaries
- **B:** Relation mutation/read/index/backlink/audit/reconcile, Bookmark/Person relationship migration and Tag hierarchy integrity.
- **C:** Database/View/schema UX, Stage1/People generic collection replacement and Tag hierarchy query/filter/picker UX.
- **D:** Weblink URL identity/normalization/capture-native behavior and Image/File native capabilities.
- **E:** canonical Object Search projection/FTS freshness.
- **F:** Vault/filesystem/preservation lifecycle.
- **G:** behavior-preserving hotspot reduction and caller-zero legacy retirement after A/B/C/D parity.

## Hotspot / concurrency rule
Recheck live PR ownership before editing `object_inspector_page.dart`, `generic_database_page.dart`, Stage1, People or `app_database.dart`. Body UX should prefer reusable Body widgets/services/tests and avoid unrelated Inspector redesign.

## Validation
GitHub Actions is authoritative when local Flutter execution is unavailable. Body interaction slices require changed-Dart formatting, Analyze and full Flutter Test green plus real widget regressions for the changed interaction contract.

## Resume sequence
1. verify latest `main`, open PR ownership and the focused issue before editing;
2. prefer #1057 as the next Body UX dependency unless a newer live A dependency supersedes it;
3. implement idle/contextual chrome first without changing persisted Body format;
4. add reorder only through the existing canonical mutation seam and keep accessible move commands;
5. run changed-Dart format, Analyze and full Flutter Test CI, then merge only after green checks;
6. after #1057, refresh live A dependency order between #1058, #1041 and #1044 rather than assuming this file’s ordering is permanent.
