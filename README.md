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

## Local update

```bash
git pull
flutter pub get
dart run build_runner build
flutter run -d macos
```

Run the same generation step after Drift schema changes. `--delete-conflicting-outputs` is not required by the current build_runner setup.

## Database

The current Drift schema version is **13**. Migration code preserves existing bookmark, workspace, lifecycle, tag-group, attachment, and PDF-annotation data while moving runtime CRUD toward typed Drift queries.

Raw SQL is intentionally retained only where it is appropriate, such as legacy-schema discovery/migration and SQLite FTS5 queries.
