# Core User Journeys

This catalog defines a small set of stable daily-use journeys for product acceptance and H oversight. It is intentionally journey-shaped rather than feature-shaped: one journey may be proven by several existing real-host/widget regressions instead of one brittle monolithic end-to-end test.

## Status model

- **covered** — current repository tests/artifacts prove the important steps strongly enough to use this journey as product-acceptance evidence.
- **partial** — useful automated coverage exists, but at least one important cross-feature step is not yet proven as one layered journey.
- **gap** — the desired product journey is valid, but current automated/artifact evidence is not yet sufficient.

A `partial` or `gap` status is not a CI failure by itself. H uses it as explicit product-health evidence and routes a focused A–G Issue only when the missing step is actionable and worth prioritizing.

When screenshot/runtime artifacts are used, verify their source SHA/build provenance. Plain deterministic Flutter tests are tied to the tested commit by normal CI and do not need a copied volatile SHA in this durable catalog.

## Shared expectations

- Canonical Object/Relation/Database authorities remain the source of truth; journeys must not justify a parallel Bookmark/People/Photo/search store.
- Representative desktop review profile is the repository UI Audit profile where visual evidence helps: dark desktop `1440×900`, DPR `1.0`.
- Keyboard paths are first-class where the flow is desktop-critical; do not invent keyboard requirements for a flow that has no established keyboard interaction yet.
- Click/key targets below are product-friction targets, not exact CI assertions. If a journey grows materially more awkward, H should treat that as evidence for review rather than silently changing the target.
- Empty/loading/error behavior should fail closed, keep a usable host, and avoid raw persistence/filesystem implementation details in user-visible text.

## J01 — Capture and recover a canonical Weblink

**Status:** covered

**Goal / starting state:** from Home, save a URL without creating legacy Bookmark authority, then reuse the same canonical identity on equivalent input and retain an obvious path to the created Object.

**Happy path:** enter URL → capture → canonical Weblink Object is created/reused → result/recent Object is visible → open path is available.

**Friction target:** one text entry + one explicit capture action; keyboard submit is also supported for repeated capture.

**Keyboard:** URL field → `Enter`/done should submit the same canonical capture path.

**State/error expectations:** invalid URL and ambiguous canonical collisions fail closed without fabricating a Weblink.

**Canonical authorities:** Weblink Object + canonical URL identity; no new Bookmark row.

**Coverage:**
- `test/home_start_page_test.dart` — canonical quick capture, no Bookmark data, recent/result affordance, keyboard reuse, invalid input and collision fail-closed behavior.

**Related product direction:** #155 / Home-start capture work; keep live Issue state authoritative.

## J02 — Build a useful custom Object

**Status:** partial

**Goal / starting state:** create a Book/custom Object and enrich it with a title, Relation/Tag context and Body without crossing into domain-specific duplicate stores.

**Happy path:** create Object → title → Relation and/or Tag → Body → reopen and observe the same canonical values.

**Friction target:** common enrichment should stay inside the shared Object/Database/detail surfaces rather than requiring separate management pages.

**Keyboard:** normal text editing and picker keyboard behavior should remain usable where supported.

**State/error expectations:** stale/missing Relation targets fail closed; partial edits must not invent parallel data.

**Canonical authorities:** Object, Property, Relation/Tag, Body.

**Coverage:** existing real-host tests prove important slices (Relation editing/quick-create, Body editing, Object detail), but the complete create→Relation/Tag→Body sequence is not yet demonstrated as one layered acceptance journey.

**Gap:** Tag + Body + reopen coherence after initial custom-Object creation needs an explicit layered acceptance mapping before this becomes `covered`.

## J03 — Find/create a Person through a Relation picker

**Status:** covered

**Goal / starting state:** while editing an Object Relation that targets Person, find an existing Person or quick-create one and save the canonical Relation selection.

**Happy path:** open Relation picker → search → choose existing target or quick-create → refreshed canonical candidates → save Relation.

