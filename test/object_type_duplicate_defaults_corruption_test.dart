import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/object_type_management_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicateSchema rejects stale visiblePropertyIds atomically', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: sourceId,
      name: 'Value',
      type: ObjectPropertyType.text,
    );
    await _seedCorruptDefaults(
      database: database,
      defaultsStore: defaultsStore,
      objectTypeId: sourceId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId, 999999],
        propertyOrder: <int>[propertyId],
      ),
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsA(isA<FormatException>()),
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.map((type) => type.id).toList(), <int>[sourceId]);
  });

  test('duplicateSchema rejects stale propertyOrder atomically', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final management = ObjectTypeManagementStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final sourceId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: sourceId,
      name: 'Value',
      type: ObjectPropertyType.text,
    );
    await _seedCorruptDefaults(
      database: database,
      defaultsStore: defaultsStore,
      objectTypeId: sourceId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId],
        propertyOrder: <int>[propertyId, 999999],
      ),
    );

    await expectLater(
      management.duplicateSchema(objectTypeId: sourceId),
      throwsA(isA<FormatException>()),
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.map((type) => type.id).toList(), <int>[sourceId]);
  });
}

Future<void> _seedCorruptDefaults({
  required AppDatabase database,
  required ObjectTypeDefaultsStore defaultsStore,
  required int objectTypeId,
  required ObjectTypeDefaults defaults,
}) async {
  await defaultsStore.ensureSchema();
  await database.customStatement(
    '''INSERT INTO object_type_defaults(object_type_id, defaults_json, updated_at)
       VALUES (?, ?, CURRENT_TIMESTAMP)''',
    <Object?>[objectTypeId, jsonEncode(defaults.toJson())],
  );
}
