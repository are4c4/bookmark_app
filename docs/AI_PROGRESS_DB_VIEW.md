# AI Progress — Database / View Lane

> Durable handoff for the Database / View implementation lane. Update this file before every run in this lane ends.

## Lane scope

Own Database collection semantics, Database/View separation, View persistence/navigation, query controls, layouts, projection consistency, and database-page UX.

## Current goal

Complete the Database / View side of Issue #56 as a coherent, user-facing generic database workflow while minimizing overlap with Object / Relation work.

## Active Issue

`#56` — Integrate generic Object database UX toward Notion/Capacities workflow

## Current known state

- Generic Object filter/sort, grouping, Board view, Board drag/drop, and projection foundations already exist.
- PR #54 was the current Object view toolbar slice in the previous shared handoff and should be reviewed against latest `main` before new overlapping work.
- Database and View must remain distinct concepts:
  - Database = which Objects belong to the collection.
  - View = how that collection is presented/queried.
- Initial Database membership model: target ObjectType + Database-level `collectionFilter`.
- Multiple Views per Database are required with top-tab navigation.
- New View creation defaults to duplicating the current View config; blank View is a secondary path.
- View configuration should support layout/filter/sort/group/display settings and persist independently.
- Object opening should support side peek / center peek / full page, but shared Object-detail content belongs primarily to the Object / Relation lane.

## Next actions

1. Inspect current `main`, Issue #56, and open PRs before coding.
2. Review/land or supersede PR #54 safely.
3. Wire the shared View toolbar into the real generic database page.
4. Persist/restore Filter / Sort / Group / layout through the View store.
5. Route Gallery / List / Table / Board through the shared Object projection pipeline.
6. Implement Database-level `collectionFilter` separately from View-level filters.
7. Implement multiple Views per Database with top-tab navigation and overflow.
8. Add View create/duplicate/blank/rename/reorder/delete flows.
9. Add integration/regression tests and run relevant Flutter validation.

## Cross-lane boundaries

- Do not redesign Object/Property/Relation persistence here unless required by a small integration contract.
- If Object detail rendering is needed, consume a reusable Object detail surface from the Object / Relation lane rather than duplicating it.
- Coordinate schema changes that affect both Database membership and Object storage through Issue #56 and the repository-wide handoff.

## Completed

- Two-lane handoff structure established.

## In progress

- Resume from current GitHub PR/branch state after inspecting latest `main`.

## Validation

- Documentation-only lane split at creation time.

## Blockers / risks

- Avoid concurrent broad edits to `GenericDatabasePage` from both lanes.
- Existing PRs may have moved since this file was created; GitHub state is authoritative.
- GitHub Actions usage limits may require targeted local/static validation.
