# AI Progress — Object Lane

> Durable handoff for the Object implementation lane. Update this file before every Object-lane run ends.

## Lane scope
Object/ObjectType architecture, Property value semantics, Object-centric Database/View integration, Object detail presentation, Body/block model, reusable Object types, Daily Notes, Value-to-Object promotion, system-collection exposure, Object-owned presentation, and app-shell/product delivery work that does not belong to Relation semantics.

## Active issues
- `#56` — generic Object/Database/View product integration.
- `#155` — reusable Weblink Object + managed Image presentation/navigation.
- `#156` — fixed/masonry Gallery View modes; real host integrated, media-driven sizing remains.
- `#149` — Property-row visual polish; implementation landed, pending real-host visual validation.
- `#218` — installable macOS `Bookmark.app` / DMG packaging and safe release identity.

## Current integration state
The generic Object/Database/View foundation is integrated into real hosts. Current work is product exposure, rich presentation, identity-safe system-Object creation UX, release packaging, and legacy consolidation rather than new parallel abstractions.

Important `main` state before #218:
- canonical Bookmark -> Weblink and Weblink -> Image production flows are live;
- managed remote previews become Image Objects and Representative-image Relations in the real app host;
- Bookmark detail consumes the managed visual resolver (#199);
- Weblinks / Images / Daily Notes are exposed through the existing generic sidebar/Database path (#203/#213);
- generic Daily Notes creation preserves one Object per local date (#214);
- generic Weblink/Image title-only and Board creation fail closed instead of bypassing canonical URL/file identity (#215);
- Gallery fixed/masonry persistence, renderer, toolbar and real `GenericDatabasePage` integration are merged (#204/#206/#212);
- managed Image pixel dimensions are persisted (#207);
- shared `WeblinkVisualResolver` is merged and reused by `BookmarkVisualResolver` (#209);
- deterministic shared six-dot Property handle/grid is merged (#205);
- Relation backlink coverage for exposed Weblink hosts is merged (#211);
- #217 exposes managed Weblink image width/height/aspect-ratio metadata to presentation for the remaining masonry slice.

## Active #218 macOS release packaging branch
Branch: `feature/object-macos-release-packaging`

Implemented checkpoints:
1. Created Issue #218 with release identity/data-safety acceptance.
2. Added `tool/package_macos.sh`:
   - stable release product name defaults to `Bookmark`;
   - preferred Bundle Identifier defaults to `com.are4c4.bookmark`;
   - reads build name/number from `pubspec.yaml`;
   - generates a standard Flutter macOS runner locally when the repository clone does not contain `macos/`;
   - rewrites only local runner `AppInfo.xcconfig` identity values;
   - detects existing profile data under the current macOS container and preserves the current Bundle Identifier instead of silently making that data appear missing;
   - supports a single 1024x1024 PNG source and regenerates all standard AppIcon sizes through macOS `sips`;
   - runs `flutter build macos --release`;
   - creates `dist/macos/Bookmark-<version>.dmg` with `Bookmark.app` and an `/Applications` shortcut;
   - optional `--install`, `--open-dmg`, and `--configure-only` modes;
   - refuses to overwrite an existing `/Applications/Bookmark.app` automatically.
3. Added `docs/MACOS_RELEASE.md` with release identity, local-data safety, icon, DMG, install and Gatekeeper guidance.
4. Updated README with the installable macOS release command.
5. Added `dist/` to `.gitignore` so packaged DMGs remain untracked.
6. Updated existing Flutter CI macOS job so main pushes / manual dispatch build the release app + DMG and upload a `Bookmark-macOS` artifact instead of only producing an unexported debug app.
7. Refreshed the branch onto latest main including merged #211 and #217 before opening the release PR.

## Validation performed
- `bash -n` syntax validation passed for the exact `tool/package_macos.sh` content before it was pushed.
- No local macOS/Flutter workspace is attached to this chat runtime, so actual `flutter build macos --release` and `hdiutil` execution must be validated by the macOS GitHub Actions job after integration (or by the user's Mac after pulling).
- Existing normal Flutter analyze/test CI remains unchanged for pull requests; the macOS release job intentionally still runs only on main push or manual workflow dispatch, matching the repository's previous macOS-job cost policy.

## #218 remaining / next exact actions
1. Open a focused PR for `feature/object-macos-release-packaging` against latest `main`.
2. Let normal pull-request analyze/test CI validate repository changes.
3. Merge after green CI; the resulting main push should execute the macOS release job, producing `Bookmark.app` + `Bookmark-0.1.0.dmg` artifact from a clean runner.
4. Verify the macOS release job output path and artifact; fix any Flutter-template/product-name path mismatch if one appears.
5. Update #218 after that real build validation.
6. On the user's Mac, pull main and run `bash tool/package_macos.sh --install` (or `--open-dmg`) to install locally. If the local debug runner uses a different Bundle Identifier and has existing data, the script should preserve that identifier and print it.
7. A branded custom artwork file is intentionally not invented in this engineering slice. The AppIcon pipeline is complete; when a 1024x1024 source artwork is chosen, pass it through `BOOKMARK_ICON_SOURCE=...` and rebuild.

## Other Object-lane next actions after #218
1. **#155 remaining Bookmark visual host migration** — move Stage1/reverse-lookup legacy thumbnail hosts to the existing canonical managed visual component in a patch-capable runtime.
2. **#156 media-driven masonry sizing** — use #217 visual geometry in the real Gallery card path, add portrait/landscape real-host regression, preserve no-media fallback.
3. **#155 Weblink/Image daily-use create UX** — replace current fail-closed generic creation with dedicated canonical URL/file affordances.
4. **#155 generic Weblink/Image presentation** — polish Table/Gallery/List/detail through existing ObjectType/View/default contracts.
5. **#149** — close only after the merged #205 handle looks aligned in an actual user screenshot.

## Cross-lane boundaries
- Relation work for aliases, managed preview lifecycle, exposed Weblink delete/edit/backlinks is already integrated through #211.
- #218 changes no Object/Relation persistence semantics.
- Any future Relation mutation/deletion continues through canonical Relation services only.

## Risks / blockers
- Changing Bundle Identifier can change the macOS sandbox container and make existing data appear absent. #218 therefore preserves an existing identifier when it detects profile data; do not remove that guard casually.
- The repository still does not track the generated `macos/` runner. Release identity is therefore applied reproducibly by the packaging script rather than by committing generated Xcode files.
- Developer ID signing/notarization is deliberately out of scope for #218; no signing secrets belong in the repository.
- A custom branded icon artwork is a separate visual-design input; the engineering pipeline to install it is already present.

## Stop reason
The repository-side #218 implementation is ready for PR/CI. Actual release-build validation requires a macOS runner, which will run after merge under the existing main-push macOS CI policy; no destructive or speculative local-data migration should be attempted from this runtime.