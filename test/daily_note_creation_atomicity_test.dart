import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Note creation rolls back Object, Date and Body when registry fails',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);
    final service = DailyNoteService(
      genericStore: genericStore,
      objectStore: objectStore,
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );

    await service.ensureRegistry();
    final definition = await service.ensureDefinition(workspaceId);
    await defaultsStore.writeBodyTemplate(
      objectTypeId: definition.objectType.id,
      bodyTemplate: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'daily-template',
            type: 'paragraph',
            text: 'Template',
          ),
        ],
      ),
    );
    // Keep the Body table outside the failure transaction so this regression
    // checks that the Body row is rolled back, rather than depending on whether
    // lazy schema creation itself is also rolled back on a fresh database.
    await bodyStore.ensureSchema();
    await database.customStatement('''
      CREATE TRIGGER fail_daily_note_registry_insert
      BEFORE INSERT ON daily_note_registry
      BEGIN
        SELECT RAISE(ABORT, 'forced registry failure');
      END
    ''');

    await expectLater(
      service.openOrCreate(
        workspaceId: workspaceId,
        date: DateTime(2026, 9, 7),
      ),
      throwsA(anything),
    );

    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
    final bodyRows = await database.customSelect(
      'SELECT object_id FROM object_bodies',
    ).get();
    expect(bodyRows, isEmpty);
    final valueRows = await database.customSelect(
      'SELECT record_id FROM generic_values WHERE property_id = ?',
      variables: [
        Variable<int>(definition.dateProperty.id),
      ],
    ).get();
    expect(valueRows, isEmpty);
    final registryRows = await database.customSelect(
      'SELECT object_id FROM daily_note_registry',
    ).get();
    expect(registryRows, isEmpty);
  });
}
