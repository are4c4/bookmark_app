import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ObjectStore reports system and custom ObjectType kinds correctly', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final customId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '書籍',
    );
    final systemType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
      name: 'タグ',
      icon: '🏷️',
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    final custom = types.firstWhere((type) => type.id == customId);
    final system = types.firstWhere((type) => type.id == systemType.id);

    expect(custom.kind, ObjectTypeKind.custom);
    expect(system.kind, ObjectTypeKind.system);
    expect((await objectStore.getObjectType(systemType.id))!.kind, ObjectTypeKind.system);
  });
}
