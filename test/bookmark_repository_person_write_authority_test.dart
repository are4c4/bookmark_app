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
  test(
    'repository create/update Person uses one canonical Person identity',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceStore = WorkspaceStore(database);
      final workspaceId = await workspaceStore.initialize();
      final lifecycleStore = BookmarkLifecycleStore(database);
      await lifecycleStore.initialize();
      final repository = BookmarkRepository(
        database,
        workspaceStore: workspaceStore,
        lifecycleStore: lifecycleStore,
        workspaceId: workspaceId,
      );

      final personId = await repository.createPerson(
        'Repository Person',
        note: 'first note',
      );
      final person = (await repository.watchPeople().first).singleWhere(
        (candidate) => candidate.id == personId,
      );

      final objectStore = ObjectStore(GenericDatabaseStore(database));
      final bridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
      );
      final objectId = await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      );
      expect(objectId, isNotNull);

      await repository.updatePerson(person, 'Renamed Person', 'second note');

      expect(
        await bridge.objectIdForLegacyPerson(workspaceId, personId),
        objectId,
      );
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final objects = await objectStore.listObjects(schema.objectType.id);
      expect(objects, hasLength(1));
      expect(objects.single.id, objectId);
      expect(objects.single.title, 'Renamed Person');
      expect(objects.single.values[schema.noteProperty.id], 'second note');

      final projected = (await repository.watchPeople().first).singleWhere(
        (candidate) => candidate.id == personId,
      );
      expect(projected.name, 'Renamed Person');
      expect(projected.note, 'second note');
    },
  );
}
