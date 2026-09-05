# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, Object-owned presentation, and app-shell/product delivery work that does not belong to Relation semantics.

## Active issues
- `#56` — generic Object/Database/View daily-use product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation and legacy compatibility retirement.
- `#247` — Bookmark View opening-mode parity, especially center peek; implementation is open in #344.
- `#249` — Bookmark Gallery/List presentation parity; one-Person-per-chip is merged, List density and Bookmark fixed/masonry remain.
- `#252` — direct Notion-like Property-add UX; shared anchored popover foundation is open in #346.
- `#149` — deterministic shared Property handle is merged; Bookmark detail still bypasses the shared handle slot and remains a focused follow-up.
- `#245` — legacy Photos -> canonical Image Objects; managed Image import is already live, broader legacy migration remains.
- `#242` — user-selectable Vault folders; designed but lower priority while presentation parity is actionable.

`#156` fixed/masonry generic Gallery is complete/closed. Maintainability/legacy-only cleanup is owned by Refactor under `#225`.

## Current integration state — 2026-09-06
The generic Object/Database/View foundation is live. Current Object work is mainly daily-use parity and replacement of remaining legacy Bookmark presentation/read surfaces before compatibility storage can retire.

Important merged state:
- canonical Bookmark -> Weblink and Weblink -> managed Image/Representative-image Relation flows are live;
- Weblinks / Images / Daily Notes are exposed through generic Database/sidebar hosts;
- canonical Weblink URL-entry and managed Image import are live in the generic host (#286/#291);
- fixed/masonry Gallery and managed Weblink/Image media are integrated, including fixed-mode managed media (#334);
- Weblink/Image generated defaults, generated titles, site name/favicon metadata and safe clickable URL Properties are integrated (#293/#298/#302/#309/#311);
- direct generic Weblink creation performs fail-soft metadata/preview enrichment (#303), with canonical Relation lifecycle coverage (#307);
- canonical Bookmark visual presentation is shared across Notion card, reverse lookup, lifecycle rows and Stage1 List/Table (#294/#299/#296/#324);
- canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion cards and Stage1 Gallery/List/Table/browser-open (#317/#320/#322/#341);
- one semantic chip per Bookmark Person role assignment is merged (#301);
- GenericDatabasePage read/projection and dependency-composition responsibilities moved out through Refactor #310/#323.

## Current Object PR — #344 / #247
Branch: `feature/object-bookmark-opening-mode-247`
Head at handoff: `b70e85c7a06bf8feb41ea05a67e36b401217bbf5`
PR: `#344 Honor Bookmark View opening mode`

Implemented:
- Stage1 Gallery/List/Table normal item selection now delegates to `_presentBookmark(...)` instead of directly forcing `_selectedBookmarkId`;
- the active Bookmark View opening mode is resolved through `DatabaseViewOpenModeService`;
- presentation delegates to the shared `ObjectOpenPresentationHost`;
- side peek preserves the existing right-side `BookmarkDetailPanel` branch;
- center peek and full page reuse the same `BookmarkDetailPanel` content through the shared host;
- stale side-panel selection is cleared before center/full presentation;
- the Bookmark overflow `詳細を表示` action uses the same opening-mode dispatch;
- selection-mode behavior is unchanged;
- deterministic Stage1 guard coverage verifies the shared dispatch boundary without reintroducing the heavyweight Stage1 WidgetTester lifecycle that previously stalled CI.

Validation at this handoff:
- #344 Flutter CI run #1311: Generate + Analyze succeeded; full Test is still running.
- no Relation writes, schema changes, URL/Image identity changes or Refactor-owned extraction were introduced.

Do not merge #344 until the full Test job is green. If CI fails, inspect and fix the exact failure before any #249 edit to `bookmark_unified_stage1_page.dart`.

## Parallel safe foundation — #346 / #252
Branch: `feature/object-property-add-popover-252`
Head at handoff: `c395ef237f7605aa24b3a7da4db53c09010d0a62`
PR: `#346 Add shared anchored Property add popover`

Implemented without touching a shared host:
- reusable `PropertyAddPopover` under shared Database presentation widgets;
- anchored `MenuAnchor` interaction from a caller-owned `+` action;
- search/filter of caller-supplied hidden Properties and one-click reveal callback;
- same compact surface can switch to new-Property creation;
- canonical Property type definitions stay caller-owned through supplied `PropertyAddTypeOption`s rather than a second type registry;
- persistence, Relation/computed semantics and View visibility remain host/application-owned;
- widget regressions cover search/reveal and typed create-new flows.

Validation at this handoff:
- #346 Flutter CI run #1313: Generate + Analyze succeeded; full Test is still running.

Next #252 slice after #346 is green/integrated: use the shared popover from generic detail/Table, wiring hidden-property reveal to current View visibility and create-new to the existing canonical `_createProperty` semantics. Keep Relation/formula/rollup persistence in existing services rather than moving it into the widget.

## #149 root-cause follow-up
Fresh inspection confirmed the remaining Bookmark-only visual mismatch is concrete, not a shared `PropertyDragHandle` failure:
- `BookmarkReorderableProperties` still defines its own `_dragHandle()` with `Icons.drag_indicator`;
- it places that glyph in an outer `Row(crossAxisAlignment: CrossAxisAlignment.start)` beside `DetailPropertyRow`;
- shared `DetailPropertyRow` already provides a fixed 28x34 `dragHandle` column that centers the supplied visual on the first-line grid;
- shared `PropertyDragHandle` already supplies deterministic 2x3-dot geometry.

This evidence was recorded on Issue #149. The next safe #149 implementation should remove the Bookmark-local glyph/outer-handle geometry and feed shared `PropertyDragHandle` into `DetailPropertyRow.dragHandle` while preserving the host-owned `ReorderableDragStartListener`. Real-host visual confirmation remains required before closing #149.

## Exact next Object actions
1. Finish #344 validation; merge only after full green CI. Then validate center/side/full presentation in the real Bookmark host and update/close #247 only when acceptance is proven.
2. Finish #346 validation; after integration, wire the shared Property add popover into generic detail/Table as a small #252 slice.
3. Implement the focused #149 Bookmark drag-handle convergence described above; avoid another pixel-offset patch.
4. Continue #249 after #344 releases the Stage1 hotspot: improve List row hierarchy/spacing, then reuse the existing fixed/masonry View contract in Bookmark Gallery. Do not duplicate #156 settings/renderers.
5. Continue #155 legacy URL/thumbnail retirement only after every user-facing host has a proven canonical replacement. Keep compatibility/import/export data until caller-zero and migration policy are explicit.
6. Continue #245 only with safe staged Photo -> Image promotion/migration slices; no destructive table removal.
7. Defer broad Vault work (#242) while higher-value presentation parity remains actionable unless storage-path work becomes a direct dependency.

## Cross-lane boundaries
### Relation
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. #344 and #346 are presentation/UI-contract work and introduce no new Relation mutation semantics. Resume Relation implementation only for a genuinely new Relation-producing workflow or concrete correctness regression.

### Refactor — #225
At the start of this run open Refactor PRs were #336, #340 and #342; they own focused attachment/profile failure/privacy work and did not own the Stage1 or new Property-popover files used here. Inspect ownership again before every shared-host edit. Object owns product-semantic replacement surfaces; Refactor owns behavior-preserving extraction/deletion after parity is proven.

## Risks / blockers
- large shared hosts remain conflict-prone; use focused patches and compare the final branch against latest main;
- do not start #249 Stage1 edits while #344 is open;
- #252 host integration should wait for the shared #346 component to be green/integrated and should inspect GenericDatabasePage ownership again;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data while production/import/export paths still need them;
- identity-sensitive Weblink/Image creation must not regress to generic title-only creation;
- ambiguous Relation state must fail closed in presentation; do not repair it from widgets;
- #149 requires visual evidence in the actual Bookmark host after the concrete Bookmark-local handle path is replaced.

## Validation
- #341 final Flutter CI run #1305: success and merged as `d62f5d60e5fe768db8ca8b56fec20b52c7660bd9`.
- #344 run #1311: Analyze green; Test running at handoff.
- #346 run #1313: Analyze green; Test running at handoff.

## Stop / continuation condition
This run produced two independent, conflict-aware Object slices (#344 for #247 and #346 foundation for #252), plus a concrete #149 root-cause finding. Continue by resolving both active CI runs first. Once #344 is integrated, the Stage1 hotspot is free for #249; once #346 is integrated, generic detail/Table can adopt the shared Notion-like Property-add flow. No product/design clarification is required.