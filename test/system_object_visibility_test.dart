import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom database list hides system object types but all-types list keeps them', () async {
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

    final customDatabases = await genericStore.listDatabases(workspaceId);
    final relationTargetTypes = await genericStore.listAllDatabases(workspaceId);
    final objectTypes = await objectStore.listObjectTypes(workspaceId);

    expect(customDatabases.map((item) => item.id), [customId]);
    expect(
      relationTargetTypes.map((item) => item.id),
      containsAll([customId, tagType.id, imageType.id]),
    );
    expect(
      objectTypes.map((item) => item.id),
      containsAll([customId, tagType.id, imageType.id]),
    );
  });
}
