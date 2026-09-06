# AI Progress — Search & Indexing Lane

> Lane E handoff. Read `AGENTS.md`, the active Issue, and `docs/AI_PROGRESS.md` before implementation.

## Lane goal
Converge search on one canonical Object-level indexing/query architecture that works for built-in primitives and user-defined ObjectTypes.

## Primary active issues
- #414 — stale FTS tokens after focused Bookmark refresh.
- #494 — unified Object search across title/aliases/Properties/Body/Weblink metadata/File-derived text.

## Owns
- FTS/search schema and query correctness.
- Incremental refresh/rebuild/reconciliation behavior.
- Search projection from Object title/aliases/selected Properties/Body.
- Weblink metadata contributions to the canonical projection.
- File/PDF extracted-text indexing after Primitive lane exposes derived text.
- Search ranking/filter context and result opening by canonical Object id.

## Does not own
- Weblink/File metadata extraction itself: Primitive lane.
- Body editing/persistence: Object Core lane.
- Database/View configuration UI: Database/View lane.

## Initial next actions
1. Reproduce #414 independently on latest main and identify whether focused row deletion or another indexing path leaves stale tokens.
2. Fix focused refresh without rebuilding unrelated records and add removed-title/tag regression coverage.
3. Inventory current Object/global/Bookmark search paths for #494 and classify canonical vs migration-only duplicates.
4. Define a canonical Object searchable projection with explicit contributors rather than domain-specific search repositories.

## Safety
- Removing/changing source data must remove stale searchable tokens.
- Derived text is rebuildable/search-only metadata, not Object identity.
- Do not log raw user content or extracted file text in diagnostics.
- Preserve current ranking/query behavior unless an Issue explicitly changes product semantics.

## Handoff checklist
Record active Issue, branch/PR/commit, reproduction status, index/query changes, validation, cross-lane data dependencies, next actions, and stop reason.
