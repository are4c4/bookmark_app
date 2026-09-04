# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, and Object-owned presentation.

## Active issues
- `#56` — generic Object/Database/View product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#156` — fixed/masonry Gallery View modes.
- `#149` — Property-row visual polish; implementation landed, pending real-host visual validation.

## Current integration state
The generic Object/Database/View foundation is already integrated into real hosts. Current work is product exposure and presentation rather than new parallel abstractions.

Important current `main` state:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and Representative-image Relations in the real app host;
- Bookmark detail consumes the managed visual resolver (#199);
- Weblinks are exposed through the existing generic sidebar/Database navigation list (#203);
- Gallery View mode persistence is on `main` (#204);
- the deterministic shared six-dot Property handle/grid is on `main` (#205);
- shared fixed/masonry Gallery renderer + toolbar control is on `main` (#206).

## Latest sustained-run checkpoints
1. Read `AGENTS.md`, Issue #56, repository-wide progress, this Object handoff, recent PRs/commits and CI before changing state.
2. Inspected open PR #203 (`feature/object-weblink-sidebar-collection-155`). Flutter CI #845 was green. Squash-merged as `1f1b749f7191846f7e5b925f20112c23a1bfc5a5`.
   - Weblink is now the first selected system ObjectType exposed by `GenericDatabaseStore.listDatabases(...)`.
   - Sidebar label is `Weblinks`, icon remains the canonical `🔗`, and routing reuses the existing generic Database tile / `GenericDatabasePage` path.
   - No Weblink-specific persistence or navigation model was introduced.
3. Refreshed Issue #155 after #199/#203 so its remaining work is explicitly presentation/consolidation: remaining Bookmark Gallery/Table managed visual migration, polished generic Weblink collection presentation, rich Weblink/Image presentation, then legacy compatibility retirement.
4. Inspected open PR #206 (`feature/object-gallery-renderer-156`) and its diff. It adds shared `ObjectGalleryView` plus Gallery-only fixed/masonry toolbar control while reusing one item builder and `DatabaseViewGalleryAdapter`.
5. Verified Flutter CI #846 for #206:
   - Drift generation: success
   - `flutter analyze`: success
   - full tests: success
6. Squash-merged #206 as `0b9026ba860560bdfee6fb670a488325078c9f3d`.
7. Refreshed Issue #156 to record:
   - #204 persisted `settings.galleryMode = fixed | masonry` is merged;
   - #206 shared renderer/control is merged;
   - real `GenericDatabasePage` still uses its legacy fixed `GridView.builder`, so end-to-end mode switching in the actual Gallery host is the next priority.
8. Re-audited current `GenericDatabasePage`: its `_gallery(...)` host still owns the existing card builder/opening/property/create-card behavior. The safest next integration is to replace only Gallery geometry with `ObjectGalleryView` and decode mode from the active View, without changing card semantics.

## Exact next actions
1. **#156 real-host Gallery integration — highest priority**
   - patch `GenericDatabasePage` rather than whole-file replacement;
   - import/use `DatabaseViewGalleryAdapter` and `ObjectGalleryView`;
   - keep the existing `_gallery` item builder, Object opening, semantic Property rendering and create-card flow unchanged;
   - decode `GalleryViewMode` from `_activeView` only; do not create another state model;
   - add a focused real-host widget regression: toolbar fixed/masonry change -> persisted View setting -> real Gallery renderer geometry changes while Object identity/opening remains unchanged.
2. **#155 remaining managed visual migration**
   - identify remaining Bookmark Gallery/Table/card thumbnail hosts still reading legacy thumbnail paths directly;
   - switch them to the merged `BookmarkVisualResolver`/shared visual component in small read-only slices;
   - do not retire legacy remote fallback until all old hosts are migrated and validated.
3. **#155 Weblink generic collection polish**
   - verify `Weblinks` sidebar routing in the real app;
   - improve default generic Weblink Table/Gallery/List presentation using existing ObjectType defaults/View contracts rather than a Weblink-specific page.
4. **#149**
   - #205 implementation is merged; close only after a real-host screenshot/visual validation confirms the deterministic handle is aligned. Do not resume pixel-tuning of `Icons.drag_indicator`.

## Cross-lane boundaries
- Relation lane has no independent open work. #166 alias-aware picker and #155 managed-preview Relation lifecycle are already covered through real hosts.
- New Object-owned presentation/navigation work must remain read-only with respect to Relations unless it introduces a genuinely new Relation-producing workflow.
- Any Relation mutation/deletion continues through canonical Relation services only.
- #156 Gallery geometry and #149 visual alignment are Object-only presentation work.

## Validation
- #203 head `d81c1fcbd1b92c78583b17c93735eb64d360a54b`: Flutter CI #845 — success; squash merge `1f1b749f7191846f7e5b925f20112c23a1bfc5a5`.
- #206 head `9ac63ebf55f006e49bc84299a3d74493a92f0e54`: Flutter CI #846 — success; Analyze — success; full Test — success; squash merge `0b9026ba860560bdfee6fb670a488325078c9f3d`.
- #205 deterministic Property handle is already merged as `dbc30cd054f86bcc2db5dbd207aac4265cdb3150`.
- This connector-only runtime cannot run local Flutter commands; GitHub Actions is the executable validation source.

## Risks / blockers
- `GenericDatabasePage` is a large hotspot. The available connector writes existing files by whole-file replacement, while the next #156 step should be a small patch. Reconstructing the entire page merely to replace Gallery geometry is unnecessarily risky and contrary to the repository guidance to avoid broad hotspot replacement.
- The next safe high-priority implementation therefore needs a patch-capable code-editing runtime (or an equivalent small-diff file patch action) to modify `GenericDatabasePage` safely.
- No product/design blocker and no Relation blocker is active.

## Stop reason
This run completed multiple safe checkpoints (#203 merge, #206 CI validation/merge, Issue #155/#156 synchronization). The next highest-priority Object slice is the real `GenericDatabasePage` Gallery integration, but the current connector exposes only whole-file replacement for that large hotspot. A safe small patch requires a patch-capable runtime; broad reconstruction would create avoidable regression risk. This matches the runtime/tool-limit stopping condition. The next Object run should resume with the exact #156 host patch above.
