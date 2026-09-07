import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry claim with mismatched Daily Note Date is recovered', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    await service.ensureRegistry();
    final definition = await service.ensureDefinition(workspaceId);
    final wrongDateId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: '2026-09-03',
    );
    await objectStore.setPropertyValue(
      objectId: wrongDateId,
      property: definition.dateProperty,
      value: '2026-09-03',
    );
    final matchingId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: '2026-09-04',
    );
    await objectStore.setPropertyValue(
      objectId: matchingId,
      property: definition.dateProperty,
      value: '2026-09-04',
    );

    await database.customStatement(
      '''INSERT INTO daily_note_registry(workspace_id, note_date, object_id)
         VALUES (?, ?, ?)''',
      <Object?>[workspaceId, '2026-09-04', wrongDateId],
    );

    final note = await service.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 4),
    );

    expect(note.id, matchingId);
    expect(note.values[definition.dateProperty.id], '2026-09-04');
    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects.map((object) => object.id), containsAll(<int>[wrongDateId, matchingId]));
    expect(objects, hasLength(2));

    final registry = await database.customSelect(
      '''SELECT object_id FROM daily_note_registry
         WHERE workspace_id = ? AND note_date = ?''',
      variables: <Variable<Object>>[
        Variable<int>(workspaceId),
        const Variable<String>('2026-09-04'),
      ],
    ).getSingle();
    expect(registry.read<int>('object_id'), matchingId);
  });
}
