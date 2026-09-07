# AI Progress — Object Core & Body Lane

> Lane A durable handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation. This file owns Object/ObjectType core semantics and universal Body behavior; it does not own primitive product behavior or generic Database/View presentation.

## Lane goal
Keep the reusable Object/ObjectType core coherent while making Body and Object detail capabilities universal across built-in and user-defined ObjectTypes.

## Primary active issues
- #481 — universal Body/note surface for every ObjectType.
- #56 — Object/ObjectType/detail/opening portions of the generic architecture umbrella.
- #484 — core user-defined ObjectType semantics and built-in-vs-user-defined boundary only; Weblink/Image/File/Tag implementation belongs to the Primitive lane.
- #493 — Object-core invariants around safe schema/value evolution; Relation lifecycle and Database/View authoring remain their owning lanes.

## Owns
- Object/ObjectType identity and core schema semantics.
- Typed Property value semantics that are not presentation-host-specific.
- Versioned Body/block/reference persistence and editing contracts.
- Universal Body capability across ordinary/system ObjectTypes.
- Aliases/shared Object identity metadata contracts.
- Daily Note identity/navigation and time-based Object patterns.
- Shared Object detail/opening semantics.
- User-defined ObjectType core behavior.

## Does not own
- Weblink/Image/File/Tag primitive product behavior -> `docs/AI_PROGRESS_PRIMITIVES.md`.
- Database/View/Table/List/Gallery/Board/schema-authoring UX -> `docs/AI_PROGRESS_DATABASE_VIEW.md`.
- Relation lifecycle/data-integrity internals -> `docs/AI_PROGRESS_RELATION.md`.
- Search/FTS/indexing -> `docs/AI_PROGRESS_SEARCH.md`.
- Vault/filesystem/delivery -> `docs/AI_PROGRESS_STORAGE.md`.
- behavior-preserving cleanup -> `docs/AI_PROGRESS_REFACTOR.md`.

## Current integrated core state
- Object/ObjectType persistence, generic Object records, aliases, shared detail content and typed Property presentation are integrated.
- Body is versioned/block-oriented and supports text/checklist/reference-style blocks plus Object and Database/View references.
- #503 made Body editing universal in the real `ObjectInspectorPage`; system identity-sensitive title/Property/create guards remain separate from Body capability.
- #689 merged as `0619bb7c640c67d02c26d6b08cf2114f1c9be614`: the real shared Inspector regression now covers Weblink, Image, an ordinary custom Person ObjectType, and Daily Note through the same canonical `ObjectBodyStore` edit path.
- Daily Note uses the shared Object model with one-note-per-date workflow semantics. #686 rejects registry claims whose referenced Object has a mismatched canonical Date and repairs only the stale claim.
- #677 enforces Record/Property ObjectType ownership at the low-level generic value boundary.
- #685 merged as `6da5f027e4109c496e35f140118c4d6e207c0ca1`: generic value upsert and parent Object freshness touch are one transaction.
- #699 is integrated: `ObjectStore.setPropertyValue(...)` resolves persisted Property semantics before mutation, rejects caller type drift/computed direct writes, and prevents a Relation Property from being disguised as a Value Property to bypass canonical Relation validation/index synchronization.
- Alias mutations and Body writes/clears advance Object freshness atomically; malformed top-level Body documents fail closed instead of becoming an empty document.
- Center peek and full-page generic openings reuse the canonical Object detail route. Generic Database/View side-peek composition remains Lane C ownership.

## Active Lane A PRs at 2026-09-07

### #698 — Bookmark universal Body parity
`feature/object-bookmark-universal-body-481`

Current intent:
- expose the canonical mirrored Bookmark Object Body inside the actual Bookmark detail composition used by Bookmark side/center/full opening;
- use reusable `ObjectBodyEditorSection` backed by existing Body/block/reference services;
- resolve Bookmark -> Object identity through focused data-layer `BookmarkObjectDetailContext`, not presentation -> raw database reach-through;
- fail soft for old/unmirrored Bookmark rows without manufacturing Object identity;
- fail closed on corrupt Body reads so read failure cannot be overwritten as an empty Body;
- ignore stale asynchronous Body loads after the host switches Objects.

The branch is being refreshed by another Lane A execution while CI runs. Always re-read the current PR head and require full green CI for that exact head before merge.

### #712 — exact generic create id ownership
`fix/object-create-returned-id-integrity-56`

Current slice:
- `GenericDatabaseStore.createDatabase/createProperty/createRecord` return the row id from Drift `customInsert(...)` for their exact INSERT;
- removes INSERT -> `ORDER BY id DESC LIMIT 1` identity lookup, which can return a different concurrent creator's row;
- focused concurrency regression verifies each returned id resolves to the name/title created by that specific Future;
- no Relation, Database/View presentation, primitive, Search, Storage, or Refactor behavior change.

Normal Flutter CI is required before merge.

## #481 close audit
Already covered on main or active Lane A work:
- Weblink Body in shared Inspector;
- Image Body in shared Inspector;
- ordinary/custom Person Body in shared Inspector;
- Daily Note Body in shared Inspector;
- Bookmark Body in its real legacy-compatible detail surface via #698.

Remaining cross-lane blocker:
- `GenericDatabasePage._detail(...)` still renders title/Properties/Backlinks without Body;
- generic Database side peek is Lane C-owned presentation, so Lane A must not broaden #698 into `generic_database_page.dart`;
- #481 must remain open until Lane C composes the canonical Body/detail contract into that side-peek surface.

## Hotspot / concurrency rules
- Do not broadly rewrite `object_inspector_page.dart`, `generic_database_page.dart`, `app_shell.dart`, or `bookmark_unified_stage1_page.dart` without a fresh open-PR ownership audit.
- #698 deliberately avoids the generic Database/View host.
- If `ObjectBodyEditorSection` lands, a later Lane A follow-up may make `ObjectInspectorPage` consume the same reusable section to remove duplicated Body editing composition, but only after checking hotspot ownership and preserving current Inspector-specific behavior.
- Do not redesign Relation persistence/indexing from this lane.

## Next actions
1. Process the latest exact-head CI for #698; merge only when the current head is green and mergeable. Do not close #481 afterward because the Lane C side-peek blocker remains.
2. Process #712 CI. If green and non-overlapping with newer main, merge; if Analyze/Test exposes a problem, fix only the returned-id slice.
3. After #698 integration, audit whether the shared Inspector can consume `ObjectBodyEditorSection` in a patch-sized, behavior-preserving Lane A follow-up without colliding with another hotspot owner.
4. Continue #56/#484 Object core only when a concrete invariant is demonstrated. Avoid speculative abstractions and cross-lane schema/presentation work.
5. Refresh this handoff after the active PRs settle so the next run does not resume from stale heads.

## Stop condition for this checkpoint
Do not stop merely because CI is running. Stop only when active Lane A PRs are integrated or have a concrete blocker, and no independent Object-core slice can safely proceed without crossing another lane's ownership.
