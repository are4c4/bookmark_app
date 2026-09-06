import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Daily Note adoption returns a concurrent registry winner',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
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
    final legacyId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Legacy matching note',
    );
    await objectStore.setPropertyValue(
      objectId: legacyId,
      property: definition.dateProperty,
      value: '2026-09-08',
    );
    final winnerId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Concurrent winner',
    );

    await database.customStatement('''
      CREATE TRIGGER claim_daily_note_before_legacy_adoption
      BEFORE INSERT ON daily_note_registry
      WHEN NEW.note_date = '2026-09-08'
      BEGIN
        INSERT OR IGNORE INTO daily_note_registry(workspace_id, note_date, object_id)
        VALUES ($workspaceId, '2026-09-08', $winnerId);
      END
    ''');

    final opened = await service.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 8),
    );

    expect(opened.id, winnerId);
    final registryRows = await database.customSelect(
      '''SELECT object_id FROM daily_note_registry
         WHERE workspace_id = ? AND note_date = ?''',
      variables: [],
      readsFrom: const {},
    ).get();
    expect(registryRows, hasLength(1));
    expect(registryRows.single.read<int>('object_id'), winnerId);
  });

  test('failed lost-claim cleanup rolls back the newly created Daily Note',
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
    final winnerId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Concurrent winner',
    );
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
    await bodyStore.ensureSchema();

    await database.customStatement('''
      CREATE TRIGGER seed_daily_note_winner_on_duplicate_create
      AFTER INSERT ON generic_records
      WHEN NEW.database_id = ${definition.objectType.id}
        AND NEW.id <> $winnerId
      BEGIN
        INSERT OR IGNORE INTO daily_note_registry(workspace_id, note_date, object_id)
        VALUES ($workspaceId, '2026-09-09', $winnerId);
      END
    ''');
    await database.customStatement('''
      CREATE TRIGGER fail_daily_note_duplicate_cleanup
      BEFORE DELETE ON generic_records
      WHEN OLD.database_id = ${definition.objectType.id}
        AND OLD.id <> $winnerId
      BEGIN
        SELECT RAISE(ABORT, 'forced duplicate cleanup failure');
      END
    ''');

    await expectLater(
      service.openOrCreate(
        workspaceId: workspaceId,
        date: DateTime(2026, 9, 9),
      ),
      throwsA(anything),
    );

    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects.map((object) => object.id).toList(), <int>[winnerId]);
    final bodyRows = await database.customSelect(
      'SELECT object_id FROM object_bodies',
    ).get();
    expect(bodyRows, isEmpty);
    final registryRows = await database.customSelect(
      'SELECT object_id FROM daily_note_registry',
    ).get();
    expect(registryRows, isEmpty);
  });
}
