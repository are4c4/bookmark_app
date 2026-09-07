import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes reject duplicate Property ids without replacing valid defaults',
      () async {
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
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId],
        propertyOrder: <int>[propertyId],
        openMode: ObjectOpenMode.centerPeek,
      ),
    );

    for (final duplicateDefaults in <ObjectTypeDefaults>[
      ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId, propertyId],
        propertyOrder: <int>[propertyId],
      ),
      ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId],
        propertyOrder: <int>[propertyId, propertyId],
      ),
    ]) {
      await expectLater(
        defaultsStore.write(
          objectTypeId: typeId,
          defaults: duplicateDefaults,
        ),
        throwsArgumentError,
      );
    }

    final restored = await defaultsStore.read(typeId);
    expect(restored?.visiblePropertyIds, <int>[propertyId]);
    expect(restored?.propertyOrder, <int>[propertyId]);
    expect(restored?.openMode, ObjectOpenMode.centerPeek);
  });

  test('reads reject persisted duplicate Property ids without repairing the row',
      () async {
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
    await defaultsStore.ensureSchema();

    for (final corruptDefaults in <ObjectTypeDefaults>[
      ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId, propertyId],
        propertyOrder: <int>[propertyId],
      ),
      ObjectTypeDefaults(
        visiblePropertyIds: <int>[propertyId],
        propertyOrder: <int>[propertyId, propertyId],
      ),
    ]) {
      final corruptJson = jsonEncode(corruptDefaults.toJson());
      await database.customStatement(
        '''INSERT INTO object_type_defaults(object_type_id, defaults_json, updated_at)
           VALUES (?, ?, CURRENT_TIMESTAMP)
           ON CONFLICT(object_type_id)
           DO UPDATE SET defaults_json = excluded.defaults_json,
                         updated_at = CURRENT_TIMESTAMP''',
        <Object?>[typeId, corruptJson],
      );

      await expectLater(
        defaultsStore.read(typeId),
        throwsA(isA<FormatException>()),
      );

      final row = await database.customSelect(
        'SELECT defaults_json FROM object_type_defaults WHERE object_type_id = ?',
        variables: [Variable<int>(typeId)],
      ).getSingle();
      expect(row.read<String>('defaults_json'), corruptJson);
    }
  });
}
