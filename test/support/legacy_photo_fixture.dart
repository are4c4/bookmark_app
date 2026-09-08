import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/drift.dart';

/// Test-only constructor for historical Photo rows.
///
/// Production Photo creation is retired; compatibility and migration tests still
/// need to model pre-Image state explicitly without restoring a runtime API.
extension LegacyPhotoFixtureDatabase on AppDatabase {
  Future<int> addPhoto({
    required String path,
    String? title,
    String? note,
    Iterable<String> tagNames = const <String>[],
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
