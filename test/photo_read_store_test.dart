import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/photo_read_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PhotoReadStore store;

  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: '/profiles/current',
    );
    store = PhotoReadStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('watchAll preserves newest-first ordering and resolves stored paths',
      () async {
    await database.into(database.photos).insert(
          PhotosCompanion.insert(
            path: 'photos/older.jpg',
            title: const Value('Older'),
            note: const Value('old note'),
            tags: const Value('one, two'),
            createdAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    await database.into(database.photos).insert(
          PhotosCompanion.insert(
            path: 'photos/newer.jpg',
            title: const Value('Newer'),
            createdAt: Value(DateTime(2026, 1, 2)),
          ),
        );

    final photos = await store.watchAll().first;

    expect(photos.map((photo) => photo.title), ['Newer', 'Older']);
    expect(photos.first.path, '/profiles/current/photos/newer.jpg');
    expect(photos.last.path, '/profiles/current/photos/older.jpg');
    expect(photos.last.note, 'old note');
    expect(photos.last.tags, 'one, two');
  });

  test('resolveRecord leaves absolute paths unchanged', () {
    final photo = PhotoRecord(
      id: 1,
      path: '/external/photo.jpg',
      title: null,
      note: null,
      tags: '',
      createdAt: DateTime(2026, 1, 1),
    );

    expect(store.resolveRecord(photo).path, '/external/photo.jpg');
  });
}
