# bookmark_app

A Flutter bookmark manager with multiple database views.

## Current foundation

- Drift + SQLite bookmark database
- Bookmark fields: id, url, title, thumbnail, description, createdAt, favorite
- Repository layer shared by future views
- Responsive gallery view
- Favorite toggle

The thumbnail column stores a URL or local file path rather than image bytes.

## Local setup

This repository currently contains the app source but not Flutter-generated platform folders.
From a local checkout, run:

```bash
flutter create .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The build_runner command generates `lib/data/app_database.g.dart` for Drift.

## Planned view architecture

```text
Drift / SQLite
      |
BookmarkRepository
      |
+-----+------+------+
|            |      |
Gallery     List   Table
```

All views will read the same bookmark records rather than keeping separate copies of the data.
