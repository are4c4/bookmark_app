import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live Object sync reports exact canonical Person semantic changes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    await database.customStatement(
      "INSERT INTO people(name, note) VALUES ('Alice', 'old note')",
    );
    final personId = (await database.customSelect(
      "SELECT id FROM people WHERE name = 'Alice'",
    ).getSingle())
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
    final personObjectId =
        (await sync.personBridge.objectIdForLegacyPerson(workspaceId, personId))!;
    expect(notifications, isEmpty);

    await sync.syncWorkspace(workspaceId);
    expect(
      notifications,
      isEmpty,
      reason: 'unchanged Person mirror passes must not notify downstream',
    );

    await database.updatePerson(personId, 'Alice renamed', 'new note');
    await sync.syncWorkspace(workspaceId);

    expect(notifications, <List<int>>[
      <int>[personObjectId],
    ]);
    final personType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'person',
    ))!;
    final personObject = (await sync.objectStore.listObjects(personType.id))
        .singleWhere((object) => object.id == personObjectId);
    expect(personObject.title, 'Alice renamed');
    final noteProperty =
        personType.properties.singleWhere((property) => property.name == 'Note');
    expect(personObject.values[noteProperty.id], 'new note');
  });
}
