import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system ObjectType schemas reject user mutations', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final systemType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
      name: 'タグ',
      icon: '🏷️',
    );
    final managedProperty = await systemStore.ensureProperty(
      objectTypeId: systemType.id,
      name: 'Parent',
      type: ObjectPropertyType.objectRelation,
      config: {'targetObjectTypeId': systemType.id, 'multiple': false},
    );

    await expectLater(
      objectStore.renameObjectType(systemType.id, '変更'),
      throwsStateError,
    );
    await expectLater(
      objectStore.deleteObjectType(systemType.id),
      throwsStateError,
    );
    await expectLater(
      objectStore.createProperty(
        objectTypeId: systemType.id,
        name: '任意列',
        type: ObjectPropertyType.text,
      ),
      throwsStateError,
    );
    await expectLater(
      objectStore.deleteProperty(managedProperty.id),
      throwsStateError,
    );
  });

  test('custom ObjectType schemas remain editable', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));

    final customId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '書籍',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: customId,
      name: '著者',
      type: ObjectPropertyType.text,
    );

    await objectStore.renameObjectType(customId, '本');
    await objectStore.deleteProperty(propertyId);
    final renamed = await objectStore.getObjectType(customId);
    expect(renamed?.name, '本');

    await objectStore.deleteObjectType(customId);
    expect(await objectStore.getObjectType(customId), isNull);
  });
}
