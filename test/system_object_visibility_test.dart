import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom database list hides system object types', () async {
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
    final systemType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
      name: 'タグ',
      icon: '🏷️',
    );

    final customDatabases = await genericStore.listDatabases(workspaceId);
    final allDatabases = await genericStore.listAllDatabases(workspaceId);
    final objectTypes = await objectStore.listObjectTypes(workspaceId);

    expect(customDatabases.map((item) => item.id), [customId]);
    expect(allDatabases.map((item) => item.id), containsAll([customId, systemType.id]));
    expect(objectTypes.map((item) => item.id), containsAll([customId, systemType.id]));
  });
}
