import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkRepository repository;
  late int workspaceId;
  late ObjectStore objectStore;
  late PersonObjectBridge bridge;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    objectStore = ObjectStore(GenericDatabaseStore(database));
    bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'Bookmark create establishes Person through canonical Object authority',
    () async {
      final bookmarkId = await repository.create(
        url: 'https://example.com/person-authority',
        title: 'Person authority',
        personNames: const [' Alice ', 'alice'],
      );

      final people = await repository.watchPeople().first;
      expect(people, hasLength(1));
      expect(people.single.name, 'alice');
      final objectId = await bridge.objectIdForLegacyPerson(
        workspaceId,
        people.single.id,
      );
      expect(objectId, isNotNull);

      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final objects = await objectStore.listObjects(schema.objectType.id);
      expect(objects, hasLength(1));
      expect(objects.single.id, objectId);
      expect(objects.single.title, 'alice');

      final bookmark = (await repository.watchAll().first).singleWhere(
        (candidate) => candidate.id == bookmarkId,
      );
      expect(bookmark.people.map((person) => person.id), [people.single.id]);
    },
  );

  test(
    'Bookmark insert failure rolls back newly canonicalized Person',
    () async {
      await database.customStatement('''
      CREATE TRIGGER reject_bookmark_insert
      BEFORE INSERT ON bookmarks
      BEGIN
        SELECT RAISE(ABORT, 'reject bookmark insert');
      END;
    ''');

      await expectLater(
        repository.create(
          url: 'https://example.com/rollback-person',
          title: 'Rollback person',
          personNames: const ['Rollback Person'],
        ),
        throwsA(anything),
      );

      expect(await repository.watchPeople().first, isEmpty);
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      expect(await objectStore.listObjects(schema.objectType.id), isEmpty);
    },
  );
}
