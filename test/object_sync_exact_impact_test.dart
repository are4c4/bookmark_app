import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_impact.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bridge impact reports create and semantic change but not unchanged repeat',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    await _insertBookmark(
      database,
      workspaceId: workspaceId,
      url: 'https://example.com/impact',
      title: 'Impact bookmark',
    );

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    final firstCore = await sync.coreBridge.syncAllWithImpact(workspaceId);
    final bookmarkObjectId = await _bookmarkObjectId(database, workspaceId);
    expect(firstCore.objectIds, contains(bookmarkObjectId));

    final repeatCore = await sync.coreBridge.syncAllWithImpact(workspaceId);
    expect(repeatCore.isEmpty, isTrue);

    final firstWeblink =
        await sync.bookmarkWeblinkBridge.syncWorkspaceWithImpact(workspaceId);
    final weblinkType = (await sync.systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
    ))!;
    final weblinkObjectId =
        (await sync.objectStore.listObjects(weblinkType.id)).single.id;
    expect(firstWeblink.impact.objectIds, contains(bookmarkObjectId));
    expect(firstWeblink.impact.objectIds, contains(weblinkObjectId));

    final repeatWeblink =
        await sync.bookmarkWeblinkBridge.syncWorkspaceWithImpact(workspaceId);
    expect(repeatWeblink.impact.isEmpty, isTrue);

    await database.customStatement(
      'UPDATE bookmarks SET title = ? WHERE id = ?',
      <Object>['Changed bookmark', await _bookmarkId(database)],
    );
    final changedCore = await sync.coreBridge.syncAllWithImpact(workspaceId);
    expect(changedCore.objectIds, <int>[bookmarkObjectId]);
  });

  test('full sync cancels transient bridge writes and reports exact retarget impact',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final bookmarkId = await _insertBookmark(
      database,
      workspaceId: workspaceId,
      url: 'https://example.com/original',
      title: 'Original bookmark',
    );
    final notifications = <List<int>>[];
    final sync = ObjectSyncService(
      database,
      onCanonicalObjectsMirrored: (ids) async {
        notifications.add(ids.toList(growable: false));
      },
    );
    addTearDown(sync.dispose);

    // Initial activation establishes canonical state but intentionally does not
    // notify downstream projections.
    await sync.syncWorkspace(workspaceId);
    final bookmarkObjectId = await _bookmarkObjectId(database, workspaceId);
    final weblinks = WeblinkObjectService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: ObjectTypeDefaultsStore(GenericDatabaseStore(database)),
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    final originalWeblink =
        (await sync.objectStore.listObjects(definition.objectType.id)).single;
    expect(notifications, isEmpty);

    // CoreObjectBridge transiently revisits compatibility fields that the
    // Bookmark->Weblink bridge retires later in the same pass. Final canonical
    // state is unchanged, so exact pass impact must remain empty.
    await sync.syncWorkspace(workspaceId);
    expect(notifications, isEmpty);

    await database.customStatement(
      'UPDATE bookmarks SET title = ? WHERE id = ?',
      <Object>['Renamed bookmark', bookmarkId],
    );
    await sync.syncWorkspace(workspaceId);
    expect(notifications, hasLength(1));
    expect(notifications.single, <int>[bookmarkObjectId]);

    notifications.clear();
    await database.customStatement(
      'UPDATE bookmarks SET url = ? WHERE id = ?',
      <Object>['https://example.com/retargeted', bookmarkId],
    );
    await sync.syncWorkspace(workspaceId);

    final allWeblinks =
        await sync.objectStore.listObjects(definition.objectType.id);
    final retargeted = allWeblinks.singleWhere(
      (object) =>
          object.values[definition.urlProperty.id] ==
          'https://example.com/retargeted',
    );
    expect(notifications, hasLength(1));
    expect(notifications.single, contains(bookmarkObjectId));
    expect(notifications.single, contains(retargeted.id));
    expect(notifications.single, isNot(contains(originalWeblink.id)));
  });
}

Future<int> _insertBookmark(
  AppDatabase database, {
  required int workspaceId,
  required String url,
  required String title,
}) async {
  await database.customStatement(
    'INSERT INTO bookmarks(url, title) VALUES (?, ?)',
    <Object>[url, title],
  );
  final bookmarkId = await _bookmarkId(database);
  await database.customStatement(
    'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
    <Object>[bookmarkId, workspaceId],
  );
  return bookmarkId;
}

Future<int> _bookmarkId(AppDatabase database) async =>
    (await database.customSelect(
      'SELECT id FROM bookmarks ORDER BY id DESC LIMIT 1',
    ).getSingle())
        .read<int>('id');

Future<int> _bookmarkObjectId(AppDatabase database, int workspaceId) async =>
    (await database.customSelect(
      '''SELECT object_id FROM bookmark_object_links
         WHERE workspace_id = ? ORDER BY bookmark_id LIMIT 1''',
      variables: <Variable<Object>>[Variable<int>(workspaceId)],
    ).getSingle())
        .read<int>('object_id');
