import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('read rejects persisted Property references owned by another ObjectType',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    await objectStore.createProperty(
      objectTypeId: sourceTypeId,
      name: 'Owned',
      type: ObjectPropertyType.text,
    );
    final foreignTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Foreign',
    );
    final foreignPropertyId = await objectStore.createProperty(
      objectTypeId: foreignTypeId,
      name: 'Foreign property',
      type: ObjectPropertyType.text,
    );

    await defaultsStore.ensureSchema();
    final rawJson = '{"visiblePropertyIds":[$foreignPropertyId]}';
    await database.customStatement(
      '''INSERT INTO object_type_defaults(object_type_id, defaults_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)''',
      <Object?>[sourceTypeId, rawJson],
    );

    await expectLater(
      defaultsStore.read(sourceTypeId),
      throwsA(isA<FormatException>()),
    );

    final row = await database.customSelect(
      'SELECT defaults_json FROM object_type_defaults '
      'WHERE object_type_id = $sourceTypeId',
    ).getSingle();
    expect(row.read<String>('defaults_json'), rawJson);
  });

  test('read rejects stale persisted Property references', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Article',
    );
    final propertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Summary',
      type: ObjectPropertyType.text,
    );
    final stalePropertyId = propertyId + 1000000;

    await defaultsStore.ensureSchema();
    await database.customStatement(
      '''INSERT INTO object_type_defaults(object_type_id, defaults_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)''',
      <Object?>[
        typeId,
        '{"propertyOrder":[$propertyId,$stalePropertyId]}',
      ],
    );

    await expectLater(
      defaultsStore.read(typeId),
      throwsA(isA<FormatException>()),
    );
  });
}
