# AI Progress Handoff

> Repository-wide integration checkpoint for AI development. Lane-specific implementation details live in the lane handoff files.

## Current goal
Finish the transition from strong generic Object/Relation foundations to a coherent daily-use workflow: **ObjectType = schema, Database = collection, View = presentation/query**.

Product direction: **Capacities-like Object-centric data model + Notion-like Database/View UX**.

Active architecture/product issues:
- `#56` — generic Object/Database/View integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#156` — fixed/masonry Gallery presentation.
- `#149` — Property handle alignment; implementation merged, real-host visual validation remains.
- `#218` — installable macOS `Bookmark.app` / DMG packaging and safe release identity.

`#166` (Object aliases) is closed as completed.

## Current implementation position
The generic Object/Relation architecture is integrated into real Database/Object hosts. Relation work is mature; the dominant remaining work is Object-owned product exposure, rich media presentation, identity-aware system-Object creation UX, release packaging, and legacy consolidation.

Recent main integration:
- #199 Bookmark detail uses managed Weblink/Image visual resolution.
- #203/#213 expose Weblinks / Images / Daily Notes through generic sidebar navigation.
- #204/#206/#212 provide persisted fixed/masonry Gallery modes and real-host renderer switching.
- #205 provides the deterministic six-dot Property handle/grid.
- #207 persists managed Image pixel dimensions.
- #209 shares canonical Weblink visual resolution with Bookmark presentation.
- #214 preserves date-keyed Daily Note creation in the generic host.
- #215 protects identity-sensitive Weblink/Image collections from invalid title-only generic creation.
- #211 adds exposed-Weblink backlink real-host Relation coverage.
- #217 exposes managed Weblink image dimensions/aspect ratio for the remaining media-driven masonry slice.

## macOS release delivery — Issue #218
A focused Object-lane release branch now adds a reproducible local/CI packaging path without committing generated macOS Xcode runner files.

Implemented on `feature/object-macos-release-packaging`:
- `tool/package_macos.sh` builds a release `Bookmark.app` and compressed DMG;
- default product name `Bookmark`;
- preferred Bundle Identifier `com.are4c4.bookmark`;
- version/build number are read from `pubspec.yaml` (`0.1.0+1` currently);
- missing `macos/` runner is generated locally from the Flutter template;
- if an existing local runner uses another Bundle Identifier and its sandbox contains Bookmark profile data, the script preserves that identifier instead of silently hiding the existing data;
- optional one-source 1024x1024 AppIcon pipeline via macOS `sips`;
- optional first-install copy to `/Applications`, with fail-closed behavior if `Bookmark.app` already exists;
- DMG output `dist/macos/Bookmark-<version>.dmg` with an `/Applications` shortcut;
- release artifacts are gitignored;
- README + `docs/MACOS_RELEASE.md` document installation, icon input, Gatekeeper, data identity and update behavior;
- the existing main-push/manual macOS GitHub Actions job is changed from a debug-only build to a release app + DMG build and uploads a `Bookmark-macOS` artifact.

Release packaging intentionally does not include Developer ID signing/notarization, Apple credentials, Mac App Store distribution, or destructive Bundle Identifier/data migration.

## Issue #155 production state
### Bookmark -> Weblink
Live on `main`:
- canonical `Bookmark -> Weblink` through `ObjectSyncService` / `RelationMutationService`;
- conservative URL normalization/reuse;
- verification-first direct Object URL retirement while legacy `bookmarks.url` remains compatibility data;
- Weblink-owned core metadata.

### Managed Image / Weblink -> Image
Live on `main`:
- app-managed remote image storage;
- managed Image Object identity/provenance/reuse;
- production `Representative image` and `Related images` Relations;
- real preview pipeline and background app-host ingestion;
- canonical read-only Weblink visual resolution;
- Bookmark detail managed cover rendering;
- Relation lifecycle/backlink/delete/reconcile real-host coverage.

### First-class navigation / creation safety
- Weblinks, Images and Daily Notes reuse the generic sidebar/Database path.
- Daily Note generic creation remains canonical/date-keyed.
- Weblink/Image generic title-only creation fails closed until dedicated URL/file affordances are implemented.

Remaining #155 work is primarily remaining Bookmark visual-host migration, polished generic Weblink/Image presentation, identity-aware URL/file creation UX and eventual legacy URL/thumbnail retirement.

## #156 current state
Fixed/masonry View persistence, toolbar, shared renderer and real `GenericDatabasePage` host switching are merged. Managed Image dimensions are persisted, and #217 now surfaces managed Weblink visual geometry. Remaining work is feeding that real media aspect ratio into masonry card height, mixed portrait/landscape host coverage and a stable no-media fallback.

## Relation status
Canonical Relation mutation/read/index/backlink/audit/reconcile is mature. Alias-aware picker integration and Weblink/Image live-host lifecycle/backlink coverage are merged through #211. No independent Relation implementation slice is currently required unless a new Relation-producing Object workflow or concrete regression appears.

## Repository-wide design contract
- Object is global and unique; Databases collect/show Objects rather than own duplicates.
- ObjectType = schema + reusable defaults.
- Database = target ObjectType + collection semantics.
- View = presentation/query over a Database collection.
- Defaults resolve `View > Database > ObjectType > app`.
- Object content = typed Properties + block-oriented Body.
- Tags are Objects; lightweight choices remain Select/MultiSelect Values.
- Daily Note is an Object keyed by unique local date.
- Weblink stores resource-derived facts; Bookmark stores user-specific context and relates to Weblink.
- Relation writes/deletions use canonical Relation APIs.
- Aliases are search/presentation metadata; references persist canonical Object ids.
- Identity-sensitive system collections must not fall back to raw title-only Object creation.

## Delivery priorities
1. Integrate/validate #218 release packaging, then use `Bookmark.app` as the normal daily-use build path.
2. Finish remaining Bookmark visual hosts on the canonical managed visual resolver.
3. Finish #156 media-driven masonry using #217 geometry.
4. Add canonical URL-entry / managed Image-import affordances for exposed Weblink/Image collections.
5. Polish generic Weblink/Image Table/Gallery/List/detail presentation.
6. Validate #205 visually in the real app and close #149 if alignment is correct.
7. Continue retiring legacy Bookmark-specific paths only after Object-first replacements are proven in daily use.
8. Prefer usage-discovered friction over speculative new abstractions.

## Validation status
- Existing pull-request analyze/test CI remains unchanged.
- `tool/package_macos.sh` passed `bash -n` syntax validation before push.
- Actual release build/DMG validation requires the macOS GitHub Actions job after #218 is merged or a local macOS run.
- Recent green product CI remains represented by #215 and preceding merged Object/Relation PRs.

## Known risks / sequencing constraints
- Bundle Identifier changes can change the sandbox container path; do not bypass #218's data-preservation guard without an explicit migration/backup plan.
- Generated macOS runner files are not currently tracked; release identity is applied by repository-owned packaging tooling.
- Developer ID signing/notarization is not part of the current personal-use packaging scope.
- Large remaining Stage1/reverse-lookup visual-host changes should still be made with patch-capable edits rather than whole-file reconstruction.
- #156 media geometry must reuse existing managed Image/Weblink visual metadata and must not create a parallel media identity path.

## Current lane status
Object lane has an active focused #218 packaging branch ready for PR/CI. After that, resume the remaining #155 visual-host migration and #156 real media-driven masonry work. Relation lane has no independent implementation requirement at this checkpoint.