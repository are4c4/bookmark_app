import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late PersonObjectBridge bridge;
  late PersonObjectWriteService service;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemObjectStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
    );
    service = PersonObjectWriteService(
      database: database,
      objectStore: objectStore,
      personBridge: bridge,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'create writes canonical Person first and projects legacy compatibility',
    () async {
      final personId = await service.create(
        workspaceId: workspaceId,
        name: '  Alice  ',
        note: '  canonical note  ',
      );

      final legacy = await (database.select(
        database.people,
      )..where((person) => person.id.equals(personId))).getSingle();
      expect(legacy.name, 'Alice');
      expect(legacy.note, 'canonical note');

      final objectId = await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      );
      expect(objectId, isNotNull);
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final object = (await objectStore.listObjects(schema.objectType.id))
          .singleWhere((candidate) => candidate.id == objectId);
      expect(object.title, 'Alice');
      expect(object.values[schema.noteProperty.id], 'canonical note');
      expect(object.values[schema.legacyPersonIdProperty.id], personId);
    },
  );

  test(
    'update preserves canonical identity and projects rename and note',
    () async {
      final personId = await service.create(
        workspaceId: workspaceId,
        name: 'Before',
        note: 'old note',
      );
      final objectId = await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      );

      await service.update(
        workspaceId: workspaceId,
        personId: personId,
        name: 'After',
        note: 'new note',
      );

      expect(
        await bridge.objectIdForLegacyPerson(workspaceId, personId),
        objectId,
      );
      final legacy = await (database.select(
        database.people,
      )..where((person) => person.id.equals(personId))).getSingle();
      expect(legacy.name, 'After');
      expect(legacy.note, 'new note');

      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final object = (await objectStore.listObjects(schema.objectType.id))
          .singleWhere((candidate) => candidate.id == objectId);
      expect(object.title, 'After');
      expect(object.values[schema.noteProperty.id], 'new note');
    },
  );

  test(
    'legacy projection conflict rolls back canonical rename and note',
    () async {
      final aliceId = await service.create(
        workspaceId: workspaceId,
        name: 'Alice',
        note: 'alice note',
      );
      await service.create(
        workspaceId: workspaceId,
        name: 'Bob',
        note: 'bob note',
      );
      final aliceObjectId = await bridge.objectIdForLegacyPerson(
        workspaceId,
        aliceId,
      );

      await expectLater(
        service.update(
          workspaceId: workspaceId,
          personId: aliceId,
          name: 'Bob',
          note: 'must roll back',
        ),
        throwsA(anything),
      );

      final legacy = await (database.select(
        database.people,
      )..where((person) => person.id.equals(aliceId))).getSingle();
      expect(legacy.name, 'Alice');
      expect(legacy.note, 'alice note');

      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final object = (await objectStore.listObjects(schema.objectType.id))
          .singleWhere((candidate) => candidate.id == aliceObjectId);
      expect(object.title, 'Alice');
      expect(object.values[schema.noteProperty.id], 'alice note');
    },
  );

  test(
    'existing legacy Person is imported once then reused by canonical writes',
    () async {
      final personId = await database.createPerson('Legacy', note: 'old note');

      final reusedId = await service.create(
        workspaceId: workspaceId,
        name: 'Legacy',
        note: 'new note',
      );
      expect(reusedId, personId);

      final firstObjectId = await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      );
      expect(firstObjectId, isNotNull);

      final restarted = PersonObjectWriteService.forDatabase(database);
      await restarted.update(
        workspaceId: workspaceId,
        personId: personId,
        name: 'Legacy renamed',
        note: 'after restart',
      );

      expect(
        await bridge.objectIdForLegacyPerson(workspaceId, personId),
        firstObjectId,
      );
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      expect(await objectStore.listObjects(schema.objectType.id), hasLength(1));
      final object = (await objectStore.listObjects(schema.objectType.id))
          .single;
      expect(object.title, 'Legacy renamed');
      expect(object.values[schema.noteProperty.id], 'after restart');
    },
  );
}
