import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/daily_note_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Note backfills missing defaults while preserving Body template',
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

    final definition = await service.ensureDefinition(workspaceId);
    await defaultsStore.write(
      objectTypeId: definition.objectType.id,
      defaults: const ObjectTypeDefaults(
        bodyTemplate: ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'daily-template',
              type: 'paragraph',
              text: 'Plan the day',
            ),
          ],
        ),
      ),
    );

    final refreshed = await service.ensureDefinition(workspaceId);
    final defaults = await defaultsStore.read(refreshed.objectType.id);

    expect(defaults, isNotNull);
    expect(defaults!.visiblePropertyIds, <int>[refreshed.dateProperty.id]);
    expect(defaults.propertyOrder, <int>[refreshed.dateProperty.id]);
    expect(defaults.openMode, ObjectOpenMode.fullPage);
    expect(defaults.bodyTemplate?.blocks.single.text, 'Plan the day');
  });

  test('Daily Note backfill preserves explicit presentation overrides', () async {
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
    await defaultsStore.write(
      objectTypeId: definition.objectType.id,
      defaults: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[],
        propertyOrder: <int>[],
        openMode: ObjectOpenMode.centerPeek,
      ),
    );

    await service.ensureDefinition(workspaceId);
    final defaults = await defaultsStore.read(definition.objectType.id);

    expect(defaults, isNotNull);
    expect(defaults!.visiblePropertyIds, isEmpty);
    expect(defaults.propertyOrder, isEmpty);
    expect(defaults.openMode, ObjectOpenMode.centerPeek);
  });
}
