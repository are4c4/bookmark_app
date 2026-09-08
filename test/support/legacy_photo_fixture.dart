import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/drift.dart';

/// Test-only constructor for historical Photo rows.
///
/// Production code no longer owns a Photo creation API. Compatibility and
/// migration regressions still need to construct persisted legacy Photo state,
/// so those tests seed the table directly through this extension instead of
/// keeping a callable runtime facade on [AppDatabase].
extension LegacyPhotoFixtureDatabaseExtension on AppDatabase {
  Future<int> addPhoto({
    required String path,
    String? title,
    String? note,
    Iterable<String> tagNames = const [],
  }) {
    final seen = <String>{};
    final normalizedTags = <String>[];
    for (final raw in tagNames) {
      final name = raw.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
        normalizedTags.add(name);
      }
    }

    return into(photos).insert(
      PhotosCompanion.insert(
        path: pathResolver.toStoredPath(path),
        title: Value(title),
        note: Value(note),
        tags: Value(normalizedTags.join(', ')),
      ),
    );
  }
}
