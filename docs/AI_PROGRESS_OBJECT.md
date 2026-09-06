# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, Object-owned presentation, and app-shell/product delivery work that does not belong to Relation semantics.

## Active issues
- `#56` — generic Object/Database/View daily-use product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation and legacy compatibility retirement.
- `#247` — Bookmark View opening-mode parity; implementation #344 is merged, real-host validation remains before close.
- `#249` — Bookmark Gallery/List presentation parity; one-Person-per-chip is merged, List density and Bookmark fixed/masonry remain.
- `#252` — direct Notion-like Property-add UX; shared popover #346 is merged and real generic detail/Table integration is open in #349.
- `#149` — Bookmark Property handle now converges on the shared deterministic row grid through merged #348; real-host visual confirmation remains before close.
- `#245` — legacy Photos -> canonical Image Objects; managed Image import and a legacy Photo->Image bridge already exist, broader product migration/legacy UI retirement remains.
- `#242` — user-selectable Vault folders; designed but lower priority while presentation parity is actionable.

`#156` fixed/masonry generic Gallery is complete/closed. Maintainability/legacy-only cleanup is owned by Refactor under `#225`.

## Current integration state — 2026-09-06
The generic Object/Database/View foundation is live. Current Object work is mainly daily-use parity and replacement of remaining legacy Bookmark presentation/read surfaces before compatibility storage can retire.

