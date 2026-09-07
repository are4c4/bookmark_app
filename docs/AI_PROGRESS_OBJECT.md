# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, `docs/AI_PROGRESS.md`, live PR ownership and CI before implementation. GitHub is the source of truth; this file is only a checkpoint.

## Lane goal
Keep reusable Object/ObjectType identity, typed Property semantics, universal Body, Daily Note identity/navigation and shared detail/opening contracts coherent across built-in and user-defined ObjectTypes.

## Current status — 2026-09-08
**Lane A currently has no independent actionable product acceptance item.**

The two recent A-facing product tracks are complete:
- #481 — universal Body/note surface — completed/closed after #874 composed the canonical `ObjectBodyEditorSection` into Generic Database side peek.
- #249 — Bookmark Gallery/List presentation parity — completed/closed after #885 moved the real Stage1 Gallery onto the shared fixed/masonry View contract.

#56 remains the broader product umbrella. Resume Lane A only for a concrete Object/ObjectType/Body/Daily Note/shared-detail invariant or an explicitly A-owned #56 slice. Do not create speculative Object abstractions merely to keep the lane active.

## Universal Body — completed product contract
The universal Body path now has the required real-host parity:
- system and custom Objects edit Body through the shared canonical persistence model;
- Weblink/Image identity-sensitive Property rules remain independent from Body mutability;
- custom Objects and Daily Notes use the same Body contract;
- Bookmark detail composes canonical Object Body without a Bookmark-specific note table/writer;
- Generic Database side peek composes `ObjectBodyEditorSection` (#874);
- center/full generic openings use the shared Object Inspector path;
- side/center/full therefore operate on the same canonical persisted Body;
- Body text participates in canonical Object Search through Lane E;
- rich/unknown blocks remain forward-compatible while malformed known structure fails closed.

#481 is closed. Do not reopen it because historical handoff text still describes the old side-peek gap.

## Object/Body integrity already integrated
Representative completed core correctness includes:
- #503 — universal Inspector Body editing for system/custom Objects.
- #511/#517 — ObjectType Body templates and focused default updates.
- #521 — reject blank/lossy/duplicate Body block identities.
- #667 — Body clear advances parent `updated_at` only on a real persisted removal.
- #670/#749/#755/#761/#796 — malformed Body document/version/block/known-checklist states fail closed while valid future/unknown content stays forward-compatible.
- #689 — custom ObjectType and Daily Note Body regressions.
- #699 — persisted Property ObjectType/type/semantics are authoritative for `setPropertyValue`.
- #712 — concurrent generic Object creation returns the exact inserted row id.
- #724 — intrinsic created/updated timestamps remain read-only.
- #740 — ObjectType defaults reject duplicate Property ids on write/read.
- #780 — Bookmark detail composes canonical Body through Bookmark -> Object identity.
- #811 — corrupt Body gets safe fail-closed load/retry presentation rather than editable-empty fallback.
- #827/#833/#843 — template preflight/transaction/naming invariants prevent partial primitive provisioning or ambiguous Property identity.
- #835 — unknown persisted Property storage types fail closed instead of coercing to Text.
- #874 — Generic Database side peek reuses the canonical Body editor; #481 closes.

These are existing contracts, not invitations to redesign the Body model.

## Bookmark presentation parity — completed focused scope
#249 is now completed/closed:
- one Person/Object target per semantic chip is integrated;
- Bookmark List hierarchy/spacing/long-content behavior is substantially converged;
- Bookmark URL presentation uses the canonical resolver path;
- shared opening-mode parity is complete under #247;
- #480 extracted the reusable Gallery mode control;
- #885 (`38494512…`) mounts that shared control in the real Bookmark host, persists `settings['galleryMode']` per View and renders through `ObjectGalleryView` fixed/masonry geometry;
- #885 real-host regression switches fixed -> masonry -> fixed and verifies persisted View state; Flutter CI #2712 is fully green.

Real-macOS visual usage may still reveal polish follow-ups under #56, but there is no remaining #249 implementation acceptance item.

## Current ownership boundaries
### Lane A owns
- Object/ObjectType identity and core semantics;
- typed Property value invariants not specific to a presentation host;
- universal Body persistence/edit/detail contracts;
- Daily Note identity/navigation semantics;
- shared Object opening/detail behavior;
- focused Object-core obligations from #56.

### Lane A does not own by default
- #155/#245 Weblink/Image/File/Photo product semantics — Lane D;
- Relation mutation/index/backlink/audit/reconcile correctness — Lane B;
- Database/View/schema/template UX — Lane C;
- canonical FTS refresh/index orchestration — Lane E;
- Vault/filesystem/release delivery — Lane F;
- broad behavior-preserving hotspot extraction/legacy deletion — Lane G/#225.

A file location does not change lane ownership. For example, a patch in `GenericDatabasePage` can still be Primitive/Object work if it only composes an existing domain seam.

## Current cross-lane context
- #245 is actively migrating legacy Photo authority to canonical Image Objects/Relations. #881 already moved Bookmark detail image editing onto canonical `Images` / `Cover Image` Relations. Do not absorb that work into Lane A because it touches Bookmark presentation.
- #888 is Search-owned: nested Daily Note navigation from a Search-opened Inspector can leave a visited Object's FTS row stale. Lane E may add a generic optional visited-Object navigation callback/collector to Object Inspector, but it must keep Search orchestration out of Object domain code.
- #225 may later consolidate duplicate Body presentation orchestration or reduce `ObjectInspectorPage` responsibility. Such extraction is Refactor-owned unless a concrete Object correctness defect requires a smaller A slice.

## Hotspot / concurrency rules
Always re-audit open PR changed files before editing:
- `lib/views/object_inspector_page.dart`
- `lib/views/generic_database_page.dart`
- `lib/views/bookmark_unified_stage1_page.dart`
- `lib/views/app_shell.dart`
- other repository-wide hotspots listed in `AGENTS.md` / `docs/AI_PROGRESS.md`.

Prefer store/service/test-level core fixes when possible. Do not broad-rewrite a shared host to solve a small invariant.

## Stop reason / resume triggers
Current stop reason satisfies the AGENTS idle criterion: **no remaining independent actionable Lane A product work is known.**

Resume Lane A when one of these occurs:
1. #56 or a new Issue defines a concrete Object/ObjectType/Body/Daily Note/shared-detail acceptance gap;
2. another lane exposes a real Object-core invariant that must be fixed below presentation;
3. a reproducible corruption/identity/detail regression is reported;
4. ownership of a focused product slice is explicitly reassigned to A.

Do not reopen completed #481/#249 or old #484/#490/#493 tasks from historical prose. Start every future run from live GitHub state.
