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
- `#242` — user-selectable Vault folders; designed but not yet the current priority.
- `#218` — macOS packaging is integrated/CI-built; local product validation is largely complete outside this lane run.

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
- managed Image source URL identity normalization is integrated (#308);
- canonical Bookmark visual presentation is shared across Notion card, reverse lookup, lifecycle rows and Stage1 List/Table (#294/#299/#296/#324);
- canonical Bookmark URL presentation already covers lifecycle, reverse lookup and Notion cards (#317/#320/#322);
- one semantic chip per Bookmark Person role assignment is merged (#301);
- GenericDatabasePage read/projection and dependency-composition responsibilities have moved out through Refactor #310/#323.

## Active Object PR — #341
PR: `#341 Prefer canonical Weblink URLs in Bookmark Stage1`

Branch: `feature/object-stage1-canonical-url-155`

Current head after this handoff commit: resolve from GitHub before making another write; the production/test fix immediately before this document commit is `bd11da8263827a8d16a650490efe1b8b135f444c`.

### Product slice
- adds shared `BookmarkResolvedUrlText` over the existing read-only `BookmarkUrlResolver`;
- Stage1 external browser-open resolves canonical Bookmark -> Weblink URL first, retaining `bookmark.url` only as compatibility fallback;
- Stage1 Gallery/Notion-card, List metadata and Table URL cells use the same canonical resolver path;
- compact Stage1 URL presentation remains domain-oriented where the previous UI was compact;
- presentation never repairs or writes Relation state;
- focused canonical/fallback widget coverage avoids ObjectSync timer ownership.

### CI failure found and fixed during the 2026-09-06 run
Initial #341 CI run #1300:
- Analyze: passed;
- Test: 643 passed, 1 failed;
- only failure was `bookmark_stage1_visual_test.dart`, whose source-level architecture guard still used removed helper `String _compactUrl(` as the `_table` end marker.

Fix committed as `bd11da8263827a8d16a650490efe1b8b135f444c`:
- architecture guard now ends `_table` at `String _formatDate(`;
- no production semantics changed.

A fresh CI run was started from that fix and had reached full Test execution after Analyze passed when this handoff was refreshed. Because this documentation commit advances the PR head again, evaluate CI for the latest #341 head before integration.

## Exact next Object actions
1. Check latest #341 Analyze/Test. If green and mergeable, merge #341; if the same or a new deterministic failure appears, fix it on the branch first.
2. After #341 releases `bookmark_unified_stage1_page.dart`, prioritize `#247` Bookmark opening-mode parity. Reuse the shared Object opening contract; do not add a Bookmark-only center-peek implementation.
3. Continue `#249` remaining parity in small slices: improve Bookmark List row hierarchy/spacing, then wire Bookmark Gallery to the existing persisted fixed/masonry View contract. Do not duplicate #156 settings/renderers.
4. Implement `#252` through a reusable anchored/searchable Property-add component first, then small generic detail/Table host integrations; avoid another Bookmark-only dialog.
5. Reassess `#149` after shared opening/detail convergence; the generic deterministic six-dot implementation itself is already merged.
6. Continue `#155` legacy URL/thumbnail retirement only after every user-facing host has a proven canonical replacement. Keep compatibility/import/export data until caller-zero and migration policy are explicit.
7. Continue `#245` only with safe staged Photo -> Image promotion/migration slices; no destructive table removal.
8. Defer broad Vault work (#242) while the higher-value presentation parity issues above are actionable unless storage-path work becomes a direct dependency.

## Cross-lane boundaries
### Relation
- canonical Relation mutation/read/index/backlink/audit/reconcile is mature;
- #341 is presentation/read-only and introduces no Relation mutation semantics;
- resume Relation implementation only for a genuinely new Relation-producing workflow or concrete correctness regression.

### Refactor — #225
At this checkpoint open Refactor PRs are focused failure/privacy work (#336 and #340) and do not own `generic_database_page.dart`; nevertheless Refactor is actively decomposing shared hotspots.

Rules:
- inspect open PR ownership again before every non-trivial shared-host edit;
- Object owns product-semantic replacement surfaces;
- Refactor owns behavior-preserving extraction/deletion only after Object-first parity is proven;
- do not broaden Object PRs into failure-policy or architecture-cleanup work that belongs to #225.

## Risks / blockers
- `bookmark_unified_stage1_page.dart` is currently owned by #341; do not start #247/#249 edits in that file until #341 is integrated or superseded.
- large shared hosts remain conflict-prone; use focused patches and regressions.
- legacy Bookmark URL/thumbnail and Photo storage remain compatibility data while production/import/export paths still need them.
- identity-sensitive Weblink/Image creation must not regress to generic title-only creation.
- ambiguous Relation state must fail closed in presentation; do not repair it from widgets.
- `#149` requires visual evidence in the actual Bookmark host, not only geometry tests.

## Validation
- Initial #341 run #1300: Analyze green; full Test 643/644 with one stale architecture-guard failure.
- The stale guard was corrected in `bd11da8263827a8d16a650490efe1b8b135f444c`.
- Subsequent #341 CI had Analyze green and full Test in progress at the time this document was written. Check the newest PR-head workflow before merging.

## Stop / continuation condition
No product decision blocker exists. Continue by integrating #341 once latest CI is green, then take #247 as the next highest-value non-conflicting Bookmark->generic presentation parity slice. If #341 remains under CI at execution end, that pending CI alone is not a conceptual blocker; the next run should inspect its final result first.