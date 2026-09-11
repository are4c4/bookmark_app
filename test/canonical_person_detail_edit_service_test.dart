import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/canonical_person_detail_edit_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy-backed Person detail edits keep canonical and legacy state equal',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final bridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
      );
      final personId = await PersonObjectWriteService.forDatabase(database)
          .create(workspaceId: workspaceId, name: 'Before', note: 'old note');
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final objectId = (await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      ))!;
      final service = CanonicalPersonDetailEditService.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      var content = (await service.loader.load(
        objectTypeId: schema.objectType.id,
        objectId: objectId,
      ))!;

      content = await service.rename(content: content, title: 'After');
      expect(content.object.title, 'After');
      expect(
        (await database.select(database.people).get()).single.name,
        'After',
      );

      content = await service.setNote(
        content: content,
        property: schema.noteProperty,
        note: 'new note',
      );
      expect(content.object.values[schema.noteProperty.id], 'new note');
      expect(
        (await database.select(database.people).get()).single.note,
        'new note',
      );

      content = await service.setNote(
        content: content,
        property: schema.noteProperty,
        note: '   ',
      );
      expect(content.object.values[schema.noteProperty.id], isNull);
      expect(
        (await database.select(database.people).get()).single.note,
        isNull,
      );
    },
  );

  test('native canonical Person remains editable without creating legacy projection', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    final objectId = await objectStore.createObject(
      objectTypeId: schema.objectType.id,
      title: 'Native',
    );
    final service = CanonicalPersonDetailEditService.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    var content = (await service.loader.load(
      objectTypeId: schema.objectType.id,
      objectId: objectId,
    ))!;

    content = await service.rename(content: content, title: 'Native renamed');
    content = await service.setNote(
      content: content,
      property: schema.noteProperty,
      note: 'native note',
    );

    expect(content.object.title, 'Native renamed');
    expect(content.object.values[schema.noteProperty.id], 'native note');
    expect(await database.select(database.people).get(), isEmpty);
    expect(await bridge.legacyPersonIdForObject(workspaceId, objectId), isNull);
  });

  test(
    'missing Person mapping fails closed before canonical mutation',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final bridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
      );
      final personId = await PersonObjectWriteService.forDatabase(database)
          .create(
            workspaceId: workspaceId,
            name: 'Preserved',
            note: 'preserved note',
          );
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final objectId = (await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      ))!;
      final service = CanonicalPersonDetailEditService.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final content = (await service.loader.load(
        objectTypeId: schema.objectType.id,
        objectId: objectId,
      ))!;

      await database.customStatement(
        'DELETE FROM person_object_links WHERE workspace_id = ? AND person_id = ?',
        <Object>[workspaceId, personId],
      );

      await expectLater(
        service.rename(content: content, title: 'Must not commit'),
        throwsA(isA<StateError>()),
      );

      final object = (await objectStore.listObjects(schema.objectType.id))
          .single;
      final person = (await database.select(database.people).get()).single;
      expect(object.title, 'Preserved');
      expect(object.values[schema.noteProperty.id], 'preserved note');
      expect(person.name, 'Preserved');
      expect(person.note, 'preserved note');
    },
  );

  test(
    'ambiguous legacy identity fails closed before Person detail mutation',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final bridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
      );
      final personId = await PersonObjectWriteService.forDatabase(database)
          .create(workspaceId: workspaceId, name: 'Unique');
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final objectId = (await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      ))!;
      final duplicateId = await objectStore.createObject(
        objectTypeId: schema.objectType.id,
        title: 'Duplicate claim',
      );
      await objectStore.setPropertyValue(
        objectId: duplicateId,
        property: schema.legacyPersonIdProperty,
        value: personId,
      );
      final service = CanonicalPersonDetailEditService.fromStores(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final content = (await service.loader.load(
        objectTypeId: schema.objectType.id,
        objectId: objectId,
      ))!;

      await expectLater(
        service.setNote(
          content: content,
          property: schema.noteProperty,
          note: 'Must not commit',
        ),
        throwsA(isA<StateError>()),
      );

      final original = (await objectStore.listObjects(schema.objectType.id))
          .singleWhere((object) => object.id == objectId);
      final person = (await database.select(database.people).get()).single;
      expect(original.title, 'Unique');
      expect(original.values[schema.noteProperty.id], isNull);
      expect(person.name, 'Unique');
      expect(person.note, isNull);
    },
  );
}
