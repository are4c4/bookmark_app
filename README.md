# bookmark_app

A Flutter bookmark/database manager built around a local Drift / SQLite database.

## Current features

- URL bookmarks with title / description / Open Graph metadata
- Gallery / List / Table views
- Full-text search, filters, favorites, status, rating, and saved views
- Hierarchical tags and independent tag groups
- People database with role-specific relations such as 著者 / 講師 / 出演者
- Photo database and bookmark-photo relations
- Collections and directional bookmark relations / backlinks
- Multiple Profiles with physically isolated SQLite databases and photo folders
- Workspaces inside each Profile
- Inbox / archive / trash lifecycle state
- File attachments and PDF annotations
- Drag & drop for workspace, tag, person-role, collection, and photo relations

## Local update / development run

To update the local checkout and run the latest development build:

```bash
cd ~/bookmark_app
git pull
flutter pub get
dart run build_runner build
flutter run -d macos
```

Run the same generation step after Drift schema changes. `--delete-conflicting-outputs` is not required by the current build_runner setup.

## Update the installed macOS app

To replace an already installed `Bookmark.app` with the latest version while keeping the existing app data:

1. Quit Bookmark completely.
2. Pull the latest source and regenerate code:

```bash
cd ~/bookmark_app
git pull
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

3. Build the latest release app and DMG:

```bash
bash tool/package_macos.sh
```

4. Open the release output in Finder:

```bash
open ~/bookmark_app/build/macos/Build/Products/Release/
```

5. In Finder, move the existing `/Applications/Bookmark.app` aside or to the Trash, then drag the newly built `Bookmark.app` into the Applications folder.

The generated files are:

```text
~/bookmark_app/build/macos/Build/Products/Release/Bookmark.app
~/bookmark_app/dist/macos/Bookmark-<version>.dmg
```

The packaging script deliberately refuses to overwrite an existing `/Applications/Bookmark.app` automatically. It also preserves an existing Bundle Identifier when switching identifiers would make existing profile data appear missing. Replacing only the app bundle therefore normally keeps the existing Bookmark/Profile/Image database data intact.

If `/Applications` rejects a terminal copy with a permission error, use Finder drag-and-drop instead. macOS may ask for administrator authentication.

## macOS app / DMG

To build the app as `Bookmark.app` and create an installable DMG:

```bash
bash tool/package_macos.sh
```

For a first direct install into `/Applications` when `Bookmark.app` does not already exist there:

```bash
bash tool/package_macos.sh --install
```

The release script reads the version from `pubspec.yaml`, applies the release product identity safely, preserves an existing Bundle Identifier when changing it would hide existing profile data, and creates:

```text
build/macos/Build/Products/Release/Bookmark.app
dist/macos/Bookmark-<version>.dmg
```

See [`docs/MACOS_RELEASE.md`](docs/MACOS_RELEASE.md) for Bundle Identifier safety, custom AppIcon input, DMG packaging, Gatekeeper notes, and update/install details.

## Database

The current Drift schema version is **13**. Migration code preserves existing bookmark, workspace, lifecycle, tag-group, attachment, and PDF-annotation data while moving runtime CRUD toward typed Drift queries.

Raw SQL is intentionally retained only where it is appropriate, such as legacy-schema discovery/migration and SQLite FTS5 queries.
