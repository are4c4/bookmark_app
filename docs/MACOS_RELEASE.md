# macOS release packaging

Issue: #218

This repository does not currently track the generated `macos/` Flutter runner. The release workflow therefore keeps the product identity and packaging rules in `tool/package_macos.sh` and applies them to the local/generated runner at build time.

## Product identity

Default release identity:

- product/app name: `Bookmark`
- preferred Bundle Identifier: `com.are4c4.bookmark`
- version/build number: top-level `version:` in `pubspec.yaml`

The current pubspec starts at `0.1.0+1`, so a release made without changing the version produces `Bookmark-0.1.0.dmg`.

### Existing local data and Bundle Identifier changes

Flutter/macOS profile data may live inside the app sandbox container, for example:

```text
~/Library/Containers/<bundle-id>/Data/Documents/BookmarkApp/Profiles/
```

Changing the Bundle Identifier can therefore make existing data appear to disappear even though the old files still exist in the old container.

`tool/package_macos.sh` protects against this: when the local generated runner already has a different Bundle Identifier and the matching container contains Bookmark profile data, the script preserves that existing Bundle Identifier for the build instead of silently switching to `com.are4c4.bookmark`.

A future explicit Bundle Identifier migration should begin with a backup and must be treated separately from normal release packaging. The packaging script never deletes, moves, or rewrites profile/database/photo data.

## Build and create a DMG

From the project root on macOS:

```bash
bash tool/package_macos.sh
```

The script:

1. verifies required macOS build tools;
2. generates the standard Flutter macOS runner locally if it is absent;
3. applies the release product name and safe Bundle Identifier;
4. reads version/build number from `pubspec.yaml`;
5. optionally regenerates all AppIcon sizes from one 1024x1024 PNG;
6. runs `flutter pub get`;
7. runs `flutter build macos --release`;
8. creates a compressed DMG containing `Bookmark.app` and an `/Applications` shortcut.

Outputs:

```text
build/macos/Build/Products/Release/Bookmark.app
dist/macos/Bookmark-<version>.dmg
```

## Install directly into Applications

For a first install:

```bash
bash tool/package_macos.sh --install
```

The install step deliberately refuses to overwrite an existing `/Applications/Bookmark.app`. Move/rename the old app first when replacing a previous build; this prevents an automated packaging command from destructively replacing an installed application unexpectedly.

Alternatively, create and open the DMG:

```bash
bash tool/package_macos.sh --open-dmg
```

Then drag `Bookmark.app` to the `Applications` shortcut in Finder.

## App icon

The generated Flutter runner already has an AppIcon asset catalog. A custom icon can be installed without hand-creating every macOS icon size by supplying one square 1024x1024 PNG:

```bash
BOOKMARK_ICON_SOURCE=/absolute/path/to/bookmark_icon_1024.png \
  bash tool/package_macos.sh
```

The script uses macOS `sips` to regenerate 16, 32, 64, 128, 256, 512 and 1024 px assets in the local `AppIcon.appiconset`.

If no custom icon source is supplied, the existing generated AppIcon is preserved. A branded artwork file can therefore be introduced independently from the packaging mechanics without blocking release builds.

## Configure without building

To inspect/apply local product identity and icon settings without creating a release build:

```bash
bash tool/package_macos.sh --configure-only
```

The script prints the effective product name, Bundle Identifier, version and build number.

## Override identity explicitly

For a temporary/test build:

```bash
BOOKMARK_APP_NAME=Bookmark \
BOOKMARK_BUNDLE_ID=com.are4c4.bookmark.dev \
  bash tool/package_macos.sh
```

Do not casually change Bundle Identifiers for a profile that already contains important data. The safety check preserves the existing local identifier when it detects profile data in the current container.

## Signing and Gatekeeper

This workflow creates a personal local release. It does **not** configure Apple Developer ID signing, notarization, or Mac App Store distribution, and it never stores signing credentials in the repository.

A locally-built app normally runs on the machine that built it. If an unsigned/not-notarized DMG is transferred to another Mac, Gatekeeper may require the user to explicitly approve/open it. Developer ID signing and notarization should be added only when external distribution becomes a real requirement.

## Updating an installed app

Normal application updates should not modify profile/database/photo data. Build artifacts live separately from application data.

Recommended flow:

```bash
git pull
flutter pub get
dart run build_runner build
bash tool/package_macos.sh
```

Then replace the old installed app with the newly built `Bookmark.app` while keeping the same effective Bundle Identifier. Always keep a profile backup before intentional Bundle Identifier or storage migrations.
