# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent daily-use workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture/product issues:
- `#56` — generic Object/Database/View integration
- `#155` — reusable Weblink Object + managed Image presentation/navigation
- `#156` — fixed/masonry Gallery presentation
- `#149` — Property handle visual validation
- `#218` — installable macOS delivery; implementation merged in #220

`#166` alias-aware Object identity / Relation picker work is complete and closed.

## Current implementation position
The generic Object/Relation architecture is integrated into real Database/Object hosts. The project is now mainly in product exposure, rich media presentation, identity-aware Weblink/Image creation UX, macOS delivery validation and legacy consolidation.

Recent integration on `main`:
- #199 Bookmark detail uses managed Weblink/Image visual resolution.
- #203/#213 expose Weblinks / Images / Daily Notes through generic sidebar navigation.
- #204/#206/#212 provide persisted fixed/masonry Gallery modes and real-host renderer switching.
- #205 provides the deterministic six-dot Property handle/grid.
- #207 persists managed Image pixel dimensions.
- #209/#217 provide canonical managed Weblink visual resolution + geometry.
- #214 preserves date-keyed Daily Note creation in the generic host.
- #215 fails closed for invalid title-only Weblink/Image generic creation.
- #220 packages Bookmark as an installable macOS app/DMG using a safe local/CI workflow.
- Relation real-host coverage expanded through #208/#210/#211/#216/#222 for exposed Weblinks/Images editing, backlinks and deletion lifecycle.

## Issue #155 production state
### Bookmark -> Weblink
Live on `main`:
- canonical `Bookmark -> Weblink` through `ObjectSyncService` / `RelationMutationService`;
- normalized Weblink identity/reuse;
- verification-first mirrored direct-URL retirement while legacy `bookmarks.url` remains compatibility data;
- Weblink-owned shared metadata.

### Managed Image / Weblink -> Image
Live on `main`:
- app-managed remote image storage;
- managed Image Object identity/provenance/reuse;
- production `Representative image` single and `Related images` multi Relations;
- real preview pipeline/background ingestion;
- canonical read-only visual resolution and managed Image dimensions;
- Bookmark detail cover rendering.

### First-class system collection UX
Weblinks, Images and Daily Notes use the generic sidebar/Database path. Relation safety for newly exposed collection surfaces is now covered in real hosts:
- #208 — Weblink Representative/Related Image editing uses canonical Relation APIs.
- #210 — Weblink deletion detaches incoming Bookmark Relation safely.
- #211 — Weblink detail resolves canonical Bookmark backlinks.
- #216 — composite Weblink deletion detaches incoming Bookmark and outgoing Image Relations while preserving surviving Bookmark/Image Objects.
- #222 — exposed Image detail shows Weblink backlinks; deleting the Image clears Representative, shrinks Related images, removes stale edges/backlinks and keeps Relation audit healthy.

Weblink/Image generic title-only creation still fails closed until dedicated canonical URL/file affordances exist.

Remaining #155 work is primarily presentation and migration:
- remaining Bookmark visual hosts use managed visual resolver;
- rich generic Weblink/Image Table/Gallery/detail presentation;
- canonical user-facing Weblink URL-entry / Image-import creation UX;
- legacy URL/remote-thumbnail compatibility retirement only after Object-first hosts are proven.

## #156 current state
Fixed/masonry View persistence, toolbar, shared renderer, Image dimensions and real-host renderer switching are merged. Open Object #221/#223 are presentation-only work that consumes canonical `RelationReadService`/Weblink visual data to drive media geometry; they introduce no Relation mutation/index/backlink path.

## Relation status
Canonical mutation/read/index/backlink/audit/reconcile is mature. Real-host Relation coverage now includes exposed Weblink and Image collections through #222. Repository audit after #222 found no new view-level direct `ObjectStore.setRelation(...)` use; low-level writes remain confined to Relation internals and tests/corruption fixtures.

No independent Relation implementation is currently required unless Object lane introduces a new Relation-producing workflow or a concrete correctness regression appears.

## macOS release delivery — #218/#220
Merged #220 provides:
- `tool/package_macos.sh` release build/DMG workflow;
- `Bookmark` product naming and preferred `com.are4c4.bookmark` bundle id;
- protection against silently hiding existing local profile data when bundle identity differs;
- optional icon source, install/open helpers and `/Applications` overwrite guard;
- CI release app + DMG artifact packaging;
- README + `docs/MACOS_RELEASE.md` documentation.

Developer ID signing/notarization and App Store distribution remain out of scope for the current personal-use delivery path.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicates.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = presentation/query over a Database collection.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Tags/Weblinks/Images are reusable Objects; lightweight local choices remain Values.
- Daily Note is an Object keyed by unique local date.
- Weblink stores shared resource facts; Bookmark stores user-specific context and relates to Weblink.
- Relation writes/deletions use canonical Relation APIs.
- Aliases are search/presentation metadata; references persist canonical Object ids.
- Identity-sensitive system collections must not fall back to raw title-only Object creation.

## Delivery priorities
1. Finish #156/#155 managed media presentation in real Gallery/Table/detail hosts (#221/#223 and follow-ups).
2. Add canonical URL-entry / managed Image-import affordances for exposed Weblink/Image collections.
3. Validate/use #220 `Bookmark.app` packaging in normal daily use.
4. Validate #205 visually and close #149 if the actual host alignment is correct.
5. Retire legacy Bookmark URL/thumbnail presentation only after Object-first replacements are proven.
6. Prefer usage-discovered friction over speculative abstraction.

## Validation status
Recent Relation CI:
- #208 CI #853 — green
- #210 CI #855 — green
- #211 corrected CI #890 — green
- #216 CI #891 — green
- #222 CI #902 — green

Object #221/#223 are currently presentation-only open PRs and should be evaluated on their own CI before integration.

## Known risks / sequencing constraints
- Do not introduce direct serialized-id Relation writes from new system-collection/import UX.
- Ambiguous Relation damage is not automatically repaired.
- Future Object merge/dedup requires explicit Relation policy before edge/value rewrites.
- Bundle Identifier changes can change macOS sandbox location; keep #220 data-preservation guard intact.
- Rich Gallery media must reuse existing managed Image/Weblink identity and geometry rather than create parallel media state.

## Current lane status
Object lane is active on #155/#156 presentation via #221/#223. Relation lane has completed the new exposed Weblink/Image host correctness work through #222 and should resume only for a new Relation-producing workflow or concrete Relation regression.
