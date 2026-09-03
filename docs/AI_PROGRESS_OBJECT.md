# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, and Value-to-Object promotion contracts.

## Active Issue
`#56` — Integrate generic Object database UX toward Notion/Capacities workflow.

## Current integration state
The Object lane is in real-host completion. `main` includes the major Database/Object-detail/Body/Daily Note integrations, real Multi-View management verification, real Object + Database/View Body-reference insertion, and the shared contextual Object opening presentation host through PR #131.

Key real-host milestones on `main` include #111 GenericDatabasePage collection-aware integration, #112/#113 shared Object Property/Body inspector integration, #115 Body actions, #117 Daily Note navigation, #120/#121/#124 Object Body references, #127 Multi-View management verification, #128/#130 Database/View Body references, and #131 the side/center/full-page presentation host plus canonical opening resolver composition.

The current production priority remains contextual Object opening: make real `GenericDatabasePage` record/card selection consume persisted opening-mode resolution for side peek / center peek / full page while reusing `ObjectInspectorPage` detail content.

## Active branch / PR
- Branch: `feature/object-open-presentation-resolved-host`
- PR: #132 — `Resolve and present Object opening in one host call`
- Latest functional head before this handoff update: `95f7d6851a8191d1698938e23bfb245e31afb6ec`
- Flutter CI #665 is running on that functional head at this checkpoint.

## Checkpoints completed in this run
1. **Confirmed and integrated Object-reference host work**
   - PR #124 had already completed Flutter CI #640 successfully and was merged before this run resumed.
   - Real `ObjectInspectorPage` now persists explicit Object Body references through the typed latest-read controller path.
   - Subsequent #130 is also merged, so the real inspector supports Database/View Body references as well.

2. **Validated and merged shared Object opening presentation host**
   - PR #131 latest head `19e8c838e02310500a68d74743d7c1ad0920c9ce` passed Flutter CI #663.
   - Squash-merged as `da8c2906b6eda363db5906a8f1d61c93fd567f1b`.
   - `ObjectOpenPresentationHost` maps resolved `sidePeek` to contextual pane state, `centerPeek` to a modal dialog, and `fullPage` to Navigator routing while sharing one detail builder.
   - `GenericDatabasePageServices` exposes canonical `ObjectOpenPresentationService` resolution.

3. **Reduced the remaining real-host patch surface**
   - PR #132 adds `ObjectOpenPresentationHost.openResolved(...)`.
   - The method delegates mode resolution to `ObjectOpenPresentationService`, then immediately presents the result through the existing host.
   - It returns the resolved `ObjectOpenMode` for host-level regressions/diagnostics.
   - This prevents the large real Database page from reimplementing `View > Database > ObjectType > app` precedence.

4. **Added resolved-presentation regression coverage**
   - Existing side/center/full presentation tests remain.
   - New coverage proves a View `fullPage` override wins over an ObjectType `centerPeek` default and routes shared detail as a full page.

## Exact next actions
1. Inspect PR #132 latest-head CI; fix branch-caused failures and merge when green/mergeable.
2. On latest `main`, make a tightly controlled `GenericDatabasePage` patch that calls `ObjectOpenPresentationHost.openResolved(...)` from real record/card selection.
3. Preserve current `_selectedRecordId` + `ResizableDetailPane` behavior for `sidePeek`; use shared `ObjectInspectorPage` for center/full page.
4. Route Gallery/List/Table/Board selection through one page method so all layouts obey the same persisted open mode.
5. Add real-host tests covering at least side peek, a View full-page override, and center peek/ObjectType fallback; extend across layouts where practical without duplicating test setup.
6. After contextual opening lands, prioritize active-use regressions/polish before broader model expansion.
7. Keep Image/File Body reference actions hidden until concrete selectors exist; keep manual include/exclude deferred.
8. Implement `RichText/Document Property` only after navigation is stable because of its broad enum/query/group/Board/detail impact.

## Cross-lane boundaries
- Relation lifecycle, bidirectional integrity, source/target validation, backlink/index repair, stale metadata handling, and Tag hierarchy mutation remain Relation-owned.
- User-facing Relation Property writes must continue through canonical Relation mutation/editor APIs.
- Body Object/Database/View references remain document references, not Relation Property writes.
- GenericDatabasePage, Object detail/navigation, Body editing/reference insertion, Daily Notes, and multi-View UX remain Object-owned.
- No active Relation dependency blocks the current opening-mode work.

## Risks / blockers
- No product/design blocker is active.
- `GenericDatabasePage` remains a large hotspot. This connector replaces existing files as whole files; the actual host wiring must therefore be a narrowly controlled edit against the exact current blob SHA with diff verification. PR #131/#132 intentionally shrink the required page logic.
- Rich Body documents must never be flattened through paragraph-only adapters.
- Opening modes must reuse shared detail content rather than creating separate editors.
- Avoid duplicate work if another Object run opens a real-host navigation PR; inspect current branches/PRs before editing the hotspot.

## Validation
- #124 Flutter CI #640: success; merged.
- #130 Flutter CI #657: success; squash merge `0e0ea6e628d238f7861adc06a3ff730ed001f396`.
- #131 Flutter CI #663: success; squash merge `da8c2906b6eda363db5906a8f1d61c93fd567f1b`.
- #132 functional head `95f7d6851a8191d1698938e23bfb245e31afb6ec`: Flutter CI #665 running at this handoff checkpoint.
- Connector runtime has no local Flutter SDK; executable validation relies on GitHub Actions for connector-only changes.

## Stop reason
No architectural/product blocker is active. The remaining production step is the focused real `GenericDatabasePage` opening-mode patch. Continue after #132 CI resolves; pending CI itself is not a stop reason, but avoid unsafe broad whole-file replacement or overlapping a parallel run on the same hotspot.
