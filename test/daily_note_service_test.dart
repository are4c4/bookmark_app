import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same local date opens one Daily Note Object', () async {
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

    final morning = await service.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 2, 8),
    );
    final evening = await service.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 2, 21),
    );

    expect(evening.id, morning.id);
    expect(morning.title, '2026-09-02');
    final definition = await service.ensureDefinition(workspaceId);
    expect(morning.values[definition.dateProperty.id], '2026-09-02');
    expect(
      (await objectStore.listObjects(definition.objectType.id)).length,
      1,
    );
  });

  test('different dates create different Daily Note Objects', () async {
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

    final first = await service.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 2),
    );
    final second = await service.openOrCreate(
      workspaceId: workspaceId,
      date: DateTime(2026, 9, 3),
    );

    expect(second.id, isNot(first.id));
  });

  test('Daily Note defaults to full page and remains a system ObjectType', () async {
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

    final definition = await service.ensureDefinition(workspaceId);
    final defaults = await defaultsStore.read(definition.objectType.id);

    expect(defaults?.openMode, ObjectOpenMode.fullPage);
    expect(await genericStore.listDatabases(workspaceId), isEmpty);
  });
}