**Friction target:** search/select/save should stay within one picker interaction; quick-create should not force a detour into People management.

**Keyboard:** search field should remain a normal focused text input; save/dismiss behavior must not strand focus.

**State/error expectations:** stale target/deleted target/cardinality inconsistencies fail closed rather than serializing a malformed Relation.

**Canonical authorities:** Person is an ObjectType target; Relation is the edge authority.

**Coverage:**
- `test/object_relation_picker_dialog_test.dart` — canonical selection, quick-create/reload, single-value replacement and fail-closed cases.
- `test/generic_database_page_relation_quick_create_integration_test.dart` — real Generic Database host quick-creates a Person target and persists the refreshed Relation context.
- #1353 UI Audit includes the generic Person Relation picker as advisory visual evidence when current-source provenance matches.

## J04 — Create a Database and first Object

**Status:** partial

**Goal / starting state:** create a Database/context, add common Properties, and create the first Object without making the Database the owner of Object identity.

**Happy path:** create Database → choose target ObjectType/context → add common Properties → create Object → see it in the Database View.

**Friction target:** first usable collection should not require leaving the Database flow for routine schema/object setup.

**Keyboard:** creation dialogs/forms should retain ordinary Tab/Enter/Escape semantics where supported.

**State/error expectations:** invalid schema choices fail clearly; Object identity remains global inside the Vault.

**Canonical authorities:** Database collection/context + View + global Object identity.

**Coverage:** collection/schema/object-creation tests exist, but current evidence does not yet prove this complete first-run journey as one layered acceptance mapping.

## J05 — Configure and reopen a useful View

**Status:** partial

**Goal / starting state:** from a populated Database, filter/sort/group or change presentation, save the View, and return to the same useful state.

**Happy path:** open populated Database → configure View → save/select View → leave/reopen → configuration and Object set remain coherent.

**Friction target:** View controls should be available from the active Database without a separate legacy workflow.

**Keyboard:** desktop View controls should not make keyboard users lose the active context.

**State/error expectations:** deleting/detaching a View must not delete Objects; unsupported/stale settings should fail safely.

**Canonical authorities:** Database defines set/context; View defines query/presentation only.

**Coverage:** individual View/filter/layout/preservation regressions exist, but reopen persistence across the whole filter/sort/group journey is not yet cataloged as covered.

## J06 — Global keyboard search and open

**Status:** gap

**Goal / starting state:** from normal app use, open `Cmd/Ctrl+K`, find an Object, and open the intended shared Object surface.

**Happy path:** shortcut → command/global search → type query → choose Object → open shared detail host.

**Friction target:** shortcut to opened Object should normally require query + one selection/confirm action.

**Keyboard:** this is a keyboard-critical journey; focus starts in search, arrows/Enter/Escape must be coherent.

**State/error expectations:** no-results and indexing errors remain usable and privacy-safe.

**Canonical authorities:** canonical Object Search/FTS and shared Object opening contract.

**Gap:** canonical Global Search has strong tests, but the app-shell `Cmd/Ctrl+K` entry → search → open sequence is not yet proven as one journey-level acceptance path.

## J07 — Add an Image and use it normally

**Status:** gap

**Goal / starting state:** import/add an Image, see it in a canonical Gallery/List context, and open/edit normal metadata without falling back to legacy Photo authority.

**Happy path:** add Image → canonical managed Image Object → visible representative media → open inspector/detail → edit normal metadata.

**Friction target:** import and first useful view should not require a legacy Photo-management detour.

**Keyboard:** normal picker/dialog dismissal and detail editing should remain accessible where relevant.

**State/error expectations:** unsupported/corrupt input fails safely; managed/external ownership rules are preserved.

**Canonical authorities:** Image Object + managed/external media ownership contracts.

**Gap:** current primitive/media tests prove important slices, but the full import→Gallery→open/edit journey is not yet demonstrated as one layered acceptance path.

## J08 — Write and navigate Daily Notes without losing work

**Status:** covered

