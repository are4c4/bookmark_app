import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;
  late SystemObjectStore systemStore;
  late PersonObjectBridge bridge;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    objectStore = ObjectStore(GenericDatabaseStore(database));
    systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    bridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('legacy Person creates and repeatedly reuses one canonical Person Object', () async {
    await database.customStatement(
      "INSERT INTO people(name, note) VALUES ('Alice', 'first note')",
    );
    final personId = (await database.customSelect(
      "SELECT id FROM people WHERE name = 'Alice'",
    ).getSingle())
        .read<int>('id');

    final firstTouched = await bridge.syncLegacyPeople(workspaceId);
    final firstObjectId =
        await bridge.objectIdForLegacyPerson(workspaceId, personId);
    expect(firstObjectId, isNotNull);
    expect(firstTouched, [firstObjectId]);

    final schema = await bridge.ensurePersonObjectType(workspaceId);
    expect(schema.objectType.kind, ObjectTypeKind.system);
    expect(
      await systemStore.systemKeyForObjectType(schema.objectType.id),
      PersonObjectBridge.systemKey,
    );
    final objects = await objectStore.listObjects(schema.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.id, firstObjectId);
    expect(objects.single.title, 'Alice');
    expect(objects.single.values[schema.legacyPersonIdProperty.id], personId);
    expect(objects.single.values[schema.noteProperty.id], 'first note');
    expect(schema.legacyPersonIdProperty.type, ObjectPropertyType.number);
    expect(schema.legacyPersonIdProperty.config['system'], isTrue);
    expect(schema.legacyPersonIdProperty.config['hidden'], isTrue);
    expect(schema.legacyPersonIdProperty.isIdentityManaged, isTrue);

    final secondTouched = await bridge.syncLegacyPeople(workspaceId);
    final secondObjectId =
        await bridge.objectIdForLegacyPerson(workspaceId, personId);
    expect(secondObjectId, firstObjectId);
    expect(secondTouched, [firstObjectId]);
    expect(await objectStore.listObjects(schema.objectType.id), hasLength(1));
    expect(
      await bridge.legacyPersonIdForObject(workspaceId, firstObjectId!),
      personId,
    );
  });

  test(
    'canonical rename and note survive sync and project to legacy People',
    () async {
      await database.customStatement(
        "INSERT INTO people(name, note) VALUES ('Before', 'old note')",
      );
      final personId =
          (await database
                  .customSelect("SELECT id FROM people WHERE name = 'Before'")
                  .getSingle())
              .read<int>('id');
      await bridge.syncLegacyPeople(workspaceId);
      final objectId = (await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      ))!;
      final schema = await bridge.ensurePersonObjectType(workspaceId);

      await objectStore.renameObject(objectId, 'Canonical name');
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.noteProperty,
        value: 'canonical note',
      );
      await database.updatePerson(personId, 'Stale legacy name', 'stale note');

      await bridge.syncLegacyPeople(workspaceId);

      final sameObjectId = await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      );
      final object = (await objectStore.listObjects(schema.objectType.id))
          .single;
      expect(sameObjectId, objectId);
      expect(object.id, objectId);
      expect(object.title, 'Canonical name');
      expect(object.values[schema.noteProperty.id], 'canonical note');

      final legacy = await (database.select(
        database.people,
      )..where((person) => person.id.equals(personId))).getSingle();
      expect(legacy.name, 'Canonical name');
      expect(legacy.note, 'canonical note');
    },
  );

  test('missing link is restored from one legacy id claim without overwriting canonical state', () async {
    await database.customStatement(
      "INSERT INTO people(name, note) VALUES ('Mapped', 'legacy note')",
    );
    final personId =
        (await database
                .customSelect("SELECT id FROM people WHERE name = 'Mapped'")
                .getSingle())
            .read<int>('id');
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    final existingObjectId = await objectStore.createObject(
      objectTypeId: schema.objectType.id,
      title: 'Canonical title',
    );
    await objectStore.setPropertyValue(
      objectId: existingObjectId,
      property: schema.legacyPersonIdProperty,
      value: personId,
    );
    await objectStore.setPropertyValue(
      objectId: existingObjectId,
      property: schema.noteProperty,
      value: 'canonical note',
    );

    await bridge.syncLegacyPeople(workspaceId);

    expect(
      await bridge.objectIdForLegacyPerson(workspaceId, personId),
      existingObjectId,
    );
    final objects = await objectStore.listObjects(schema.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.title, 'Canonical title');
    expect(objects.single.values[schema.noteProperty.id], 'canonical note');
    final legacy = await (database.select(
      database.people,
    )..where((person) => person.id.equals(personId))).getSingle();
    expect(legacy.name, 'Canonical title');
    expect(legacy.note, 'canonical note');
  });

  test('ambiguous legacy id claims fail closed without creating a replacement', () async {
    await database.customStatement(
      "INSERT INTO people(name) VALUES ('Ambiguous')",
    );
    final personId = (await database.customSelect(
      "SELECT id FROM people WHERE name = 'Ambiguous'",
    ).getSingle())
        .read<int>('id');
    final schema = await bridge.ensurePersonObjectType(workspaceId);
    for (final title in ['Candidate A', 'Candidate B']) {
      final objectId = await objectStore.createObject(
        objectTypeId: schema.objectType.id,
        title: title,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: schema.legacyPersonIdProperty,
        value: personId,
      );
    }

    await expectLater(
      bridge.syncLegacyPeople(workspaceId),
      throwsStateError,
    );

    expect(await objectStore.listObjects(schema.objectType.id), hasLength(2));
    final mappings = await database.customSelect(
      'SELECT object_id FROM person_object_links WHERE workspace_id = ? AND person_id = ?',
      variables: [
        Variable<int>(workspaceId),
        Variable<int>(personId),
      ],
    ).get();
    expect(mappings, isEmpty);
  });

  test('damaged mapping fails closed instead of manufacturing another Person Object', () async {
    await database.customStatement(
      "INSERT INTO people(name) VALUES ('Stable')",
    );
    final personId = (await database.customSelect(
      "SELECT id FROM people WHERE name = 'Stable'",
    ).getSingle())
        .read<int>('id');
    await bridge.syncLegacyPeople(workspaceId);
    final objectId =
        (await bridge.objectIdForLegacyPerson(workspaceId, personId))!;
    final schema = await bridge.ensurePersonObjectType(workspaceId);

    await database.customStatement(
      '''UPDATE generic_values SET value_json = ?
         WHERE record_id = ? AND property_id = ?''',
      <Object>[
        '${personId + 1000}',
        objectId,
        schema.legacyPersonIdProperty.id,
      ],
    );

    await expectLater(
      bridge.syncLegacyPeople(workspaceId),
      throwsStateError,
    );
    expect(await objectStore.listObjects(schema.objectType.id), hasLength(1));
  });

  test('Person identity mapping is independently scoped per workspace', () async {
    await database.customStatement(
      "INSERT INTO people(name) VALUES ('Shared legacy person')",
    );
    final personId = (await database.customSelect(
      "SELECT id FROM people WHERE name = 'Shared legacy person'",
    ).getSingle())
        .read<int>('id');
    final secondWorkspaceId =
        await WorkspaceStore(database).createWorkspace('Second');

    await bridge.syncLegacyPeople(workspaceId);
    await bridge.syncLegacyPeople(secondWorkspaceId);

    final firstObjectId =
        await bridge.objectIdForLegacyPerson(workspaceId, personId);
    final secondObjectId =
        await bridge.objectIdForLegacyPerson(secondWorkspaceId, personId);
    expect(firstObjectId, isNotNull);
    expect(secondObjectId, isNotNull);
    expect(firstObjectId, isNot(secondObjectId));
  });

  test('Person schema provisioning fails closed on incompatible legacy id Property', () async {
    final type = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: PersonObjectBridge.systemKey,
      name: '人物',
      icon: '👤',
    );
    await objectStore.createProperty(
      objectTypeId: type.id,
      name: 'Legacy Person ID',
      type: ObjectPropertyType.text,
      allowSystemMutation: true,
    );

    await expectLater(
      bridge.ensurePersonObjectType(workspaceId),
      throwsStateError,
    );

    final refreshed = (await objectStore.getObjectType(type.id))!;
    expect(
      refreshed.properties
          .singleWhere((property) => property.name == 'Legacy Person ID')
          .type,
      ObjectPropertyType.text,
    );
    expect(
      refreshed.properties.where((property) => property.name == 'Note'),
      isEmpty,
      reason: 'schema preflight must fail before adding sibling Properties',
    );
  });
}
