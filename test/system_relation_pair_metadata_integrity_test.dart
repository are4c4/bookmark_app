import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system Relation provisioning rejects managed pair metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final type = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag-test',
      name: 'Tag',
      icon: '🏷️',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: type.id,
      name: 'Parent',
      type: ObjectPropertyType.objectRelation,
      config: <String, dynamic>{
        'targetObjectTypeId': type.id,
        'multiple': false,
        'bidirectional': true,
        'inversePropertyId': 999999,
        'pairRole': 'source',
      },
      allowSystemMutation: true,
    );

    await expectLater(
      systemStore.ensureRelationProperty(
        objectTypeId: type.id,
        name: 'Parent',
        targetObjectTypeId: type.id,
        multiple: false,
      ),
      throwsStateError,
    );

    final refreshed = (await objectStore.getObjectType(type.id))!;
    final parents = refreshed.properties
        .where((property) => property.name == 'Parent')
        .toList(growable: false);
    expect(parents, hasLength(1));
    expect(parents.single.id, propertyId);
    expect(parents.single.config['bidirectional'], isTrue);
    expect(parents.single.config['inversePropertyId'], 999999);
    expect(parents.single.config['pairRole'], 'source');
  });

  test('system Relation provisioning rejects any reserved pair key presence',
      () async {
    for (final metadata in <Map<String, dynamic>>[
      <String, dynamic>{'bidirectional': false},
      <String, dynamic>{'inversePropertyId': null},
      <String, dynamic>{'pairRole': 'source'},
    ]) {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final workspaceId = await WorkspaceStore(database).initialize();
      final objectStore = ObjectStore(GenericDatabaseStore(database));
      final systemStore = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final type = await systemStore.ensureSystemObjectType(
        workspaceId: workspaceId,
        systemKey: 'system-test',
        name: 'System',
        icon: '◻️',
      );
      await objectStore.createProperty(
        objectTypeId: type.id,
        name: 'Related',
        type: ObjectPropertyType.objectRelation,
        config: <String, dynamic>{
          'targetObjectTypeId': type.id,
          'multiple': true,
          ...metadata,
        },
        allowSystemMutation: true,
      );

      await expectLater(
        systemStore.ensureRelationProperty(
          objectTypeId: type.id,
          name: 'Related',
          targetObjectTypeId: type.id,
          multiple: true,
        ),
        throwsStateError,
      );
      await database.close();
    }
  });
}
