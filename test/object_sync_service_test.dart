import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live mirror follows tag changes after startup sync', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);
    await database.customStatement("INSERT INTO tags(name) VALUES ('後から追加')");

    await Future<void>.delayed(const Duration(milliseconds: 650));

    final tagType = await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
    );
    expect(tagType, isNotNull);
    final objects = await sync.objectStore.listObjects(tagType!.id);
    expect(objects.map((object) => object.title), contains('後から追加'));
  });

  test('activating another workspace replaces the previous live mirror', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaces = WorkspaceStore(database);
    final first = await workspaces.initialize();
    final second = await workspaces.createWorkspace('Second');
    final firstSync = ObjectSyncService(database);
    final secondSync = ObjectSyncService(database);
    addTearDown(firstSync.dispose);
    addTearDown(secondSync.dispose);

    await firstSync.syncWorkspace(first);
    await secondSync.syncWorkspace(second);
    await database.customStatement("INSERT INTO tags(name) VALUES ('共有タグ')");
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final firstTagType = await firstSync.systemObjectStore.getSystemObjectType(
      workspaceId: first,
      systemKey: 'tag',
    );
    final secondTagType = await secondSync.systemObjectStore.getSystemObjectType(
      workspaceId: second,
      systemKey: 'tag',
    );
    final firstObjects = await firstSync.objectStore.listObjects(firstTagType!.id);
    final secondObjects = await secondSync.objectStore.listObjects(secondTagType!.id);

    expect(firstObjects.map((object) => object.title), isNot(contains('共有タグ')));
    expect(secondObjects.map((object) => object.title), contains('共有タグ'));
  });
}
