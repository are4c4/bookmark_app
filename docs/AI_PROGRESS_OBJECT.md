# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, Object-owned presentation, and app-shell/product delivery work that does not belong to Relation semantics.

## Active issues
- `#56` — generic Object/Database/View daily-use product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation and legacy compatibility retirement.
- `#247` — Bookmark View opening-mode parity, especially center peek.
- `#249` — Bookmark Gallery/List presentation parity; one-Person-per-chip is merged, List density and Bookmark fixed/masonry remain.
- `#252` — direct Notion-like Property-add UX.
- `#149` — deterministic shared Property handle is merged; Bookmark real-host visual parity still needs confirmation/follow-up.
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
- canonical Bookmark URL presentation now covers lifecycle, reverse lookup, Notion cards and Stage1 Gallery/List/Table/browser-open (#317/#320/#322/#341);
- one semantic chip per Bookmark Person role assignment is merged (#301);
- GenericDatabasePage read/projection and dependency-composition responsibilities moved out through Refactor #310/#323.

## Completed in this run — #341
`#341 Prefer canonical Weblink URLs in Bookmark Stage1` is merged to `main` as `d62f5d60e5fe768db8ca8b56fec20b52c7660bd9`.

The final PR head `379f8a0fd69a9257c9873554d237272b18428a05` passed Flutter CI run #1305 before merge.

Product result:
- Stage1 browser-open resolves canonical Bookmark -> Weblink URL first, retaining legacy `bookmark.url` only as compatibility fallback;
- Stage1 Gallery/Notion-card, List metadata and Table URL cells share the read-only canonical resolver path;
- compact Stage1 URL presentation remains domain-oriented where appropriate;
- presentation never repairs or writes Relation state.

The prior CI failure was test-only: a source guard still used removed `_compactUrl` as an end marker. It was corrected to use `_formatDate`; no production behavior changed.

## Next highest-priority Object work — #247
`#247` is now unblocked because #341 released `bookmark_unified_stage1_page.dart`.

Current evidence from `main`:
- `_selectBookmark` still directly assigns `_selectedBookmarkId` for Gallery/List/Table clicks;
- the build method interprets that state exclusively as the legacy right-side `BookmarkDetailPanel`;
- `_activeDatabaseView` is loaded and View opening mode is persisted elsewhere, but the Bookmark click path does not dispatch through the shared opening presentation contract.

Implementation direction remains the Issue contract: resolve the effective active View opening mode and route Bookmark opening through the shared presentation host/detail payload where practical, preserving side peek as the existing side panel branch and adding real Bookmark-host regressions for center peek and switching back to side peek.

## Exact next Object actions
1. Implement `#247` as a focused Bookmark-host opening-dispatch slice now that #341 is merged. Reuse shared opening-mode semantics; do not create a Bookmark-only center-peek design.
2. Continue `#249` in small slices: improve Bookmark List row hierarchy/spacing, then wire Bookmark Gallery to the existing persisted fixed/masonry View contract. Do not duplicate #156 settings/renderers.
3. Implement `#252` through a reusable anchored/searchable Property-add component first, then small generic detail/Table host integrations; avoid another Bookmark-only dialog.
4. Reassess `#149` after shared opening/detail convergence; the generic deterministic six-dot implementation itself is already merged.
5. Continue `#155` legacy URL/thumbnail retirement only after every user-facing host has a proven canonical replacement. Keep compatibility/import/export data until caller-zero and migration policy are explicit.
6. Continue `#245` only with safe staged Photo -> Image promotion/migration slices; no destructive table removal.
7. Defer broad Vault work (#242) while higher-value presentation parity remains actionable unless storage-path work becomes a direct dependency.

## Cross-lane boundaries
### Relation
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. #341 is presentation/read-only and introduced no Relation mutation semantics. Resume Relation implementation only for a genuinely new Relation-producing workflow or concrete correctness regression.

### Refactor — #225
Open Refactor PRs at this checkpoint are #336, #340 and #342; they are focused failure/privacy/recovery work and do not own `bookmark_unified_stage1_page.dart`. Inspect ownership again before every shared-host edit. Object owns product-semantic replacement surfaces; Refactor owns behavior-preserving extraction/deletion after parity is proven.

## Risks / blockers
- large shared hosts remain conflict-prone; use focused patches and regressions;
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data while production/import/export paths still need them;
- identity-sensitive Weblink/Image creation must not regress to generic title-only creation;
- ambiguous Relation state must fail closed in presentation; do not repair it from widgets;
- `#149` requires visual evidence in the actual Bookmark host, not only geometry tests.

## Validation
- #341 final Flutter CI run #1305: success on head `379f8a0fd69a9257c9873554d237272b18428a05`.
- #341 merged successfully as `d62f5d60e5fe768db8ca8b56fec20b52c7660bd9`.

## Stop / continuation condition
This run integrated the previously blocked Stage1 canonical URL slice and inspected the now-unblocked #247 path. The next implementation requires a focused edit to the ~1500-line shared Stage1 host plus regression coverage. The current GitHub connector only exposes whole-file replacement for repository file writes, so hand-reconstructing that large hotspot would violate the repository's safe patch-sized-edit rule. Resume #247 when a patch-capable checkout/edit path is available; no product/design input is required.