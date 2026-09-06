# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. This file does not own Weblink/Image/File product work or generic Database/View presentation.

## Lane goal
Keep reusable Object/ObjectType identity and typed Property semantics coherent while making Body/detail behavior universal and preserving Daily Note identity/navigation semantics.

## Primary active issues
- #481 — universal Body/note surface for every ObjectType.
- #56 — Object/ObjectType/detail/opening/core semantics portions of the generic architecture umbrella.
- #484 — core user-defined ObjectType semantics and built-in-vs-user-defined boundary only; primitive implementation belongs to Lane D.

## Current integrated state
- PR #503 merged as `a8cf84d3af59ef537ae66518b7c7a9f4206c43c5`: Body editing is universal in the shared `ObjectInspectorPage` while system identity-sensitive title/Property/create guards remain unchanged.
- Center peek/full page reuse the shared Inspector; side peek remains a Lane C presentation dependency and must consume the same canonical Body/detail contract rather than create another persistence path.
- ObjectType duplication preserves Property order, defaults, Body templates and computed Property references with fail-closed corruption handling through the merged #550/#588/#599/#612/#624 sequence.
- Daily Note definition/default backfill and atomic create/register behavior are covered by merged #611/#618.

## Active Lane A PRs
### PR #640 — Reject invalid ObjectType default Property references
Branch: `fix-object-type-default-reference-write-56`
Head: `fdfd7197599cb8fa0bfe97b0c41b5148ef9ab0c6`

Scope:
- non-empty ObjectType defaults writes require an existing ObjectType;
- every `visiblePropertyIds` / `propertyOrder` id must belong to that ObjectType;
- stale/cross-type refs fail before persistence and preserve the prior defaults row;
- empty lists, Body-only defaults, opening-mode defaults and the focused Body-template seam remain valid.

Validation:
- Flutter CI #2019 is in progress; maintainability/legacy guards were green when last checked.
- PR is mergeable and changes only `object_type_defaults_store.dart` plus its focused test.

### PR #644 — Recover stale Daily Note registry claims
Branch: `fix/object-daily-note-stale-registry-56`
Head before this handoff update: `793640d1199ed1225fa9fbae20e5e1cb723e7276`

Scope:
- a registry claim is authoritative only when its `object_id` resolves inside the canonical Daily Note ObjectType;
- stale/corrupt date claims are removed so `INSERT OR IGNORE` cannot permanently block the date;
- after adopting a pre-registry Daily Note, the service re-resolves and returns the actual registry winner, covering concurrent winner semantics;
- no existing legacy Object is deleted merely because another registry winner exists.

Regression:
- seeds a registry row for a Daily Note date that points at an Object of another ObjectType;
- proves `openOrCreate` clears the stale claim, creates/returns the canonical Daily Note and persists the repaired registry winner.

Validation:
- Flutter CI #2026 is queued/running for the implementation head.
- No shared hotspot, Relation lifecycle, primitive, Database/View presentation, search, storage, or Refactor files are touched.

## Hotspot / concurrency state
- No new broad shared-hotspot lease is taken by #640 or #644; both are data/core/test slices.
- Open PR audit showed unrelated Lane C/D/E/F/G work, but no overlap with `daily_note_service.dart` in the active PR set checked for this run.
- `object_inspector_page.dart` should not be broadly rewritten; #503 already landed the required Phase-1 universal Body hunk.

## Cross-lane dependencies
- #481 side-peek Body composition remains Lane C because `GenericDatabasePage._detail` is the alternate presentation host.
- Body indexing belongs to Lane E/#494; Lane A should only preserve the canonical Body persistence/reference contract.
- Weblink/Image/File-specific rich detail or identity behavior belongs to Lane D.

## Next actions
1. Process CI #2019 for #640; if green and still mergeable, squash merge.
2. Process CI #2026 for #644; fix only failures caused by this slice, then squash merge when green/mergeable.
3. After both integrate, re-read latest #481/#56 and select another independent Lane A service/domain/test slice; prefer ObjectType defaults/identity, Body/reference, aliases, Daily Note or user-defined ObjectType core semantics over shared-host changes.
4. Do not implement side-peek layout, primitive-specific behavior, search indexing, Vault/filesystem, or #225 cleanup from this lane.

## Validation / stop reason for this run
- #503 merge state and CI success were verified.
- #640 live PR/CI state was checked; it remains in progress rather than being merged prematurely.
- #644 was implemented as an independent Daily Note identity slice with focused regression and CI started.
- This checkpoint stops with both focused CI runs still external/in progress; no additional clearly isolated high-confidence Lane A bug was taken after the handoff update to avoid stacking speculative changes while two core PRs are validating.