Important merged state:
- canonical Bookmark -> Weblink and Weblink -> managed Image/Representative-image Relation flows are live;
- Weblinks / Images / Daily Notes are exposed through generic Database/sidebar hosts;
- canonical Weblink URL-entry and managed Image import are live in the generic host (#286/#291);
- fixed/masonry Gallery and managed Weblink/Image media are integrated, including fixed-mode managed media (#334);
- Weblink/Image generated defaults, generated titles, site name/favicon/content-type/published-date metadata and safe clickable URL Properties are integrated (#293/#298/#302/#309/#311/#339);
- direct generic Weblink creation performs fail-soft metadata/preview enrichment (#303), with canonical Relation lifecycle coverage (#307);
- canonical Bookmark visual presentation is shared across Notion card, reverse lookup, lifecycle rows and Stage1 List/Table (#294/#299/#296/#324);
- canonical Bookmark URL presentation covers lifecycle, reverse lookup, Notion cards and Stage1 Gallery/List/Table/browser-open (#317/#320/#322/#341);
- Bookmark Stage1 honors the active View opening mode through the shared presentation host (#344);
- Bookmark Property rows use the shared deterministic six-dot first-line grid (#348);
- one semantic chip per Bookmark Person role assignment is merged (#301);
- GenericDatabasePage read/projection and dependency-composition responsibilities moved out through Refactor #310/#323.

## Completed this run — #346 / #252 shared Property-add foundation
Branch: `feature/object-property-add-popover-252`
Final head: `7db55914177610bd62ba746b8166470b0580f7be`
Merged PR: `#346 Add shared anchored Property add popover`
Merge commit: `446679baceddaa684bdc89ec112ed0675dbf6906`

Implemented:
- reusable `PropertyAddPopover` under shared Database presentation widgets;
- anchored `MenuAnchor` interaction from a caller-owned `+` action;
- search/filter of caller-supplied hidden Properties and one-click reveal callback;
- same compact surface can switch to new-Property creation;
- canonical Property type definitions remain caller-owned through supplied `PropertyAddTypeOption`s;
- persistence, Relation/computed semantics and View visibility remain host/application-owned;
- widget regressions cover hidden-Property search/reveal and typed create-new flows.

CI handling:
- initial full Test exposed two UI-test-only issues: inherited `PrimaryScrollController` reuse inside the popover and an ambiguous text finder;
- internal scrolling was isolated with `primary: false` and tests were moved to stable candidate keys;
- Flutter CI run #1318 passed Generate + Analyze + full Test before merge.

## Completed this run — #348 / #149 Bookmark handle convergence
Branch: `feature/object-bookmark-property-handle-149`
Final head: `24843c4e3156709330a14fc92616020bc45c565d`
Merged PR: `#348 Align Bookmark Property drag handles with shared row grid`
Merge commit: `8727128c49a6ed5b6a8a0b74e371278b9d19fb4b`

Implemented:
- removed the remaining Bookmark-local `Icons.drag_indicator` glyph path;
- reused shared deterministic `PropertyDragHandle`;
- moved the host-owned `ReorderableDragStartListener` into `DetailPropertyRow.dragHandle` so Bookmark uses the same fixed first-line handle column as generic detail;
- preserved reorder indexes/gesture ownership and all Bookmark Property semantics;
- kept each reorderable item keyed;
- added a deterministic architecture guard that forbids the legacy glyph/outer-row path.

Validation:
- Flutter CI run #1322 passed Generate + Analyze + full Test before merge.
- Issue #149 remains open only for real-host visual confirmation per its close condition.

## In progress — #349 / #252 real generic host integration
Branch: `feature/object-property-add-host-252`
Head at handoff: `ce32a03149d77d5f1f3d18b9534668811d6907d0`
PR: `#349 Use anchored Property add flow in generic detail and Table`

Implemented:
- shared popover now supports either icon-only or labeled caller-owned triggers;
- real generic Table header `+` uses the anchored popover;
- real generic side-detail `プロパティを追加` uses the same anchored popover;
- existing View-hidden Properties can be exposed with one click and are appended to explicit View order without changing the established empty-list = natural/all-visible semantics;
- simple one-step Property types (text, number, checkbox, date, URL, rating) can be created compactly through the existing `GenericDatabaseStore` path;
- advanced select/multiSelect, Relation, formula and rollup creation remains on the existing top-header advanced modal/configuration path, avoiding duplicate Relation/computed semantics;
- real `GenericDatabasePage` regression reveals an existing hidden Property and creates a new Number Property from the same Table popover, then verifies persisted View visibility/order.

Safety review:
- open PR ownership was checked before editing `generic_database_page.dart`; active Refactor/Relation PRs did not own that hotspot;
- final PR diff was compare-audited after the full-file contents edit: exactly three files, with only the intended popover trigger extension, host wiring/helpers, and focused real-host regression.

Validation at handoff:
- Flutter CI run #1325 is in progress. Do not merge #349 until Generate + Analyze + full Test are green.

## #245 audit note
Fresh inspection confirmed the repository already has an idempotent legacy Photo -> Image Object bridge in `CoreObjectBridge`:
- legacy photos share the canonical system key `image`;
- `photo_object_links` maps legacy Photo ids to generic Image Object ids;
- mirrored Image Objects carry `Legacy Photo ID`, `File`, `Note`, and `Legacy Tags`;
- native managed Image Objects intentionally omit `Legacy Photo ID` and use `ImageObjectService` identity/provenance.

Therefore do not add a second Photo->Image bridge. Remaining #245 work should focus on product-semantic convergence: dedup/path safety where needed, Bookmark image/cover semantics, generic Images feature parity, Person profile-image migration, and eventual legacy `写真` UI/storage caller retirement.

## Exact next Object actions
1. Resolve #349 CI first; merge only after full green. If it fails, fix the focused host regression/compile issue without broadening scope.
2. Continue #252 after #349 with advanced-type compact parity only where the existing canonical services can be reused safely; keep Relation/formula/rollup ownership outside the widget. Then converge the remaining generic top-header add action and compatible Bookmark/person-role add flows in separate small slices.
3. Continue #249 in small Stage1 slices after rechecking open PR ownership: improve List row hierarchy/spacing, then reuse the existing fixed/masonry View contract in Bookmark Gallery. Do not duplicate #156 settings/renderers.
4. Validate #247 center/side/full presentation and #149 six-dot alignment in the actual Bookmark host; close only when the visual acceptance is confirmed.
5. Continue #155 legacy URL/thumbnail retirement only after every user-facing host has a proven canonical replacement. Keep compatibility/import/export data until caller-zero and migration policy are explicit.
6. Continue #245 from the existing `CoreObjectBridge` rather than inventing a parallel Photo bridge; no destructive table removal.
7. Defer broad Vault work (#242) while higher-value presentation parity remains actionable unless storage-path work becomes a direct dependency.

## Cross-lane boundaries
### Relation
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. #346/#348/#349 are presentation/UI-contract work and introduce no new Relation mutation semantics. Advanced Relation-type Property creation remains on existing canonical services; do not move Relation persistence into `PropertyAddPopover`.

### Refactor — #225
During this run active Refactor PRs included focused error/rollback/privacy work (#336/#340/#342/#343/#347) and did not own the Property popover, Bookmark Property-row file, or `GenericDatabasePage` when #349 was started. Recheck ownership before every subsequent shared-host edit. Object owns product-semantic replacement surfaces; Refactor owns behavior-preserving extraction/deletion after parity is proven.

## Risks / blockers
- large shared hosts remain conflict-prone; use focused patches and compare the final branch against latest main;
- #349 full CI is pending and is the immediate integration gate;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data while production/import/export paths still need them;
- identity-sensitive Weblink/Image creation must not regress to generic title-only creation;
- ambiguous Relation state must fail closed in presentation; do not repair it from widgets;
- #149/#247 still require actual Bookmark-host validation before issue closure.

## Validation
- #341 final Flutter CI run #1305: success; merged as `d62f5d60e5fe768db8ca8b56fec20b52c7660bd9`.
- #344 Flutter CI run #1311: success; merged as `1d8e6937e07d5c8589de40f8eabfd410d3d08cbd`.
- #346 Flutter CI run #1318: success; merged as `446679baceddaa684bdc89ec112ed0675dbf6906`.
- #348 Flutter CI run #1322: success; merged as `8727128c49a6ed5b6a8a0b74e371278b9d19fb4b`.
- #349 Flutter CI run #1325: in progress at handoff.

## Stop / continuation condition
This run resolved and merged the shared #252 popover foundation, implemented and merged the concrete Bookmark #149 handle convergence, and opened the next real-host #252 integration with a compare-audited focused diff. Continue from #349 CI, then move to #249 or the next small #252 parity slice depending on current hotspot ownership. No product/design clarification is required.