**Goal / starting state:** open/write a Daily Note, move to an adjacent day/context, edit there, and return without losing the edit or navigation context.

**Happy path:** open/create note → edit Body → navigate day/context → edit nested/current note → return.

**Friction target:** adjacent-day navigation should stay inside the shared Daily Note/Object detail flow.

**Keyboard:** Body editing uses the shared editor contract; navigation controls must not corrupt focus/state.

**State/error expectations:** navigation must not silently discard Body writes.

**Canonical authorities:** Daily Note is a canonical Object with Body; navigation does not create a parallel note store.

**Coverage:**
- `test/object_global_search_daily_note_refresh_test.dart` — opens a Daily Note from Search, navigates to the next day, edits Body, returns through navigation, and verifies the changed state is observable through canonical Search refresh.

## J09 — Search, open, edit, and stay fresh

**Status:** covered

**Goal / starting state:** use canonical Search to open a result, edit relevant Object content, return to Search, and immediately observe fresh tokens/results.

**Happy path:** query → open result → edit shared Object/Body surface → return → new token appears and stale token disappears.

**Friction target:** no manual index rebuild/restart should be required after ordinary edits.

**Keyboard:** search field remains the primary focused query input; opening/returning must not strand the user.

**State/error expectations:** index refresh failure must not expose raw implementation errors; stale data should not be presented as success.

**Canonical authorities:** Object Search/FTS is derived from canonical Object data.

**Coverage:**
- `test/object_global_search_daily_note_refresh_test.dart` — real Search result → nested edit → return → fresh token present / stale token absent.
- `test/object_global_search_page_test.dart` and related Search regressions cover result rendering/opening boundaries.
- #1353 UI Audit covers the Global Search empty state as advisory visual evidence when provenance matches.

## J10 — Edit the same Object across Side Peek and full page

**Status:** covered

**Goal / starting state:** open an Object from a Database, edit it in Side Peek/shared detail, promote/open it full-page, and preserve the same Object/View context.

**Happy path:** Database row → Side Peek → edit Body/Properties → promote to full page → same Object opens → return → active View/context remains coherent.

**Friction target:** opening mode changes presentation, not data authority; moving between hosts must not require re-entering edits.

**Keyboard:** shared editors keep their normal focus/edit semantics; opening/closing hosts must not create duplicate edit surfaces.

**State/error expectations:** stale/deleted Relations and invalid mutations fail closed; presentation transitions must not lose writes.

**Canonical authorities:** one Object, shared Property/Relation/Body stores, View only controls presentation/query context.

**Coverage:**
- `test/generic_database_page_side_peek_body_test.dart` — real Database Side Peek edits canonical Object Body and verifies persistence.
- `test/generic_database_page_side_peek_promotion_test.dart` — promotes the same Object to full page and preserves the active View on return.
- related real-host Property/Relation side-peek regressions cover shared editing boundaries.
- #1353 populated shared Body snapshot can provide advisory visual evidence when the source SHA matches.

## How product work references journeys

Product PRs/Issues may list stable IDs such as `J03, J10`; do not copy the whole journey text. A journey reference means the change should improve or at least not regress the relevant behavioral intent.

Changing a journey's intent/status/coverage mapping is a durable product-contract change and should be explicit in review. Adding one more focused test does not require rewriting the journey unless it materially changes its coverage status.

## H journey-health review

During broad oversight and PR-level Product Review, H should:

1. identify affected journey IDs from the Issue/PR or infer them from the actual user-visible behavior;
2. check current tests/artifacts for the journey's named steps, using exact-source UI Audit evidence when screenshots matter;
3. distinguish deterministic breakage from advisory friction/visual evidence;
4. search existing Issues before creating a new finding;
5. route one concrete gap to exactly one A–G owner when actionable;
6. keep `partial`/`gap` visible instead of pretending an unproven journey is healthy;
7. avoid turning subjective delight into a blocking numerical score.

A covered journey can still have a UX finding. `covered` means the important behavior is represented by acceptance evidence, not that the product is permanently finished.