import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database navigation exposes reusable system collections but hides internal types', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final customId = await genericStore.createDatabase(
      workspaceId: workspaceId,
      name: '書籍',
    );
    final tagType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
      name: 'タグ',
      icon: '🏷️',
    );
    final imageType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'image',
      name: '画像',
      icon: '🖼️',
    );
    final weblinkType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'weblink',
      name: 'Weblink',
      icon: '🔗',
    );
    final dailyNoteType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'dailyNote',
      name: 'Daily Note',
      icon: '📅',
    );

    final navigation = await genericStore.listDatabases(workspaceId);
    final relationTargetTypes = await genericStore.listAllDatabases(workspaceId);
    final objectTypes = await objectStore.listObjectTypes(workspaceId);

    expect(
      navigation.map((item) => item.id),
      [weblinkType.id, imageType.id, dailyNoteType.id, customId],
    );
    expect(navigation[0].name, 'Weblinks');
    expect(navigation[0].icon, '🔗');
    expect(navigation[1].name, 'Images');
    expect(navigation[1].icon, '🖼️');
    expect(navigation[2].name, 'Daily Notes');
    expect(navigation[2].icon, '📅');
    expect(navigation.map((item) => item.id), isNot(contains(tagType.id)));
    expect(
      relationTargetTypes.map((item) => item.id),
      containsAll([
        customId,
        tagType.id,
        imageType.id,
        weblinkType.id,
        dailyNoteType.id,
      ]),
    );
    expect(
      objectTypes.map((item) => item.id),
      containsAll([
        customId,
        tagType.id,
        imageType.id,
        weblinkType.id,
        dailyNoteType.id,
      ]),
    );
  });

  test('workspace Object sync makes Daily Notes available before first note is opened', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);

    await sync.syncWorkspace(workspaceId);

    final navigation = await GenericDatabaseStore(database).listDatabases(workspaceId);
    final dailyNotes = navigation.singleWhere((item) => item.name == 'Daily Notes');
    expect(dailyNotes.icon, '📅');
  });
}
