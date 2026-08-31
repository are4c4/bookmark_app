# bookmark_app

A Flutter bookmark manager built around a local Drift / SQLite database.

## Current features

- Save bookmarks from URLs
- Fetch page title, description, and Open Graph thumbnail
- Gallery / List / Table views over the same database
- Search, favorites, edit, delete, and external URL opening
- Normalized tags with many-to-many bookmark relations
- Multiple tag filtering with OR / AND matching
- Sorting by registration date, title, or URL in ascending / descending order
- Persisted saved views
- Edit and delete saved views
- Saved views remember:
  - layout
  - search query
  - favorites-only filter
  - multiple selected tags
  - OR / AND tag matching
  - sort field
  - sort direction

## Local update

```bash
git pull
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos
```

The database schema is currently version 4. Existing bookmarks, normalized tags, and old single-tag saved views are migrated forward automatically.
