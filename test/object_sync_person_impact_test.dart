import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'live Object sync preserves canonical Person authority over legacy edits',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      await database.customStatement(
        "INSERT INTO people(name, note) VALUES ('Alice', 'old note')",
      );
      final personId =
          (await database
                  .customSelect("SELECT id FROM people WHERE name = 'Alice'")
                  .getSingle())
              .read<int>('id');

      final notifications = <List<int>>[];
      final sync = ObjectSyncService(
        database,
        onCanonicalObjectsMirrored: (ids) async {
          notifications.add(ids.toList(growable: false));
        },
      );
      addTearDown(sync.dispose);

      await sync.syncWorkspace(workspaceId);
      final personObjectId = (await sync.personBridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      ))!;
      expect(notifications, isEmpty);

      await sync.syncWorkspace(workspaceId);
      expect(
        notifications,
        isEmpty,
        reason: 'unchanged Person reconciliation must not notify downstream',
      );

      await database.updatePerson(
        personId,
        'Stale legacy rename',
        'stale note',
      );
      await sync.syncWorkspace(workspaceId);

      expect(
        notifications,
        isEmpty,
        reason:
            'legacy compatibility edits must not become canonical mutations',
      );
      final personType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: 'person',
      ))!;
      final personObject = (await sync.objectStore.listObjects(personType.id))
          .singleWhere((object) => object.id == personObjectId);
      expect(personObject.title, 'Alice');
      final noteProperty = personType.properties.singleWhere(
        (property) => property.name == 'Note',
      );
      expect(personObject.values[noteProperty.id], 'old note');

      final legacy = await (database.select(
        database.people,
      )..where((person) => person.id.equals(personId))).getSingle();
      expect(legacy.name, 'Alice');
      expect(legacy.note, 'old note');
    },
  );
}
