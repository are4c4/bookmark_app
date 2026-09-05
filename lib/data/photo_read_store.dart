import 'package:drift/drift.dart';

import 'app_database.dart';

class PhotoReadStore {
  const PhotoReadStore(this.database);

  final AppDatabase database;

  PhotoRecord resolveRecord(PhotoRecord photo) => PhotoRecord(
        id: photo.id,
        path: database.pathResolver.resolveStoredPath(photo.path),
        title: photo.title,
        note: photo.note,
        tags: photo.tags,
        createdAt: photo.createdAt,
      );

  Stream<List<PhotoRecord>> watchAll() =>
      (database.select(database.photos)
            ..orderBy([
              (photo) => OrderingTerm.desc(photo.createdAt),
            ]))
          .watch()
          .map((rows) => rows.map(resolveRecord).toList());
}
